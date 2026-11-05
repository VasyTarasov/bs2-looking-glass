"""RGSS3 archive support. Copy encrypted assets verbatim; replace only Scripts.

No unpacker, game asset or original script is distributed with the mod.
The original archive stays in the target game's local rollback directory.
"""
from pathlib import Path
import hashlib, json, os, shutil, struct, uuid
from archive_reader import ArchiveReader

def sha_file(path):
    with Path(path).open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()

def entries(path):
    size=Path(path).stat().st_size;seen=set();result=[]
    with Path(path).open('rb') as f:
        if f.read(8)!=b'RGSSAD\0\x03':raise ValueError('Unsupported RGSS archive')
        seed=f.read(4)
        if len(seed)!=4:raise ValueError('Truncated RGSS header')
        key=(struct.unpack('<I',seed)[0]*9+3)&0xffffffff
        while True:
            header=f.tell();raw=f.read(16)
            if len(raw)!=16:raise ValueError('Truncated RGSS directory')
            offset,length,file_key,nlen=[n^key for n in struct.unpack('<4I',raw)]
            if offset==0:break
            if not 0<nlen<4096 or offset+length>size:raise ValueError('Invalid RGSS entry')
            encrypted=f.read(nlen);kb=struct.pack('<I',key)
            name=bytes(b^kb[i%4] for i,b in enumerate(encrypted)).decode('utf8').replace('\\','/')
            if name.casefold() in seen:raise ValueError('Duplicate RGSS entry')
            seen.add(name.casefold());result.append((name,header,offset,length,file_key,key))
            if len(result)>100000:raise ValueError('Excessive RGSS directory')
        directory_end=f.tell()
    if any(row[2]<directory_end for row in result):raise ValueError('RGSS entry overlaps directory')
    return result

def read_scripts(archive):return ArchiveReader(archive).read('Data/Scripts.rvdata2')

def encrypt(data,key):
    result=bytearray(len(data))
    for i in range(0,len(data),4):
        kb=struct.pack('<I',key)
        for j,b in enumerate(data[i:i+4]):result[i+j]=b^kb[j]
        key=(key*7+3)&0xffffffff
    return bytes(result)

def patched_copy(source,destination,scripts):
    rows=entries(source);matches=[r for r in rows if r[0]=='Data/Scripts.rvdata2']
    if len(matches)!=1:raise ValueError('Original script table missing')
    name,header,offset,length,file_key,key=matches[0]
    shutil.copyfile(source,destination)
    with Path(destination).open('r+b') as f:
        f.seek(0,2);position=f.tell()
        if position+len(scripts)>=2**32:raise ValueError('RGSS archive exceeds 32-bit offsets')
        f.write(encrypt(scripts,file_key))
        f.seek(header);f.write(struct.pack('<II',position^key,len(scripts)^key));f.flush();os.fsync(f.fileno())
    if read_scripts(destination)!=scripts:raise ValueError('Archive script verification failed')
    # Header locations, keys, names and every other encrypted payload stay unchanged.
    after=entries(destination)
    if [r for r in after if r[0]!=name]!=[r for r in rows if r[0]!=name]:raise ValueError('Archive directory changed unexpectedly')

