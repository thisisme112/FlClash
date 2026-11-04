import argparse
import os
import re
from pathlib import Path


def is_transient_failure(log):
    source_errors = re.compile(
        r'\.dart:\d+:\d+: Error:|error •|error\[E\d+\]|'
        r'\.kt:\d+:|\.cpp\(\d+\).*error|SyntaxError:|'
        r'unresolved reference|CONFLICT \(|Manual source resolution required',
        re.IGNORECASE,
    )
    if source_errors.search(log):
        return False
    network_errors = re.compile(
        r'curl: \((5|6|7|18|28|35|52|56)\)|'
        r'HTTP(?: Error| error| status| code)?[: ]+50[234]|'
        r'connection (?:reset|timed out|refused)|'
        r'temporary failure in name resolution|'
        r'could not (?:GET|HEAD) .*(?:timed out|50[234])|'
        r'read timed out|TLS handshake timeout|runner lost communication',
        re.IGNORECASE,
    )
    return bool(network_errors.search(log))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('log', type=Path)
    args = parser.parse_args()
    transient = is_transient_failure(args.log.read_text(errors='replace'))
    result = 'transient=' + str(transient).lower()
    print(result)
    if os.environ.get('GITHUB_OUTPUT'):
        with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
            output.write(result + '\n')


if __name__ == '__main__':
    main()
