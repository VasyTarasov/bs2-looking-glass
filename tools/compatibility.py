"""Language-independent BS2 recognition and per-object factual-data adaptation.

Never execute Ruby or change game databases during recognition. Archive layout,
compression, editor ids, translations and additional scripts are not build ids.
"""
from pathlib import Path
import hashlib, json, re, struct, zlib
from archive_reader import Marshal
from marshal_primitives import write

TABLES={'skill':'Skills','item':'Items','weapon':'Weapons','armor':'Armors','state':'States'}
FIELDS={
 'skill':'occasion scope speed success_rate hit_type repeats tp_gain effects damage mp_cost tp_cost stype_id required_wtype_id1 required_wtype_id2',
 'item':'occasion scope speed success_rate hit_type repeats tp_gain effects damage price consumable itype_id',
 'weapon':'price params features etype_id wtype_id',
 'armor':'price params features etype_id atype_id',
 'state':'priority restriction features auto_removal_timing min_turns max_turns chance_by_damage steps_to_remove remove_by_walking remove_at_battle_end remove_by_damage remove_by_restriction',
}
ENGINE_SHA='27647690ed16218cd988dd71069fdca67207515b2a2df775be361f0198ab6876'

def sha(data):return hashlib.sha256(data).hexdigest()

def plain(value):
    if isinstance(value,bytes):return value.decode('utf8','replace')
    if isinstance(value,bool) or value is None:return value
    if isinstance(value,float) and value.is_integer():return int(value)
    if isinstance(value,list):return [plain(x) for x in value]
    if isinstance(value,dict):return {k.lstrip('@'):plain(v) for k,v in value.items() if not k.startswith('__')}
    return value

def fingerprint(obj,kind):
    values={k:plain(obj.get('@'+k,[] if k in ('features','effects') else None)) for k in FIELDS[kind].split()}
    note=obj.get('@note',b'')
    if isinstance(note,bytes):note=note.decode('utf8','replace')
    values['tags']=sorted(re.sub(r'\s+','',x) for x in re.findall(r'<[^<>]*>',note))
    return sha(json.dumps(values,sort_keys=True,ensure_ascii=True,separators=(',',':')).encode())

def script_rows(raw):
    reader=Marshal(raw);rows=reader.read()
    if reader.pos!=len(raw) or not isinstance(rows,list) or not 50<=len(rows)<=4096:
        raise ValueError('Invalid or incomplete RPG Maker script table')
    total=0;code=[]
    for row in rows:
        if not isinstance(row,list) or len(row)!=3 or not isinstance(row[1],bytes) or not isinstance(row[2],bytes):
            raise ValueError('Invalid RPG Maker script entry')
        inflater=zlib.decompressobj();body=inflater.decompress(row[2],8*1024*1024)
        if not inflater.eof or inflater.unused_data or inflater.unconsumed_tail:
            raise ValueError('Invalid or excessive compressed game script')
        total+=len(body)
        if total>32*1024*1024:raise ValueError('Excessive game script table')
        if row[1]==b'DisplayMod':
            raise ValueError('DisplayMod is already installed. Remove it with its own uninstaller before installing QoL Pack.')
        code.append(body.replace(b'\r\n',b'\n'))
    joined=b'\n'.join(code)
    for name in (b'Game_Action',b'Game_Battler',b'Game_Actor',b'Game_Party',b'Scene_Battle',b'Window_Base'):
        if not re.search(rb'\bclass\s+'+name+rb'\b',joined):raise ValueError('Required BLACK SOULS II class missing: '+name.decode())
    if not any(row[1]==b'Main' for row in rows):raise ValueError('Game entry point Main is missing')
    return rows,sha(b'\0'.join(body for body in code if body.strip()))

