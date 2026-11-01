"""Synthetic module-update checks; no game installation or player saves."""
from pathlib import Path
import json, sys, shutil, unittest, uuid
from contextlib import contextmanager
from unittest.mock import patch
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import update

@contextmanager
def synthetic_root():
    parent=Path.cwd().resolve();root=parent/('qa-update-'+uuid.uuid4().hex)
    root.mkdir()
    try:yield root
    finally:
        assert root.resolve().parent==parent
        shutil.rmtree(root)

class Update09993Tests(unittest.TestCase):
    def fixture(self,root):
        game=root/'synthetic-game';(game/'BS2Suite').mkdir(parents=True)
        (game/'Data').mkdir();(game/'Data/Scripts.rvdata2').write_bytes(b'synthetic script sentinel')
        (game/'Save01.rvdata2').write_bytes(b'synthetic save sentinel')
        (game/'Game.exe').write_bytes(b'not an executable')
        (game/'BS2Suite/modules.ini').write_bytes(b'semantic_groups=1\nloadouts=1\ndebug=0\n')
        (game/'BS2Suite/macros.ini').write_bytes(b'format=2\n[1,1,1]\nname=Player preset\nkey=1\nrow=guard,0,0,0\n')
        record={'version':'0.9992-dev','active':True,'installed_scripts_sha256':update.sha((game/'Data/Scripts.rvdata2').read_bytes())}
        (game/'BS2Suite/install.json').write_text(json.dumps(record))
        # Minimal old/new module trees are independent of the implementation.
        source=root/'package';(source/'mod/BS2Suite').mkdir(parents=True);(source/'tools').mkdir()
        old=b'# encoding: UTF-8\nold module\n';new=b'# encoding: UTF-8\nnew module\n'
        installed=game/'Mods/BS2Suite';installed.mkdir(parents=True)
        (installed/'main.rb').write_bytes(old)
        (source/'mod/BS2Suite/main.rb').write_bytes(new)
        (source/'mod/BS2Suite/action_context09993.rb').write_bytes(b'# new helper\n')
        (source/'tools/previous_09992dev.json').write_text(json.dumps({'main.rb':update.sha(old)}))
        (source/'tools/previous_092.json').write_text('{}')
        return game,source

    def test_verified_previous_version_check_apply_and_idempotence(self):
        with synthetic_root() as folder:
            game,source=self.fixture(Path(folder))
            keep={str(p.relative_to(game)):p.read_bytes() for p in [game/'Game.exe',game/'Data/Scripts.rvdata2',game/'Save01.rvdata2',game/'BS2Suite/macros.ini']}
            with patch.object(update,'ROOT',source),patch.object(update,'target_running',return_value=False):
                preview=update.run(game)
                self.assertTrue(preview['compatible']);self.assertFalse(preview['changes'])
                result=update.run(game,True);self.assertEqual(result['updated'],'1.0')
                self.assertTrue(update.run(game,True)['already_updated'])
            self.assertEqual(json.loads((game/'BS2Suite/install.json').read_bytes())['version'],'1.0')
            self.assertTrue((game/'Mods/BS2Suite/action_context09993.rb').is_file())
            self.assertTrue(all((game/k).read_bytes()==v for k,v in keep.items()))
            self.assertEqual(len(list((game/'BS2Suite').glob('rollback-1.0-*'))),1)

    def test_modified_old_module_refused_before_any_change(self):
        with synthetic_root() as folder:
            game,source=self.fixture(Path(folder));path=game/'Mods/BS2Suite/main.rb';path.write_bytes(b'manual change')
            before={str(p.relative_to(game)):p.read_bytes() for p in game.rglob('*') if p.is_file()}
            with patch.object(update,'ROOT',source),patch.object(update,'target_running',return_value=False):
                with self.assertRaises(ValueError):update.run(game,True)
            self.assertTrue(all((game/k).read_bytes()==v for k,v in before.items()))

    def test_known_same_version_revision_preserves_settings_and_updates(self):
        with synthetic_root() as folder:
            game,source=self.fixture(Path(folder))
            record=game/'BS2Suite/install.json';data=json.loads(record.read_bytes());data['version']='1.0';record.write_text(json.dumps(data))
            old=game/'Mods/BS2Suite/main.rb'
            (source/'tools/previous_100_initial.json').write_text(json.dumps({'main.rb':update.sha(old.read_bytes()),'action_context09993.rb':None}))
            keep={str(p.relative_to(game)):p.read_bytes() for p in [game/'Game.exe',game/'Data/Scripts.rvdata2',game/'Save01.rvdata2',game/'BS2Suite/modules.ini',game/'BS2Suite/macros.ini']}
            with patch.object(update,'ROOT',source),patch.object(update,'target_running',return_value=False):
                self.assertEqual(update.run(game)['own_files_to_update'],2)
                self.assertEqual(update.run(game,True)['own_files_updated'],2)
                self.assertTrue(update.run(game,True)['already_updated'])
            self.assertTrue(all((game/k).read_bytes()==v for k,v in keep.items()))

    def test_same_version_unknown_edit_is_refused(self):
        with synthetic_root() as folder:
            game,source=self.fixture(Path(folder))
            record=game/'BS2Suite/install.json';data=json.loads(record.read_bytes());data['version']='1.0';record.write_text(json.dumps(data))
            (source/'tools/previous_100_initial.json').write_text(json.dumps({'main.rb':'0'*64,'action_context09993.rb':None}))
            with patch.object(update,'ROOT',source),patch.object(update,'target_running',return_value=False):
                with self.assertRaises(ValueError):update.run(game,True)

    def test_partial_write_failure_restores_old_files_and_profile(self):
        with synthetic_root() as folder:
            game,source=self.fixture(Path(folder))
            before={str(p.relative_to(game)):p.read_bytes() for p in game.rglob('*') if p.is_file()}
            real=update.atomic_write;state={'failed':False}
            def fail_once(path,data):
                if path.name=='main.rb' and not state['failed']:
                    state['failed']=True;raise OSError('synthetic failure')
                return real(path,data)
            with patch.object(update,'ROOT',source),patch.object(update,'target_running',return_value=False),patch.object(update,'atomic_write',side_effect=fail_once):
                with self.assertRaises(OSError):update.run(game,True)
            self.assertTrue(all((game/k).read_bytes()==v for k,v in before.items()))
            self.assertFalse((game/'Mods/BS2Suite/action_context09993.rb').exists())

if __name__=='__main__':unittest.main()
