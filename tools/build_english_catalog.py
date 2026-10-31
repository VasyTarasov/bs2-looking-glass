"""Build English factual data from the exact supported English database.

Requires a user's local game database for reproducibility; no original game
descriptions, scripts, assets or personal saves are copied into the mod.
"""
from pathlib import Path
import argparse,hashlib,json,re
from install import ROOT
from archive_reader import Marshal,clean
from marshal_primitives import read,write
KINDS={'skill':'Skills','item':'Items','weapon':'Weapons','armor':'Armors','state':'States'}
PARAMS=['Max HP','Max MP','ATK','DEF','MAT','MDF','AGI','LUK']
def build(data_path):
    data_path=Path(data_path).resolve()
    if any(p.casefold()=='secrets' for p in data_path.parts):raise ValueError('Protected source refused')
    profile=json.loads((ROOT/'build_profile.en.json').read_text(encoding='utf8'))
    tables={}
    for kind,table in KINDS.items():
        path=data_path/(table+'.rvdata2');raw=path.read_bytes()
        if hashlib.sha256(raw).hexdigest()!=profile['files']['Data/'+path.name]:raise ValueError('Unsupported English database: '+table)
        tables[kind]=clean(Marshal(raw).read())
    catalog=read((ROOT/'mod/BS2Suite/catalog_v1.rvdata2').read_bytes());changed=[];notes=0
    for entry in catalog['entries']:
        native=tables[entry['kind']][entry['id']]
        if entry['names']['en']!=native['@name']:raise ValueError('Non-canonical English name: '+entry['uid'])
        if entry['kind'] in ('weapon','armor') and entry['raw_mechanics']['params']!=native['@params']:
            entry['raw_mechanics']['params']=native['@params'];changed.append(entry['uid'])
            values=[PARAMS[i]+' '+('+' if n>0 else '')+str(n) for i,n in enumerate(native['@params']) if n]
            pos=[PARAMS[i]+' +'+str(n) for i,n in enumerate(native['@params']) if n>0]
            neg=[PARAMS[i]+' '+str(n) for i,n in enumerate(native['@params']) if n<0]
            display=entry['display']['en'];prefix='Flat item bonuses: '
            lines=[prefix+', '.join(v)+'.' for v in [pos,neg] if v]
            for key in ('lines','required_lines'):
                display[key]=lines+[s for s in display[key] if not s.startswith(prefix)]
            for key in display['blocks']:
                display['blocks'][key]=[s for s in display['blocks'][key] if not s.startswith(prefix)]
            if pos:display['blocks']['benefits'].insert(0,prefix+', '.join(pos)+'.')
            if neg:display['blocks']['drawbacks'].insert(0,prefix+', '.join(neg)+'.')
            display['brief']='; '.join(s.rstrip('.') for s in lines+display['blocks']['drawbacks'][1:])
            for section in entry['details']['en']:
                section['lines']=['Item bonuses: '+' · '.join(values) if s.startswith('Item bonuses: ') else s for s in section['lines']]
        for section in entry['details']['en']:
            if section['title']=='Weapon shelves':
                for i,line in enumerate(section['lines']):
                    if re.search('[А-Яа-яЁё]',line):section['lines'][i]=entry['display']['en']['brief'];notes+=1
        for value in [entry['display']['en'],entry['details']['en']]:
            if re.search('[А-Яа-яЁё]',json.dumps(value,ensure_ascii=False)):raise ValueError('Untranslated English factual text: '+entry['uid'])
    catalog['metadata']['game_language']='en'
    catalog['metadata']['native_english_stat_overrides']=changed
    path=ROOT/'mod/BS2Suite/catalog_v1.en.rvdata2';raw=write(catalog)
    if read(raw)!=catalog:raise ValueError('Catalog serialization mismatch')
    path.write_bytes(raw)
    assets_path=ROOT/'runtime-assets.json';assets=json.loads(assets_path.read_text(encoding='utf8'))
    assets['mod/BS2Suite/catalog_v1.en.rvdata2']={'sha256':hashlib.sha256(raw).hexdigest(),'kind':'generated factual English catalog; exact native stats and names; no original descriptions or scripts'}
    assets_path.write_text(json.dumps(assets,indent=2)+'\n',encoding='utf8')
    result={'result':'PASS','entries':len(catalog['entries']),'stat_overrides':changed,'legacy_notes_replaced':notes,'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}
    (ROOT/'localization/english-catalog.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
    return result
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--data',required=True,type=Path);a=p.parse_args();print(json.dumps(build(a.data)))
