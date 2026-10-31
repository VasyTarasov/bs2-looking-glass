# encoding: UTF-8
# The oracle observes item_apply AFTER every recovery effect, not execute_damage.
rgss_main do
  @checks=0;@native=0
  def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
  def check(v,s);raise s unless v;@checks+=1;end
  def feature(c,i,v);RPG::BaseItem::Feature.new(c,i,v);end
  def forecast_action(actor,item,target)
    a=Game_Action.new(actor);item.is_a?(RPG::Item) ? a.set_item(item.id) : a.set_skill(item.id)
    a.target_index=target.index;actor.instance_variable_set(:@actions,[a]);actor.instance_variable_set(:@action_input_index,0)
    BS2Suite::DirectWeapons.clear(actor);BS2Suite::SequenceForecast.new(actor).steps[0]
  end
  def verify(actor,target,item,label,seeds=3)
    actor.cool_time.clear;actor.recover_all;target.recover_all
    step=forecast_action(actor,item,target)
    check(step && !step[:reason] && !step[:rows].empty?,label+' supported: '+(step && step[:reason]).to_s)
    seeds.times do |seed|
      user=BS2Suite::Projection.copy(actor);victim=BS2Suite::Projection.copy(target)
      user.pay_skill_cost(item) if item.is_a?(RPG::Skill)
      totals={'HP'=>0,'MP'=>0};srand(582900+seed)
      item.repeats.times do
        victim.result.clear;victim.item_apply(user,item)
        totals['HP']+=victim.result.hp_damage;totals['MP']+=victim.result.mp_damage;@native+=1
      end
      step[:rows].each do |r|
        check(totals[r[:resource]].between?(r[:min],r[:max]),label+' '+r[:resource]+' '+totals[r[:resource]].to_s+' outside '+[r[:min],r[:max]].inspect)
      end
    end
    step
  end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'percentage and mixed resource effects '+BS2Suite::VERSION }
    DataManager.init;DataManager.setup_new_game
    actor=$game_party.leader;actor.change_class(1);actor.change_level(200,false);actor.clear_equipments
    actor.instance_variable_get(:@param_plus)[1]+=999999;actor.recover_all
    BS2Suite::Options.data['knowledge_threshold']=0
    original_records=($data_skills+$data_items).compact.select { |x| x.effects.any? { |e| [11,12].include?(e.code) && (e.value1<0 || e.value2<0) } }
    check(original_records.size==89,'all 89 original negative resource-effect records enumerated')
    # Isolate each database resource effect with its original Item/Skill class;
    # this checks REC/PHA/rounding, not unsupported events on the complete skill.
    record=RPG::Enemy.new;record.id=5900;record.name='QA resource';record.params=[2000000,2000000,20,20,20,20,20,20];$data_enemies[5900]=record
    troop=RPG::Troop.new;troop.id=5900;m=RPG::Troop::Member.new;m.enemy_id=5900;troop.members=[m];$data_troops[5900]=troop
    BattleManager.setup(5900,true,false);$game_party.on_battle_start;target=$game_troop.members[0]
    source=RPG::State.new;source.id=5900;source.name='QA PHA';source.features=[feature(23,3,1.5)];$data_states[5900]=source;actor.add_state(5900)
    effects=0
    original_records.each do |original|
      original.effects.each do |effect|
        next unless [11,12].include?(effect.code) && (effect.value1<0 || effect.value2<0)
        effects+=1
        item=original.is_a?(RPG::Item) ? RPG::Item.new : RPG::Skill.new
        item.id=5901;item.name='QA resource effect';item.occasion=1;item.scope=1;item.hit_type=0;item.success_rate=100
        item.damage.type=0;item.effects=[effect];item.repeats=1
        if item.is_a?(RPG::Item);$data_items[item.id]=item;$game_party.gain_item(item,5)
        else;$data_skills[item.id]=item;actor.learn_skill(item.id);end
        [0.0,0.5,2.0].each do |rec|
          record.features=[feature(23,2,rec)];target.refresh
          verify(actor,target,item,'database '+original.class.to_s+' '+original.id.to_s+' REC '+rec.to_s,1)
        end
      end
    end
    log('database_records=89; isolated_effects='+effects.to_s)
    actor.remove_state(5900)
    # Full, unmodified player techniques on the real boss templates. Certain
    # percentage effects are not multiplied by formula element/critical/PDR.
    boss_checks=0;explicitly_unsupported=0
    [569,606,611,613,620].each do |troop_id|
      BattleManager.setup(troop_id,true,false);$game_party.on_battle_start
      $game_troop.members.each do |enemy|
        next if enemy.hidden?
        [491,492,841,896].each do |id|
          item=$data_skills[id];actor.learn_skill(id);actor.recover_all;actor.cool_time.clear;enemy.recover_all
          step=forecast_action(actor,item,enemy)
          if step[:reason]
            check(step[:rows].empty?,'unsupported boss context never exposes a false complete total');explicitly_unsupported+=1;next
          end
          verify(actor,enemy,item,'real boss '+troop_id.to_s+' skill '+id.to_s);boss_checks+=1
          if id==491 && troop_id==606 && enemy.enemy_id==545
            check(step[:rows][0][:min]==163350 && step[:rows][0][:max]==163350,'Lindamea dark immunity does not cancel the separate 3 percent effect')
          end
        end
      end
    end
    log('real_boss_actions='+boss_checks.to_s+'; explicitly_unsupported='+explicitly_unsupported.to_s)
    # Two different resource effects must remain separate numeric rows.
    BattleManager.setup(5900,true,false);$game_party.on_battle_start;target=$game_troop.members[0];record.features=[]
    s=RPG::Skill.new;s.id=5902;s.name='QA HP plus MP';s.scope=1;s.occasion=1;s.hit_type=0;s.damage.type=1;s.damage.formula='10';s.damage.variance=0
    s.effects=[RPG::UsableItem::Effect.new(11,0,-0.03,0),RPG::UsableItem::Effect.new(12,0,-0.02,0)]
    $data_skills[s.id]=s;actor.learn_skill(s.id)
    step=verify(actor,target,s,'separate HP and MP effects')
    expected_hp=10+(target.mhp*0.03*target.rec).to_i;expected_mp=(target.mmp*0.02*target.rec).to_i
    check(step[:rows].map { |r| [r[:resource],r[:mean]] }.sort==[['HP',expected_hp.to_f],['MP',expected_mp.to_f]],'MP effect never contaminates HP damage')
    # Earlier effects may change the maximum/REC used by the next effect.
    st=RPG::State.new;st.id=5903;st.name='QA REC and maximum';st.features=[feature(21,0,1.5),feature(23,2,0.5)];$data_states[st.id]=st
    s.effects=[RPG::UsableItem::Effect.new(21,st.id,1,0),RPG::UsableItem::Effect.new(11,0,-0.03,0)]
    step=verify(actor,target,s,'state before percentage effect')
    changed=BS2Suite::Projection.copy(target);changed.add_state(st.id)
    check(step[:rows][0][:mean]==10+(changed.mhp*0.03*changed.rec).to_i,'percentage uses post-state maximum and REC')
    # Forecasts are read-only and do not consume the native RNG stream.
    actor.recover_all;target.recover_all;forecast_action(actor,s,target)
    before=Marshal.dump([$game_party,$game_actors,$game_troop,$game_variables,$game_switches])
    srand(99123);expected=rand;srand(99123);BS2Suite::SequenceForecast.new(actor);observed=rand
    check(expected==observed,'percentage forecasting preserves native RNG')
    check(before==Marshal.dump([$game_party,$game_actors,$game_troop,$game_variables,$game_switches]),'percentage forecasting preserves game state')
    log('result=PASS; checks='+@checks.to_s+'; native_applications='+@native.to_s)
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure
    BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  end
end
