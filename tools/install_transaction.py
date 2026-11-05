"""Private rollback journal for owned files; no player saves are inspected."""
from pathlib import Path
import ctypes,hashlib,os,shutil,uuid

BOOTSTRAP='mod_loader/scripts/999999999 - BS2Suite.rb'

def checked(path,root):
    path=Path(path)
    if path.resolve()==root or not path.resolve().is_relative_to(root):raise ValueError('Installation path leaves the game folder')
    for p in [path,*path.parents]:
        if p==root:break
        if p.is_symlink() or p.is_junction():raise ValueError('Linked mod installation paths are not supported')
    return path

def clone(source,target):
    source=Path(source);target=Path(target)
    target.parent.mkdir(parents=True,exist_ok=True)
    if Path(source).suffix.lower()=='.rgss3a':
        try:os.link(source,target);return
        except OSError:pass
    shutil.copy2(source,target)

class Transaction:
    def __init__(self,game):self.game=Path(game).resolve();self.saved=[];self.temp=None;self.mutex=None
    def __enter__(self):
        if os.name=='nt':
            api=ctypes.WinDLL('kernel32',use_last_error=True)
            api.CreateMutexW.argtypes=[ctypes.c_void_p,ctypes.c_bool,ctypes.c_wchar_p];api.CreateMutexW.restype=ctypes.c_void_p
            api.WaitForSingleObject.argtypes=[ctypes.c_void_p,ctypes.c_uint];api.WaitForSingleObject.restype=ctypes.c_uint
            api.ReleaseMutex.argtypes=[ctypes.c_void_p];api.CloseHandle.argtypes=[ctypes.c_void_p]
            self.api=api;self.mutex=api.CreateMutexW(None,False,'Local\\BS2Suite_'+hashlib.sha256(str(self.game).casefold().encode()).hexdigest())
            if not self.mutex or api.WaitForSingleObject(self.mutex,0) not in (0,128):
                if self.mutex:api.CloseHandle(self.mutex)
                self.mutex=None;raise ValueError('Another installer is changing this game folder. Wait for it to finish.')
        try:
            self.temp=self.game/('.bs2suite-transaction-'+uuid.uuid4().hex)
            self.temp.mkdir()
            for rel in ('BS2Suite','Mods/BS2Suite','Data/Scripts.rvdata2','Game.rgss3a','mod_loader/mod_loader.json',BOOTSTRAP):
                src=checked(self.game/rel,self.game);dst=self.temp/rel
                kind='dir' if src.is_dir() else 'file' if src.is_file() else 'absent'
                self.saved.append((src,dst,kind))
                if kind=='dir':
                    for p in src.rglob('*'):checked(p,self.game)
                    shutil.copytree(src,dst,copy_function=clone)
                elif kind=='file':clone(src,dst)
            return self
        except BaseException:
            self.__exit__(None,None,None);raise
    def __exit__(self,typ,value,tb):
        try:
            if typ and self.temp:
                for src,dst,kind in self.saved:
                    checked(src,self.game)
                    if kind=='dir':
                        if src.is_dir():shutil.rmtree(src)
                        src.parent.mkdir(parents=True,exist_ok=True)
                        os.replace(dst,src)
                    elif kind=='file':
                        if dst.is_file():src.parent.mkdir(parents=True,exist_ok=True);os.replace(dst,src)
                    elif src.exists():
                        if src.is_dir():shutil.rmtree(src)
                        else:src.unlink()
        finally:
            if self.temp and self.temp.exists():
                checked(self.temp,self.game);shutil.rmtree(self.temp)
            if self.mutex:self.api.ReleaseMutex(self.mutex);self.api.CloseHandle(self.mutex);self.mutex=None
        return False
