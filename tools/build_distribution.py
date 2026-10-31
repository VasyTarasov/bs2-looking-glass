"""Build the offline Windows distribution from audited sources and pinned CPython."""
from pathlib import Path, PurePosixPath
import argparse, hashlib, io, json, stat, urllib.request, zipfile
from repo_audit import ROOT, audit, read_files

def digest(data):return hashlib.sha256(data).hexdigest()

def runtime_files(archive, lock):
    raw=Path(archive).read_bytes()
    if digest(raw)!=lock['sha256']:raise ValueError('Official Python archive checksum mismatch')
    files={}
    with zipfile.ZipFile(io.BytesIO(raw)) as z:
        for row in z.infolist():
            p=PurePosixPath(row.filename)
            if len(p.parts)!=1 or p.is_absolute() or '\\' in row.filename or ':' in row.filename or row.is_dir() or stat.S_ISLNK(row.external_attr>>16):
                raise ValueError('Unexpected embedded Python archive path')
            if row.filename.casefold() in {x.casefold() for x in files}:raise ValueError('Duplicate embedded Python archive path')
            if row.file_size>50*1024*1024:raise ValueError('Unexpected embedded Python file size')
            files[row.filename]=z.read(row)
    if not {'python.exe','LICENSE.txt',lock['stdlib_zip'],lock['path_file'],'vcruntime140.dll'}<=files.keys():
        raise ValueError('Incomplete embedded Python archive')
    # Isolated CPython: only its stdlib and this distribution's tools are visible.
    files[lock['path_file']]=(lock['stdlib_zip']+'\n.\n../../tools\n../..\n').encode('ascii')
    manifest={'version':lock['version'],'architecture':lock['architecture'],'archive_sha256':lock['sha256'],
              'files':{name:digest(data) for name,data in sorted(files.items())}}
    files['manifest.json']=(json.dumps(manifest,indent=2)+'\n').encode()
    return {'runtime/python/'+name:data for name,data in files.items()}

def build(output, archive, download=False):
    output=Path(output).resolve();archive=Path(archive).resolve()
    for path in [output,archive]:
        if ROOT==path or ROOT in path.parents:raise ValueError('Build outputs/cache must be outside the source repository')
        if any(p.casefold()=='secrets' for p in path.parts):raise ValueError('Protected path refused')
    if audit()['result']!='PASS':raise ValueError('Source publication audit failed')
    lock=json.loads((ROOT/'tools/python-runtime.json').read_bytes())
    if download and not archive.exists():
        archive.parent.mkdir(parents=True,exist_ok=True)
        with urllib.request.urlopen(lock['url'],timeout=60) as response:raw=response.read(32*1024*1024+1)
        if len(raw)>32*1024*1024 or digest(raw)!=lock['sha256']:raise ValueError('Official Python download checksum mismatch')
        archive.write_bytes(raw)
    vendor=runtime_files(archive,lock)
    files,errors=read_files(ROOT)
    if errors:raise ValueError('Source publication audit failed')
    files.update(vendor)
    version=json.loads(files['project.json'])['version'];prefix='BLACK-SOULS-II-QoL-Pack-'+version+'/'
    manifest={name:digest(data) for name,data in sorted(files.items())}
    files['SHA256.json']=(json.dumps(manifest,indent=2)+'\n').encode()
    output.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        for name,data in sorted(files.items()):
            row=zipfile.ZipInfo(prefix+name,(2026,10,31,0,0,0));row.compress_type=zipfile.ZIP_DEFLATED;row.external_attr=0o100644<<16
            z.writestr(row,data,compresslevel=9)
    with zipfile.ZipFile(output) as z:
        if z.testzip() is not None:raise ValueError('Distribution ZIP integrity failed')
        for name,expected in manifest.items():
            if digest(z.read(prefix+name))!=expected:raise ValueError('Distribution manifest integrity failed')
    sha=digest(output.read_bytes());output.with_suffix(output.suffix+'.sha256').write_text(sha+'  '+output.name+'\n',encoding='ascii')
    return {'result':'PASS','version':version,'files':len(files),'bytes':output.stat().st_size,'sha256':sha,
            'python':lock['version'],'architecture':lock['architecture'],'offline':True,'release_created':False}

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True)
    p.add_argument('--python-archive',type=Path,required=True);p.add_argument('--download',action='store_true');a=p.parse_args()
    print(json.dumps(build(a.output,a.python_archive,a.download)))
