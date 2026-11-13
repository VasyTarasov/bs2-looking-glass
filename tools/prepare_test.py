"""Prepare a silent, Steam-free test copy. Original game and saves stay untouched."""
from pathlib import Path
import argparse,hashlib,json,shutil,sys,zlib
sys.dont_write_bytecode=True
from archive_reader import Marshal
from install import ROOT,dump,patch_scripts,target_running,run as check_install

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

def suite_file(name):
    aliases={'smoke':'keys'}
    if not name.replace('_','').isalnum():raise ValueError('Invalid suite name')
    path=ROOT/'tests'/(aliases.get(name,name)+'_spec.rb')
    if not path.is_file():raise ValueError('Unknown suite')
    return path

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,required=True)
    parser.add_argument('--game',type=Path,required=True)
    parser.add_argument('--copy',action='store_true',help='Copy only runtime folders/executable, excluding saves and Steam files')
    parser.add_argument('--suite',choices=['priority_finish','battle_exit','battle_exit_edges','battle_exit_loop','compatibility','v1_modules','v1_basic','v1_reference','v1_visual','localization','forecast_zero099994','hud_mechanics099994','catalog_ui','catalog_v1','forecast_percent','forecast_presentation','cleanse09999','auto_items09998','polish_content','polish_support','polish_gunbreak','polish_inventory','polish_economy','polish_system','module_boot','live09996','menus09995','diagnostic_text09995','menus09994','queue09993','forecast_weapons','forecast_matrix','forecast_catalog','forecast_baseline','highlight_catalog','iteration09992','iteration0999','macros_optional0998','iteration0997','map0997','rings0996','diagnostics0995','battle_speed0994','resources0993','preferences0992','iteration0991','performance0991','iteration092dev','reference098','weapon_audit','iteration097','iteration094','smoke','system','keys','reference','forecast','modules','effects_loadouts','screens','adversarial','stress','iteration','showcase','export','semantic','semantic_integration','semantic_forecast','semantic_boot','map_return','debug_performance'],default='v1_modules')
    parser.add_argument('--vanilla',action='store_true',help='System suite without the mod for differential comparison')
    parser.add_argument('--cases',default='victory')
    parser.add_argument('--seed',type=int,default=24015)
    parser.add_argument('--isolate-visual-rng',action='store_true',help='Disable mist and separate sprite-constructor RNG in QA fixtures for deterministic comparison')
    parser.add_argument('--battle-ctrl',choices=['normal','instant'],help='System QA: hold Ctrl throughout battle with the selected presentation mode')
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
    compatible=check_install(source,mode='check')
    if args.copy:
        game.mkdir(parents=True,exist_ok=True)
        for folder in ('Data','Graphics','Audio','Fonts','System','Movies'):
            if (source/folder).is_dir():shutil.copytree(source/folder,game/folder,dirs_exist_ok=True)
        for name in ('Game.exe','Game.ini'):shutil.copy2(source/name,game/name)
    if (game/'steam_autocloud.vdf').exists() or (game/'steam_api.dll').exists():
        raise ValueError('Use a clean test directory without Steam files')
    if args.vanilla and args.suite!='system':raise ValueError('Vanilla mode requires system suite')
    original=source/'BS2Suite/Scripts.original.rvdata2' if compatible['installed'] else source/'Data/Scripts.rvdata2'
    if compatible.get('storage')=='archive' and not compatible['installed']:
        from packed_game import read_scripts
        raw=read_scripts(source/'Game.rgss3a')
    else:raw=original.read_bytes()
    scripts=Marshal(raw if args.vanilla else patch_scripts(raw)).read()
    for i,row in enumerate(scripts):
        if b'class SteamAPIContext' in zlib.decompress(row[2]):
            scripts[i]=[row[0],row[1],zlib.compress(b'# Disabled in isolated test copy only.\n')]
    spec=suite_file(args.suite)
    main_index=next(i for i,row in enumerate(scripts) if row[1]==b'Main')
    scripts[main_index]=[scripts[main_index][0],b'BS2QoL native tests',zlib.compress(spec.read_bytes())]
    scripts.insert(0,[900001,b'BS2QoL silent test prelude',zlib.compress(PRELUDE)])
    data=b'\x04\x08'+dump(scripts)
    check=Marshal(data)
    if len(check.read())!=len(scripts) or check.pos!=len(data):raise ValueError('Invalid test script table')
    shutil.copytree(ROOT/'mod/BS2Suite',game/'Mods/BS2Suite',dirs_exist_ok=True)
    from install import DEFAULTS, config, select
    selected=DEFAULTS if args.modules is None else ([] if args.modules=='none' else select(args.modules))
    (game/'BS2Suite').mkdir(exist_ok=True)
    import install as installer_module
    if installer_module._compatibility_policy:(game/'BS2Suite/compatibility.rvdata2').write_bytes(installer_module._compatibility_policy)
    (game/'BS2Suite/modules.ini').write_bytes(config(selected))
    (game/'BS2Suite/language.ini').write_text('language='+compatible['language']+'\n',encoding='ascii')
    shutil.copy2(ROOT/'tests/native_capture.rb',game/'BS2QA_native_capture.rb')
    if args.suite.startswith('battle_exit') or args.suite=='priority_finish':
        shutil.copy2(ROOT/'tests/battle_exit_helpers.rb',game/'BS2QA_exit_helpers.rb')
    if args.suite=='iteration0991':
        for name in ['iteration0991_extra.rb','tempo0992_extra.rb','followup0992_extra.rb']:shutil.copy2(ROOT/'tests'/name,game/name)
    from install import BOOT
    (game/'BS2QA_bootstrap.rb').write_bytes(BOOT)
    (game/'Data').mkdir(exist_ok=True)
    (game/'Data/Scripts.rvdata2').write_bytes(data)
    if compatible.get('storage')=='archive':
        from packed_game import patched_copy
        packed_source=source/'BS2Suite/Game.original.rgss3a' if compatible['installed'] else source/'Game.rgss3a'
        patched_copy(packed_source,game/'Game.rgss3a',data)
    (game/'qa_options.txt').write_text('variant='+('vanilla' if args.vanilla else 'mod')+'\nseed='+str(args.seed)+'\ncases='+args.cases+'\nisolate_visual_rng='+str(args.isolate_visual_rng).lower()+'\n',encoding='utf8')
    if args.battle_ctrl:
        with (game/'qa_options.txt').open('a',encoding='utf8') as stream:stream.write('battle_ctrl='+args.battle_ctrl+'\n')
    (game/'test_prepare_profile.json').write_text(json.dumps({
      'silent':True,'steam_disabled':True,'test_harness':True,
      'scripts_sha256':hashlib.sha256(data).hexdigest()}),encoding='utf8')
    print(json.dumps({'prepared':True,'source_modified':False,'personal_saves_copied':False,
                      'requires_private_test_launcher':True}))

if __name__=='__main__':main()
