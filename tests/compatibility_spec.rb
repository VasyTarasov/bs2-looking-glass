# encoding: UTF-8
rgss_main do
  @checks=0
  def log(text);File.open('test_result.txt','a') { |f| f.puts text };end
  def check(value,text);raise text unless value;@checks+=1;log('PASS '+text);end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'Live BS2 compatibility contracts' }
    check(BS2Suite::VERSION=='1.02','current compatibility release boots')
    check(BS2Suite::SteamBridge.game_window!=0,'bridge selects this process RGSS window')
    DataManager.init;DataManager.setup_new_game
    SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(Graphics.width,Graphics.height))
    actor=$game_party.leader;actor.change_class(1);actor.change_level(70,false);actor.recover_all;$game_party.menu_actor=actor
    policy=BS2Suite::Compatibility.policy
    check(policy['schema']==1,'installer policy is loaded by the real game')
    excluded=policy['excluded'] || []
    if File.file?('expected_old_translation.txt');check(excluded.size>0,'old translation has live-property fallbacks');end
    entries=[$data_skills,$data_items,$data_weapons,$data_armors,$data_states]
    kinds=%w(skill item weapon armor state)
    samples=[]
    entries.each_with_index do |table,kind|
      table.compact.select { |x| !x.name.to_s.empty? }.first(6).each { |x| samples<<x }
    end
    excluded.first(12).each { |uid| x=BS2Suite::Compatibility.native(uid);samples<<x if x }
    samples.uniq.each do |object|
      uid=BS2Suite::CatalogV1.uid(object)
      row=BS2Suite::CatalogV1.entry(object)
      if excluded.include?(uid)
        check(row.nil?,'changed object does not inherit stale catalog: '+uid)
        check(BS2Suite::Reference098.get(object).nil?,'changed object does not inherit stale legacy prose: '+uid)
      elsif row
        native=object.name.to_s.dup.force_encoding('UTF-8')
        key=policy['native_language']=='ru' ? 'ru' : 'en'
        check(row['names'][key]==native,'catalog uses current translation name: '+uid)
      end
      # Both original catalogs and generic fallbacks must render actual cards.
      if object.is_a?(RPG::State)
        lines=BS2Suite::CatalogUI.state_properties(object)
        check(lines.is_a?(Array),'native state properties available: '+uid)
      elsif object.is_a?(RPG::UsableItem) || object.is_a?(RPG::EquipItem)
        card=BS2QoL::PracticalCard.new(object,actor,BS2Suite::Locale.current)
        check(card.sections.is_a?(Array) && !card.sections.flatten.empty?,'F7 card renders: '+uid)
      end
    end
    actor.learn_skill(13);$game_party.gain_item($data_items[61],4)
    BattleManager.setup(79,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
    actor.instance_variable_set(:@actions,Array.new(3) { Game_Action.new(actor) });actor.instance_variable_set(:@action_input_index,0)
    actor.instance_variable_set(:@ap,ATB::MAX_AP);BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
    scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,scene);scene.start;scene.start_actor_command_selection
    scene.command_item;window=scene.instance_variable_get(:@item_window);window.refresh
    index=window.instance_variable_get(:@data).index($data_items[61]);check(!index.nil?,'native battle items remain available')
    window.select(index);window.openness=255;window.show.activate
    check(BS2QoL::Reference.open(scene,window),'actual F7 opens in battle')
    2.times { scene.update_basic };BS2QoL::Reference.close(scene);scene.on_item_cancel
    check(scene.instance_variable_get(:@actor_command_window).active,'F7 restores battle input')
    scene.terminate;$game_party.on_battle_end
    check(Graphics.width==640 && Graphics.height==480,'source-frame size remains compatible')
    BS2Suite::SteamBridge.poll
    check(BS2Suite::SteamBridge.error.nil?,'graphical bridge booted without a window error')
    check(BS2Suite::SteamBridge.stats[4]==1,'native HD renderer is ready')
    log('result=PASS; checks='+@checks.to_s)
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure
    BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  end
end
