# encoding: UTF-8
rgss_main do
  @checks=0
  def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
  def check(v,s);raise s unless v;@checks+=1;log('PASS '+s);end
  class SystemKeys09997
    attr_accessor :keys,:focus
    def initialize;@keys=[];@focus=true;end
    def down;@keys;end
    def focused?;@focus;end
  end
  def frame(keys=[]);@raw.keys=keys;Graphics.update;Input.update;end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'Controls, sound, run and quick-save lifecycle' }
    DataManager.init;DataManager.setup_new_game
    actor=$game_party.leader;actor.learn_skill(120)
    map=Scene_Map.new;SceneManager.instance_variable_set(:@scene,map)
    @raw=SystemKeys09997.new;BS2QoL::Keyboard.backend=@raw;BS2QoL::Keyboard.reset
    keys=BS2Suite::Keys
    check(!keys.set(:reference,keys.token(:C)),'global command cannot steal confirmation')
    check(!keys.set(:C,keys.token(:B)),'confirmation cannot steal cancel')
    check(!keys.set(:reference,'F12'),'engine restart stays reserved')
    old=keys.token(:reference)
    free=(%w(F11 J K L P CTRL+F3 CTRL+F4)).find { |t| !keys.data.values.include?(t) }
    check(keys.set(:reference,free),'reference can be rebound to free key')
    keys.instance_variable_set(:@data,nil)
    check(keys.token(:reference)==free,'custom reference key survives cold reload')
    check(keys.set(:reference,old),'reference binding can be restored')
    @raw.focus=false;frame([keys::BASE[keys.token(:quicksave)]])
    check(!keys.trigger?(:quicksave),'unfocused window ignores global shortcut')
    @raw.focus=true;frame
    [:bgm,:bgs,:me,:se].each do |channel|
      original=('bs2suite_'+channel.to_s+'_play').to_sym
      Audio.singleton_class.send(:alias_method,:qa_original_audio,original)
      Audio.singleton_class.send(:define_method,original) { |*args| @qa_args=args }
      old_volume=BS2Suite::Options.get(channel.to_s)
      [[0,0],[50,39],[100,77]].each do |setting,expected|
        check(BS2Suite::Options.set(channel.to_s,setting),'volume setting '+channel.to_s+':'+setting.to_s)
        Audio.send((channel.to_s+'_play').to_sym,'QA silent fixture',77,95)
        args=Audio.instance_variable_get(:@qa_args)
        check(args==['QA silent fixture',expected,95],'audio wrapper scales only volume '+channel.to_s+':'+setting.to_s)
      end
      BS2Suite::Options.set(channel.to_s,old_volume)
      Audio.singleton_class.send(:alias_method,original,:qa_original_audio)
    end
    $game_map.singleton_class.send(:define_method,:disable_dash?) { false }
    BS2Suite::Options.set('run_mode',2);frame
    check($game_player.dash?,'always-run mode runs without held Shift')
    frame([16]);check(!$game_player.dash?,'always-run mode uses Shift to walk');frame
    BS2Suite::Options.set('run_mode',1);BS2Suite::Run.instance_variable_set(:@active,false)
    check(!$game_player.dash?,'toggle-run starts inactive')
    BS2Suite::Run.toggle;check($game_player.dash?,'toggle-run activates dash')
    $game_map.singleton_class.send(:define_method,:disable_dash?) { true }
    check(!$game_player.dash?,'map dash prohibition overrides toggle-run')
    $game_map.singleton_class.send(:define_method,:disable_dash?) { false }
    $game_player.instance_variable_set(:@move_route_forcing,true)
    check(!$game_player.dash?,'forced movement overrides toggle-run')
    $game_player.instance_variable_set(:@move_route_forcing,false)
    $game_map.singleton_class.send(:remove_method,:disable_dash?)
    $game_player.perform_transfer
    $game_map.interpreter.clear
    $game_player.moveto(0,0);$game_message.clear;$game_temp.clear_common_event
    $game_system.save_disabled=false
    (100..104).each { |id| File.delete(DataManager.make_filename(id)) if File.file?(DataManager.make_filename(id)) }
    check(DataManager.savefile_max==105,'manual and quick slots remain separate')
    5.times { |i| check(BS2Suite::QuickSaves.save(map),'quick save '+i.to_s) }
    (100..104).each { |id| File.utime(Time.at(1000+id),Time.at(1000+id),DataManager.make_filename(id)) }
    check(BS2Suite::QuickSaves.next_slot==100,'rotation chooses oldest quick save')
    path=DataManager.make_filename(100);before=File.open(path,'rb') { |f| f.read }
    singleton=BS2Suite::Saves.singleton_class
    singleton.send(:alias_method,:qa_replace, :replace)
    singleton.send(:define_method,:replace) { |*args| raise IOError,'injected replace failure' }
    check(!BS2Suite::QuickSaves.save(map) && File.open(path,'rb') { |f| f.read }==before,'failed quick save keeps previous complete file')
    singleton.send(:alias_method,:replace,:qa_replace)
    $game_system.save_disabled=true
    check(!BS2Suite::QuickSaves.save(map),'native save prohibition blocks quick save')
    $game_system.save_disabled=false;$game_message.add('QA dialog')
    check(!BS2Suite::QuickSaves.save(map),'dialog blocks quick save')
    $game_message.clear
    saved={};[[:combat_effects,'J'],[:Z,'I'],[:C,'K'],[:B,'BACKSPACE']].each do |action,key|
      saved[action]=keys.token(action)
      check(keys.set(action,key),'hint test can rebind '+action.to_s)
    end
    window=BS2Suite::CombatEffectsWindow.new
    check(window.help_text.include?('K / F7') && window.help_text.include?('J / BACKSPACE'),'H hints follow current confirm, close and effects bindings')
    enabled=BS2Suite.instance_variable_get(:@enabled).dup
    BS2Suite.instance_variable_get(:@enabled).delete('reference_cards')
    check(!window.help_text.include?('сведения'),'H does not advertise a disabled reference module')
    BS2Suite.instance_variable_set(:@enabled,enabled);window.dispose
    $game_party.on_battle_start
    BS2Suite::BattleSupport.instance_variable_set(:@master,true)
    check(BS2Suite::BattleSupport.label.include?('I на предмете'),'support hint follows the reassigned automation key')
    $game_party.on_battle_end
    set={:name=>'QA empty',:slots=>Hash[BS2Modules::Loadouts.slots(actor).map { |i| [i,[actor.equip_slots[i],0]] }]}
    check(BS2Modules::Loadouts.lines(actor,set).join.include?('K →'),'loadout confirmation hint follows the confirm binding')
    saved.to_a.reverse.each do |action,key|
      restored=keys.set(action,key)
      diagnostic=restored ? '' : ' token='+key.inspect+' conflicts='+keys.data.reject { |id,value| id==action || value.split('+')[-1]!=key.to_s.split('+')[-1] }.inspect
      check(restored,'hint test restores '+action.to_s+diagnostic)
    end
    log('result=PASS; checks='+@checks.to_s)
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure
    BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  end
end
