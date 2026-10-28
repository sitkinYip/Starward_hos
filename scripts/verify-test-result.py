#!/usr/bin/env python3
"""Fail closed on absent, empty, ignored, or unsuccessful Hypium Local Test reports."""

import json
from pathlib import Path
import re
import sys

report = Path(sys.argv[1])
if not report.is_file():
    raise SystemExit('FAIL: Hypium did not produce test_result.txt.')
content = report.read_text()
results = re.findall(r'^result=(Success|Error|Failure|Ignore)\s*$', content, re.MULTILINE)
tests = re.findall(r'^test=(.+)$', content, re.MULTILINE)
success = results.count('Success')
failed = results.count('Error') + results.count('Failure')
ignored = results.count('Ignore')
summary = {'tests': len(tests), 'passed': success, 'failed': failed, 'ignored': ignored, 'source': str(report)}
output = Path('artifacts/validation/local-test-summary.json')
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n')
print(json.dumps(summary, ensure_ascii=False))
if not tests or not results or success != len(tests) or failed or ignored:
    raise SystemExit('FAIL: Missing, incomplete, ignored, or failed Hypium tests.')
