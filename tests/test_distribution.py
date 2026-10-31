"""Integrity boundary for third-party code added only to release ZIPs."""
from pathlib import Path
import json,sys,tempfile,unittest,zipfile
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import build_distribution as distro

class DistributionTests(unittest.TestCase):
 def archive(self,files):
  with tempfile.NamedTemporaryFile(suffix='.zip',delete=False) as f:p=Path(f.name)
  with zipfile.ZipFile(p,'w') as z:
   for name,data in files.items():z.writestr(name,data)
  self.addCleanup(p.unlink)
  return p
 def lock(self,p):
  return {'version':'fixture','architecture':'win32','sha256':distro.digest(p.read_bytes()),'stdlib_zip':'python314.zip','path_file':'python314._pth'}
 def test_wrong_vendor_archive_is_rejected(self):
  p=self.archive({'python.exe':b'fixture'})
  with self.assertRaisesRegex(ValueError,'checksum'):distro.runtime_files(p,{'sha256':'0'*64})
 def test_unsafe_and_missing_vendor_files_are_rejected(self):
  for files in [{'../python.exe':b'fixture'},{'C:/python.exe':b'fixture'},{'python.exe':b'fixture'}]:
   p=self.archive(files)
   with self.assertRaises(ValueError):distro.runtime_files(p,self.lock(p))
 def test_isolated_paths_and_license_are_included(self):
  p=self.archive({name:b'fixture' for name in ['python.exe','LICENSE.txt','python314.zip','python314._pth','vcruntime140.dll']})
  files=distro.runtime_files(p,self.lock(p));prefix='runtime/python/'
  self.assertEqual(files[prefix+'python314._pth'],b'python314.zip\n.\n../../tools\n../..\n')
  manifest=json.loads(files[prefix+'manifest.json'])
  self.assertEqual(manifest['files']['LICENSE.txt'],distro.digest(b'fixture'))
  self.assertNotIn('import site',files[prefix+'python314._pth'].decode())

if __name__=='__main__':unittest.main()
