# encoding: UTF-8
@checks=0
def log(text);File.open('test_result.txt','a') { |file| file.puts text };end
def check(value,label);raise 'Assertion: '+label unless value;@checks+=1;log('PASS '+label);end
class SemanticRawKeys
  attr_accessor :keys,:focus
  def initialize;@keys=[];@focus=true;end
  def down;@keys.dup;end
  def focused?;@focus;end
end
def frame(keys=[])
  @raw.keys=keys;Graphics.update;Input.update
  if @scene && BS2QoL::Reference.active?(@scene)
    BS2QoL::Reference.update(@scene)
  elsif @scene && BS2Suite::Palette.current(@scene)
    BS2Suite::Palette.current(@scene).update;BS2Suite::Palette.update(@scene)
  elsif @scene
    @scene.instance_variable_get(:@actor_command_window).update
  end
end
def key(code);frame;frame([code]);end
def sequence(text);text.each_byte { |code| key(code) };end
def setup_battle(actor)
  BattleManager.setup(79,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
  BS2Suite::Semantic.acknowledge(actor,'N')
  actor.instance_variable_set(:@ap,ATB::MAX_AP);actor.make_actions
  BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
  @scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,@scene);@scene.start;@scene.start_actor_command_selection
  @scene.instance_variable_get(:@actor_command_window).openness=255
end
def finish_battle
  BS2Suite::Palette.close(@scene) if BS2Suite::Palette.current(@scene)
  BS2QoL::Reference.close(@scene) if BS2QoL::Reference.active?(@scene)
  @scene.terminate;$game_party.on_battle_end;@scene=nil
end
def snapshot(actor)
  [actor.hp,actor.mp,actor.tp,actor.equips.map { |e| e && e.id },actor.instance_variable_get(:@states).dup,
   actor.instance_variable_get(:@buffs).dup,actor.actions.map { |a| [a.object_id,a.item && a.item.id,a.target_index] },
   $game_party.weapons.map { |w| [w.id,$game_party.item_number(w)] }]
