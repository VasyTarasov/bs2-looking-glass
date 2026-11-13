"""Update verified own modules, including recognized 1.0 revisions."""
from pathlib import Path, PurePosixPath
import argparse,datetime,hashlib,json,sys,re
sys.dont_write_bytecode=True
from install import ROOT,VERSION,atomic_write
from process_check import target_running

def sha(data):return hashlib.sha256(data).hexdigest()

def matches_own_ruby(data,expected,rel,canonical=None):
    if data is None:return expected is None
    if sha(data)==expected:return True
    # Git checkouts and packaged previews can use different source line endings.
    # Accept only a byte-identical known Ruby source after LF/CRLF conversion;
    # all game files, binaries and other mod content retain exact hash checks.
    if not rel.endswith('.rb'):return False
    lf=data.replace(b'\r\n',b'\n')
    if canonical and sha(lf)==canonical:return True
    return sha(lf)==expected or sha(lf.replace(b'\n',b'\r\n'))==expected


def grouped_macros(data):
    """Byte-preserving format-1 migration: old slots belong to group one."""
    if data is None or re.search(rb'(?m)^format=2\r?$',data):return data
    if len(data)>65536:raise ValueError('Macro profile exceeds the supported size')
    if not re.search(rb'(?m)^format=1\r?$',data):return data
    if re.search(rb'(?m)^\[[0-9]+,[0-9]+,[0-9]+\]\r?$',data):raise ValueError('Mixed macro formats; profile left untouched')
    migrated=re.sub(rb'(?m)^\[([0-9]{1,4}),([1-8])\](\r?)$',rb'[\1,1,\2]\3',data)
    return re.sub(rb'(?m)^format=1(\r?)$',rb'format=2\1',migrated)

