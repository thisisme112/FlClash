import argparse
import datetime
import json
import os
import re
import subprocess
import time
from pathlib import Path


UNAVAILABLE_LOG = 'GitHub Actions job log unavailable.'


def failed_step_log(job, log):
    windows = []
    for step in job.get('steps', []):
        if step.get('conclusion') == 'failure' and step.get('started_at') and step.get('completed_at'):
            windows.append((step['started_at'], step['completed_at']))
    if not windows:
        return log

    def timestamp(value):
        return datetime.datetime.fromisoformat(value.replace('Z', '+00:00'))

    ranges = [(timestamp(start), timestamp(end) + datetime.timedelta(seconds=1)) for start, end in windows]
    lines = []
    for line in log.splitlines():
        match = re.match(r'^(\d{4}-\d{2}-\d{2}T[0-9:.]+Z)', line)
        if match and any(start <= timestamp(match[1]) <= end for start, end in ranges):
            lines.append(line)
    return '\n'.join(lines) if lines else log


def github_api(endpoint):
    result = subprocess.run(['gh', 'api', endpoint], check=True, capture_output=True)
    return result.stdout


def read_job_log(api, endpoint):
    for delay in (3, 6):
        try:
            return api(endpoint).decode(errors='replace')
        except subprocess.CalledProcessError:
            time.sleep(delay)
    return api(endpoint).decode(errors='replace')


def collect_failed_logs(repo, run, destination, api=github_api, *, attempt=1):
    if not re.fullmatch(r'[\w.-]+/[\w.-]+', repo) or not str(run).isdigit() or attempt < 1:
        raise ValueError('Invalid repository, run ID or attempt')
    destination.parent.mkdir(parents=True, exist_ok=True)
    try:
        jobs = json.loads(api(f'repos/{repo}/actions/runs/{run}/attempts/{attempt}/jobs?per_page=100'))
    except subprocess.CalledProcessError as error:
        print(f'::warning::Could not list jobs for run {run} attempt {attempt} (gh exit {error.returncode}).')
        destination.write_text(UNAVAILABLE_LOG + '\n')
        return 'unknown'
    destination.with_suffix('.jobs.json').write_text(json.dumps(jobs, indent=2))
    sections = []
    findings = set()
    for job in jobs['jobs']:
        if job['conclusion'] not in ('failure', 'timed_out', 'startup_failure'):
            continue
        job_id = int(job['id'])
        try:
            log = read_job_log(api, f'repos/{repo}/actions/jobs/{job_id}/logs')
        except subprocess.CalledProcessError as error:
            print(f'::warning::Could not download log for job {job_id} (gh exit {error.returncode}).')
            failed_log = UNAVAILABLE_LOG
        else:
            failed_log = failed_step_log(job, log)
        sections.append(job['name'] + '\n' + failed_log)
        findings.add(classify_failure(failed_log))
    destination.write_text('\n\n'.join(sections))
    if 'source' in findings:
        return 'source'
    if not findings or 'unknown' in findings:
        return 'unknown'
    return 'cache' if 'cache' in findings else 'transient'


def classify_failure(log):
    source_errors = re.compile(
        r'\.dart:\d+:\d+: Error:|error •|error\[E\d+\]|'
        r'\.kt:\d+:|\.cpp\(\d+\).*error|SyntaxError:|'
        r'unresolved reference|CONFLICT \(|Manual source resolution required|upload-pack: not our ref|'
        r'Some tests failed|TestFailure|\[E\]',
        re.IGNORECASE,
    )
    if UNAVAILABLE_LOG in log:
        return 'unknown'
    if source_errors.search(log):
        return 'source'
    if re.search(r'could not read workspace metadata from .*\.gradle[/\\]caches[/\\]', log, re.IGNORECASE):
        return 'cache'
    network_errors = re.compile(
        r'curl: \((5|6|7|18|28|35|52|56)\)|'
        r'HTTP(?: Error| error| status| code)?[: ]+50[234]|'
        r'connection (?:reset|timed out|refused)|'
        r'temporary failure in name resolution|'
        r'could not (?:GET|HEAD) .*(?:timed out|50[234])|'
        r'read timed out|TLS handshake timeout|runner lost communication',
        re.IGNORECASE,
    )
    return 'transient' if network_errors.search(log) else 'unknown'


def is_transient_failure(log):
    return classify_failure(log) == 'transient'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('log', type=Path, nargs='?')
    parser.add_argument('--collect', action='store_true')
    parser.add_argument('--repo')
    parser.add_argument('--run')
    parser.add_argument('--attempt', type=int, default=1)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    if args.collect:
        finding = collect_failed_logs(args.repo, args.run, args.output, attempt=args.attempt)
        result = f'finding={finding}'
    else:
        if args.log is None:
            parser.error('A log path is required')
        transient = is_transient_failure(args.log.read_text(errors='replace'))
        result = 'transient=' + str(transient).lower()
    print(result)
    if os.environ.get('GITHUB_OUTPUT'):
        with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
            output.write(result + '\n')


if __name__ == '__main__':
    main()
