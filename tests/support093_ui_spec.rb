# encoding: UTF-8
rgss_main do
load 'BS2QA_native_capture.rb'
@checks=0
def log(t);File.open('test_result.txt','a') { |f| f.puts t };end
def check(v,t);raise t unless v;@checks+=1;log('PASS '+t);end
class Support093Keys
  attr_accessor :keys
  def initialize;@keys=[];end
  def down;@keys.dup;end
  def focused?;true;end
end
def frame(keys=[])
  @raw.keys=keys;Graphics.update;Input.update
  popup=BS2Suite::Palette.current(@scene)
  if popup;popup.update;BS2Suite::Palette.update(@scene)
  else;@scene.instance_variable_get(:@actor_command_window).update;end
end
def key(n);frame;frame([n]);end
def seq(t);t.each_byte { |n| key(n) };end
begin
  File.open('test_result.txt','w') { |f| f.puts 'support093 UI '+RUBY_VERSION }
  DataManager.init;DataManager.setup_new_game
  BS2Suite::HDDisplay.apply(BS2Suite::HDDisplay::DEFAULT) if defined?(BS2Suite::HDDisplay)
  SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
  actor=$game_actors[1];actor.change_class(1);actor.change_level(70,false);actor.clear_equipments
  [102,157,362,278].each { |id| $game_party.gain_item($data_weapons[id],1) }
  actor.change_equip(0,$data_weapons[102]);actor.recover_all
  [3,61,105,59].each { |id| $game_party.gain_item($data_items[id],12) }
  model=BS2Suite::Semantic;direct=BS2Suite::DirectWeapons;support=BS2Suite::BattleSupport
  model.sync(actor);%w(N V B M).each { |p| model.acknowledge(actor,p) }
  dummy=RPG::Enemy.new;dummy.id=5000;dummy.name='Манекен';dummy.battler_name='';dummy.params=[10000,100,50,50,50,50,50,50];$data_enemies[5000]=dummy
  troop=RPG::Troop.new;troop.id=79;member=RPG::Troop::Member.new;member.enemy_id=5000;member.x=320;member.y=190;troop.members=[member];$data_troops[79]=troop
  BattleManager.setup(79,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
  actor.instance_variable_set(:@ap,ATB::MAX_AP);actor.make_actions
  BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
  @scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,@scene);@scene.start;@scene.start_actor_command_selection
  @scene.instance_variable_get(:@actor_command_window).openness=255
  @raw=Support093Keys.new;BS2QoL::Keyboard.backend=@raw;BS2QoL::Keyboard.reset;frame
  seq('N1');popup=BS2Suite::Palette.current(@scene)
  i=popup.entries.index { |r| BS2Suite::WeaponFamilies.root(r[:id])==277 };popup.select(i)
  before=actor.equips[0];key(68)
  check(direct.selected(actor) && BS2Suite::WeaponFamilies.root(direct.selected(actor).id)==277,'D nominates highlighted Knuckles')
  check(actor.equips[0]==before,'D nomination never equips early')
  check(BS2Suite::Palette.current(@scene)==popup,'D keeps weapon menu usable')
  knight=popup.entries.find { |r| BS2Suite::WeaponFamilies.root(r[:id])==101 };key(48+knight[:digit])
  check(actor.equips[0]==before && direct.selected(actor),'manual equip preserves nominated executor')
  seq('NN');check(!direct.selected(actor) && !BS2Suite::Palette.current(@scene),'NN clears executor and exits')
  seq('N1');popup=BS2Suite::Palette.current(@scene);popup.select(i);key(68);key(68)
  check(!direct.selected(actor),'second D on same weapon clears nomination');key(27)
  seq('B');popup=BS2Suite::Palette.current(@scene)
  group=popup.entries.find { |g| model.rows(actor,'B',g[:group_number]).any? { |r| r[:id]==61 } }
  popup.select(popup.entries.index(group));key(68)
  check(support.definitions.any? { |r| r['group']==group[:group_number] && r['prefix']=='B' },'D on group configures maintenance group')
  check(support.expand(actor).all? { |obj| support.eligible?(obj) } && support.expand(actor).any? { |obj| obj.id==61 },'mixed group auto filter retains buffs and excludes heals')
  key(27);support.instance_variable_set(:@master,false)
  actor.clear_buffs;actor.make_actions;support.reset
  support.instance_variable_set(:@definitions,[{'actor'=>1,'kind'=>'item','id'=>61}])
  support.instance_variable_set(:@master,true)
  BattleManager.instance_variable_set(:@actor_index,0)
  @scene.start_actor_command_selection;@scene.instance_variable_get(:@actor_command_window).openness=255
  frame;before=actor.actions.dup;count=actor.actions.size;items=$game_party.item_number($data_items[61]);hp=actor.hp;mp=actor.mp
  support.tick(@scene)
  check($game_party.item_number($data_items[61])==items-1,'native quick support consumes one actual item')
  check(actor.actions==before && actor.actions.size==count && !actor.input.item,'native quick support preserves player queue and blank slot')
  check(actor.instance_variable_get(:@buffs)[2]==1,'native quick support applies first level')
  check(!support.busy? && !HZM_VXA::QuickSkill.quickSkill?,'native quick support leaves no recursion/engine-active flag')
  10.times { frame };support.tick(@scene)
  check($game_party.item_number($data_items[61])==items-2 && actor.instance_variable_get(:@buffs)[2]==2,'second native quick cast reaches maximum')
  30.times { frame };support.tick(@scene)
  check($game_party.item_number($data_items[61])==items-2,'maximum does not consume further items')
  check(actor.hp==hp && actor.mp==mp,'stat item does not silently alter HP or MP')
  key(68);check(!support.active?,'D on battle commands pauses all configured support')
  key(68);check(support.active?,'D on battle commands resumes saved support')
  # A pending charged cast is safely removed by pause, without leaving a dead command.
  actor.learn_skill(127);actor.clear_buffs;actor.make_actions;support.new_epoch(actor)
  support.instance_variable_set(:@definitions,[{'actor'=>1,'kind'=>'skill','id'=>127}]);plan=support.next_plan(actor)
  support.propose(@scene,plan);key(68)
  check(!support.pending && !actor.input.item,'pause cancels only unconfirmed automatic proposal')
  check(@scene.instance_variable_get(:@actor_command_window).active,'pause leaves commands active')
  actor.input.prepare
  check(!actor.input.item && !actor.input.instance_variable_get(:@bs2s_support_plan),'cleared support cannot resurrect during prepare')
  # A normal charged support uses the native execution and native MP cost.
  support.instance_variable_set(:@master,false);actor.clear_buffs;actor.make_actions
  plan=support.next_plan(actor);support.propose(@scene,plan)
  action=actor.input;action.prepare;mp=actor.mp;cost=actor.skill_mp_cost($data_skills[127])
  @scene.instance_variable_set(:@subject,actor)
  @scene.use_item
  check(actor.mp==mp-cost && actor.buff?(4),'charged support pays actual MP and applies native buff')
  support.instance_variable_set(:@pending,nil);@scene.instance_variable_set(:@subject,nil)
  # A source weapon is temporary unless an explicit final nomination wins.
  actor.forget_skill(110);actor.cool_time.delete(110);actor.clear_states;actor.clear_buffs;actor.recover_all
  actor.change_equip(0,$data_weapons[102]);direct.clear(actor)
  actor.instance_variable_set(:@actions,[Game_Action.new(actor)]);actor.instance_variable_set(:@action_input_index,0)
  support.new_epoch(actor);support.instance_variable_set(:@definitions,[{'actor'=>1,'kind'=>'skill','id'=>110}])
  plan=support.next_plan(actor);check(plan && plan[:source].is_a?(RPG::Weapon) && plan[:source]!=actor.equips[0],'charged V support resolves a different real owned source')
  support.propose(@scene,plan);action=actor.input;action.prepare
  check(actor.equips[0]==plan[:source],'charged V source equips only at native prepare')
  mp=actor.mp;cost=actor.skill_mp_cost($data_skills[110]);@scene.instance_variable_set(:@subject,actor);@scene.use_item
  check(actor.equips[0].id==102 && actor.mp==mp-cost,'charged V source restores prior weapon after real payment and application')
  actor.cool_time.delete(110);actor.clear_states;actor.clear_buffs;actor.recover_all
  actor.instance_variable_set(:@actions,[Game_Action.new(actor)]);actor.instance_variable_set(:@action_input_index,0)
  support.new_epoch(actor);plan=support.next_plan(actor);support.propose(@scene,plan)
  direct.select(actor,$data_weapons[278]);direct.arm(actor);action=actor.input;action.prepare
  check(action.item.id==110 && actor.equips[0].id==278,'explicit final nomination overrides the temporary source without changing skill ID')
  @scene.use_item
  check(actor.equips[0].id==278,'post-cast restoration preserves explicit final weapon')
  direct.clear(actor);support.instance_variable_set(:@pending,nil);@scene.instance_variable_set(:@subject,nil)
  # Native buffs erase opposing negative levels; automation must not cleanse.
  actor.clear_buffs;actor.add_debuff(2,5);actor.add_debuff(2,5);actor.make_actions;support.new_epoch(actor)
  support.instance_variable_set(:@definitions,[{'actor'=>1,'kind'=>'item','id'=>61}])
  items=$game_party.item_number($data_items[61])
  check(!support.next_plan(actor),'support leaves opposing negative parameter levels for manual handling')
  check(actor.instance_variable_get(:@buffs)[2]==-2 && $game_party.item_number($data_items[61])==items,'blocked implicit cleansing consumes no items')
  # Battle-bound nomination still preserves the selected special ID and timing.
  support.instance_variable_set(:@master,false);actor.change_equip(0,$data_weapons[362]);actor.make_actions;actor.input.set_attack
  action=actor.input;selected_id=action.item.id;direct.select(actor,$data_weapons[278]);direct.arm(actor)
  action.prepare
  check(action.item.id==selected_id && actor.equips[0].id==278,'new D model keeps last-slot swap and selected Hans ID')
  check(!action.attack?,'Hans additional-shot classification reflects actual new weapon')
  # Show the completed two-line menu on a real classic frame.
  actor.make_actions;@scene.start_actor_command_selection;model.acknowledge(actor,'N');seq('N1')
  Graphics.transition(0);Graphics.brightness=255;3.times { Graphics.update };SuiteCapture.save('BS2QA_093_palette.bmp')
  if defined?(BS2Suite::HDDisplay)
    popup=BS2Suite::Palette.current(@scene)
    check(BS2Suite::HDDisplay.palette_rows(popup).any? { |r| r.include?('выделенное оружие') },'HD palette advertises contextual D')
    hd=BS2Suite::HDDisplay;hd.poll(true)
    check(hd.active? && !popup.visible,'HD support palette uses the active sidebar renderer')
    read=Win32API.new('Mods/BS2Suite/native/bs2_steam_bridge.dll','BS2_HDReadback',['P','I'],'I')
    read.call('',0);w,h=hd.status[6,2];pixels=("\0"*(w*h*4)).force_encoding('ASCII-8BIT');size=0
    90.times { Graphics.update;size=read.call(pixels,pixels.bytesize);break if size==pixels.bytesize }
    check(size==pixels.bytesize,'HD support composite has a complete native readback')
    header=[40,w,-h,1,32,0,pixels.bytesize,0,0,0,0].pack('LllSSLLLLLL')
    File.open('BS2QA_093_hd_palette.bmp','wb') { |f| f.write('BM'+[54+pixels.bytesize,0,54].pack('L3')+header+pixels) }
  end
  BS2Suite::Palette.close(@scene);@scene.terminate;$game_party.on_battle_end
  log('result=PASS; checks='+@checks.to_s)
rescue Exception=>e
  log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
ensure
  SuiteCapture.close
end
end

