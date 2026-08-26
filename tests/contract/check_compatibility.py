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
    if connectors['1.x']['minimum_release'] != '1.0.8':
        raise AssertionError('connector 1.x baseline changed unexpectedly')
    if connectors['2.x']['moodle'] != ['5.2']:
        raise AssertionError('connector 2.x must remain scoped to Moodle 5.2')
    if connectors['2.x']['minimum_release'] != '2.0.8':
        raise AssertionError('connector 2.x baseline changed unexpectedly')
    if connectors['2.x']['status'] != 'rollout-gate':
        raise AssertionError('connector 2.x must remain gated until Moodle CI passes')

    superset = compatibility['superset']
    if superset['build'] != 'source':
        raise AssertionError('superset build must be "source"')
    if superset['version'] != '6.1.0':
        raise AssertionError('superset version changed unexpectedly')

    marker = (ROOT / 'superset' / '.xpbuilder-vendor').read_text(encoding='utf-8')
    if superset['source_tag'] not in marker:
        raise AssertionError('vendored source tag does not match compatibility.json')
    if superset['source_commit'] not in marker:
        raise AssertionError('vendored source commit does not match compatibility.json')

    dockerfile = (ROOT / 'Dockerfile').read_text(encoding='utf-8')
    if re.search(r'^\s*FROM\s+apache/superset', dockerfile, re.M):
        raise AssertionError('runtime must be built from the vendored source, not a registry image')
    if 'apache/superset:latest' in dockerfile:
        raise AssertionError('floating Superset image tag is forbidden')
    if 'superset-src' not in dockerfile:
        raise AssertionError('Dockerfile is missing the source prep stage')

    print('Compatibility contract checks passed')


if __name__ == '__main__':
    main()
