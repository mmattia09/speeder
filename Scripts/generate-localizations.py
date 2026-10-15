#!/usr/bin/env python3
"""Generate standard Apple .strings files; reject missing/unsafe translations."""
import json
import re
from pathlib import Path
root = Path(__file__).resolve().parent.parent
languages = ('en', 'it', 'fr', 'es', 'de')
tables = {language: {} for language in languages}
for number, line in enumerate((root / 'Scripts/localizations.txt').read_text().splitlines(), 1):
    if not line.strip():
        continue
    cells = [value.replace('\\n', '\n') for value in line.split('|')]
    assert len(cells) == 5 and all(cells), f'Incomplete row {number}'
    key = cells[0]
    assert key not in tables['en'], f'Duplicate key {key}'
    tokens = re.findall(r'%(?:lld|@)', key)
    for language, value in zip(languages, cells):
        assert re.findall(r'%(?:lld|@)', value) == tokens, f'Format mismatch: {language}: {key}'
        tables[language][key] = value
for language, table in tables.items():
    for key in ('Speeder', 'wpm', 'WPM', 'JSON…', 'CSV…', 'OK', '%@ wpm', '%lld wpm', '%lld / 3', '%@ · %@ wpm · %@'):
        table[key] = key
    table['Accent %@'] = {'en':'Accent %@','it':'Accento %@','fr':'Accent %@','es':'Acento %@','de':'Akzent %@'}[language]
    table['%lld percent'] = {'en':'%lld percent','it':'%lld per cento','fr':'%lld pour cent','es':'%lld por ciento','de':'%lld Prozent'}[language]
    directory = root / 'Resources' / f'{language}.lproj'
    directory.mkdir(parents=True, exist_ok=True)
    content = '\n'.join(f'{json.dumps(key, ensure_ascii=False)} = {json.dumps(value, ensure_ascii=False)};' for key, value in sorted(table.items()))
    (directory / 'Localizable.strings').write_text(content + '\n')
print(f'Generated {len(tables["en"])} keys in {len(languages)} languages')
