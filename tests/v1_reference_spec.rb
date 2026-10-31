# encoding: UTF-8
rgss_main do
  @checks=0
  def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
  def check(value,text);raise text unless value;@checks+=1;log('PASS '+text);end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'Reference and HD with Legacy/native controls and no groups' }
    check(!BS2Suite.enabled?('semantic_groups') && !defined?(BS2Suite::PaletteWindow),'groups are actually absent')
    check(!defined?(BS2Suite::BattleSupport) && !defined?(BS2Suite::Macros),'automation and macros are actually absent')
    DataManager.init;DataManager.setup_new_game
    SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(Graphics.width,Graphics.height))
    actor=$game_party.leader;actor.change_class(1);actor.change_level(70,false);actor.learn_skill(13);actor.recover_all
    $game_party.gain_item($data_items[61],4)
    BattleManager.setup(79,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
    actor.instance_variable_set(:@actions,Array.new(3) { Game_Action.new(actor) });actor.instance_variable_set(:@action_input_index,0)
    actor.instance_variable_set(:@ap,ATB::MAX_AP);BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
    scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,scene);scene.start;scene.start_actor_command_selection
    BS2Suite::HDDisplay.apply(BS2Suite::HDDisplay::DEFAULT) if defined?(BS2Suite::HDDisplay)
    scene.command_item;window=scene.instance_variable_get(:@item_window);window.refresh
    index=window.instance_variable_get(:@data).index($data_items[61]);check(!index.nil?,'native item list contains the selected item')
    window.select(index);window.openness=255;window.show.activate
    3.times { scene.update_basic }
    check(BS2QoL::Reference.open(scene,window),'F7 item reference opens without groups')
    3.times { scene.update_basic };check(BS2QoL::Reference.active?(scene),'item reference survives full scene updates')
    BS2QoL::Reference.close(scene);scene.on_item_cancel
    scene.command_skill;window=scene.instance_variable_get(:@skill_window);window.bs2q_all_types=true;window.refresh
    index=window.instance_variable_get(:@data).index($data_skills[13]);check(!index.nil?,'native skill list contains the learned technique')
    window.select(index);window.openness=255;window.show.activate
    3.times { scene.update_basic }
    check(BS2QoL::Reference.open(scene,window),'F7 skill formula and forecast open without groups')
    3.times { scene.update_basic };BS2QoL::Reference.close(scene);scene.on_skill_cancel
    check(scene.instance_variable_get(:@actor_command_window).active,'closing references restores native command input')
    scene.terminate;$game_party.on_battle_end
    log('result=PASS; checks='+@checks.to_s)
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure
    BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  end
end
