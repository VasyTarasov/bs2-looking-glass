from pathlib import Path
import os,ctypes

def target_running(executable):
    """Metadata only. No input, focus, process memory, command line or termination."""
    if os.name!='nt':return False
    from ctypes import wintypes as w
    class ENTRY(ctypes.Structure):
        _fields_=[('dwSize',w.DWORD),('cntUsage',w.DWORD),('th32ProcessID',w.DWORD),
          ('th32DefaultHeapID',ctypes.c_size_t),('th32ModuleID',w.DWORD),('cntThreads',w.DWORD),
          ('th32ParentProcessID',w.DWORD),('pcPriClassBase',w.LONG),('dwFlags',w.DWORD),('szExeFile',w.WCHAR*260)]
    api=ctypes.WinDLL('kernel32',use_last_error=True)
    api.CreateToolhelp32Snapshot.argtypes=[w.DWORD,w.DWORD];api.CreateToolhelp32Snapshot.restype=w.HANDLE
    api.Process32FirstW.argtypes=[w.HANDLE,ctypes.POINTER(ENTRY)];api.Process32FirstW.restype=w.BOOL
    api.Process32NextW.argtypes=[w.HANDLE,ctypes.POINTER(ENTRY)];api.Process32NextW.restype=w.BOOL
    api.OpenProcess.argtypes=[w.DWORD,w.BOOL,w.DWORD];api.OpenProcess.restype=w.HANDLE
    api.QueryFullProcessImageNameW.argtypes=[w.HANDLE,w.DWORD,w.LPWSTR,ctypes.POINTER(w.DWORD)];api.QueryFullProcessImageNameW.restype=w.BOOL
    api.CloseHandle.argtypes=[w.HANDLE];api.CloseHandle.restype=w.BOOL
    snapshot=api.CreateToolhelp32Snapshot(2,0)
    if snapshot==ctypes.c_void_p(-1).value:raise RuntimeError('Cannot inspect running game safely')
    try:
        row=ENTRY();row.dwSize=ctypes.sizeof(row)
        okay=api.Process32FirstW(snapshot,ctypes.byref(row))
        while okay:
            if row.szExeFile.casefold()==executable.name.casefold():
                process=api.OpenProcess(0x1000,False,row.th32ProcessID)
                if not process:raise RuntimeError('A running Game.exe could not be identified; close it before installation')
                try:
                    buffer=ctypes.create_unicode_buffer(32768);length=w.DWORD(len(buffer))
                    if not api.QueryFullProcessImageNameW(process,0,buffer,ctypes.byref(length)):
                        raise RuntimeError('Cannot identify running Game.exe safely')
                    if Path(buffer.value).resolve()==executable.resolve():return True
                finally:api.CloseHandle(process)
            okay=api.Process32NextW(snapshot,ctypes.byref(row))
        return False
    finally:api.CloseHandle(snapshot)

