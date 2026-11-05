"""RMModLoader 2.x adapter: late bootstrap, untouched game/translation data."""
from pathlib import Path
import json,shutil
from archive_reader import ArchiveReader
from install_transaction import BOOTSTRAP

def present(game):
    game=Path(game)
    return (game/'ModLoader.dll').is_file() and (game/'Loader.exe').is_file()

def reader(game):
    game=Path(game);arc=ArchiveReader(game/'Game.rgss3a') if (game/'Game.rgss3a').is_file() else None
    def read(name):
        overlay=game/'mod_loader'/name
        if overlay.is_file():return overlay.read_bytes()
        if arc:return arc.read(name)
        return (game/name).read_bytes()
    return read

def owned_bootstrap(installer):
    return b'# BLACK SOULS II QoL Pack: external-loader adapter\n'+installer.BOOT

def restore_config(game,record,installer):
    config=game/'mod_loader/mod_loader.json';backup=game/'BS2Suite/Loader.original.json'
    original=backup.read_bytes() if record.get('loader_config_existed') else None
    if original is not None and installer.digest(original)!=record['loader_config_original_sha256']:
        raise ValueError('Original Loader configuration backup differs; no settings were overwritten')
    current=config.read_bytes() if config.is_file() else None
    if current is not None and installer.digest(current)==record.get('loader_config_installed_sha256'):
        if original is None:config.unlink()
        else:installer.atomic_write(config,original)
        return
    if current is None:return
    try:now=json.loads(current.decode('utf-8-sig'));before=json.loads(original.decode('utf-8-sig')) if original else {}
    except (ValueError,UnicodeError):return # A later user edit belongs to the user.
    changed=False
    for key,value in record.get('loader_owned_settings',{}).items():
        if key in now and now[key]==value:
            if key in before:now[key]=before[key]
            else:now.pop(key,None)
            changed=True
    if changed:installer.atomic_write(config,(json.dumps(now,ensure_ascii=False,indent=2)+'\n').encode('utf8'))

