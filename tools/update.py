"""Update verified 0.9.0–0.9.8 own modules; never replace game binaries or script data."""
from pathlib import Path, PurePosixPath
import argparse,datetime,hashlib,json,sys
sys.dont_write_bytecode=True
from install import ROOT,VERSION,atomic_write
from process_check import target_running

def sha(data):return hashlib.sha256(data).hexdigest()

def run(game,apply=False):
    game=Path(game).resolve()
    if any(part.casefold()=='secrets' for part in game.parts):raise ValueError('Protected target refused')
    running=target_running(game/'Game.exe')
    if apply and running:raise RuntimeError('Игра открыта. Сохранитесь и закройте её перед обновлением.')
    directory=game/'BS2Suite';record_path=directory/'install.json';config_path=directory/'modules.ini'
    record_bytes=record_path.read_bytes();record=json.loads(record_bytes)
    if not record.get('active'):raise ValueError('Сначала требуется установленный мод 0.9.0–0.9.8.')
    if sha((game/'Data/Scripts.rvdata2').read_bytes())!=record['installed_scripts_sha256']:raise ValueError('Игровые скрипты изменены; автоматическое обновление отменено.')
    previous_versions={'0.9.0-preview':'090','0.9.1-alpha':'091','0.9.2-alpha':'092','0.9.3-alpha':'093','0.9.4-alpha':'094','0.9.5-alpha':'095','0.9.6-alpha':'096','0.9.7-alpha':'097','0.9.8-alpha':'098','0.91-dev':'091dev'}
    if record['version'] not in (*previous_versions,VERSION):raise ValueError('Этот обновитель предназначен для 0.9.0–0.9.8. Для другой версии используйте Install.cmd.')
    previous=json.loads((ROOT/('tools/previous_'+previous_versions.get(record['version'],'092')+'.json')).read_text(encoding='utf8'))
    source=ROOT/'mod/BS2Suite';changes=[]
    for path in sorted(source.rglob('*')):
        if not path.is_file():continue
        rel=path.relative_to(source).as_posix();parts=PurePosixPath(rel)
        if parts.is_absolute() or '..' in parts.parts:raise ValueError('Invalid module path')
        target=game/'Mods/BS2Suite'/rel;old=target.read_bytes() if target.exists() else None;new=path.read_bytes()
        expected=sha(new) if record['version']==VERSION else previous.get(rel)
        if (sha(old) if old is not None else None)!=expected:raise ValueError('Собственный файл мода изменён: '+rel)
        if old!=new:changes.append((rel,old,new))
    retired=game/'Mods/BS2Suite/scaling.rb'
    if retired.exists():
        old=retired.read_bytes()
        if sha(old)!=previous.get('scaling.rb'):raise ValueError('Изменён старый мод масштабирования; удаление отменено.')
        changes.append(('scaling.rb',old,None))
    if record['version']==VERSION:return {'result':'PASS','already_updated':True,'target_running':running,'changes':False}
    if config_path.stat().st_size>8192:raise ValueError('Unexpected module configuration size')
    config_bytes=config_path.read_bytes();text=config_bytes.decode('utf8')
    lines=[line for line in text.splitlines() if line.split('=',1)[0].strip()!='scaling']
    if not any(line.startswith('weapon_family_cleanup=') for line in lines):lines.append('weapon_family_cleanup=1')
    config_new=('\n'.join(lines)+'\n').encode('utf8')
    if not apply:return {'result':'PASS','compatible':True,'target_running':running,'own_files_to_update':len(changes),'changes':False}
    if target_running(game/'Game.exe'):raise RuntimeError('Игра была запущена. Обновление отменено.')
    backup=directory/('rollback-0.92-dev-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f'))
    backup.mkdir()
    (backup/'install.json').write_bytes(record_bytes);(backup/'modules.ini').write_bytes(config_bytes)
    for rel,old,new in changes:
        if old is not None:
            path=backup/'Mods/BS2Suite'/rel;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(old)
    (backup/'manifest.json').write_text(json.dumps({'from':record['version'],'to':VERSION,'files':[{'path':rel,'before':sha(old) if old is not None else None,'after':sha(new) if new is not None else None} for rel,old,new in changes]},indent=2),encoding='utf8')
    completed=[]
    try:
        if target_running(game/'Game.exe'):raise RuntimeError('Игра была запущена. Обновление отменено.')
        for rel,old,new in changes:
            target=game/'Mods/BS2Suite'/rel;target.parent.mkdir(parents=True,exist_ok=True)
            if new is None:target.unlink()
            else:atomic_write(target,new)
            completed.append((target,old))
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
    args=parser.parse_args()
    try:
        result=run(args.game,args.apply)
        print('Обновление готово. Файлы игры и сохранения не заменялись.' if args.human and args.apply else json.dumps(result,ensure_ascii=True))
    except Exception as error:
        print(str(error) if args.human else json.dumps({'result':'FAIL','error':str(error)},ensure_ascii=True));raise SystemExit(1)