end
begin
  File.open('test_result.txt','w') { |file| file.puts 'semantic_070; ruby='+RUBY_VERSION }
  DataManager.init;DataManager.setup_new_game
  BS2Suite::Options.set('knowledge_threshold',2)
  SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
  actor=$game_party.members[0];actor.change_class(1);actor.change_level(70,false);actor.clear_equipments
  $game_party.weapons.each { |w| $game_party.lose_item(w,999,true) }
  $game_party.items.each { |i| $game_party.lose_item(i,999) }
  actor.skills.each { |s| actor.forget_skill(s.id) }
  [102,256].each { |id| $game_party.gain_item($data_weapons[id],1) }
  actor.change_equip(0,$data_weapons[102]);actor.recover_all
  model=BS2Suite::Semantic;direct=BS2Suite::DirectWeapons
  model.sync(actor)
  check(model.groups(actor,'V').size==1,'two early swords use one compact group')
  check(model.rows(actor,'V',1).map { |r| r[:id] }==[105,106,308],'early three techniques have the requested compact order')
  [157,362].each { |id| $game_party.gain_item($data_weapons[id],1) }
  model.sync(actor)
  check(model.rows(actor,'V',1).map { |r| r[:id] }==[105,106,308,110,155,122],'Club and Hans +1 append exactly three techniques')
  check(model.set_mode(actor,'advanced'),'advanced author profile can be selected early')
  check(model.rows(actor,'V',1).map { |r| r[:id] }==[105,106,308,110,155,122],'advanced profile is usable with the same six early techniques')
  model.set_mode(actor,'progression')
  @raw=SemanticRawKeys.new;BS2QoL::Keyboard.backend=@raw;BS2QoL::Keyboard.reset;frame
  BS2Suite::Keys.instance_variable_set(:@data,BS2Suite::Keys::DEFAULT.dup)
  check(BS2Suite::Keys::DEFAULT.size==BS2Suite::Keys::LABELS.size,'prefix actions have configurable key labels')
  BS2Suite::Knowledge.instance_variable_set(:@counts,{})
  setup_battle(actor)
  first_enemy=$game_troop.alive_members[0]
  check(!BS2Suite::Knowledge.allowed?(first_enemy),'first encounter does not reveal exact enemy data')
  known_count=BS2Suite::Knowledge.counts[first_enemy.enemy_id]
  3.times { BS2Suite::Knowledge.present }
  check(BS2Suite::Knowledge.counts[first_enemy.enemy_id]==known_count,'frames and repeated scene observations do not count as new encounters')
  hidden=BS2QoL::PracticalCard.new($data_skills[14],actor,:ru)
  check(hidden.forecast_lines.join.include?('закрыт'),'unknown target cannot leak through numerical forecast')
  before=snapshot(actor)
  sequence('V')
  check(BS2Suite::Palette.current(@scene).prefix=='V','V opens the technique root')
  sequence('V')
  check(!BS2Suite::Palette.current(@scene) && snapshot(actor)==before,'V V closes without acting')
  sequence('B');sequence('B');check(!BS2Suite::Palette.current(@scene),'B B closes')
  sequence('M');sequence('M');check(!BS2Suite::Palette.current(@scene),'M M closes')
  sequence('V1');key(27)
  check(!BS2Suite::Palette.current(@scene),'one Esc exits a nested palette')
  direct.select(actor,$data_weapons[362])
  sequence('NN')
  check(!direct.selected_id(actor) && snapshot(actor)==before,'N N clears intent without switching equipment or spending a slot')
  sequence('N2')
  row=BS2Suite::Palette.current(@scene).entries.find { |r| r[:object].id==362 }
  key(row[:digit]+48)
  check(direct.selected(actor).id==362 && actor.equips[0].id==102 && snapshot(actor)==before,'N2 selects a future weapon without touching current stats resources or actions')
  sequence('N');key(27)
  check(direct.selected(actor).id==362,'Esc preserves the selected execution weapon')
  sequence('N1')
  row=BS2Suite::Palette.current(@scene).entries.find { |r| r[:object].id==362 }
  key(row[:digit]+48)
  check(actor.equips[0].id==362 && actor.instance_variable_get(:@action_input_index)==0,'N1 changes weapon immediately without consuming an action')
  count=actor.actions.size
  frame;frame([17,49])
  check(actor.actions.size==count && actor.actions.all? { |a| !a.item },'legacy chords are disabled by default')
  direct.clear(actor)
  sequence('V14')
  check(actor.actions.any? { |a| a.item && a.item.id==110 },'V1 digit4 equips the source and queues Battle Surge through native selection')
  check(actor.equips[0].id==157,'source selection follows Club +1')
  remaining=actor.actions.size+1
  while remaining>0 && BS2QoL::Hotkeys.context(@scene)==:commands
    @scene.bs2q_command(:guard);remaining-=1
  end
  check(actor.instance_variable_get(:@bs2s_direct_final).equal?(actor.actions.last),'native completion of input arms the actual last action automatically')
  finish_battle
  # Real final-action preparation, including the previously investigated Hans ID.
  [133,366].each { |id| $game_party.gain_item($data_weapons[id],1) }
  actor.change_equip(0,$data_weapons[366]);actor.recover_all;actor.learn_skill(14)
  setup_battle(actor)
  actions=[Game_Action.new(actor),Game_Action.new(actor)]
  actions.each { |a| a.set_attack;a.target_index=0 }
  actor.instance_variable_set(:@actions,actions)
  ids=actions.map { |a| a.item.id }
  direct.select(actor,$data_weapons[133]);direct.arm(actor)
  final=actions[1]
  actions[0].prepare
  check(actor.equips[0].id==366,'first action retains the currently equipped weapon')
  actor.remove_current_action;final.prepare
  check(actor.equips[0].id==133 && final.item.id==549,'final prepare switches weapon but preserves Hans special skill ID')
  check(!final.attack? && final.make_targets.size==1,'Hans extra shots are lost on the new platform exactly as in native mechanics')
  check(actor.actions.size==1,'final switch does not regenerate or add action slots')
  actor.change_equip(0,$data_weapons[102]);actor.recover_all
  one=Game_Action.new(actor);one.set_skill(14);one.target_index=0;actor.instance_variable_set(:@actions,[one])
  direct.select(actor,$data_weapons[362]);direct.arm(actor);one.prepare
  check(actor.equips[0].id==366 && one.item.id==14,'single-action queues execute the same rule and follow the owned upgrade')
  direct.clear(actor);actor.change_equip(0,$data_weapons[102]);actor.recover_all
  BS2Suite::Options.set('knowledge_threshold',0)
  buff=Game_Action.new(actor);buff.set_skill(110)
  attack=Game_Action.new(actor);attack.set_skill(101);attack.target_index=0
  actor.instance_variable_set(:@actions,[buff,attack])
  before=snapshot(actor);srand(725);expected=rand;srand(725)
  report=BS2Suite::SequenceForecast.new(actor,$data_weapons[133])
  log('forecast='+report.steps.map { |s| [s[:item] && s[:item].id,s[:reason],s[:rows],s[:cost]] }.inspect)
  check(report.steps.size==2 && report.steps[1][:rows].any?,'sequence forecast includes the projected final weapon')
  check(snapshot(actor)==before && rand==expected,'sequence preview does not mutate the live world or consume RNG')
  view=BS2Suite::Projection.weapon(actor,$data_weapons[133])
  check(view.atk>actor.atk && actor.equips[0].id==102,'weapon projection uses new stats without live equipment changes')
  # Restore input and verify battle F7 opens a sequence card.
  actor.make_actions;BattleManager.instance_variable_set(:@phase,:input);@scene.start_actor_command_selection
  @scene.instance_variable_get(:@actor_command_window).openness=255
  key(118)
  check(BS2QoL::Reference.active?(@scene) && @scene.instance_variable_get(:@bs2q_reference_window).card.is_a?(BS2Suite::SequenceCard),'F7 in battle commands opens the queue and N comparison')
  key(27);check(!BS2QoL::Reference.active?(@scene),'sequence reference closes with Esc')
  finish_battle
  # Template replacements are structural, not dependent on current MP.
  model.set_mode(actor,'advanced');model.sync(actor)
  rows=model.groups(actor,'V').map { |g| model.rows(actor,'V',g[:number]) }.flatten
  check(rows.any? { |r| r[:id]==159 } && !rows.any? { |r| r[:id]==110 },'advanced crit slot uses the explicit Hans +5 variant instead of the Club variant')
  model.set_mode(actor,'progression');model.sync(actor)
  rows=model.groups(actor,'V').map { |g| model.rows(actor,'V',g[:number]) }.flatten
  check(rows.any? { |r| r[:id]==159 } && rows.any? { |r| r[:id]==110 },'progression keeps both meaningful crit tools')
  # Copy / edit / persisted round trip; favs and legacy data remain independent.
  custom=model.clone_profile(actor)
  check(custom && model.customs[custom],'author profile can be copied')
  check(model.assign(actor,'V',1,0,$data_skills[110],$data_weapons[157]),'custom slot zero is editable')
  check(model.rows(actor,'V',1).any? { |r| r[:digit]==0 && r[:id]==110 },'zero is a real item/action slot')
  saved=model.customs[custom]['entries'].size;model.instance_variable_set(:@customs,nil)
  check(model.customs[custom]['entries'].size==saved,'custom definitions round-trip through bounded plain text')
  check(model.remove(actor,'V',1,0),'custom binding can be removed')
  %w(V M B).each do |prefix|
    keys=BS2Suite::SemanticCatalog::RECORDS.select { |r| r[:prefix]==prefix }.map { |r| r[:key] }
    groups=model.partition(keys,prefix)
    check(groups.size<=10 && groups.all? { |g| g['keys'].size<=10 } && groups.map { |g| g['keys'] }.flatten.sort==keys.sort,'full '+prefix+' catalogue fits without losing entries')
    check(groups.none? { |g| g['name'].include?('Другие приёмы') || g['name']=~/\AПриёмы [0-9]/ },'full '+prefix+' catalogue retains semantic names')
  end
  log('result=PASS; checks='+@checks.to_s)
rescue Exception=>e
  log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
ensure
  exit
end
