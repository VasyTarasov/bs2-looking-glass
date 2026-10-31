"""Selective, reversible installer for the verified loose-data build of BS2."""
from pathlib import Path
import argparse, hashlib, json, os, shutil, sys, zlib
sys.dont_write_bytecode = True
from archive_reader import Marshal
from process_check import target_running

ROOT = Path(__file__).resolve().parent.parent
VERSION = '1.0'
MANIFEST=json.loads((ROOT/'modules.json').read_text(encoding='utf8'))
IDS=[m['id'] for m in MANIFEST]
DEFAULTS=[m['id'] for m in MANIFEST if m['default']]
NAME = b'BS2Suite bootstrap'
QOL_BOOT = b'''# encoding: UTF-8
path = File.join(Dir.pwd, 'Mods', 'BS2QoL', 'main.rb')
source = File.open(path, 'rb') { |file| file.read }
source.force_encoding('UTF-8')
eval(source, TOPLEVEL_BINDING, path, 1)
'''
MODULES_BOOT=QOL_BOOT.replace(b'BS2QoL', b'BS2Modules')
BOOT = b'''# encoding: UTF-8
begin
  path = File.join(Dir.pwd, 'Mods', 'BS2Suite', 'main.rb')
  source = File.open(path, 'rb') { |file| file.read }
  eval(source.force_encoding('UTF-8'), TOPLEVEL_BINDING, path, 1)
rescue Exception => original_error
  begin
    config = File.join(Dir.pwd, 'BS2Suite', 'modules.ini')
    if File.file?(config) && File.size(config) < 8192 && File.open(config, 'rb') { |f| f.read }.each_line.any? { |line| line.strip == 'debug=1' }
      directory = File.join(Dir.pwd, 'BS2Suite', 'debug')
      Dir.mkdir(directory) unless File.directory?(directory)
      File.open(File.join(directory, 'bootstrap.log'), 'ab') do |file|
        file.puts Time.now.utc.to_s + ' ' + original_error.class.to_s + ': ' + original_error.message
        file.puts original_error.backtrace
        file.flush
      end
    end
  rescue StandardError
  end
  raise original_error
end
'''

def digest(data): return hashlib.sha256(data).hexdigest()

def number(n):
    if n == 0: return b'\0'
    if 0 < n < 123: return bytes([n+5])
    if -124 < n < 0: return bytes([(n-5)&255])
    size=next(i for i in range(1,5) if -(1<<(8*i))<=n<(1<<(8*i)))
    return bytes([size if n>0 else (-size)&255])+(n&((1<<(size*8))-1)).to_bytes(size,'little')

def dump(value):
    if isinstance(value,int): return b'i'+number(value)
    if isinstance(value,bytes): return b'"'+number(len(value))+value
    if isinstance(value,list): return b'['+number(len(value))+b''.join(dump(v) for v in value)
    raise TypeError(type(value))

def table(raw):
    reader=Marshal(raw); rows=reader.read()
    if reader.pos != len(raw) or not isinstance(rows,list): raise ValueError('Invalid script table')
    return rows

def validate_scripts(raw, profile):
    rows=table(raw)
    baseline=[];qol=0
    for row in rows:
        if row[1] in (b'BS2QoL bootstrap',b'BS2Modules bootstrap'):
            expected=QOL_BOOT if row[1]==b'BS2QoL bootstrap' else MODULES_BOOT
            if zlib.decompress(row[2]) != expected: raise ValueError('Unknown previous bootstrap')
            qol+=1
        else: baseline.append([row[0].decode('ascii') if isinstance(row[0],bytes) else row[0],row[1].decode('utf8'),digest(row[2])])
    if qol>2 or baseline!=profile['scripts']: raise ValueError('Unsupported or modified game scripts')
    if rows[-1][1]!=b'Main': raise ValueError('Main must be last')
    return bool(qol)

def patch_scripts(raw):
    rows=table(raw)
    if any(row[1]==NAME for row in rows): raise ValueError('Modules bootstrap already present')
    rows=[row for row in rows if row[1] not in (b'BS2QoL bootstrap',b'BS2Modules bootstrap')]
    rows.insert(len(rows)-1,[900015,NAME,zlib.compress(BOOT)])
    result=b'\x04\x08'+dump(rows)
    if table(result)!=rows: raise ValueError('Script serialization failed')
    return result

def atomic_write(path,data):
    temp=path.with_name(path.name+'.bs2modules.tmp')
    with temp.open('wb') as stream:
        stream.write(data);stream.flush();os.fsync(stream.fileno())
    os.replace(temp,path)

def select(text):
    result=set(text.split(',')) if text else set()
    if not result or result-set(IDS): raise ValueError('Choose known module IDs')
    return expand(result)

from module_selection import expand, configuration as config

def verify_own_modules(game):
    for path in (p for p in (ROOT/'mod/BS2Suite').rglob('*') if p.is_file()):
        installed=Path(game)/'Mods/BS2Suite'/path.relative_to(ROOT/'mod/BS2Suite')
        if not installed.is_file():raise ValueError('Installed code differs; restore verified modules before configuring')
        old=installed.read_bytes();expected=path.read_bytes()
        if old==expected:continue
        # Git stores Ruby as LF; a verified Windows ZIP may use CRLF.
        # Keep exact checks for binaries and reject every other source change.
        if path.suffix=='.rb' and old.replace(b'\r\n',b'\n')==expected.replace(b'\r\n',b'\n'):continue
        raise ValueError('Installed code differs; restore verified modules before configuring')

