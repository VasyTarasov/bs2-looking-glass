# encoding: UTF-8
rgss_main do
load 'BS2QA_native_capture.rb'
@checks=0
def log(t);File.open('test_result.txt','a') { |f| f.puts t };end
def check(v,t);raise t unless v;@checks+=1;log('PASS '+t);end
def plan_rule(support,actor,obj)
  kind,id=support.key(obj)
  support.instance_variable_set(:@definitions,[{'actor'=>actor.id,'kind'=>kind,'id'=>id}])
  support.instance_variable_set(:@attempts,{})
end
def apply_plan(support,plan)
  obj=plan[:object];user=plan[:actor];target=plan[:target]
  user.use_item(obj);obj.repeats.times { target.item_apply(user,obj) };support.record(plan)
end
begin
  File.open('test_result.txt','w') { |f| f.puts 'support093 native '+RUBY_VERSION }
  DataManager.init;DataManager.setup_new_game
  SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
  actor=$game_actors[1];actor.change_class(1);actor.change_level(70,false);actor.clear_equipments
  $game_party.weapons.each { |w| $game_party.lose_item(w,999,true) }
  [102,256,157,362].each { |id| $game_party.gain_item($data_weapons[id],1) }
  actor.change_equip(0,$data_weapons[102]);actor.recover_all
  model=BS2Suite::Semantic;direct=BS2Suite::DirectWeapons;support=BS2Suite::BattleSupport
  model.sync(actor)
  check(direct.groups(actor).size==1,'early recommended arsenal is one group')
  roots=direct.rows(actor,1).map { |r| BS2Suite::WeaponFamilies.root(r[:id]) }
  check(roots.sort==[101,156,361],'early Knight Club Hans included; technique-only Broken excluded')
  check(direct.groups(actor).all? { |g| direct.behavior(actor,g[:number])=='now' },'all N groups equip immediately')
  roots_all=BS2Suite::Arsenal093::CATEGORIES.map { |g| g[1] }.flatten
  check(roots_all.uniq.size==37,'thirty-seven authored families, not the whole weapon database')
  roots_all.each { |id| $game_party.gain_item($data_weapons[id],1) };model.sync(actor)
  check(direct.groups(actor).size==5,'mature recommended arsenal has five categories')
  rows=direct.shelf(actor)
  check(rows.map { |r| r['id'] }.sort==roots_all.sort,'no recommendation lost or duplicated')
  direct.groups(actor).each do |g|
    rr=direct.rows(actor,g[:number]);check(rr.size<=10,'bounded N group '+g[:number].to_s)
    check(rr.map { |r| r[:digit] }==model::DIGITS[0,rr.size].chars.map { |v| v.to_i },'dense N digits '+g[:number].to_s)
  end
  100.times do |n|
    subset=roots_all.select.with_index { |id,i| ((i*7+n*11)%43)<(n%38) }
    parts=BS2Suite::Arsenal093.partition(subset,{})
    check(parts.all? { |g| g['ids'].size<=10 } && parts.size<=5 && parts.map { |g| g['ids'] }.flatten.sort==subset.sort,'bounded growing partition '+n.to_s)
  end
  model.acknowledge(actor,'N')
  check(support.eligible?($data_items[61]),'attack buff item eligible')
  check(support.eligible?($data_items[105]),'enemy debuff item eligible')
  [1,2,3,4,8,19,32,48,51,81,87,99,107,108].each { |i| check(!support.eligible?($data_items[i]),'item excluded from support '+i.to_s) }
  [308,577,356,850,878,32,849].each { |i| check(!support.eligible?($data_skills[i]),'unsafe/extra/cleanse/attack skill excluded '+i.to_s) }
  [110,155,122,124,118,26,127,140,844,105,106,111,240].each { |i| check(support.eligible?($data_skills[i]),'authored effect eligible '+i.to_s) }
  check(!support.active?,'battle support defaults off')
  BattleManager.setup(79,true,false);$game_party.on_battle_start
  enemy=$game_troop.members[0]
  enemy2=Game_Enemy.new(1,enemy.enemy_id);$game_troop.instance_variable_set(:@enemies,[enemy,enemy2])
  actor.make_actions;support.new_epoch(actor)
  [61,105].each { |i| $game_party.gain_item($data_items[i],20) }
  actor.recover_all;actor.clear_states;actor.clear_buffs
  plan_rule(support,actor,$data_items[61])
  plan=support.next_plan(actor);check(plan && plan[:target]==actor,'automatic buff targets protagonist')
  check(support.expand(actor).equal?(support.expand(actor)),'frozen battle group expansion is reused between UI frames')
  before=Marshal.dump([actor.hp,actor.mp,actor.equips.map { |w| w && w.id },$game_party.item_number($data_items[61])])
  srand(7401);expected=rand;srand(7401);support.next_plan(actor);actual=rand
  check(expected==actual,'planning never consumes RNG')
  check(before==Marshal.dump([actor.hp,actor.mp,actor.equips.map { |w| w && w.id },$game_party.item_number($data_items[61])]),'planning never equips pays or applies')
  apply_plan(support,plan);check(actor.buff?(2) && actor.instance_variable_get(:@buffs)[2]==1,'real item applies first buff level')
  apply_plan(support,support.next_plan(actor));check(actor.instance_variable_get(:@buffs)[2]==2,'real item reaches native maximum level')
  check(!support.next_plan(actor),'no repeated cast while fresh and maximum')
  actor.make_actions;support.new_epoch(actor);actor.instance_variable_get(:@buff_turns)[2]=1
  plan=support.next_plan(actor);check(!!plan,'buff renewed BEFORE expiry at last tick')
  apply_plan(support,plan);check(actor.instance_variable_get(:@buff_turns)[2]>=5,'native recast actually extends maximum-level buff')
  check(!support.next_plan(actor),'refresh does not loop even with plentiful items')
  # Real observed target-specific pressure, without reading enemy future actions.
  plan_rule(support,actor,$data_items[105]);actor.make_actions;support.new_epoch(actor)
  [enemy,enemy2].each { |e| e.clear_states;e.clear_buffs;e.add_debuff(3,5);e.add_debuff(3,5);e.add_debuff(5,5);e.add_debuff(5,5) }
  3.times { support.tick_clock(enemy,:buff) };support.tick_clock(enemy2,:buff)
  actor.make_actions;support.new_epoch(actor)
  [enemy,enemy2].each { |e| e.instance_variable_get(:@buff_turns)[3]=3;e.instance_variable_get(:@buff_turns)[5]=3 }
  check(support.reserve(enemy,:buff)==4 && support.reserve(enemy2,:buff)==2,'each enemy has its own observed safety reserve')
  check(support.due?($data_items[105],enemy) && !support.due?($data_items[105],enemy2),'fast enemy renewed earlier than slower enemy')
  plan=support.next_plan(actor);check(plan && plan[:target]==enemy,'debuff plan selects the due enemy')
  support.record(plan);following=support.next_plan(actor)
  check(!following || following[:target]!=enemy,'failed unchanged target not retried this opportunity')
  enemy2.clear_buffs;plan=support.next_plan(actor);check(plan && plan[:target]==enemy2,'each other enemy still independently considered after failure')
  enemy.add_debuff(3,5);enemy.add_debuff(5,5)
  check(!support.due?($data_items[105],enemy),'fresh duration not refreshed even when reserve is large')
  # Party-wide skills retain native scope, so are not auto-cast with companions.
  actor.learn_skill(140);ally=$game_actors[2];$game_party.add_actor(2);ally.recover_all
  check(!support.available?(actor,$data_skills[140]),'party-wide auto buff blocked with living companions')
  plan_rule(support,actor,$data_items[61]);actor.clear_buffs;actor.make_actions;support.new_epoch(actor)
  check(support.next_plan(actor)[:target]==actor,'single ally buff remains directed only at protagonist with companions present')
  # Ordinary actions keep a real visible slot and remain replaceable by manual input.
  $game_party.remove_actor(2);actor.learn_skill(127);actor.clear_buffs;actor.make_actions
  BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
  scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,scene);scene.start
  BattleManager.instance_variable_set(:@actor_index,0);actor.make_actions;scene.start_actor_command_selection
  plan_rule(support,actor,$data_skills[127]);support.new_epoch(actor)
  plan=support.next_plan(actor);count=actor.actions.size;weapon=actor.equips[0]
  support.propose(scene,plan)
  check(actor.actions.size==count && actor.input.item.id==127,'ordinary support fills one existing real action, never adds one')
  command=scene.instance_variable_get(:@actor_command_window)
  check(command.current_symbol==:bs2_support,'charged support has explicit selected confirmation command')
  check(actor.equips[0]==weapon,'ordinary proposal does not equip source early')
  actor.input.set_attack
  check(!actor.input.instance_variable_get(:@bs2s_support_plan) && actor.input.item,'manual command replaces support normally')
  support.instance_variable_set(:@pending,nil)
  # New notes describe exact versions and distinct equip/execute semantics.
  notes=BS2Suite::ShortNotes
  check(notes.describe($data_weapons[438]).include?('СКР +6'),'Anchor final agility is version-specific')
  check(notes.describe($data_weapons[384]).include?('100%'),'Andor final action chance is version-specific')
  check(notes.describe($data_items[48]).include?('SEN −30'),'hidden common-event SEN cost exposed in concise note')
  check(notes.describe($data_items[3]).include?('хрупкость'),'heal also discloses cleansing')
  check(notes.describe_final($data_weapons[366]).include?('549'),'final Hans note explicitly requires the selected normal attack ID')
  check(notes.describe_final($data_weapons[278]).include?('чужой'),'final Knuckles note does not promise extra hits to a foreign attack')
  # Every curated annotation must fit two compact lines even with a status marker.
  metric=Window_Base.new(0,0,640,100);metric.contents.font.size=12
  texts=notes::SKILLS093.values+notes::ITEMS093.values+notes::WEAPONS093.values.flatten
  overflow=texts.select do |text|
    parts=[''];(text+' · [поддержка: пауза]').split(/\s+/).each do |word|
      value=parts[-1].empty? ? word : parts[-1]+' '+word
      metric.text_size(value).width>592 && !parts[-1].empty? ? parts<<word : parts[-1]=value
    end
    parts.size>2
  end
  check(overflow.empty?,'all curated annotations and status markers fit two native classic text lines');metric.dispose
  # Forecast source switching uses copies and restores the prior platform for later slots.
  direct.clear(actor);actor.recover_all;actor.clear_buffs
  obj=support::SKILLS.map { |id| $data_skills[id] }.find { |s| support.eligible?(s) && support.source(actor,s).is_a?(RPG::Weapon) && s.for_user? && !support.quick?(s) }
  check(!!obj,'authored charged self support has a real weapon source')
  provider=support.source(actor,obj);action=Game_Action.new(actor);action.set_skill(obj.id)
  action.instance_variable_set(:@bs2s_support_plan,{:source=>provider})
  actor.instance_variable_set(:@actions,[action]);original=actor.equips[0]
  projected=BS2Suite::Projection.weapon(actor,provider)
  report=BS2Suite::SequenceForecast.new(actor)
  check(report.steps[0][:cost] && report.steps[0][:cost][1]==[projected.skill_mp_cost(obj)]*2,'forecast pays the projected support source MP price')
  check(actor.equips[0]==original,'source forecast never equips the live actor')
  actor.make_actions
  component=support::SKILLS.map { |id| $data_skills[id] }.select { |s| support.eligible?(s) && s.for_user? }.map { |s| support.tracked(s) }.flatten(1).find { |t,id,d| t==:state && $data_states[id].auto_removal_timing>0 && $data_states[id].min_turns>=2 }
  check(!!component,'authored maintenance includes a native timed state')
  type,sid,duration=component;state=$data_states[sid];actor.erase_state(sid)
  check(support.due_component?(actor,type,sid,duration),'missing state is due')
  actor.add_state(sid);actor.instance_variable_get(:@state_turns)[sid]=state.min_turns
  check(!support.due_component?(actor,type,sid,duration),'fresh timed state is never rerolled')
  actor.instance_variable_get(:@state_turns)[sid]=1
  check(support.due_component?(actor,type,sid,duration),'timed state refresh is due before expiry')
  actor.erase_state(sid)
  popup=BS2Suite::PaletteWindow.new(actor,'N');popup.acknowledge;popup.set_group(1)
  check(popup.height<=Graphics.height-64,'two-line notes remain inside classic viewport')
  Graphics.transition(0);popup.update;SuiteCapture.save('BS2QA_093_notes.bmp');popup.dispose
  scene.terminate;$game_party.on_battle_end
  check(!support.active? && !support.pending,'battle activation and pending actions cleared at battle end')
  check(support.definitions.any?,'configured rules remain after battle end')
  log('result=PASS; checks='+@checks.to_s)
rescue Exception=>e
  log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
ensure
  SuiteCapture.close
end
end
