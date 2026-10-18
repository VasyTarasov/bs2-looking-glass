"""Prepare a silent, Steam-free test copy. Original game and saves stay untouched."""
from pathlib import Path
import argparse,hashlib,json,shutil,sys,zlib
sys.dont_write_bytecode=True
from archive_reader import Marshal
from install import ROOT,dump,patch_scripts,target_running

PRELUDE=b'''# encoding: UTF-8
$bs2s_private_qa=true
module Audio
  class << self
    [:bgm_play,:bgs_play,:me_play,:se_play,:bgm_stop,:bgs_stop,:me_stop,:se_stop,
     :bgm_fade,:bgs_fade,:me_fade].each { |name| define_method(name) { |*args| nil } }
  end
end
module Input
  class << self
    def update; end
    def trigger?(*args); false; end
    def press?(*args); false; end
    def repeat?(*args); false; end
    def dir4; 0; end
    def dir8; 0; end
  end
end
File.open('test_result.txt','w') { |file| file.puts 'stage=silent_prelude' }
'''

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,required=True)
    parser.add_argument('--game',type=Path,required=True)
    parser.add_argument('--copy',action='store_true',help='Copy only runtime folders/executable, excluding saves and Steam files')
    parser.add_argument('--suite',choices=['resources0993','preferences0992','iteration0991','performance0991','iteration092dev','reference098','weapon_audit','iteration097','iteration094','smoke','system','keys','reference','forecast','modules','effects_loadouts','retry','screens','adversarial','stress','iteration','showcase','export','semantic','semantic_integration','semantic_forecast','semantic_boot','map_return','debug_performance'],default='modules')
    parser.add_argument('--vanilla',action='store_true',help='System suite without the mod for differential comparison')
    parser.add_argument('--cases',default='victory')
    parser.add_argument('--seed',type=int,default=24015)
    parser.add_argument('--isolate-visual-rng',action='store_true',help='Disable mist and separate sprite-constructor RNG in QA fixtures for deterministic comparison')
    parser.add_argument('--modules',default=None)
    args=parser.parse_args()
    source=args.source.resolve();game=args.game.resolve()
    if any(part.casefold()=='secrets' for p in (source,game) for part in p.parts):raise ValueError('Protected path refused')
    if game==source or game in source.parents or source in game.parents:
        raise ValueError('Test game must be in a separate directory')
    if target_running(game/'Game.exe'):raise ValueError('Test copy is already running')
    if list(game.glob('Save*.rvdata2')):raise ValueError('Test directory must not contain personal saves')
    if game.exists() and any(game.iterdir()) and not (game/'test_prepare_profile.json').is_file():
        raise ValueError('Use an empty directory or an already prepared test copy')
    profile=json.loads((ROOT/'build_profile.json').read_text(encoding='utf8'))
    for name,expected in profile['files'].items():
        if hashlib.sha256((source/name).read_bytes()).hexdigest()!=expected:
            raise ValueError('Source build mismatch: '+name)
    if args.copy:
        game.mkdir(parents=True,exist_ok=True)
        for folder in ('Data','Graphics','Audio','Fonts','System','Movies'):
            shutil.copytree(source/folder,game/folder,dirs_exist_ok=True)
        for name in ('Game.exe','Game.ini'):shutil.copy2(source/name,game/name)
    if (game/'steam_autocloud.vdf').exists() or (game/'steam_api.dll').exists():
        raise ValueError('Use a clean test directory without Steam files')
    if args.vanilla and args.suite!='system':raise ValueError('Vanilla mode requires system suite')
    raw=(source/'Data/Scripts.rvdata2').read_bytes()
    scripts=Marshal(raw if args.vanilla else patch_scripts(raw)).read()
    if b'class SteamAPIContext' not in zlib.decompress(scripts[222][2]):raise ValueError('Unexpected Steam script')
    scripts[222]=[scripts[222][0],scripts[222][1],zlib.compress(b'# Disabled in isolated test copy only.\n')]
    spec=(args.suite+'_spec.rb') if args.suite in ['resources0993','preferences0992','iteration0991','performance0991','iteration092dev','reference098','weapon_audit','iteration097','iteration094'] else {'system':'system_spec.rb','smoke':'keys_spec.rb','keys':'keys_spec.rb','reference':'reference_spec.rb','forecast':'forecast_spec.rb','modules':'modules_spec.rb','effects_loadouts':'effects_loadouts_spec.rb','retry':'battle_retry_spec.rb','screens':'screens_spec.rb','iteration':'iteration_spec.rb','adversarial':'adversarial_spec.rb','stress':'stress_spec.rb','showcase':'showcase_spec.rb','export':'export_spec.rb','semantic':'semantic_spec.rb','semantic_integration':'semantic_integration_spec.rb','semantic_forecast':'semantic_forecast_spec.rb','semantic_boot':'semantic_boot_spec.rb','map_return':'map_return_spec.rb','debug_performance':'debug_performance_spec.rb'}[args.suite]
    scripts[-1]=[scripts[-1][0],b'BS2QoL native tests',zlib.compress((ROOT/'tests'/spec).read_bytes())]
    scripts.insert(0,[900001,b'BS2QoL silent test prelude',zlib.compress(PRELUDE)])
    data=b'\x04\x08'+dump(scripts)
    check=Marshal(data)
    if len(check.read())!=(225 if args.vanilla else 226) or check.pos!=len(data):raise ValueError('Invalid test script table')
    shutil.copytree(ROOT/'mod/BS2Suite',game/'Mods/BS2Suite',dirs_exist_ok=True)
    from install import DEFAULTS, config, select
    selected=DEFAULTS if args.modules is None else ([] if args.modules=='none' else select(args.modules))
    (game/'BS2Suite').mkdir(exist_ok=True)
    (game/'BS2Suite/modules.ini').write_bytes(config(selected))
    shutil.copy2(ROOT/'tests/native_capture.rb',game/'BS2QA_native_capture.rb')
    if args.suite=='iteration0991':
        for name in ['iteration0991_extra.rb','tempo0992_extra.rb','followup0992_extra.rb']:shutil.copy2(ROOT/'tests'/name,game/name)
    from install import BOOT
    (game/'BS2QA_bootstrap.rb').write_bytes(BOOT)
    (game/'Data/Scripts.rvdata2').write_bytes(data)
    (game/'qa_options.txt').write_text('variant='+('vanilla' if args.vanilla else 'mod')+'\nseed='+str(args.seed)+'\ncases='+args.cases+'\nisolate_visual_rng='+str(args.isolate_visual_rng).lower()+'\n',encoding='utf8')
    (game/'test_prepare_profile.json').write_text(json.dumps({
      'silent':True,'steam_disabled':True,'test_harness':True,
      'scripts_sha256':hashlib.sha256(data).hexdigest()}),encoding='utf8')
    print(json.dumps({'prepared':True,'source_modified':False,'personal_saves_copied':False,
                      'requires_private_test_launcher':True}))

if __name__=='__main__':main()