def run(game,mode='check',selected=None,language='auto'):
    game=Path(game).resolve()
    if any(part.casefold()=='secrets' for part in game.parts): raise ValueError('Protected directory refused')
    if language not in ('auto','en','ru'):raise ValueError('Unknown game language')
    if (game/'Game.rgss3a').exists():
        from packed_game import run as run_packed
        return run_packed(game,mode,selected,language)
    directory=game/'BS2Suite';marker=directory/'install.json';target=game/'Data/Scripts.rvdata2'
    raw=target.read_bytes()
    record=json.loads(marker.read_text(encoding='utf8')) if marker.exists() else None
    original=(directory/'Scripts.original.rvdata2').read_bytes() if record else raw
    detected=None
    for candidate,filename in [('ru','build_profile.json'),('en','build_profile.en.json')]:
        candidate_profile=json.loads((ROOT/filename).read_text(encoding='utf8'))
        try:validate_scripts(original,candidate_profile)
        except ValueError:continue
        detected=candidate;profile=candidate_profile;break
    if not detected:raise ValueError('Unsupported or modified game scripts')
    if language!='auto' and language!=detected:raise ValueError('Selected language does not match the game. Choose '+detected.upper()+'.')
    language=detected
    active=bool(record and digest(raw)==record['installed_scripts_sha256'])
    if record and digest(raw) not in (record['installed_scripts_sha256'],record['original_scripts_sha256']):
        raise ValueError('Script table changed after installation; refusing to overwrite it')
    running=target_running(game/'Game.exe')
    if mode!='check' and running: raise ValueError('Close the target game before changing modules')
    if mode=='uninstall':
        if not record: raise ValueError('No installation record')
        if not active: return {'already_uninstalled':True,'changes':False}
        original=(directory/'Scripts.original.rvdata2').read_bytes()
        if digest(original)!=record['original_scripts_sha256']: raise ValueError('Backup mismatch')
        atomic_write(target,original)
        atomic_write(marker,json.dumps(dict(record,active=False),indent=2).encode('utf8'))
        return {'uninstalled':True,'profiles_preserved':True,'saves_touched':False}
    for name,expected in profile['files'].items():
        if name=='Data/Scripts.rvdata2': continue
        path=game/name
        if not path.is_file() or digest(path.read_bytes())!=expected: raise ValueError('Unsupported build: '+name)
    original=(directory/'Scripts.original.rvdata2').read_bytes() if active else raw
    if active and digest(original)!=record['original_scripts_sha256']: raise ValueError('Backup mismatch')
    qol=validate_scripts(original,profile)
    if mode=='check':
        from module_selection import migrate,parse
        text=(directory/'modules.ini').read_text(encoding='utf8') if (directory/'modules.ini').exists() else ''
        module_ids=(sorted(parse(text)&set(IDS)) if record and record['version']==VERSION else migrate(text)) if text else DEFAULTS
        return {'compatible':True,'installed':active,'qol_present':qol,'language':language,'storage':'loose','target_running':running,'changes':False,'module_ids':module_ids}
    selected=DEFAULTS if selected is None else selected
    if set(selected)-set(IDS): raise ValueError('Unknown module')
    selected=expand(selected)
    if mode=='configure' or active:
        if not active: raise ValueError('Install modules before configuring')
        if record['version']!=VERSION:
            from update import run as update
            update(game,True)
        # The GUI offers changing selection, not silently replacing installed code.
        verify_own_modules(game)
        atomic_write(directory/'modules.ini',config(selected))
        atomic_write(directory/'language.ini',('language='+language+'\n').encode('ascii'))
        return {'configured':True,'language':language,'modules':selected,'saves_touched':False}
    mod=game/'Mods/BS2Suite'
    if mod.exists() and not record: raise ValueError('Existing module directory without a record')
    directory.mkdir(exist_ok=True)
    backup=directory/'Scripts.original.rvdata2'
    if backup.exists() and backup.read_bytes()!=raw: raise ValueError('Different previous backup')
    if not backup.exists(): atomic_write(backup,raw)
    patched=patch_scripts(raw)
    record={'version':VERSION,'active':False,'language':language,'storage':'loose','original_scripts_sha256':digest(raw),'installed_scripts_sha256':digest(patched)}
    # A recovery record exists before any code copy; an interrupted copy can be retried.
    atomic_write(marker,json.dumps(record,indent=2).encode('utf8'))
    shutil.copytree(ROOT/'mod/BS2Suite',mod,dirs_exist_ok=True)
    atomic_write(directory/'modules.ini',config(selected))
    atomic_write(directory/'language.ini',('language='+language+'\n').encode('ascii'))
    atomic_write(target,patched)
    atomic_write(marker,json.dumps(dict(record,active=True),indent=2).encode('utf8'))
    return {'installed':True,'modules':selected,'qol_present':qol,'saves_touched':False}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game',type=Path,required=True)
    parser.add_argument('--modules',help='comma-separated IDs from modules.json (debug is opt-in)')
    parser.add_argument('--language',choices=['auto','en','ru'],default='auto',help='Language of the target game; does not translate the base game')
    modes=parser.add_mutually_exclusive_group()
    for name in ('install','configure','uninstall'): modes.add_argument('--'+name,action='store_true')
    args=parser.parse_args()
    mode=next((name for name in ('install','configure','uninstall') if getattr(args,name)),'check')
    selected=select(args.modules) if args.modules is not None else None
    print(json.dumps(run(args.game,mode,selected,args.language),ensure_ascii=True))

if __name__=='__main__':
    try: main()
    except Exception as error:
        print(json.dumps({'ok':False,'error':str(error),'saves_touched':False},ensure_ascii=True))
        raise SystemExit(1)