def engine(game):
    game=Path(game)
    for rel in ('Game.exe','Game.ini','System/RGSS301.dll'):
        path=game/rel
        if not path.is_file() or path.is_symlink():raise ValueError('Required game file missing or linked: '+rel)
    if sha((game/'System/RGSS301.dll').read_bytes())!=ENGINE_SHA:
        raise ValueError('This RGSS engine is not supported by the native display/input components. RGSS301 from BLACK SOULS II is required.')
    with (game/'Game.exe').open('rb') as f:
        header=f.read(64)
        if len(header)<64 or header[:2]!=b'MZ':raise ValueError('Game.exe is not a Windows game executable')
        f.seek(struct.unpack_from('<I',header,60)[0]);pe=f.read(6)
    if pe!=b'PE\0\0L\x01':raise ValueError('The 32-bit RPG Maker game executable is required')
    raw=(game/'Game.ini').read_bytes()
    text=raw.decode('utf8','replace')
    values={m.group(1).lower():m.group(2).strip().strip('"').replace('\\','/').removeprefix('./') for m in re.finditer(r'^\s*(Library|Scripts)\s*=\s*(.*?)\s*$',text,re.M|re.I)}
    if values.get('library','').casefold()!='system/rgss301.dll' or values.get('scripts','').casefold()!='data/scripts.rvdata2':
        raise ValueError('Unsupported Game.ini engine or Scripts path; expected System/RGSS301.dll and Data/Scripts.rvdata2. The game title may be in any language.')

def probe(game,raw,read_data,root,language='auto'):
    engine(game);rows,script_hash=script_rows(raw)
    contract=json.loads((Path(root)/'compatibility-contract.json').read_text(encoding='utf8'))
    tables={};raw_hashes={}
    for kind,table in TABLES.items():
        data=read_data('Data/'+table+'.rvdata2')
        if len(data)>64*1024*1024:raise ValueError('Excessive game database: '+table)
        decoded=Marshal(data).read()
        if not isinstance(decoded,list) or len(decoded)>32768:raise ValueError('Invalid game database: '+table)
        tables[kind]=decoded;raw_hashes['Data/'+table+'.rvdata2']=sha(data)
    for table in ('Actors','Classes','System'):
        name='Data/'+table+'.rvdata2';data=read_data(name)
        if len(data)>64*1024*1024:raise ValueError('Excessive game database: '+table)
        parser=Marshal(data);decoded=parser.read()
        valid=(isinstance(decoded,dict) and decoded.get('__class__')=='RPG::System') if table=='System' else (isinstance(decoded,list) and 1<len(decoded)<=32768)
        if parser.pos!=len(data) or not valid:raise ValueError('Invalid game database: '+table)
        raw_hashes[name]=sha(data)
    matches=0
    for ident,expected in contract['identity_anchors'].items():
        i=int(ident);obj=tables['skill'][i] if i<len(tables['skill']) else None
        if isinstance(obj,dict) and fingerprint(obj,'skill')==expected:matches+=1
    if matches<contract['minimum_anchors']:
        raise ValueError('The selected folder is not a recognized BLACK SOULS II database, or its core mechanics were replaced. No game files were changed.')
    excluded=[];letters=[]
    for kind,table in tables.items():
        for i,obj in enumerate(table):
            if not isinstance(obj,dict):continue
            uid=kind+':'+str(i);allowed=contract['objects'].get(uid)
            if allowed and fingerprint(obj,kind) not in allowed:excluded.append(uid)
            name=obj.get('@name',b'')
            if isinstance(name,bytes):letters.append(name.decode('utf8','replace'))
    sample=' '.join(letters)
    ru=len(re.findall('[А-Яа-яЁё]',sample));latin=len(re.findall('[A-Za-z]',sample));other=len(re.findall('[\u3040-\u30ff\u3400-\u9fff\uac00-\ud7af]',sample))
    native='ru' if ru>max(20,latin//3) else 'other' if other>max(20,latin//3) else 'en'
    locale=('ru' if native=='ru' else 'en') if language=='auto' else language
    profile={'scripts':[[r[0].decode('ascii','replace') if isinstance(r[0],bytes) else r[0],r[1].decode('utf8','replace'),sha(r[2])] for r in rows if r[1] not in (b'BS2QoL bootstrap',b'BS2Modules bootstrap')],
             'files':{rel:sha((Path(game)/rel).read_bytes()) for rel in ('Game.exe','Game.ini','System/RGSS301.dll')}}
    profile['files'].update(raw_hashes)
    report={'language':locale,'game_language':native,'validation':'BS2 structure and mechanics','known_scripts':script_hash in contract['known_script_sets'],'identity_anchors':matches,'live_property_cards':len(excluded),'script_count':len(rows)}
    policy=write({'schema':1,'native_language':native,'excluded':excluded})
    return profile,report,policy

def set_probe(installer,report,policy):
    installer._compatibility_result=report
    installer._compatibility_policy=policy
