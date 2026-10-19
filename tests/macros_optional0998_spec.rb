# encoding: UTF-8
rgss_main do
  @checks=0
  def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
  def check(v,s);raise s unless v;@checks+=1;log('PASS '+s);end
  class MacroOptionalKeys
    attr_accessor :keys
    def initialize;@keys=[];end
    def down;@keys;end
    def focused?;true;end
  end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'optional macro dependencies '+BS2Suite::VERSION }
    DataManager.init;DataManager.setup_new_game
    SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
    actor=$game_party.leader;actor.change_class(1);actor.recover_all
    BattleManager.setup(79,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
    actor.instance_variable_set(:@actions,[Game_Action.new(actor)]);actor.instance_variable_set(:@action_input_index,0)
    BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
    scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,scene);scene.start;scene.start_actor_command_selection
    check(!defined?(BS2Suite::CombatEffects) && !defined?(BS2Suite::ContextEffects),'effects module is actually absent in reduced fixture')
    check(!defined?(Window_BS2QReference) && !BS2Suite.enabled?('controls'),'reference and optional control module are absent')
    raw=MacroOptionalKeys.new;BS2QoL::Keyboard.backend=raw;BS2QoL::Keyboard.reset
    2.times { Graphics.update;Input.update }
    origin=scene.instance_variable_get(:@actor_command_window);origin.openness=255
    check(BS2Suite::Macros.open(scene,origin),'macro picker opens with only semantic groups and loadouts')
    picker=scene.instance_variable_get(:@bs2s_macros)
    Graphics.update;Input.update;picker.process_handling
    check(scene.instance_variable_get(:@bs2s_macros).equal?(picker),'picker dispatch does not require ContextEffects')
    raw.keys=[67];Graphics.update;Input.update;picker.process_handling
    check(!scene.instance_variable_get(:@bs2s_macros) && origin.active,'C closes picker with effects reference and remapping disabled')
    scene.terminate;$game_party.on_battle_end
    editor=BS2Suite::MacroScene.new;SceneManager.instance_variable_set(:@scene,editor);editor.start
    editor.instance_variable_get(:@list).select(0);editor.choose
    editor.instance_variable_get(:@list).select(0);editor.choose
    editor.instance_variable_get(:@list).select(0);editor.choose
    editor.instance_variable_get(:@list).select(0);editor.choose
    list=editor.instance_variable_get(:@list);list.select(list.item_max-1);editor.choose
    raw.keys=[];Graphics.update;Input.update
    raw.keys=[118];Graphics.update;Input.update;editor.update
    check(editor.instance_variable_get(:@stage)==:choices,'F7 is harmless in editor when reference module is not installed')
    editor.terminate
    log('result=PASS; checks='+@checks.to_s)
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure
    BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  end
end
