# encoding: UTF-8
rgss_main do
  load 'BS2QA_native_capture.rb'
  def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'Optional module boot / native menu contract' }
    DataManager.init;DataManager.setup_new_game;Window_MenuCommand.init_command_position
    log('loaded='+BS2Suite::IDS.select { |id| BS2Suite.enabled?(id) }.join(','))
    SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
    windows=[]
    windows<<Window_MenuCommand.new
    windows<<BS2Suite::SettingsCommands.new(0,72)
    windows<<BS2Suite::KeyCommands.new(0,72)
    windows<<BS2Suite::ModuleCommands.new([])
    windows.each { |w| w.dispose }
    actor=$game_party.leader;actor.change_class(1);actor.change_level(30,false);actor.recover_all
    $game_party.gain_item($data_items[61],3)
    BattleManager.setup(79,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
    actor.instance_variable_set(:@actions,Array.new(3) { Game_Action.new(actor) });actor.instance_variable_set(:@action_input_index,0)
    actor.instance_variable_set(:@ap,ATB::MAX_AP);BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
    scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,scene);scene.start;scene.start_actor_command_selection
    scene.command_item;scene.instance_variable_get(:@item_window).openness=255
    3.times { scene.update_basic }
    scene.on_item_cancel
    scene.terminate
    log('result=PASS; checks=6')
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure
    BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  end
end
