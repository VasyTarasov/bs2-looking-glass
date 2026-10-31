# encoding: UTF-8
rgss_main do
  @checks=0
  def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
  def check(v,s);raise s unless v;@checks+=1;log('PASS '+s);end
  class V1Keys
    attr_accessor :keys
    def initialize;@keys=[];end
    def down;@keys;end
    def focused?;true;end
  end
  def press(keys)
    @keys.keys=[];Graphics.update;Input.update
    @keys.keys=keys;Graphics.update;Input.update
    $v1_test_d=keys.include?(68)
  end
  # The native adapter reads physical D without remapping. Supply the same
  # logical event in synthetic fixtures where that optional adapter is absent.
  module Input
    class << self
      alias v1_test_native_trigger trigger?
      def trigger?(key);(key==:Z && $v1_test_d) || v1_test_native_trigger(key);end
    end
  end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'Version 1.0 module behavior and integration contracts' }
    check(BS2Suite::VERSION=='1.0','release version')
    compiled=0
    Dir.glob('Mods/BS2Suite/**/*.rb').each do |file|
      RubyVM::InstructionSequence.compile(File.open(file,'rb') { |f| f.read }.force_encoding('UTF-8'),file);compiled+=1
    end
    check(compiled>=179,'all Russian and English Ruby files compile in the native VM')
    check(BS2Suite::DEFAULT_MODULES.size==17 && (BS2Suite::IDS-BS2Suite::DEFAULT_MODULES).sort==%w(battle_support debug legacy_shortcuts),'exact requested defaults')
    check(BS2Suite::ModuleSelection.expand(['macros']).sort==%w(macros semantic_groups),'macro dependency has no loadouts or automation')
    check(!BS2Suite::ModuleSelection.toggle(['macros','semantic_groups'],'semantic_groups').include?('macros'),'dependent selection is removed with its prerequisite')
    check(!!defined?(BS2Suite::BattleSupport)==BS2Suite.enabled?('battle_support'),'automatic support code exists only when selected')
    check(!!defined?(BS2Suite::Macros)==BS2Suite.enabled?('macros'),'macro code exists only when selected')
    check(!!defined?(BS2Suite::PaletteWindow)==BS2Suite.enabled?('semantic_groups'),'group windows exist only when selected')
    check(!!defined?(BS2Suite::InteractionHighlight)==BS2Suite.enabled?('map_highlight'),'map highlighting code is independently selected')
    check(!!defined?(BS2Suite::BattleSpeed)==BS2Suite.enabled?('battle_speed'),'battle acceleration code is independently selected')
    check(BS2Suite.enabled?('effects')==BS2Suite.enabled?('reference_cards'),'reference and effect choice is unified')
    check(BS2Suite.enabled?('controls')==BS2Suite.enabled?('basic_qol'),'basic conveniences map to their shared choice')
    DataManager.init;DataManager.setup_new_game
    SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(Graphics.width,Graphics.height))
    actor=$game_party.leader;actor.change_class(1);actor.change_level(70,false);actor.recover_all;$game_party.menu_actor=actor
    @keys=V1Keys.new;BS2QoL::Keyboard.backend=@keys;BS2QoL::Keyboard.reset
    menu=BS2Suite::ModuleScene.new;SceneManager.instance_variable_set(:@scene,menu);menu.start
    list=menu.instance_variable_get(:@commands);list.select(BS2Suite::IDS.index('battle_support'));list.update_help
    help=menu.instance_variable_get(:@help_window)
    check(help.instance_variable_get(:@text)==BS2Suite::DESCRIPTIONS[BS2Suite::IDS.index('battle_support')],'in-game descriptions match installer metadata')
    check(list.y+list.height<=help.y,'module selection and description do not overlap')
    BS2Suite::DESCRIPTIONS.each { |text| help.set_text(text);check(help.wrapped_lines.size*20<=help.contents_height,'complete description fits native window') }
    list.update_help
    menu.terminate
    BattleManager.setup(79,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
    actor.instance_variable_set(:@actions,Array.new(3) { Game_Action.new(actor) });actor.instance_variable_set(:@action_input_index,0)
    actor.instance_variable_set(:@ap,ATB::MAX_AP);BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
    scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,scene);scene.start;scene.start_actor_command_selection
    command=scene.instance_variable_get(:@actor_command_window);command.openness=255
    check(!!scene.instance_variable_get(:@bs2q_plan)==BS2Suite.enabled?('action_queue'),'queue display is independent of both input systems')
    if BS2Suite.enabled?('legacy_shortcuts')
      BS2QoL::Bindings.set('quick','C1',:item,61)
      calls=[];scene.define_singleton_method(:bs2q_apply_binding) { |binding,context| calls<<[binding,context];true }
      press([17,49]);BS2QoL::Hotkeys.handle(command)
      check(calls.size==1 && calls[0][0][1]==61,'Legacy dispatches one binding with or without combat groups')
      check(BS2QoL::Keyboard.first.nil?,'Legacy consumes its keyboard command')
    end
    if BS2Suite.enabled?('semantic_groups')
      weapon=BS2Suite::Arsenal093::CATEGORIES.map { |name,ids| ids }.flatten.map { |id| $data_weapons[id] }.find { |w| w && actor.equippable?(w) }
      $game_party.gain_item(weapon,1)
      BS2Suite::DirectWeapons.sync(actor,true)
      press([]);BS2Suite::Palette.open(scene,command,actor,'N')
      popup=BS2Suite::Palette.current(scene)
      popup.acknowledge if popup.transition.any?
      popup.set_group(popup.entries.first[:group_number]) unless popup.group || popup.entries.empty?
      if popup.group && popup.item.is_a?(RPG::Weapon)
        selected=popup.item;press([68]);BS2Suite::Palette.update(scene)
        check(BS2Suite::DirectWeapons.selected(actor)==selected,'manual N weapon nomination works independently of automatic support')
      else
        raise 'Synthetic N weapon group unavailable'
      end
      BS2Suite::Palette.close(scene)
      actor.change_equip(0,weapon)
      quick_skill=RPG::Skill.new;quick_skill.id=5901;quick_skill.note=$data_items[61].note
      check(BS2Suite::ActionRules.quick?(quick_skill),'shared rules recognize an instant skill independently of automation')
      BS2Suite::Priorities.begin_battle;BS2Suite::Priorities.used(actor,quick_skill)
      counts=BS2Suite::Priorities.instance_variable_get(:@current)
      check(!counts.has_key?(actor.id.to_s+':'+BS2Suite::Priorities.token('N',weapon.id)),'instant skill does not count as paid weapon usage with automation off or on')
      tempo=BS2Suite::TempoHint
      class << tempo
        alias v1_original_readiness readiness
        def readiness(unit,ap=nil)
          $v1_tempo_ap<<ap if $v1_tempo_ap && unit.actor? && !ap.nil?
          v1_original_readiness(unit,ap)
        end
      end
      instant=$data_items[61];$game_party.gain_item(instant,4)
      instant.define_singleton_method(:next_ap) { [100,0] }
      saved_actions=actor.actions;action=Game_Action.new(actor);action.set_item(instant.id)
      actor.instance_variable_set(:@actions,[action]);BS2Suite::DirectWeapons.clear(actor)
      known=BS2Suite::Options.data['knowledge_threshold'];BS2Suite::Options.data['knowledge_threshold']=0
      $v1_tempo_ap=[];tempo.calculate(actor)
      check(!$v1_tempo_ap.empty? && $v1_tempo_ap.all? { |ap| ap==0 },'instant item does not set paid recovery AP in tempo forecasts with automation off or on')
      $v1_tempo_ap=nil;instant.singleton_class.send(:remove_method,:next_ap)
      actor.instance_variable_set(:@actions,saved_actions);BS2Suite::Options.data['knowledge_threshold']=known
    end
    if BS2Suite.enabled?('macros')
      press([]);check(BS2Suite::Macros.open(scene,command),'macro picker opens without requiring loadouts')
      BS2Suite::Macros.close(scene)
    end
    if BS2Suite.enabled?('battle_support')
      support=BS2Suite::BattleSupport
      check(!support.active? && support.definitions.empty?,'automatic support starts off in this battle')
      item=$data_items[61];$game_party.gain_item(item,4)
      check(support.toggle_object(actor,item) && support.configured?(actor,item),'automatic item can be enabled without combat groups')
      check(support.toggle_object(actor,item) && !support.configured?(actor,item),'automatic item can be disabled without combat groups')
    else
      check(!BS2Suite::SupportState.eligible?($data_items[61]) && !BS2Suite::SupportState.active?,'disabled support exposes no activation or active status')
      check(BS2Suite::ActionRules.quick?($data_items[61]),'manual instant-action rules remain available without automation')
    end
    scene.command_item;scene.on_item_cancel
    check(scene.instance_variable_get(:@actor_command_window).active,'native item menu restores command input')
    scene.terminate;$game_party.on_battle_end
    log('result=PASS; checks='+@checks.to_s)
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure
    BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  end
end