def run(game,mode,selected,language):
    import install as installer
    game=Path(game);directory=game/'BS2Suite';marker=directory/'install.json'
    for p in (game,directory,game/'Mods',game/'Mods/BS2Suite'):
        if p.is_symlink() or p.is_junction():raise ValueError('Linked installation directories are not supported')
    archive=game/'Game.rgss3a';backup=directory/'Game.original.rgss3a'
    for p in (archive,backup,marker):
        if p.is_symlink():raise ValueError('Linked game files are not supported')
    record=json.loads(marker.read_text(encoding='utf8')) if marker.exists() else None
    if record and record.get('storage')!='archive':raise ValueError('Incompatible previous loose-installation record; use a separate game folder')
    # The verified Game.ini points at Data/Scripts, which RGSS loads from this
    # archive. Original distributions can retain loose base Data alongside it.
    # Preserve those ignored files; never treat them as the active English DB.
    loose_data_ignored=(game/'Data/Scripts.rvdata2').exists()
    current=sha_file(archive)
    if record:
        if current not in (record['installed_archive_sha256'],record['original_archive_sha256']):raise ValueError('Archive changed after installation; refusing to overwrite it')
        original_archive=backup
        if sha_file(backup)!=record['original_archive_sha256']:raise ValueError('Original archive backup mismatch')
    else:original_archive=archive
    original_hash=sha_file(original_archive)
    entries(original_archive)
    from compatibility import probe,set_probe
    reader=ArchiveReader(original_archive)
    profile,report,policy=probe(game,read_scripts(original_archive),reader.read,installer.ROOT,language)
    profile['archive_sha256']=original_hash
    set_probe(installer,report,policy)
    language=report['language']
    for name in ('Game.exe','Game.ini','System/RGSS301.dll'):
        if sha_file(game/name)!=profile['files'][name]:raise ValueError('Unsupported build: '+name)
    original=read_scripts(original_archive);installer.validate_scripts(original,profile)
    active=bool(record and current==record['installed_archive_sha256'] and record.get('active'))
    running=installer.target_running(game/'Game.exe')
    if mode!='check' and running:raise ValueError('Close the target game before changing modules')
    if mode=='check':
        from module_selection import migrate,parse,DEFAULTS
        text=(directory/'modules.ini').read_text(encoding='utf8') if (directory/'modules.ini').exists() else ''
        module_ids=(sorted(parse(text)&set(installer.IDS)) if record and record['version']==installer.VERSION else migrate(text)) if text else DEFAULTS
        return {'compatible':True,'installed':active,'language':language,'storage':'archive','loose_base_data_preserved':loose_data_ignored,'target_running':running,'changes':False,'module_ids':module_ids}
    if mode=='uninstall':
        if not record:raise ValueError('No installation record')
        if not active:return {'already_uninstalled':True,'changes':False}
        temp=archive.with_suffix('.rgss3a.bs2.tmp')
        if temp.exists():raise ValueError('An archive staging file already exists; keep it for recovery before retrying')
        try:
            shutil.copyfile(backup,temp)
            if sha_file(temp)!=record['original_archive_sha256']:raise ValueError('Restoration verification failed')
            if installer.target_running(game/'Game.exe'):raise ValueError('Game started during removal')
            os.replace(temp,archive)
            installer.atomic_write(marker,json.dumps(dict(record,active=False),indent=2).encode('utf8'))
        finally:temp.unlink(missing_ok=True)
        return {'uninstalled':True,'original_archive_restored':True,'saves_touched':False,'profiles_preserved':True}
    selected=installer.expand(installer.DEFAULTS if selected is None else selected)
    if set(selected)-set(installer.IDS):raise ValueError('Unknown module')
    if active:
        from update import run as update
        update(game,True)
        installer.verify_own_modules(game)
        installer.atomic_write(directory/'modules.ini',installer.config(selected))
        installer.atomic_write(directory/'language.ini',('language='+language+'\n').encode('ascii'))
        return {'configured':True,'language':language,'storage':'archive','saves_touched':False}
    if mode=='configure':raise ValueError('Install modules before configuring')
    mod=game/'Mods/BS2Suite'
    if mod.exists() and not record:raise ValueError('Existing modules without an installation record')
    if mod.exists():
        if record['version']!=installer.VERSION:raise ValueError('Reactivate the previous package before upgrading an inactive installation')
        installer.verify_own_modules(game)
    patched=installer.patch_scripts(original)
    directory.mkdir(exist_ok=True)
    if backup.exists():
        if sha_file(backup)!=profile['archive_sha256']:raise ValueError('Conflicting archive backup')
    else:shutil.copyfile(archive,backup)
    if sha_file(backup)!=profile['archive_sha256']:raise ValueError('Archive backup failed verification')
    installer.atomic_write(directory/'Scripts.original.rvdata2',original)
    temp=archive.with_suffix('.rgss3a.bs2.tmp')
    if temp.exists():raise ValueError('An archive staging file already exists; keep it for recovery before retrying')
    stage=game/'Mods'/('BS2Suite.install-'+uuid.uuid4().hex)
    previous_mod=directory/('modules-before-install-'+uuid.uuid4().hex)
    old_record=marker.read_bytes() if marker.exists() else None
    old_config=(directory/'modules.ini').read_bytes() if (directory/'modules.ini').exists() else None
    old_language=(directory/'language.ini').read_bytes() if (directory/'language.ini').exists() else None
    replaced=False
    mod_replaced=False
    try:
        stage.parent.mkdir(exist_ok=True)
        shutil.copytree(installer.ROOT/'mod/BS2Suite',stage)
        patched_copy(backup,temp,patched)
        record={'version':installer.VERSION,'active':False,'language':language,'storage':'archive',
                'original_scripts_sha256':installer.digest(original),'installed_scripts_sha256':installer.digest(patched),
                'original_archive_sha256':profile['archive_sha256'],'installed_archive_sha256':sha_file(temp)}
        installer.atomic_write(marker,json.dumps(record,indent=2).encode('utf8'))
        if mod.exists():os.replace(mod,previous_mod)
        os.replace(stage,mod);mod_replaced=True
        installer.atomic_write(directory/'modules.ini',installer.config(selected))
        installer.atomic_write(directory/'language.ini',('language='+language+'\n').encode('ascii'))
        if installer.target_running(game/'Game.exe'):raise ValueError('Game started during installation')
        os.replace(temp,archive);replaced=True
        installer.atomic_write(marker,json.dumps(dict(record,active=True),indent=2).encode('utf8'))
    except BaseException:
        if replaced:shutil.copyfile(backup,archive)
        if mod_replaced:
            mod.resolve().relative_to(game.resolve())
            shutil.rmtree(mod)
        if previous_mod.exists():os.replace(previous_mod,mod)
        for path,old in [(marker,old_record),(directory/'modules.ini',old_config),(directory/'language.ini',old_language)]:
            if old is None:path.unlink(missing_ok=True)
            else:installer.atomic_write(path,old)
        raise
    finally:
        temp.unlink(missing_ok=True)
        if stage.exists():
            stage.resolve().relative_to(game.resolve());shutil.rmtree(stage)
    return {'installed':True,'language':language,'storage':'archive','archive_unpacked':False,'original_archive_backed_up':True,'saves_touched':False,'modules':selected}
