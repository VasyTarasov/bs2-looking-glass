"""An exited game is not an unknown running game; access failures still refuse."""
from pathlib import Path
from unittest import TestCase
from unittest.mock import patch
import process_check

class Call:
    def __init__(self,fn):self.fn=fn
    def __call__(self,*args):return self.fn(*args)

class ProcessCheckTests(TestCase):
    def inspect(self,opened=True,exit_code=0,last_error=0):
        class API:pass
        api=API()
        def first(handle,row):
            row._obj.szExeFile='Game.exe';row._obj.th32ProcessID=40;return True
        def status(handle,output):output._obj.value=exit_code;return True
        methods={'CreateToolhelp32Snapshot':lambda *a:1,'Process32FirstW':first,'Process32NextW':lambda *a:False,
                 'OpenProcess':lambda *a:20 if opened else 0,'QueryFullProcessImageNameW':lambda *a:False,
                 'GetExitCodeProcess':status,'CloseHandle':lambda *a:True}
        for name,fn in methods.items():setattr(api,name,Call(fn))
        game=Path('synthetic-game')
        with patch.object(process_check.ctypes,'WinDLL',return_value=api,create=True),patch.object(process_check.ctypes,'get_last_error',return_value=last_error,create=True):
            return process_check.target_running(game/'Game.exe')
    def test_process_exited_after_snapshot(self):
        self.assertFalse(self.inspect(opened=False,last_error=87))
    def test_process_exited_before_path_query(self):
        self.assertFalse(self.inspect(exit_code=0))
    def test_unidentified_active_process_remains_a_refusal(self):
        with self.assertRaises(RuntimeError):self.inspect(exit_code=259)
    def test_access_denied_is_not_treated_as_an_exit(self):
        with self.assertRaises(RuntimeError):self.inspect(opened=False,last_error=5)
