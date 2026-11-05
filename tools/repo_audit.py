"""Content-free publication gate: report paths/rules, never matched values."""
from pathlib import Path,PurePosixPath
import argparse,hashlib,json,os,re,subprocess,sys,posixpath
ROOT=Path(__file__).resolve().parents[1]
ASSET_PATHS={'mod/BS2Suite/native/bs2_steam_bridge.dll','mod/BS2Suite/reference098.rvdata2','mod/BS2Suite/catalog_v1.rvdata2','mod/BS2Suite/catalog_v1.en.rvdata2'}
MEDIA_MANIFEST='docs/guide-media.json'
MEDIA_PATH=re.compile(r'^docs/assets/guide/[a-z0-9][a-z0-9-]*\.(?:png|jpg|gif)$')
FORBIDDEN_DIRS={'secrets','private','data','graphics','audio','system','fonts','userdata','work','outputs','validation','debug','.codex','.agents','bs2suite','bs2qol','bs2modules'}
TEXT={'.rb','.py','.ps1','.cmd','.md','.svg','.json','.yml','.yaml','.txt','.c','.h','.cpp'}
PRIVATE=re.compile(rb'[A-Za-z]:[\\/](?:Users[\\/]|PROJECT\s+CLOUD[\\/])|[\\/]userdata[\\/]\d+',re.I)
TOKENS=re.compile(rb'gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{40,}|sk-(?:proj-)?[A-Za-z0-9_-]{40,}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----')
ASSIGNED=re.compile(rb'(?i)(?:api[_-]?key|client[_-]?secret|access[_-]?token|password)\s*[=:]\s*[\x22\x27]([A-Za-z0-9_+/=-]{24,})[\x22\x27]')

def media_manifest(raw):
 errors=[];valid={}
 try:
  rows=json.loads(raw).get('files',{})
  if not isinstance(rows,dict):raise ValueError()
 except (ValueError,AttributeError):return {},[{'path':MEDIA_MANIFEST,'rule':'invalid guide media manifest'}]
 for rel,row in rows.items():
  if not MEDIA_PATH.fullmatch(rel) or not isinstance(row,dict) or not re.fullmatch(r'[a-f0-9]{64}',str(row.get('sha256',''))):
   errors.append({'path':MEDIA_MANIFEST,'rule':'invalid guide media entry'});continue
  valid[rel]=row
 return valid,errors

def read_media(root,staged=False):
 if staged:
  result=subprocess.run(['git','show',':'+MEDIA_MANIFEST],cwd=root,capture_output=True)
  return media_manifest(result.stdout) if result.returncode==0 else ({},[])
 path=Path(root)/MEDIA_MANIFEST
 if path.is_symlink() or path.is_junction():return {},[{'path':MEDIA_MANIFEST,'rule':'linked media manifest'}]
 return media_manifest(path.read_bytes()) if path.is_file() else ({},[])

def path_issue(rel,assets):
 p=PurePosixPath(rel);parts=[s.casefold() for s in p.parts]
 if p.is_absolute() or '..' in p.parts:return 'path traversal'
 if parts and parts[0]=='runtime':return 'release-only Python runtime; use the pinned distribution builder'
 if any(s in FORBIDDEN_DIRS and not (s=='bs2suite' and i==1 and parts[0]=='mod') for i,s in enumerate(parts[:-1])):return 'private/runtime directory'
 if any(s in {'secrets','private','.codex','.agents'} for s in parts):return 'protected/private path'
 name=p.name.casefold();ext=p.suffix.casefold()
 if name.startswith('.env') or '.session' in name or ext in {'.pem','.key','.pfx','.p12','.log','.dmp','.zip','.7z','.rar','.rgss3a','.rvdata','.ini','.pyc','.pyo'}:return 'private/generated file'
 if ext in {'.dll','.rvdata2','.exe','.bin'} and rel not in assets:return 'unapproved binary/game data'
 if name in {'installation_result.json','test_result.txt','test_prepare_profile.json','qa_options.txt','sha256.json'}:return 'local/generated result'
 if ext in {'.png','.jpg','.gif'}:
  if rel not in assets or not MEDIA_PATH.fullmatch(rel):return 'unapproved documentation media'
 elif ext not in TEXT|{'.dll','.rvdata2'} and name not in {'.gitignore','.gitattributes'}:return 'unapproved file type'
 return None

def inspect_file(rel,data,assets):
 errors=[];issue=path_issue(rel,assets)
 if issue:return [issue]
 if rel in assets:
  if hashlib.sha256(data).hexdigest()!=assets[rel]['sha256']:errors.append('runtime asset hash mismatch')
  if PRIVATE.search(data):errors.append('private path in runtime asset')
  if TOKENS.search(data) or ASSIGNED.search(data):errors.append('possible credential material in runtime asset')
  if MEDIA_PATH.fullmatch(rel):
   ext=PurePosixPath(rel).suffix
   if not (ext=='.png' and data.startswith(b'\x89PNG\r\n\x1a\n') or ext=='.gif' and data.startswith((b'GIF87a',b'GIF89a')) or ext=='.jpg' and data.startswith(b'\xff\xd8\xff')):errors.append('documentation media format mismatch')
  return errors
 try:text=data.decode('utf-8-sig')
 except UnicodeDecodeError:return ['non-UTF8 source']
 if PRIVATE.search(data):errors.append('workstation/personal path')
 if TOKENS.search(data) or ASSIGNED.search(data):errors.append('possible credential material')
 if rel.endswith('.ps1') and not data.startswith(b'\xef\xbb\xbf'):errors.append('PowerShell 5.1 requires UTF-8 BOM')
 if rel.endswith('.json'):
  try:json.loads(text)
  except ValueError:errors.append('invalid JSON')
 return errors

