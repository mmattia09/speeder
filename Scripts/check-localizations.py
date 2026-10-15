#!/usr/bin/env python3
"""Validate language parity, format arguments and literal UI message coverage."""
import json
import re
import subprocess
from pathlib import Path
root = Path(__file__).resolve().parent.parent
tables = {}
for path in sorted((root / 'Resources').glob('*.lproj/Localizable.strings')):
    tables[path.parent.stem] = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(path)]))
assert set(tables) == {'en', 'it', 'fr', 'es', 'de'}
base = tables['en']
for language, table in tables.items():
    assert table.keys() == base.keys(), f'Missing keys: {language}'
    for key, value in table.items():
        assert re.findall(r'%(?:lld|@)', key) == re.findall(r'%(?:lld|@)', value), (language, key)
pattern = r'(?:Text|Button|Label|Menu|Picker|ColorPicker|Toggle|sectionLabel|detail|L|\.help|\.accessibilityLabel|\.alert)\(\s*"((?:[^"\\]|\\.)*)"'
missing = set()
for path in (root / 'Sources/Speeder').glob('*.swift'):
    for key in re.findall(pattern, path.read_text()):
        if '\\(' in key:
            continue
        key = key.replace('\\n', '\n').replace('\\"', '"')
        if key not in base:
            missing.add(key)
assert not missing, f'Untranslated literal messages: {sorted(missing)}'
print(f'{len(base)} messages validated in {len(tables)} languages')
