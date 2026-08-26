#!/usr/bin/env python3

import json
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]


def main():
    version = (ROOT / 'VERSION').read_text(encoding='utf-8').strip()
    compatibility = json.loads(
        (ROOT / 'compatibility.json').read_text(encoding='utf-8')
    )

    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise AssertionError(f'VERSION is not semantic: {version}')
    if compatibility['xpbuilder_version'] != version:
        raise AssertionError('VERSION and compatibility.json disagree')
    if compatibility['contract_version'] != '1.0':
        raise AssertionError('unexpected connector contract version')

    connectors = compatibility['connectors']
    if connectors['1.x']['moodle'] != ['4.5', '5.0', '5.1']:
        raise AssertionError('connector 1.x Moodle range changed unexpectedly')
    if connectors['2.x']['moodle'] != ['5.2']:
        raise AssertionError('connector 2.x must remain scoped to Moodle 5.2')

    dockerfile = (ROOT / 'Dockerfile').read_text(encoding='utf-8')
    superset = compatibility['superset']
    expected = f"{superset['image']}@{superset['digest']}"
    if expected not in dockerfile:
        raise AssertionError('Dockerfile base image does not match compatibility.json')
    if 'apache/superset:latest' in dockerfile:
        raise AssertionError('floating Superset image tag is forbidden')

    print('Compatibility contract checks passed')


if __name__ == '__main__':
    main()
