import os,sys,unittest,uuid,shutil
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from install_transaction import Transaction,BOOTSTRAP

class TransactionTests(unittest.TestCase):
    def test_failed_install_restores_modules_config_archive_and_absent_bootstrap(self):
        game=Path.cwd()/('qa-txn-'+uuid.uuid4().hex);game.mkdir()
        try:
            initial={'Mods/BS2Suite/main.rb':b'old mod','BS2Suite/modules.ini':b'old config','Game.rgss3a':b'original archive','Save01.rvdata2':b'synthetic save sentinel'}
            for name,data in initial.items():p=game/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
            with self.assertRaises(OSError):
                with Transaction(game):
                    (game/'Mods/BS2Suite/main.rb').write_bytes(b'changed in place')
                    (game/'BS2Suite/modules.ini').write_bytes(b'changed config')
                    tmp=game/'replacement';tmp.write_bytes(b'new archive');os.replace(tmp,game/'Game.rgss3a')
                    boot=game/BOOTSTRAP;boot.parent.mkdir(parents=True);boot.write_bytes(b'new bootstrap')
                    raise OSError('injected disk failure')
            self.assertTrue(all((game/n).read_bytes()==v for n,v in initial.items()))
            self.assertFalse((game/BOOTSTRAP).exists())
            self.assertEqual(list(game.glob('.bs2suite-transaction-*')),[])
        finally:
            self.assertEqual(game.resolve().parent,Path.cwd().resolve());shutil.rmtree(game)

if __name__=='__main__':unittest.main()
