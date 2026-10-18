"""Exercise only synthetic fixtures in the explicitly selected sandbox."""
from pathlib import Path
import argparse,hashlib,json,shutil,sys
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(__file__).resolve().parent.parent/'tools'))
import install

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--source',type=Path,required=True);parser.add_argument('--sandbox',type=Path,required=True)
    args=parser.parse_args();source=args.source.resolve();sandbox=args.sandbox.resolve()
    if sandbox==source or source in sandbox.parents or sandbox in source.parents: raise ValueError('Separate sandbox required')
    for path in (source,sandbox):
        if any(part.casefold()=='secrets' for part in path.parts):raise ValueError('Protected path refused')
    if sandbox.exists() and any(sandbox.iterdir()):raise ValueError('Use an empty sandbox')
    sandbox.mkdir(parents=True,exist_ok=True)
    profile=json.loads((install.ROOT/'build_profile.json').read_text(encoding='utf8'))
    count=0
    def check(value,name):
        nonlocal count
        if not value:raise AssertionError(name)
        count+=1
    def fixture(name,qol=False):
        game=sandbox/name;game.mkdir()
        for rel in profile['files']:
            path=game/rel;path.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source/rel,path)
        if qol:
            rows=install.table((game/'Data/Scripts.rvdata2').read_bytes())
            rows.insert(-1,[900002,b'BS2QoL bootstrap',install.zlib.compress(install.QOL_BOOT)])
            (game/'Data/Scripts.rvdata2').write_bytes(b'\x04\x08'+install.dump(rows))
            (game/'Mods/BS2QoL').mkdir(parents=True)
            (game/'Mods/BS2QoL/main.rb').write_text('# synthetic existing mod\n',encoding='utf8')
        (game/'Save01.rvdata2').write_bytes(b'SYNTHETIC TEST SAVE - NOT USER DATA')
        return game
    def refused(call,name):
        try:call()
        except (ValueError,RuntimeError,OSError):check(True,name)
        else:raise AssertionError('Expected refusal: '+name)
    for number,selected in enumerate((['effects'],['loadouts'],install.IDS)):
        game=fixture('choice'+str(number),qol=number==2)
        scripts=game/'Data/Scripts.rvdata2';original=scripts.read_bytes();saved=(game/'Save01.rvdata2').read_bytes()
        check(install.run(game)['compatible'],'check compatible')
        check(scripts.read_bytes()==original,'check makes no changes')
        check(install.run(game,'install',selected)['installed'],'install selected modules')
        rows=install.table(scripts.read_bytes())
        check(sum(row[1]==install.NAME for row in rows)==1,'one module bootstrap')
        check((game/'BS2Suite/Scripts.original.rvdata2').read_bytes()==original,'exact backup')
        check((game/'BS2Suite/modules.ini').read_bytes()==install.config(selected),'selected config only')
        check(install.run(game,'install',selected)['configured'],'repeated install configures without duplicate')
        check(install.run(game,'configure',['effects'])['configured'],'selection change')
        (game/'BS2Suite/loadouts.ini').write_text('profile sentinel',encoding='utf8')
        check(install.run(game,'uninstall')['uninstalled'],'uninstall')
        check(scripts.read_bytes()==original,'exact restoration including preexisting QoL')
        check((game/'BS2Suite/loadouts.ini').read_text(encoding='utf8')=='profile sentinel','profiles preserved')
        check(install.run(game,'uninstall')['already_uninstalled'],'uninstall idempotent')
        check((game/'Save01.rvdata2').read_bytes()==saved,'synthetic save untouched')
        check(install.run(game,'install',selected)['installed'],'reinstall after uninstall')
        patched=scripts.read_bytes();scripts.write_bytes(patched+b'foreign-change')
        refused(lambda:install.run(game,'uninstall'),'foreign script change refused')
        check(scripts.read_bytes()==patched+b'foreign-change','foreign change not overwritten')
    game=fixture('running');original=(game/'Data/Scripts.rvdata2').read_bytes()
    prior=install.target_running;install.target_running=lambda path:True
    refused(lambda:install.run(game,'install'),'running target refused')
    check((game/'Data/Scripts.rvdata2').read_bytes()==original,'running target unchanged')
    install.target_running=prior
    game=fixture('unknown');rows=install.table((game/'Data/Scripts.rvdata2').read_bytes());rows[5][0]+=1
    (game/'Data/Scripts.rvdata2').write_bytes(b'\x04\x08'+install.dump(rows))
    refused(lambda:install.run(game,'install'),'unknown game script refused')
    game=fixture('backup');install.run(game,'install')
    (game/'BS2Suite/Scripts.original.rvdata2').write_bytes(b'bad backup')
    refused(lambda:install.run(game,'uninstall'),'damaged backup refused')
    game=fixture('code');install.run(game,'install')
    (game/'Mods/BS2Suite/main.rb').write_text('# foreign edit',encoding='utf8')
    refused(lambda:install.run(game,'configure',['effects']),'foreign code edit not replaced')
    refused(lambda:install.select('unknown'),'unknown module selection refused')
    refused(lambda:install.select(''),'empty module selection refused')
    result={'result':'PASS','checks':count,'fixture_only':True,'personal_saves_read':False,'live_game_modified':False}
    (sandbox/'result.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf8')
    print(json.dumps(result))

if __name__=='__main__':main()