def read_files(root,staged=False):
 files={};media,errors=read_media(root,staged);allowed=ASSET_PATHS|set(media)
 if staged:
  paths=subprocess.check_output(['git','ls-files','-z'],cwd=root).decode('utf8').split('\0')
  for rel in filter(None,paths):
   issue=path_issue(rel,allowed)
   if issue:errors.append({'path':rel,'rule':issue});continue
   # Index bytes are audited, not an assumed copy of the working tree.
   files[rel]=subprocess.check_output(['git','show',':'+rel],cwd=root)
  return files,errors
 for base,dirs,names in os.walk(root,followlinks=False):
  parent=Path(base)
  for d in dirs[:]:
   path=parent/d;rel=path.relative_to(root).as_posix()
   # Runtime is generated only from the pinned official archive, never copied
   # from a checkout by read_files/package. Staged runtime paths are rejected.
   if d in {'.git','__pycache__','runtime'}:dirs.remove(d);continue
   if path.is_symlink() or path.is_junction():errors.append({'path':rel,'rule':'linked directory'});dirs.remove(d);continue
   if d.casefold() in FORBIDDEN_DIRS and rel!='mod/BS2Suite':errors.append({'path':rel,'rule':'private/runtime directory'});dirs.remove(d)
  for name in names:
   if parent==root and name=='SHA256.json':continue # Generated release manifest, never an input to source packaging.
   path=parent/name;rel=path.relative_to(root).as_posix()
   if path.is_symlink():errors.append({'path':rel,'rule':'linked file'});continue
   # Refuse secret-shaped file names before opening them.
   issue=path_issue(rel,allowed)
   if issue:errors.append({'path':rel,'rule':issue});continue
   files[rel]=path.read_bytes()
 return files,errors

def link_errors(files):
 errors=[]
 for rel,data in files.items():
  if not rel.endswith('.md'):continue
  text=data.decode('utf-8-sig')
  links=re.findall(r'\]\(([^)]+)\)',text)+re.findall(r'(?:href|src)="([^"]+)"',text)
  for link in links:
   if re.match(r'^[a-z]+:',link,re.I) or link.startswith('#'):continue
   target=link.split('#')[0].split('?')[0]
   if not target:continue
   normalized=posixpath.normpath(posixpath.join(posixpath.dirname(rel),target))
   if normalized not in files:errors.append({'path':rel,'rule':'missing relative documentation target'})
 return errors

def audit(root=ROOT,staged=False):
 files,errors=read_files(root,staged)
 assets=json.loads(files.get('runtime-assets.json',b'{}'))
 media,media_errors=media_manifest(files[MEDIA_MANIFEST]) if MEDIA_MANIFEST in files else ({},[])
 errors+=media_errors
 expected={'mod/BS2Suite/native/bs2_steam_bridge.dll','mod/BS2Suite/reference098.rvdata2','mod/BS2Suite/catalog_v1.rvdata2','mod/BS2Suite/catalog_v1.en.rvdata2'}
 if set(assets)!=expected:errors.append({'path':'runtime-assets.json','rule':'unexpected binary allowlist'})
 runtime_count=len(assets);assets.update(media)
 for rel,data in files.items():
  for rule in inspect_file(rel,data,assets):errors.append({'path':rel,'rule':rule})
 for rel in assets:
  if rel not in files:errors.append({'path':rel,'rule':'missing runtime asset'})
 errors+=link_errors(files)
 project=json.loads(files.get('project.json',b'{}'))
 if project.get('version')!='1.03' or project.get('stable_release') is not True:errors.append({'path':'project.json','rule':'version 1.03 release metadata required'})
 if b'original descriptions from' in files.get('mod/BS2Suite/qol/lib/reference_data.rb',b'').lower():errors.append({'path':'reference_data.rb','rule':'original description export retained'})
 workflow=files.get('.github/workflows/checks.yml',b'')
 if workflow and (b'contents: read' not in workflow or b'persist-credentials: false' not in workflow):errors.append({'path':'.github/workflows/checks.yml','rule':'read-only checkout required'})
 return {'result':'FAIL' if errors else 'PASS','files':len(files),'staged':staged,'runtime_assets':runtime_count,'guide_media':len(media),'errors':errors}

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--staged',action='store_true');args=p.parse_args()
 report=audit(staged=args.staged);print(json.dumps(report,ensure_ascii=True));raise SystemExit(report['result']!='PASS')
