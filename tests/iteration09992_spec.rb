# encoding: UTF-8
rgss_main do
  load 'BS2QA_native_capture.rb'
  @checks=0
  def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
  def check(v,s);raise s unless v;@checks+=1;log('PASS '+s);end
  class Keys0997
    attr_accessor :keys
    def initialize;@keys=[];end
    def down;@keys;end
    def focused?;true;end
  end
  def queue(a,n=2)
    a.instance_variable_set(:@actions,Array.new(n) { Game_Action.new(a) });a.instance_variable_set(:@action_input_index,0)
    BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
  end
  def frame(keys=[]);@raw.keys=keys;Graphics.update;Input.update;end
def capture(name)
  bitmap=Graphics.snap_to_bitmap
  raw=''.force_encoding('ASCII-8BIT')
  bitmap.height.times do |y|
    raw << "\0"
    bitmap.width.times do |x|
      c=bitmap.get_pixel(x,y);raw << [c.red.to_i,c.green.to_i,c.blue.to_i,c.alpha.to_i].pack('C4')
    end
  end
  chunk=lambda { |tag,data| [data.bytesize].pack('N')+tag+data+[Zlib.crc32(tag+data)].pack('N') }
  png="\x89PNG\r\n\x1a\n".force_encoding('ASCII-8BIT')+chunk.call('IHDR',[bitmap.width,bitmap.height,8,6,0,0,0].pack('NNCCCCC'))+chunk.call('IDAT',Zlib::Deflate.deflate(raw))+chunk.call('IEND','')
  File.open(name,'wb') { |f| f.write(png) };bitmap.dispose
