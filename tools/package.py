"""Build an audited development ZIP; never publish or create a release."""
from pathlib import Path
import argparse,hashlib,json,zipfile,sys
sys.dont_write_bytecode=True
from repo_audit import ROOT,audit,read_files

def package(output):
 output=Path(output).resolve()
 if ROOT==output or ROOT in output.parents:raise ValueError('Write the archive outside the repository')
 if any(p.casefold()=='secrets' for p in output.parts):raise ValueError('Protected output refused')
 report=audit()
 if report['result']!='PASS':raise ValueError('Repository audit failed; inspect tools/repo_audit.py output')
 files,_=read_files(ROOT);version=json.loads(files['project.json'])['version'];prefix='LookingGlass-'+version+'/'
 manifest={rel:hashlib.sha256(data).hexdigest() for rel,data in sorted(files.items())}
 output.parent.mkdir(parents=True,exist_ok=True)
 with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
  for rel,data in sorted(files.items()):z.writestr(prefix+rel,data)
  z.writestr(prefix+'SHA256.json',json.dumps(manifest,indent=2)+'\n')
 with zipfile.ZipFile(output) as z:
  assert z.testzip() is None
  for rel,digest in manifest.items():assert hashlib.sha256(z.read(prefix+rel)).hexdigest()==digest
 digest=hashlib.sha256(output.read_bytes()).hexdigest()
 output.with_suffix(output.suffix+'.sha256').write_text(digest+'  '+output.name+'\n',encoding='ascii')
 return {'result':'PASS','version':version,'files':len(files),'bytes':output.stat().st_size,'sha256':digest,'release_created':False}

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args();print(json.dumps(package(a.output)))
