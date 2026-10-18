"""Game-free publication checks. All injected values are synthetic."""
from pathlib import Path
import hashlib,importlib.util,json,re,sys,tempfile,unittest,zipfile
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import repo_audit as audit
import package as packager

class RepositoryTests(unittest.TestCase):
 def setUp(self):self.assets=json.loads((ROOT/'runtime-assets.json').read_bytes())
 def test_current_tree_passes(self):self.assertEqual(audit.audit()['errors'],[])
 def test_game_binary_is_rejected(self):self.assertIn('unapproved binary/game data',audit.inspect_file('Game.exe',b'not a game',self.assets))
 def test_save_is_rejected(self):self.assertTrue(audit.path_issue('Save01.rvdata2',self.assets))
 def test_nested_original_data_is_rejected(self):self.assertTrue(audit.path_issue('mod/BS2Suite/Data/Skills.rvdata2',self.assets))
 def test_private_filename_is_rejected(self):self.assertTrue(audit.path_issue('.env',self.assets))
 def test_session_journal_is_rejected(self):self.assertTrue(audit.path_issue('account.session-journal',self.assets))
 def test_link_escape_rejected(self):self.assertTrue(audit.path_issue('../outside.py',self.assets))
 def test_synthetic_credential_rejected_without_echo(self):
  value=('ghp_'+'A'*40).encode();report=audit.inspect_file('example.py',value,self.assets)
  self.assertIn('possible credential material',report);self.assertNotIn(value.decode(),str(report))
 def test_workstation_path_rejected(self):
  value=('C:'+chr(92)+'Users'+chr(92)+'Example'+chr(92)+'file').encode()
  self.assertIn('workstation/personal path',audit.inspect_file('example.py',value,self.assets))
 def test_asset_mutation_is_rejected(self):
  rel='mod/BS2Suite/native/bs2_steam_bridge.dll';self.assertIn('runtime asset hash mismatch',audit.inspect_file(rel,b'not the helper',self.assets))
 def test_powershell_bom_is_required(self):self.assertIn('PowerShell 5.1 requires UTF-8 BOM',audit.inspect_file('Example.ps1',b'Write-Output 1',self.assets))
 def test_relative_documentation_target(self):self.assertTrue(audit.link_errors({'README.md':b'[x](missing.md)'}))
 def test_language_and_defaults(self):
  modules=json.loads((ROOT/'modules.json').read_bytes());self.assertEqual({m['id'] for m in modules if not m['default']},{'debug','legacy_shortcuts'})
  self.assertTrue(all(m['name']==m['name_en'] and m['name_ru'] for m in modules))
  self.assertIn("$script:lang='en'",(ROOT/'Installer.ps1').read_text(encoding='utf-8-sig'))
 def test_no_original_description_prose(self):
  text=(ROOT/'mod/BS2Suite/qol/lib/reference_data.rb').read_text(encoding='utf8');rows=re.findall(r'^\s*\d+ => (\[.*\]),?$',text,re.M)
  self.assertGreater(len(rows),1800);self.assertTrue(all(json.loads(r)[1]=='' for r in rows))
 def test_development_version(self):
  p=json.loads((ROOT/'project.json').read_bytes());self.assertEqual(p['version'],'0.91-dev');self.assertFalse(p['stable_release'])
  self.assertIn(p['version'],(ROOT/'tools/install.py').read_text(encoding='utf8'))
 def test_portable_private_path_guard(self):
  import install,update,collect_debug
  value=ROOT/'secrets'/'synthetic-missing-game'
  for function in [install.run,update.run,collect_debug.protect]:
   with self.assertRaises(ValueError):function(value)
 def test_python_syntax(self):
  for p in ROOT.rglob('*.py'):compile(p.read_text(encoding='utf8'),str(p),'exec')
 def test_package_integrity(self):
  with tempfile.NamedTemporaryFile(suffix='.zip',delete=False) as f:path=Path(f.name)
  try:
   result=packager.package(path);self.assertEqual(result['result'],'PASS');self.assertFalse(result['release_created'])
   with zipfile.ZipFile(path) as z:
    prefix='LookingGlass-0.91-dev/';manifest=json.loads(z.read(prefix+'SHA256.json'))
    self.assertTrue(all(hashlib.sha256(z.read(prefix+k)).hexdigest()==v for k,v in manifest.items()))
    self.assertFalse(any('/.git/' in k or k.endswith('/Game.exe') or '/Data/' in k for k in z.namelist()))
  finally:
   path.unlink(missing_ok=True);path.with_suffix('.zip.sha256').unlink(missing_ok=True)

if __name__=='__main__':unittest.main()
