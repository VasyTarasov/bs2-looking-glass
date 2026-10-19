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
    File.open('test_result.txt','w') { |f| f.puts 'forecast mechanism matrix '+BS2Suite::VERSION }
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


    def qa_skill(id,formula='100',hit=0,scope=1)
      s=RPG::Skill.new;s.id=id;s.name='QA matrix '+id.to_s;s.scope=scope;s.occasion=1;s.stype_id=1;s.hit_type=hit;s.mp_cost=0;s.tp_cost=0;s.tp_gain=0
      s.damage.type=1;s.damage.formula=formula;s.damage.element_id=0;s.damage.variance=0;s.damage.critical=false;$data_skills[id]=s;$game_party.leader.learn_skill(id);s
    end
    def qa_state(id,features=[],note='')
      s=RPG::State.new;s.id=id;s.name='QA state '+id.to_s;s.features=features;s.note=note;s.auto_removal_timing=0;$data_states[id]=s;s
    end
    def feat(code,id,value);RPG::BaseItem::Feature.new(code,id,value);end
    def plan(actor,ids)
      queue(actor,ids.size);ids.each_with_index { |id,i| actor.actions[i].set_skill(id);actor.actions[i].target_index=0 }
      BS2Suite::Performance.bump;BS2Suite::SequenceForecast.new(actor)
    end
    actor.singleton_class.send(:remove_method,:make_action_times)
    actor.clear_equipments;actor.recover_all;enemy=$game_troop.members[0]
    record=enemy.enemy;record.params[0]=2000000;record.features=[];enemy.recover_all
    # Genuine invoke_item -> counter path; only presentation is suppressed.
    class SilentAuditLog
      def method_missing(*args);end
    end
    saved_log=@scene.instance_variable_get(:@log_window);@scene.instance_variable_set(:@log_window,SilentAuditLog.new)
    @scene.singleton_class.class_eval { def show_animation_counter(*args);end;def refresh_status;end }
    @scene.instance_variable_set(:@subject,actor)
    s=qa_skill(6000,'100',2);s.note='<反撃可能>'
    record.features=[feat(22,6,1.0),feat(22,5,1.0)];enemy.refresh
    p=BS2QoL::Forecast::Prediction.new(actor,enemy,s)
    enemy.result.clear;before=enemy.hp;@scene.invoke_item(enemy,s)
    check(before-enemy.hp==100 && p.chance==1.0 && (p.expected_formula-100).abs<0.01,'100% counter receives the original hit; it does not cancel damage even with 100% reflection')
    record.features=[feat(22,6,0.5),feat(22,5,0.5)];enemy.refresh
    p=BS2QoL::Forecast::Prediction.new(actor,enemy,s);sum=0
    2000.times do |i|
      actor.recover_all;enemy.recover_all;enemy.result.clear;srand(61000+i);before=enemy.hp;@scene.invoke_item(enemy,s);sum+=before-enemy.hp
    end
    check((p.chance-0.75).abs<0.00001 && (sum/2000.0-75).abs<4,'conditional counter/reflection ordering matches 2000 native invokes (75% target damage)')
    record.features=[];enemy.refresh
    # Independent factors: physical resistance, element, crit, Guard bypass,
    # evasion and skill cancellation. Mean is compared with native application.
    s=qa_skill(6001,'1000',1);s.damage.element_id=1;s.damage.critical=true;s.note='<防御状態無視率:35>'
    qa_state(6000,[feat(22,0,1.0),feat(22,2,0.25)])
    qa_state(6001,[feat(11,1,1.2),feat(23,6,0.4),feat(22,1,0.2),feat(62,1,0),feat(23,1,2.0)],'<スキル無効:6001,10>')
    actor.add_state(6000);enemy.add_state(6001)
    prediction=BS2QoL::Forecast::Prediction.new(actor,enemy,s);observed=0.0
    3000.times do |i|
      enemy.hp=enemy.mhp;enemy.result.clear;srand(71000+i);enemy.item_apply(actor,s);observed+=enemy.result.hp_damage
    end
    observed/=3000
    check((prediction.expected_formula-observed).abs/[observed,1].max<0.04,'combined crit/Guard/resistance/evasion/cancellation mean matches 3000 native hits')
    actor.clear_states;enemy.clear_states
    # Weighted recovery modes must use their probabilities, not range midpoint.
    heal=qa_skill(6002,'100',0,7);heal.damage.type=3
    qa_state(6002,[],'<HP回復無効:25>'+"\n"+'<HP回復反転:25>');actor.add_state(6002)
    p=BS2QoL::Forecast::Prediction.new(actor,actor,heal);sum=0
    2000.times do |i|
      actor.hp=actor.mhp/2;srand(81000+i);actor.item_apply(actor,heal);sum+=actor.result.hp_damage
    end
    check((p.expected_formula+37.5).abs<0.01 && (sum/2000.0+37.5).abs<5,'25% void plus 25% inversion produces weighted recovery -37.5, verified natively')
    actor.clear_states;actor.recover_all;enemy.clear_states;enemy.recover_all
    # Buff -> attack is generated over effects, rather than a fixed pair of IDs.
    hit=qa_skill(6003,'a.atk * 4 - b.def * 2')
    (0..7).each do |param|
      buff=qa_skill(6010+param,'0',0,11);buff.damage.type=0;buff.effects=[RPG::UsableItem::Effect.new(31,param,5,0)]
      actor.clear_states;actor.remove_all_buffs;actor.recover_all;actor.cool_time.clear;enemy.clear_states;enemy.recover_all
      report=plan(actor,[buff.id,hit.id]);row=report.steps[1][:rows][0]
      check(row && !report.steps[1][:reason],'parameter buff '+param.to_s+' propagates to later damage')
      actor.item_apply(actor,buff);enemy.item_apply(actor,hit)
      check(enemy.result.hp_damage.between?(row[:min],row[:max]),'parameter buff '+param.to_s+' matches native following hit')
    end
    actor.remove_all_buffs;actor.recover_all;enemy.recover_all
    # Earlier state can change resistance of the following effect in the SAME hit.
    qa_state(6020,[feat(14,6021,0)]);qa_state(6021,[feat(21,3,0.25)])
    setup=qa_skill(6020,'0');setup.damage.type=0;setup.effects=[RPG::UsableItem::Effect.new(21,6020,1,0),RPG::UsableItem::Effect.new(21,6021,1,0)]
    probe=qa_skill(6021,'b.def * 10')
    report=plan(actor,[setup.id,probe.id]);mean=report.steps[1][:rows][0][:mean]
    enemy.clear_states;enemy.item_apply(actor,setup);enemy.item_apply(actor,probe)
    check(!enemy.state?(6021) && enemy.result.hp_damage==mean,'same-hit later state observes resistance granted by the earlier state')
    enemy.clear_states;enemy.add_state(6021)
    setup.effects=[RPG::UsableItem::Effect.new(22,6021,1,0),RPG::UsableItem::Effect.new(21,6021,1,0)]
    report=plan(actor,[setup.id,probe.id]);mean=report.steps[1][:rows][0][:mean]
    enemy.item_apply(actor,setup);enemy.item_apply(actor,probe)
    check(!enemy.state?(6021) && enemy.result.hp_damage==mean,'a state removed this hit cannot be re-added by a later effect of the same hit')
    # Restriction cleanup is another transition, not just an appended ID.
    removable=qa_state(6022,[feat(21,3,0.5)]);removable.remove_by_restriction=true
    stun=qa_state(6023);stun.restriction=4
    setup.effects=[RPG::UsableItem::Effect.new(21,6023,1,0)]
    enemy.clear_states;enemy.add_state(6022)
    report=plan(actor,[setup.id,probe.id]);mean=report.steps[1][:rows][0][:mean]
    enemy.item_apply(actor,setup);enemy.item_apply(actor,probe)
    check(!enemy.state?(6022) && enemy.result.hp_damage==mean,'restriction removes dependent states before calculating following damage')
    enemy.clear_states;enemy.recover_all;actor.recover_all
    # Probabilistic DEF debuff produces a weighted mean for the following hit.
    setup.effects=[RPG::UsableItem::Effect.new(32,3,5,0)]
    record.features=[feat(12,3,0.5)];enemy.refresh
    report=plan(actor,[setup.id,probe.id]);mean=report.steps[1][:rows][0][:mean]
    total=0.0
    2000.times do |i|
      enemy.remove_all_buffs;enemy.recover_all;srand(91000+i);enemy.item_apply(actor,setup);enemy.item_apply(actor,probe);total+=enemy.result.hp_damage
    end
    check((total/2000-mean).abs/[mean,1].max<0.04,'probabilistic debuff branch mean matches 2000 native two-step sequences')
    record.features=[];enemy.refresh;enemy.remove_all_buffs;enemy.recover_all
    # Unsupported transitions must not publish a plausible numerical total.
    repeated=qa_skill(6030,'100',1);repeated.repeats=3
    record.features=[feat(22,6,1.0)];enemy.refresh
    report=plan(actor,[repeated.id])
    check(report.steps[0][:rows].empty? && !!report.steps[0][:reason],'repeated counter reactions are explicitly unknown, never summed as unchanged hits')
    record.features=[];enemy.refresh;enemy.hp=50
    report=plan(actor,[repeated.id])
    check(report.steps[0][:rows].empty? && report.steps[0][:reason].include?('погибнуть'),'possible death before later repeated hits suppresses the fabricated total')
    enemy.recover_all;repeated.scope=5;repeated.repeats=1;repeated.damage.formula='b.hp / 10'
    report=plan(actor,[repeated.id])
    check(report.steps[0][:rows].empty? && !!report.steps[0][:reason],'random draws with HP-dependent damage are guarded even when item.repeats is one')
    repeated.scope=1;repeated.damage.formula='100';repeated.effects=[RPG::UsableItem::Effect.new(44,1,0,0)]
    report=plan(actor,[repeated.id])
    check(report.steps[0][:direct_only] && report.steps[0][:rows].any?,'a single direct hit plus event is labelled partial rather than a full action total')
    text=BS2Suite::QuickDamage.calculate(repeated,actor,nil,[enemy],nil,nil).join
    check(text.include?('итог ?'),'short UI visibly labels the unknown full result of an event-bearing attack')
    # Shared F7 and short UI consume the same second-slot result and MP cost.
    repeated.effects=[];repeated.damage.formula='a.atk * 4';repeated.mp_cost=11
    buff=qa_skill(6040,'0',0,11);buff.damage.type=0;buff.effects=[RPG::UsableItem::Effect.new(31,2,5,0)]
    actor.remove_all_buffs;actor.recover_all;enemy.recover_all;plan(actor,[buff.id,repeated.id]);actor.instance_variable_set(:@action_input_index,1)
    step=BS2Suite::ForecastContext.step(repeated,actor,nil,enemy)
    card=BS2QoL::PracticalCard.new(repeated,actor,:ru);index=card.section_names.index('По целям');text=card.sections[index].join(' ')
    check(text.include?('~'+card.n(step[:rows][0][:mean].round)) && text.include?('серии'),'actual F7 Targets uses the shared queued-state mean')
    check(card.practical_cost.join.include?('11 MP') && card.practical_cost.join.include?('предыдущих'),'F7 execution price comes from the same queued-state cost')
    # Every progression difficulty changes the live stats/critical multiplier.
    source=qa_state(6050,[feat(22,2,1.0)]);actor.add_state(6050)
    spell=qa_skill(6050,'a.atk * 4 + b.mdf');spell.damage.critical=true
    variable=Hi_ru_Difficulty::VARIABLES;previous=$game_variables[variable]
    Hi_ru_Difficulty::DIFFICULTY_SETTING[11].size.times do |difficulty|
      $game_variables[variable]=difficulty;enemy.refresh;enemy.recover_all
      p=BS2QoL::Forecast::Prediction.new(actor,enemy,spell);enemy.item_apply(actor,spell)
      check((p.expected_formula-enemy.result.hp_damage).abs<1,'difficulty '+difficulty.to_s+' matches actual native critical/stat calculation')
    end
    $game_variables[variable]=previous;actor.remove_state(6050);enemy.refresh;enemy.recover_all
    # Projection identity must still resolve the acting hero as a friendly target.
    item=RPG::Item.new;item.id=6061;item.name='QA hero heal';item.scope=7;item.occasion=1;item.note='[hzm]ターン消費無し:99';item.effects=[RPG::UsableItem::Effect.new(11,0,0.3,0)];$data_items[6061]=item;$game_party.gain_item(item,2);actor.hp=actor.mhp/2
    hp_skill=qa_skill(6060,'a.hp * 0.1');queue(actor,2);actor.actions[0].set_item(item.id);actor.actions[0].target_index=actor.index;actor.actions[1].set_skill(hp_skill.id);actor.actions[1].target_index=0
    projected=BS2Suite::Projection.copy(actor)
    check(projected.index==actor.index,'read-only actor projections retain the actual party index')
    report=BS2Suite::SequenceForecast.new(actor);row=report.steps[1][:rows][0]
    actor.item_apply(actor,item);enemy.item_apply(actor,hp_skill)
    check(row && enemy.result.hp_damage.between?(row[:min],row[:max]),'hero-targeted instant healing affects following HP-based damage on a copied actor')
    actor.add_state(6002);actor.hp=actor.mhp/2
    report=BS2Suite::SequenceForecast.new(actor)
    check(!!report.steps[0][:reason] && report.steps[1][:rows].empty?,'unimplemented recovery-mode transitions explicitly block following numeric damage')
    actor.remove_state(6002);actor.recover_all;enemy.recover_all
    plan(actor,[buff.id,repeated.id]);actor.instance_variable_set(:@action_input_index,1)
    # A future bodyguard redirect must be checked against projected HP.
    old_hp=record.params[0];record.params[0]=1000;enemy.refresh;enemy.hp=400
    br=RPG::Enemy.new;br.id=5001;br.name='QA bodyguard';br.params=[1000,100,30,30,30,30,30,30];br.features=[feat(62,2,0)];$data_enemies[5001]=br
    buddy=Game_Enemy.new(1,5001);$game_troop.members<<buddy
    normal=qa_skill(6070,'200',1);qa_state(6070,[],'<物理絶対命中>');actor.add_state(6070)
    report=plan(actor,[normal.id,normal.id])
    check(report.steps[0][:rows].any? && report.steps[1][:rows].empty? && report.steps[1][:reason].include?('Прикрытие'),'crossing the quarter-HP threshold cannot silently reuse the original target in a later slot')
    @scene.invoke_item(enemy,normal);@scene.invoke_item(enemy,normal)
    check(enemy.hp==200 && buddy.hp==800,'native second attack actually redirects after the first lowered target HP')
    $game_troop.members.delete(buddy);record.params[0]=old_hp;enemy.refresh;enemy.recover_all;actor.remove_state(6070)
    plan(actor,[buff.id,repeated.id]);actor.instance_variable_set(:@action_input_index,1)
    # A previous enemy hit does not make the caster's unchanged HP/MP unknown.
    plain=qa_skill(6080,'100');resource=qa_skill(6081,'a.hp / 10 + a.mp');resource.mp_cost=5
    actor.recover_all;actor.cool_time.clear;enemy.recover_all
    report=plan(actor,[plain.id,resource.id]);row=report.steps[1][:rows][0]
    actor.use_item(plain);enemy.item_apply(actor,plain);actor.use_item(resource);enemy.item_apply(actor,resource)
    check(row && enemy.result.hp_damage.between?(row[:min],row[:max]),'unchanged caster HP/MP remains calculable after a damaging first action')
    victim_hp=qa_skill(6082,'b.hp / 10');enemy.recover_all
    report=plan(actor,[plain.id,victim_hp.id])
    check(report.steps[1][:rows].empty? && !!report.steps[1][:reason],'the victim HP dependency stays unknown when its actual remaining HP was not modelled')
    plan(actor,[buff.id,repeated.id]);actor.instance_variable_set(:@action_input_index,1)
    qa_state(6085,[feat(32,6020,1),feat(32,6021,1)]);actor.add_state(6085)
    enemy.clear_states;enemy.recover_all;setup.effects=[RPG::UsableItem::Effect.new(21,0,1,0)]
    report=plan(actor,[setup.id,probe.id]);mean=report.steps[1][:rows][0][:mean]
    enemy.item_apply(actor,setup);enemy.item_apply(actor,probe)
    check(!enemy.state?(6021) && enemy.result.hp_damage==mean,'attack-state list also recalculates target immunity between states of one effect')
    actor.remove_state(6085);enemy.clear_states;enemy.recover_all
    plan(actor,[buff.id,repeated.id]);actor.instance_variable_set(:@action_input_index,1)
    # Scheduled instant skills are selected at execution, not at macro commit.
    qa_state(6100);grant=qa_skill(6101,'0',0,11);grant.damage.type=0;grant.effects=[RPG::UsableItem::Effect.new(21,6100,1,0)]
    late=qa_skill(6100,'100');late.note='[hzm]ターン消費無し:99'+"\n"+'<ステート変化:6103,6100>'
    variant=qa_skill(6103,'900');variant.note='[hzm]ターン消費無し:99'
    actor.remove_state(6100);plan(actor,[grant.id,plain.id])
    row={'kind'=>'skill','id'=>late.id,'source'=>0,'target'=>0};actor.actions[1].instance_variable_set(:@bs2s_macro_before,[row])
    report=BS2Suite::SequenceForecast.new(actor)
    before_id=BS2Suite::Macros.action(actor,row,0).item.id;actor.add_state(6100);after_id=BS2Suite::Macros.action(actor,row,0).item.id
    check(before_id!=after_id && report.steps[1][:rows].empty? && !!report.steps[1][:reason],'late state-dependent instant skill IDs cannot be forecast as their earlier untransformed ID')
    actor.remove_state(6100);plan(actor,[buff.id,repeated.id]);actor.instance_variable_set(:@action_input_index,1)
    # Detect only HP-event presence, never inspect hidden thresholds or scripts.
    page=RPG::Troop::Page.new;page.condition.enemy_valid=true;page.list=[RPG::EventCommand.new,RPG::EventCommand.new]
    $game_troop.troop.pages<<page
    report=plan(actor,[plain.id,plain.id])
    check(report.steps[1][:rows].any? && report.steps[1][:conditional] && !report.complete,'possible HP-script changes produce conditional per-action numbers and suppress a certified series total')
    actor.instance_variable_set(:@action_input_index,1)
    check(BS2Suite::QuickDamage.calculate(plain,actor,nil,[enemy],nil,nil).join.include?('условно'),'short UI visibly qualifies an HP-script-dependent forecast')
    $game_troop.troop.pages.delete(page);plan(actor,[buff.id,repeated.id]);actor.instance_variable_set(:@action_input_index,1)
    qa_state(6086,[],'<スキル無効:6080,100>');enemy.recover_all;enemy.add_state(6086)
    report=plan(actor,[plain.id,victim_hp.id]);row=report.steps[1][:rows][0]
    check(report.steps[0][:rows][0][:mean]==0 && row && !report.steps[1][:reason],'a guaranteed cancelled hit does not fabricate HP uncertainty for the next formula')
    enemy.remove_state(6086);plan(actor,[buff.id,repeated.id]);actor.instance_variable_set(:@action_input_index,1)
    # Distinguish a fresh list choice from an already selected, transformed ID.
    base=qa_skill(6087,'100',2);middle=qa_skill(6088,'200',2);last=qa_skill(6089,'300',2)
    base.note='<ステート変化:6088,6100>';middle.note='<ステート変化:6089,6100>'
    actor.result.clear;actor.add_state(6100);queue(actor,1);actor.input.set_skill(base.id);actor.input.target_index=0
    selected=BS2Suite::QuickDamage.calculate(actor.input.item,actor,nil,[enemy],enemy,nil).join
    hovered=BS2Suite::QuickDamage.calculate(middle,actor,nil,[enemy],nil,nil).join
    check(actor.input.item.id==6088 && selected.include?('200') && hovered.include?('300'),'selected transformed IDs are not transformed twice; fresh list selections still transform once')
    weapon=RPG::Weapon.new;weapon.id=6090;weapon.name='QA state-resistant executor';weapon.wtype_id=$data_weapons[101].wtype_id;weapon.features=[feat(14,6100,0)];$data_weapons[6090]=weapon;$game_party.gain_item(weapon,1)
    BS2Suite::DirectWeapons.select(actor,weapon);BS2Suite::DirectWeapons.arm(actor)
    card=BS2QoL::PracticalCard.new(base,actor,:ru)
    check(card.instance_variable_get(:@resolved)==middle && card.compact_forecast.join.include?('200'),'F7 resolves the selected variant before the final executor removes its qualifying state')
    actor.input.prepare;chosen=actor.input.item;actor.use_item(chosen);enemy.item_apply(actor,chosen)
    check(chosen.id==6088 && !actor.state?(6100) && enemy.result.hp_damage==200,'native execution retains that selected variant after the final weapon removes the state')
    BS2Suite::DirectWeapons.clear(actor);actor.clear_equipments;actor.clear_states;actor.recover_all;enemy.recover_all
    variants=0
    $data_skills.compact.select { |skill| skill.id<1000 }.each do |skill|
      skill.note.scan(/<ステート変化:(\d+),(\d+)>/).each do |variant_id,state_id|
        actor.clear_states;actor.recover_all;actor.result.clear;actor.add_state(state_id.to_i);actor.learn_skill(skill.id);queue(actor,1)
        action=Game_Action.new(actor);action.set_skill(skill.id)
        result=BS2Suite::ForecastContext.step(skill,actor,nil,enemy)
        check(result && result[:item] && result[:item].id==action.item.id,'database state-dependent selection '+skill.id.to_s+'/'+state_id+' agrees with native ID')
        variants+=1
      end
    end
    check(variants==33,'all 33 database state-conditional selection rules were exercised')
    actor.clear_states;actor.recover_all;enemy.recover_all;plan(actor,[buff.id,repeated.id]);actor.instance_variable_set(:@action_input_index,1)
    sequence_card=BS2Suite::SequenceCard.new(actor,:ru)
    sequence_text=sequence_card.sections.flatten.join(' ')
    check(sequence_text.include?('~') && !sequence_text.include?('попадание 0%'),'series card does not invent a zero hit chance from a missing per-hit field')
    # Verification cannot mutate the live queue, resources or random stream.
    before=Marshal.dump([actor,$game_troop.members,$game_party.instance_variable_get(:@items)]);srand(10101);expected=rand;srand(10101)
    5.times { BS2Suite::ForecastContext.step(repeated,actor,nil,enemy);BS2QoL::PracticalCard.new(repeated,actor,:ru) }
    check(before==Marshal.dump([actor,$game_troop.members,$game_party.instance_variable_get(:@items)]) && rand==expected,'shared card and sequence calculations leave state and RNG untouched')
    @scene.instance_variable_set(:@log_window,saved_log);@scene.terminate
    log('result=PASS; checks='+@checks.to_s)
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure
    BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  end
end
