"""Public module choices, dependencies and migration from preview configurations."""
from pathlib import Path
import json
MANIFEST=json.loads((Path(__file__).resolve().parents[1]/'modules.json').read_text(encoding='utf8'))
IDS=[m['id'] for m in MANIFEST]
REQUIRES={m['id']:m['requires'] for m in MANIFEST}
DEFAULTS=[m['id'] for m in MANIFEST if m['default']]

def expand(selected):
    result=set(selected)
    if result-set(IDS):raise ValueError('Unknown module selection')
    while True:
        prior=result.copy()
        for name in prior:result.update(REQUIRES[name])
        if result==prior:return sorted(result)

def parse(text):
    return {line.split('=')[0] for line in text.splitlines() if line.strip().endswith('=1')}

def migrate(text):
    old=parse(text);result=old&set(IDS)
    if old&{'controls','run_toggle','sound','learned_books'}:result.add('basic_qol')
    if 'effects' in old:result.add('reference_cards')
    if {'semantic_groups','loadouts'}<=old:result.add('macros')
    # These features were always part of the preview's shared layer.
    result.update({'battle_speed','map_highlight'})
    # Automatic support is a newly explicit opt-in module.
    result.discard('battle_support')
    return expand(result)

def for_installation(text,version,current_version):
    if not text:return DEFAULTS.copy()
    # Stable releases share the same public module switches. Preview migration
    # would silently enable features or discard the automatic-support choice.
    if version in ('1.0','1.01','1.02',current_version):
        return sorted(parse(text)&set(IDS))
    return migrate(text)

def configuration(selected):
    active=expand(selected)
    return ''.join(name+'='+str(int(name in active))+'\n' for name in IDS).encode('ascii')
