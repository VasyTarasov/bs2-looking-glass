"""Verify an older source-only release upgrades without losing synthetic profiles."""
from pathlib import Path
import argparse,json,subprocess,sys,shutil
ROOT=Path(__file__).resolve().parent.parent
def main():
    p=argparse.ArgumentParser();p.add_argument('--old-package',type=Path,required=True);p.add_argument('--source',type=Path,required=True);p.add_argument('--sandbox',type=Path,required=True);a=p.parse_args()
    source=a.source.resolve();game=a.sandbox.resolve();old=a.old_package.resolve()
    assert not any(part.casefold()=='secrets' for x in [source,game,old] for part in x.parts)
    assert not game.exists() and source not in game.parents and game not in source.parents
    game.mkdir(parents=True)
    for name in json.loads((ROOT/'build_profile.json').read_bytes())['files']:
        dest=game/name;dest.parent.mkdir(exist_ok=True,parents=True);shutil.copy2(source/name,dest)
    scripts=game/'Data/Scripts.rvdata2';original=scripts.read_bytes()
    save=game/'Save01.rvdata2';save.write_bytes(b'SYNTHETIC SAVE ONLY')
    checks=0
    def check(value):
        nonlocal checks
        assert value;checks+=1
    def call(package,mode):
        return subprocess.run([sys.executable,str(package/'tools/install.py'),'--game',str(game),'--'+mode,'--modules','combat_shortcuts,controls,saves,debug'],capture_output=True)
    check(call(old,'install').returncode==0)
    sentinels={'BS2Suite/bindings.ini':b'version=1\nbind=quick,C1,skill,308\n','BS2Suite/loadouts.ini':b'SYNTHETIC PROFILE','BS2QoL/preferences.ini':b'SYNTHETIC FAVORITES','BS2QoL/bindings.ini':b'SYNTHETIC LEGACY BINDINGS','BS2Suite/profiles.ini':b'SYNTHETIC SEMANTIC PROFILE','BS2Suite/encounters.ini':b'3=2\n'}
    for name,data in sentinels.items():
        path=game/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
    installed=scripts.read_bytes()
    check(call(ROOT,'install').returncode!=0);check(scripts.read_bytes()==installed)
    check(call(ROOT,'uninstall').returncode==0);check(scripts.read_bytes()==original)
    check(call(ROOT,'install').returncode==0)
    check(json.loads((game/'BS2Suite/install.json').read_bytes())['version']=='0.8.0-alpha')
    for name,data in sentinels.items():check((game/name).read_bytes()==data)
    check(save.read_bytes()==b'SYNTHETIC SAVE ONLY')
    check((game/'Mods/BS2Suite/bindings_v2.rb').is_file())
    check(call(ROOT,'uninstall').returncode==0);check(scripts.read_bytes()==original)
    for name,data in sentinels.items():check((game/name).read_bytes()==data)
    result={'result':'PASS','checks':checks,'old_package':old.name,'new_version':'0.8.0-alpha','synthetic_only':True,'live_game_modified':False}
    (game/'upgrade_result.json').write_text(json.dumps(result,indent=2),encoding='utf-8');print(json.dumps(result))
if __name__=='__main__':main()
