import argparse
import json
import os
import re
import subprocess
from pathlib import Path


class MergeConflict(RuntimeError):
    pass


_MISSING = object()


def merge_json(base, ours, theirs, path=''):
    if ours == theirs or theirs == base:
        return ours
    if ours == base:
        return theirs
    if isinstance(ours, dict) and isinstance(theirs, dict):
        original = base if isinstance(base, dict) else {}
        merged = {}
        for key in dict.fromkeys([*ours, *theirs]):
            value = merge_json(
                original.get(key, _MISSING),
                ours.get(key, _MISSING),
                theirs.get(key, _MISSING),
                f'{path}/{key}',
            )
            if value is not _MISSING:
                merged[key] = value
        return merged
    raise MergeConflict(f'Conflicting translations: {path}')


def git(*args, check=True):
    return subprocess.run(['git', *args], check=check, capture_output=True)


def output(name, value):
    print(f'{name}={value}')
    destination = os.environ.get('GITHUB_OUTPUT')
    if destination:
        with open(destination, 'a', encoding='utf-8') as stream:
            stream.write(f'{name}={value}\n')


def version_pins(text):
    pins = {}
    for name, pattern in [
        ('FLUTTER_VERSION', r'\d+\.\d+\.\d+'),
        ('GO_VERSION', r'\d+\.\d+\.\d+'),
        ('NDK_VERSION', r'r\d+[a-z]?'),
    ]:
        match = re.search(rf'^  {name}:\s*[\'"]?([^\s\'"]+)', text, re.MULTILINE)
        if not match or not re.fullmatch(pattern, match[1]):
            raise ValueError(f'Missing or unsupported upstream pin: {name}')
        pins[name.lower()] = match[1]
    return pins


def is_generated(path):
    return path.startswith((
        'lib/l10n/',
        'lib/models/generated/',
        'lib/providers/generated/',
        'lib/database/generated/',
    ))


def file_at(revision, path):
    result = git('show', f'{revision}:{path}', check=False)
    return result.stdout if result.returncode == 0 else None


def restore_file(path, contents):
    destination = Path(path)
    if contents is None:
        git('rm', '-f', '--ignore-unmatch', '--', path)
        if destination.is_file():
            destination.unlink()
    else:
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(contents)
        git('add', '--', path)


def conflicts():
    return [
        path for path in git('diff', '--name-only', '--diff-filter=U', '-z')
        .stdout.decode().split('\0') if path
    ]


def preserve_workflows():
    previous = git('ls-tree', '-r', '--name-only', 'HEAD', '--', '.github/workflows').stdout.decode().splitlines()
    current = git('ls-files', '--', '.github/workflows').stdout.decode().splitlines()
    for path in sorted(set(previous + current)):
        restore_file(path, file_at('HEAD', path))


def merge_upstream(revision):
    if git('merge-base', '--is-ancestor', revision, 'HEAD', check=False).returncode == 0:
        return
    result = git('merge', '--no-ff', '--no-commit', revision, check=False)
    if result.returncode not in (0, 1):
        raise RuntimeError(result.stderr.decode(errors='replace'))
    preserve_workflows()
    for path in conflicts():
        if path.startswith('arb/') and path.endswith('.arb'):
            versions = [file_at(f':{stage}', path) for stage in (1, 2, 3)]
            if versions[1] is None or versions[2] is None:
                continue
            base, ours, theirs = [json.loads(value) if value is not None else {} for value in versions]
            try:
                value = merge_json(base, ours, theirs)
            except MergeConflict:
                continue
            restore_file(path, (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode())
        elif is_generated(path):
            # The workflow regenerates these after merging their source models and ARBs.
            contents = file_at('HEAD', path)
            restore_file(path, contents if contents is not None else file_at(revision, path))
    unresolved = conflicts()
    if unresolved:
        raise MergeConflict('Manual source resolution required: ' + ', '.join(unresolved))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('operation', choices=['prepare', 'merge'])
    parser.add_argument('--upstream', default='upstream/main')
    parser.add_argument('--force', action='store_true')
    args = parser.parse_args()
    revision = git('rev-parse', '--verify', args.upstream + '^{commit}').stdout.decode().strip()
    if args.operation == 'merge':
        merge_upstream(revision)
        return
    text = git('show', f'{revision}:.github/workflows/build.yaml').stdout.decode()
    for name, value in version_pins(text).items():
        output(name, value)
    changed = git('merge-base', '--is-ancestor', revision, 'HEAD', check=False).returncode != 0
    output('upstream_sha', revision)
    output('run', 'true' if changed or args.force else 'false')


if __name__ == '__main__':
    main()