def run(game,mode,selected,language,installer):
    from compatibility import probe,set_probe
    game=Path(game);directory=game/'BS2Suite';marker=directory/'install.json';boot=game/BOOTSTRAP
    record=json.loads(marker.read_text(encoding='utf8')) if marker.is_file() else None
    expected=owned_bootstrap(installer)
    if mode=='uninstall':
        if not record or record.get('storage')!='loader':raise ValueError('No external-loader installation record')
        if not record.get('active'):return {'already_uninstalled':True,'changes':False}
        if not boot.is_file() or installer.digest(boot.read_bytes())!=record['installed_scripts_sha256']:
            raise ValueError('QoL loader bootstrap changed after installation; keep it for recovery before removing')
        restore_config(game,record,installer);boot.unlink()
        appid=game/'steam_appid.txt'
        if record.get('steam_appid_created') and appid.is_file() and appid.read_bytes()==b'3855540\n':appid.unlink()
        installer.atomic_write(marker,json.dumps(dict(record,active=False),indent=2).encode())
        return {'uninstalled':True,'storage':'loader','game_files_changed':False,'loader_settings_restored':True,'saves_touched':False}
    read=reader(game);raw=read('Data/Scripts.rvdata2')
    profile,report,policy=probe(game,raw,read,installer.ROOT,language);set_probe(installer,report,policy)
    active=bool(record and record.get('storage')=='loader' and record.get('active'))
    if active and (not boot.is_file() or installer.digest(boot.read_bytes())!=record['installed_scripts_sha256']):
        raise ValueError('QoL loader bootstrap changed after installation; refusing to overwrite it')
    if boot.is_file() and not active and boot.read_bytes()!=expected:
        raise ValueError('A different script occupies the QoL loader adapter path; no file was overwritten')
    running=installer.target_running(game/'Game.exe')
    if mode=='check':
        from module_selection import parse,migrate,DEFAULTS
        text=(directory/'modules.ini').read_text(encoding='utf8') if (directory/'modules.ini').is_file() else ''
        from module_selection import for_installation
        selected_ids=for_installation(text,record['version'] if record else None,installer.VERSION)
        return dict(report,compatible=True,installed=active,storage='loader',target_running=running,changes=False,module_ids=selected_ids)
    if running:raise ValueError('Close the game before changing modules')
    if mode=='configure' and not active:raise ValueError('Install the pack before configuring it')
    if record and record.get('active') and record.get('storage')!='loader':
        from update import run as update
        update(game,True)
        installer._run(game,'uninstall',None,language)
        record=None
    if active:
        from update import run as update
        update(game,True)
    from module_selection import parse
    if selected is None and active:selected=sorted(parse((directory/'modules.ini').read_text(encoding='utf8'))&set(installer.IDS))
    selected=installer.expand(installer.DEFAULTS if selected is None else selected)
    if set(selected)-set(installer.IDS):raise ValueError('Unknown module')
    directory.mkdir(exist_ok=True);(game/'mod_loader/scripts').mkdir(parents=True,exist_ok=True)
    config=game/'mod_loader/mod_loader.json';backup=directory/'Loader.original.json'
    current=config.read_bytes() if config.is_file() else None
    try:values=json.loads(current.decode('utf-8-sig')) if current else {}
    except (ValueError,UnicodeError):raise ValueError('Loader configuration is not valid JSON; no settings were changed')
    if not isinstance(values,dict):raise ValueError('Loader configuration must be an object')
    if active:
        original_existed=record['loader_config_existed'];original_hash=record.get('loader_config_original_sha256')
        if original_existed and (not backup.is_file() or installer.digest(backup.read_bytes())!=original_hash):raise ValueError('Original Loader configuration backup differs')
        # Release keys owned by a previously selected module before applying the new choices.
        restore_config(game,record,installer)
        current=config.read_bytes() if config.is_file() else None
        values=json.loads(current.decode('utf-8-sig')) if current else {}
    else:
        original_existed=current is not None;original_hash=installer.digest(current) if current is not None else None
        if current is not None:installer.atomic_write(backup,current)
    owned={}
    if 'hd_display' in selected:owned.update(hrfix_enable=False,fast_render=False)
    if 'basic_qol' in selected:owned['controls_change']=False
    values.update(owned);installed_config=(json.dumps(values,ensure_ascii=False,indent=2)+'\n').encode('utf8')
    shutil.copytree(installer.ROOT/'mod/BS2Suite',game/'Mods/BS2Suite',dirs_exist_ok=True)
    installer.atomic_write(directory/'modules.ini',installer.config(selected))
    installer.atomic_write(directory/'language.ini',('language='+report['language']+'\n').encode('ascii'))
    installer.atomic_write(config,installed_config)
    appid=game/'steam_appid.txt';appid_created=bool(active and record.get('steam_appid_created'))
    if not appid.exists() and (game/'steam_api.dll').is_file():
        # A direct Loader launch has no Steam launch environment. The game's
        # own Steam API needs its public app id; never replace a user's file.
        installer.atomic_write(appid,b'3855540\n');appid_created=True
    installer.atomic_write(boot,expected)
    record={'version':installer.VERSION,'active':True,'storage':'loader','language':report['language'],
            'installed_scripts_sha256':installer.digest(expected),'original_scripts_sha256':installer.digest(raw),
            'loader_config_existed':original_existed,'loader_config_original_sha256':original_hash,
            'loader_config_installed_sha256':installer.digest(installed_config),'loader_owned_settings':owned,
            'steam_appid_created':appid_created}
    installer.atomic_write(marker,json.dumps(record,indent=2).encode())
    set_probe(installer,report,policy)
    return dict(report,installed=True,storage='loader',modules=selected,game_files_changed=False,saves_touched=False)