def run(game,apply=False):
    game=Path(game).resolve()
    if any(part.casefold()=='secrets' for part in game.parts):raise ValueError('Protected target refused')
    running=target_running(game/'Game.exe')
    if apply and running:raise RuntimeError('The game is running. Save and close it before updating.')
    directory=game/'BS2Suite';record_path=directory/'install.json';config_path=directory/'modules.ini'
    record_bytes=record_path.read_bytes();record=json.loads(record_bytes)
    if not record.get('active'):raise ValueError('Install BLACK SOULS II — QoL Pack / BS2Suite before updating.')
    if record.get('storage')=='archive':
        from packed_game import read_scripts,sha_file
        if sha_file(game/'Game.rgss3a')!=record['installed_archive_sha256']:raise ValueError('Game archive changed; update canceled.')
        scripts=read_scripts(game/'Game.rgss3a')
    elif record.get('storage')=='loader':
        from install_transaction import BOOTSTRAP
        scripts=(game/BOOTSTRAP).read_bytes()
    else:scripts=(game/'Data/Scripts.rvdata2').read_bytes()
    if sha(scripts)!=record['installed_scripts_sha256']:raise ValueError('Game scripts changed; update canceled.')
    previous_versions={'1.03':'103','1.02':'102','1.01':'101','1.0':'100','0.9.0-preview':'090','0.9.1-alpha':'091','0.9.2-alpha':'092','0.9.3-alpha':'093','0.9.4-alpha':'094','0.9.5-alpha':'095','0.9.6-alpha':'096','0.9.7-alpha':'097','0.9.8-alpha':'098','0.91-dev':'091dev','0.92-dev':'092dev','0.991-dev':'0991dev','0.992-dev':'0992dev','0.993-dev':'0993dev','0.994-dev':'0994dev','0.995-dev':'0995dev','0.996-dev':'0996dev','0.997-dev':'0997dev','0.998-dev':'0998dev','0.9991-dev':'09991dev','0.999-dev':'0999dev','0.9992-dev':'09992dev','0.9993-dev':'09993dev','0.9994-dev':'09994dev','0.9995-dev':'09995dev','0.9996-dev':'09996dev','0.9997-dev':'09997dev','0.9998-dev':'09998dev','0.9999-dev':'09999dev','0.99991-dev':'099991dev','0.99992-dev':'099992dev','0.99993-dev':'099993dev','0.99994-dev':'099994dev','0.99995-dev':'099995dev'}
    if record['version'] not in (*previous_versions,VERSION):raise ValueError('This installed version does not support direct updates. Use Install.cmd.')
    previous=json.loads((ROOT/('tools/previous_'+previous_versions.get(record['version'],'092')+'.json')).read_text(encoding='utf8'))
    canonical_path=ROOT/('tools/previous_'+previous_versions.get(record['version'],'092')+'_lf.json')
    canonical=json.loads(canonical_path.read_text(encoding='utf8')) if canonical_path.is_file() and record['version']!=VERSION else {}
    labels_path=ROOT/('tools/previous_'+previous_versions.get(record['version'],'092')+'_labels.json')
    labels=json.loads(labels_path.read_text(encoding='utf8')) if labels_path.is_file() and record['version']!=VERSION else {}
    source=ROOT/'mod/BS2Suite';changes=[]
    revision_path=ROOT/'tools/previous_100_initial.json'
    revision=json.loads(revision_path.read_text(encoding='utf8')) if record['version'] in (VERSION,'1.0','1.01','1.02','1.03') and revision_path.is_file() else {}
    initial_102_path=ROOT/'tools/previous_102_initial.json'
    initial_102=json.loads(initial_102_path.read_text(encoding='utf8')) if record['version']=='1.02' and initial_102_path.is_file() else {}
    for path in sorted(source.rglob('*')):
        if not path.is_file():continue
        rel=path.relative_to(source).as_posix();parts=PurePosixPath(rel)
        if parts.is_absolute() or '..' in parts.parts:raise ValueError('Invalid module path')
        target=game/'Mods/BS2Suite'/rel;old=target.read_bytes() if target.exists() else None;new=path.read_bytes()
        expected=sha(new) if record['version']==VERSION else previous.get(rel)
        verified=matches_own_ruby(old,expected,rel,canonical.get(rel))
        if not verified and rel in revision:verified=matches_own_ruby(old,revision[rel],rel)
        if not verified and rel in initial_102:verified=matches_own_ruby(old,initial_102[rel],rel)
        if not verified and rel in labels:verified=matches_own_ruby(old,labels[rel],rel)
        if not verified:raise ValueError('An installed mod file has changed: '+rel)
        if old!=new:changes.append((rel,old,new))
    retired=game/'Mods/BS2Suite/scaling.rb'
    if retired.exists():
        old=retired.read_bytes()
        if sha(old)!=previous.get('scaling.rb'):raise ValueError('The old scaling module has changed; removal canceled.')
        changes.append(('scaling.rb',old,None))
    if record['version']==VERSION and not changes:return {'result':'PASS','already_updated':True,'target_running':running,'changes':False}
    if config_path.stat().st_size>8192:raise ValueError('Unexpected module configuration size')
    config_bytes=config_path.read_bytes();text=config_bytes.decode('utf8')
    lines=[line for line in text.splitlines() if line.split('=',1)[0].strip() not in {'scaling','defeat','retry'}]
    if not any(line.startswith('weapon_family_cleanup=') for line in lines):lines.append('weapon_family_cleanup=1')
    from module_selection import migrate,configuration
    config_new=configuration(migrate(text))
    if record['version'] in (VERSION,'1.0','1.01','1.02','1.03'):config_new=config_bytes
    macro_path=directory/'macros.ini'
    macro_old=macro_path.read_bytes() if macro_path.is_file() else None
    macro_new=grouped_macros(macro_old)
    if record['version'] in (VERSION,'1.0','1.01','1.02','1.03'):macro_new=macro_old
    if not apply:return {'result':'PASS','compatible':True,'target_running':running,'own_files_to_update':len(changes),'changes':False}
    if target_running(game/'Game.exe'):raise RuntimeError('The game started during the update. Update canceled.')
    backup=directory/('rollback-'+VERSION+'-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
    backup.mkdir()
    (backup/'install.json').write_bytes(record_bytes);(backup/'modules.ini').write_bytes(config_bytes)
    for rel,old,new in changes:
        if old is not None:
            path=backup/'Mods/BS2Suite'/rel;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(old)
    (backup/'manifest.json').write_text(json.dumps({'from':record['version'],'to':VERSION,'files':[{'path':rel,'before':sha(old) if old is not None else None,'after':sha(new) if new is not None else None} for rel,old,new in changes]},indent=2),encoding='utf8')
    if macro_old is not None and macro_new!=macro_old:(backup/'macros.ini').write_bytes(macro_old)
    completed=[]
    try:
        if target_running(game/'Game.exe'):raise RuntimeError('The game started during the update. Update canceled.')
        for rel,old,new in changes:
            target=game/'Mods/BS2Suite'/rel;target.parent.mkdir(parents=True,exist_ok=True)
            if new is None:target.unlink()
            else:atomic_write(target,new)
            completed.append((target,old))
        if macro_new!=macro_old:
            if (macro_path.read_bytes() if macro_path.is_file() else None)!=macro_old:raise RuntimeError('Macro profile changed during update')
            atomic_write(macro_path,macro_new);completed.append((macro_path,macro_old))
        atomic_write(config_path,config_new)
        atomic_write(record_path,json.dumps(dict(record,version=VERSION),indent=2).encode('utf8'))
    except BaseException:
        for path,old in reversed(completed):
            if old is None:path.unlink(missing_ok=True)
            else:atomic_write(path,old)
        atomic_write(config_path,config_bytes);atomic_write(record_path,record_bytes)
        raise
    return {'result':'PASS','updated':VERSION,'own_files_updated':len(changes),'backup':str(backup),'game_files_replaced':False,'saves_touched':False}

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game',type=Path,default=Path(r'C:\SteamLibrary\steamapps\common\BLACK SOULS II'))
    parser.add_argument('--apply',action='store_true');parser.add_argument('--human',action='store_true')
    parser.add_argument('--language',choices=['en','ru'],default='en')
    args=parser.parse_args()
    try:
        if args.apply:
            from install import run as install_run
            from module_selection import parse
            config_path=args.game/'BS2Suite/modules.ini'
            selected=sorted(parse(config_path.read_text(encoding='utf8')))
            result=install_run(args.game,'configure',selected,language='auto')
            result['updated']=VERSION
        else:result=run(args.game,False)
        message='Обновление готово. Файлы игры и сохранения не заменялись.' if args.language=='ru' else 'Update complete. Original game files and saves were preserved.'
        print(message if args.human and args.apply else json.dumps(result,ensure_ascii=True))
    except Exception as error:
        print(str(error) if args.human else json.dumps({'result':'FAIL','error':str(error)},ensure_ascii=True));raise SystemExit(1)