end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'grouped macro and sequence regressions '+BS2Suite::VERSION }
    DataManager.init;DataManager.setup_new_game
    SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
    actor=$game_party.leader;actor.change_class(1);actor.change_level(70,false);actor.clear_equipments
    [101,277,391].each { |id| $game_party.gain_item($data_weapons[id],1) }
    actor.change_equip(0,$data_weapons[277]);actor.recover_all
    actor.singleton_class.class_eval { def make_action_times;2;end }
    troop=RPG::Troop.new;troop.id=79
    enemy=RPG::Enemy.new;enemy.id=5000;enemy.name='QA';enemy.battler_name='';enemy.params=[100000,100,50,30,50,30,50,50];$data_enemies[5000]=enemy
    member=RPG::Troop::Member.new;member.enemy_id=5000;member.x=300;member.y=180;troop.members=[member];$data_troops[79]=troop
    BattleManager.setup(79,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
    actor.instance_variable_set(:@ap,ATB::MAX_AP);queue(actor)
    @raw=Keys0997.new;BS2QoL::Keyboard.backend=@raw;BS2QoL::Keyboard.reset
    @scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,@scene);@scene.start
    BS2Suite::Options.set('knowledge_threshold',0)

    def cmd(code,p=[],indent=0);RPG::EventCommand.new(code,indent,p);end
    def event_for(list,name='QA')
      data=RPG::Event.new(4,4);data.id=7000;data.name=name;page=data.pages[0];page.graphic.character_name='Actor1';page.trigger=0;page.list=list+[cmd(0)]
      Game_Event.new($game_map.map_id,data)
    end
    highlight=BS2Suite::InteractionHighlight
    # Actual repeat attack with effects/TP gain must not block later slots.
    actor.learn_skill(348);actor.learn_skill(108);actor.learn_skill(308);actor.cool_time.clear;actor.recover_all
    queue(actor);actor.actions[0].set_skill(348);actor.actions[0].target_index=0;actor.actions[1].set_skill(14);actor.actions[1].target_index=0
    report=BS2Suite::SequenceForecast.new(actor)
    check(report.steps[1][:rows].any? && !report.steps[1][:reason],'repeated native normal attack 348 does not block the following spell merely for TP gain and effects')
    # Default -1 uses native smooth_target semantics instead of an invented missing target.
    queue(actor);actor.actions[0].set_skill(348);actor.actions[0].target_index=-1;actor.instance_variable_set(:@action_input_index,1)
    step=BS2Suite::ForecastContext.step($data_skills[14],actor,nil,$game_troop.members[0])
    check(step[:rows].any? && !step[:reason],'native default target -1 and live fallback are usable in a previous action')
    # Large self damage remains linear when Endure cannot be triggered.
    actor.instance_variable_get(:@param_plus)[0]+=100000;actor.instance_variable_get(:@param_plus)[2]+=3000;actor.recover_all;actor.result.clear;actor.add_state(Nana::STATE_KONJO)
    queue(actor);actor.actions[0].set_skill(308);actor.instance_variable_set(:@action_input_index,1)
    step=BS2Suite::ForecastContext.step($data_skills[108],actor,nil,$game_troop.members[0])
    check(step[:rows].any? && !step[:reason],'safe Endure with large self-flagellation variance is not falsely rejected as nonlinear')
    actor.clear_states
    # Fractional TP gain is applied after every hit, matching actual native execution.
    state=RPG::State.new;state.id=5990;state.name='QA TP multiplier';state.features=[RPG::BaseItem::Feature.new(23,5,1.5)];$data_states[5990]=state;actor.result.clear;actor.add_state(5990)
    s=RPG::Skill.new;s.id=5991;s.name='QA repeated TP';s.scope=1;s.hit_type=0;s.occasion=1;s.repeats=2;s.tp_gain=5;s.damage.type=1;s.damage.formula='100';s.damage.variance=0;s.effects=[RPG::UsableItem::Effect.new(31,3,5,0)];$data_skills[5991]=s
    t=RPG::Skill.new;t.id=5992;t.name='QA following TP';t.scope=1;t.hit_type=0;t.occasion=1;t.damage.type=1;t.damage.formula='a.tp * 100';t.damage.variance=0;$data_skills[5992]=t
    actor.learn_skill(s.id);actor.learn_skill(t.id);actor.tp=0;queue(actor);actor.actions[0].set_skill(s.id);actor.actions[0].target_index=0;actor.actions[1].set_skill(t.id);actor.actions[1].target_index=0
    report=BS2Suite::SequenceForecast.new(actor);expected=report.steps[1][:rows][0][:mean]
    victim=$game_troop.members[0];actor.use_item(s);2.times { victim.item_apply(actor,s) };actor.use_item(t);victim.item_apply(actor,t)
    check(victim.result.hp_damage==expected && actor.tp==15,'forecast TP gain after repeated hits agrees with native fractional gain and next TP-based damage')
    actor.clear_states;actor.cool_time.clear
    # Endure is irrelevant until a hit can actually be lethal.
    victim.recover_all;victim.result.clear;victim.add_state(Nana::STATE_KONJO);s.damage.formula='100';s.repeats=3
    queue(actor);actor.actions[0].set_skill(s.id);actor.actions[0].target_index=0;actor.actions[1].set_skill(14);actor.actions[1].target_index=0
    r=BS2Suite::SequenceForecast.new(actor)
    check(r.steps[0][:rows].any? && r.steps[1][:rows].any?,'nonlethal repeated hits and next action remain calculable against Endure')
    victim.hp=150;r=BS2Suite::SequenceForecast.new(actor)
    check(r.steps[0][:rows].empty? && r.steps[0][:reason],'possible Endure activation at a later hit still blocks an unverified total')
    victim.remove_state(Nana::STATE_KONJO);victim.recover_all
    # Stress self damage under physical weapons, buffs and difficulty settings.
    [101,188,277,287].each { |id| $game_party.gain_item($data_weapons[id],1) }
    trials=0
    [101,188,277,287].each do |weapon|
      actor.force_change_equip(0,$data_weapons[weapon]);actor.clear_states;actor.remove_all_buffs
      [0,4,10,19].each do |difficulty|
        $game_variables[Hi_ru_Difficulty::VARIABLES]=difficulty
        actor.recover_all;actor.cool_time.clear;queue(actor)
        actor.actions[0].set_skill(308);actor.actions[0].target_index=-1;actor.instance_variable_set(:@action_input_index,1)
        step=BS2Suite::ForecastContext.step($data_skills[108],actor,nil,$game_troop.members[0])
        # Give the controlled hero enough HP to survive its own damage.
        if step[:reason] && step[:reason].include?('смерть')
          actor.instance_variable_get(:@param_plus)[0]+=100000;actor.recover_all
          step=BS2Suite::ForecastContext.step($data_skills[108],actor,nil,$game_troop.members[0])
        end
        check(step[:rows].any? && !step[:reason],'self-flagellation continuation: weapon '+weapon.to_s+' / difficulty '+difficulty.to_s)
        trials+=1
      end
    end
    $game_variables[Hi_ru_Difficulty::VARIABLES]=0;actor.clear_states;actor.remove_all_buffs;actor.recover_all;actor.cool_time.clear
    # Real command cancellation, including guard and normal attack.
    queue(actor);@scene.start_actor_command_selection;@scene.command_guard
    check(actor.instance_variable_get(:@action_input_index)==1 && actor.actions[0].guard?,'actual guard enters paid slot one without dispatching a two-slot turn')
    frame;@scene.prior_command
    check(actor.instance_variable_get(:@action_input_index)==0 && actor.actions.all? { |a| !a.item },'one Esc removes selected guard and returns to its slot')
    queue(actor);actor.actions[0].set_attack;actor.actions[0].target_index=0;actor.next_command;@scene.start_actor_command_selection
    frame;@scene.prior_command
    check(actor.instance_variable_get(:@action_input_index)==0 && actor.actions.all? { |a| !a.item },'normal attack is removed by the same cancellation path')
    actor.force_change_equip(0,$data_weapons[101]);$game_troop.members<<Game_Enemy.new(1,5000)
    queue(actor);@scene.start_actor_command_selection;@scene.instance_variable_get(:@actor_command_window).select(0);@scene.command_attack
    check(actor.input.item && @scene.instance_variable_get(:@enemy_window).active,'actual normal attack opens target selection')
    @scene.on_enemy_cancel
    check(actor.input.item.nil?,'cancelling target selection clears the unconfirmed normal attack')
    # Current visible event pages: useful loot, exhausted corpses, SAN, choices.
    loot=event_for([cmd(126,[1,0,0,1])])
    check(highlight.classify(loot)[0],'visible actionable pickup is highlighted')
    check(!highlight.classify(event_for([cmd(126,[1,0,0,0])]))[0],'zero-quantity pseudo-loot is not advertised as a result')
    inert=event_for([cmd(250,[RPG::SE.new]),cmd(0)])
    check(!highlight.classify(inert)[0],'sound-only scenery is not an interaction result')
    empty=event_for([cmd(101),cmd(401,['Вы не нашли ничего ценного.'])])
    check(highlight.classify(empty)==[false,:empty],'native empty-corpse response does not glow')
    choices=[cmd(101),cmd(401,['QA corpse description']),cmd(102,[['Обыскать труп','Уйти'],2]),cmd(402,[0,'Обыскать труп']),cmd(101,[],1),cmd(401,['Вы не нашли ничего ценного.'],1),cmd(0,[],1),cmd(402,[1,'Уйти']),cmd(0,[],1),cmd(404)]
    check(!highlight.classify(event_for(choices))[0],'descriptive text and a search menu cannot resurrect an exhausted corpse')
    eat=choices.dup;eat.insert(eat.size-1,cmd(402,[2,'QA useful choice']),cmd(314,[0,0],1),cmd(0,[],1))
    check(highlight.classify(event_for(eat))[0],'another useful corpse action keeps it interactable')
    hidden=event_for([cmd(126,[1,0,0,1])]);hidden.transparent=true
    check(!highlight.classify(hidden)[0],'transparent event never leaks through Alt')
    hidden.transparent=false;hidden.instance_variable_set(:@opacity,0)
    check(!highlight.classify(hidden)[0],'zero-opacity event never leaks through Alt')
    hidden.instance_variable_set(:@opacity,255);hidden.instance_variable_set(:@erased,true)
    check(!highlight.classify(hidden)[0],'erased pickup never leaks through Alt')
    invisible=event_for([cmd(126,[1,0,0,1])]);invisible.instance_variable_set(:@character_name,'')
    check(!highlight.classify(invisible)[0],'invisible trigger without a graphic is excluded')
    gated=event_for([cmd(111,[1,999,0,0,0]),cmd(126,[1,0,0,1],1),cmd(0,[],1),cmd(412)])
    $game_variables[999]=0;check(highlight.classify(gated)[0],'currently true zero-SAN-like condition permits interaction')
    $game_variables[999]=100;check(!highlight.classify(gated)[0],'the same visible event does not expose a locked interaction branch')
    high=event_for([cmd(111,[1,999,0,100,3]),cmd(126,[1,0,0,1],1),cmd(412)])
    check(!highlight.classify(high)[0],'strict over-100 condition excludes 100')
    $game_variables[999]=101;check(highlight.classify(high)[0],'strict over-100 condition includes 101')
    script=event_for([cmd(111,[12,'raise "must never run"']),cmd(126,[1,0,0,1],1),cmd(412)])
    check(highlight.classify(script)==[false,:unknown_condition],'unknown script condition is never evaluated or used to reveal loot')
    book=event_for([cmd(101),cmd(401,['QA readable text'])]);check(highlight.classify(book)[0],'ordinary readable objects remain usable')
    shadow=event_for([cmd(122,[999,999,0,0,7]),cmd(111,[1,999,0,7,0]),cmd(126,[1,0,0,1],1),cmd(412)])
    before=$game_variables[999];check(highlight.classify(shadow)[0] && $game_variables[999]==before,'local variable assignments are simulated without mutating game state')
    # Native common event 73 is the real empty-corpse search menu.
    check(!highlight.classify(event_for([cmd(117,[73])]))[0],'native common-event empty-corpse interaction is excluded')
    before=Marshal.dump([$game_switches,$game_variables,$game_self_switches,$game_party]);srand(9912);expected=rand;srand(9912)
    20.times { highlight.classify(loot);highlight.classify(empty);highlight.classify(script) }
    check(before==Marshal.dump([$game_switches,$game_variables,$game_self_switches,$game_party]) && rand==expected,'highlight analysis preserves world inventory flags and RNG')
    # The engine, rather than the highlighter, chooses the visible page.
    data=RPG::Event.new(4,4);data.id=7001
    data.pages[0].graphic.character_name='!_doors';data.pages[0].list=[cmd(126,[1,0,0,1]),cmd(0)]
    spent=RPG::Event::Page.new;spent.graphic.character_name='!_doors';spent.condition.self_switch_valid=true;spent.condition.self_switch_ch='A';spent.list=[cmd(101),cmd(401,['Вы не нашли ничего ценного.']),cmd(0)];data.pages<<spent
    e=Game_Event.new($game_map.map_id,data);check(highlight.classify(e)[0],'uncollected event uses its real active loot page')
    $game_self_switches[[$game_map.map_id,e.id,'A']]=true;e.refresh
    check(!highlight.classify(e)[0],'first-use self switch makes the actual exhausted page stop glowing')
    data=RPG::Event.new(4,4);data.id=7002;data.pages[0].graphic.character_name='!_doors';data.pages[0].list=[cmd(126,[1,0,0,1]),cmd(0)]
    concealed=RPG::Event::Page.new;concealed.condition.variable_valid=true;concealed.condition.variable_id=998;concealed.condition.variable_value=1;concealed.graphic.character_name='';concealed.list=[cmd(126,[1,0,0,1]),cmd(0)];data.pages<<concealed
    $game_variables[998]=0;e=Game_Event.new($game_map.map_id,data);check(highlight.classify(e)[0],'zero-value visible event page is eligible')
    $game_variables[998]=1;e.refresh;check(!highlight.classify(e)[0],'engine page change conceals the zero-value event without exposing its other loot page')
    # Bound diagnostic output: one context record, not one write per redraw.
    BS2Suite::Debug.start;BS2Suite::ForecastTrace.instance_variable_set(:@seen,{});BS2Suite::ForecastTrace.instance_variable_set(:@written,nil);BS2Suite::ForecastTrace.instance_variable_set(:@pending,[])
    actor.cool_time.clear;actor.cool_time[308]=5;queue(actor);actor.actions[0].set_skill(308);actor.actions[1].set_skill(108)
    report=BS2Suite::SequenceForecast.new(actor);directory=BS2Suite::Debug.directory
    text=Dir.glob(File.join(directory,'events_*.jsonl')).map { |path| File.open(path,'rb') { |f| f.read } }.join
    count=text.scan('"type":"forecast_result"').size
    check(count>0 && text.include?('cooldowns') && text.include?('steps'),'diagnostics capture real forecast refusal plus queue cooldowns and state')
    20.times { BS2Suite::ForecastTrace.record(actor,report) }
    text=Dir.glob(File.join(directory,'events_*.jsonl')).map { |path| File.open(path,'rb') { |f| f.read } }.join
    check(text.scan('"type":"forecast_result"').size==count,'unchanged redraws cannot flood the forecast diagnostic log')
    @scene.terminate
    SceneManager.instance_variable_set(:@scene,Scene_Map.new);$game_message.clear
    $game_map.set_display_pos(0,0)
    loot.instance_variable_set(:@character_name,'!_doors')
    viewport=Viewport.new;source=Sprite_Character.new(viewport,loot)
    layer=BS2Suite::InteractionHighlight::Layer.new([source],viewport)
    frame;frame([18]);layer.update
    check(layer.count==1,'held raw Alt renders a marker for the visible actionable event')
    markers=layer.instance_variable_get(:@markers).values;bits=layer.instance_variable_get(:@bitmaps).values
    80.times { frame([18]);source.update;layer.update }
    check(layer.count==1 && layer.instance_variable_get(:@markers).size==1 && layer.instance_variable_get(:@bitmaps).size==1,'holding Alt reuses its marker and bitmap instead of leaking per-frame resources')
    capture('highlight.png')
    frame;layer.update
    check(layer.count==0 && markers.none? { |m| m.visible },'releasing Alt immediately removes the visual marker')
    loot.instance_variable_set(:@erased,true);frame([18]);layer.update
    check(layer.count==0,'erasing a pickup suppresses its cached marker immediately')
    holder=Spriteset_Map.new;old_layer=holder.instance_variable_get(:@bs209992_highlight);old_layer.dispose if old_layer;holder.instance_variable_set(:@bs209992_highlight,layer)
    holder.dispose_characters
    holder.create_characters
    check(holder.instance_variable_get(:@bs209992_highlight).nil? && markers.all? { |m| m.disposed? },'native map character rebuild releases the old highlight layer during transfers')
    holder.dispose
    layer.dispose
    check(markers.all? { |m| m.disposed? } && bits.all? { |b| b.disposed? },'map layer disposal releases every owned marker and bitmap')
    source.dispose;viewport.dispose
    log('result=PASS; checks='+@checks.to_s)
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure
    BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  end
end
