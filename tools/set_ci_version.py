import os
import re
import sys
from pathlib import Path

if len(sys.argv) != 2:
    raise SystemExit('usage: set_ci_version.py <version-name>')

version_name = sys.argv[1].strip()
if not re.fullmatch(r'\d+\.\d+\.\d+', version_name):
    raise SystemExit(f'invalid version name: {version_name}')

run_number = os.environ.get('GITHUB_RUN_NUMBER', '').strip()
if not run_number.isdigit() or int(run_number) < 1:
    raise SystemExit('GITHUB_RUN_NUMBER must be a positive integer')

path = Path('pubspec.yaml')
text = path.read_text()
updated, count = re.subn(
    r'(?m)^version:\s*\d+\.\d+\.\d+\+\d+\s*$',
    f'version: {version_name}+{int(run_number)}',
    text,
    count=1,
)
if count != 1:
    raise SystemExit('could not update exactly one pubspec version line')
path.write_text(updated)
print(f'CI version set to {version_name}+{int(run_number)}')
