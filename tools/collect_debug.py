"""Collect this mod's logs and settings locally. Never collect game saves."""
from pathlib import Path
import argparse, hashlib, json, os, zipfile

def protect(path):
    path=Path(path).resolve()
    if any(part.casefold()=='secrets' for part in path.parts):
        raise ValueError('Protected path refused')
    return path

def collect(game, output):
    game=protect(game);output=protect(output)
    if output.suffix.lower()!='.zip':
        raise ValueError('Diagnostic output must use the .zip extension')
    root=protect(game/'BS2Suite')
    protect(root/'debug/sessions')
    if not (root/'debug/sessions').is_dir() and not (root/'debug/bootstrap.log').is_file():
        raise ValueError('No diagnostic sessions found. Enable the debug module first.')
    entries=[]
    bootstrap=root/'debug/bootstrap.log'
    if bootstrap.is_file() and not bootstrap.is_symlink():
        entries.append((bootstrap,'BS2Suite/debug/bootstrap.log'))
    # Only files created by this mod, no traversal through reparse/symbolic links.
    sessions=root/'debug/sessions'
    for session in (sessions.iterdir() if sessions.is_dir() else []):
        if session.is_symlink() or session.is_junction() or not session.is_dir() or session.resolve().parent!=sessions.resolve(): continue
        for path in session.iterdir():
            if path.is_symlink() or path.resolve().parent!=session.resolve(): continue
            if path.is_file() and (path.name.startswith('events_') and path.suffix=='.jsonl' or path.name in ('session.open','session.closed','session.failed')):
                entries.append((path,'BS2Suite/debug/sessions/'+session.name+'/'+path.name))
    for name in ('modules','options','keys','save_labels'):
        path=root/(name+'.ini')
        if path.is_file() and not path.is_symlink(): entries.append((path,'BS2Suite/'+path.name))
    for folder,names in [('BS2QoL',['preferences.ini','bindings.ini','reference.ini']),('BS2Modules',['loadouts.ini'])]:
        for name in names:
            path=game/folder/name
            if path.is_file() and not path.is_symlink(): entries.append((path,folder+'/'+name))
    output.parent.mkdir(parents=True,exist_ok=True)
    if output.exists(): raise ValueError('Output already exists; choose a new report name')
    temp=output.with_suffix(output.suffix+'.tmp')
    manifest={'format':1,'saves_included':False,'sessions':len(list(sessions.iterdir())) if sessions.is_dir() else 0,'files':{}}
    try:
        with zipfile.ZipFile(temp,'w',zipfile.ZIP_DEFLATED) as archive:
            for path,name in entries:
                data=path.read_bytes()
                archive.writestr(name,data)
                manifest['files'][name]=hashlib.sha256(data).hexdigest()
            archive.writestr('report.json',json.dumps(manifest,ensure_ascii=False,indent=2))
        os.replace(temp,output)
    finally:
        if temp.exists(): temp.unlink()
    return {'ok':True,'files':len(entries),'saves_included':False,'output':str(output)}

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--game',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    try: print(json.dumps(collect(args.game,args.output),ensure_ascii=False))
    except Exception as exc:
        print(json.dumps({'ok':False,'error':str(exc)}));raise SystemExit(1)
