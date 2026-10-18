# encoding: UTF-8
rgss_main do
load 'BS2QA_native_capture.rb'
@checks=0;@failures=[];@rows=[]
def log(t);File.open('test_result.txt','a') { |f| f.puts t };end
def check(value,label)
  @checks+=1;@failures<<label unless value
end
def reset_queue(actor,n)
  actor.instance_variable_set(:@actions,Array.new(n) { Game_Action.new(actor) });actor.instance_variable_set(:@action_input_index,0)
  BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
end
begin
  File.open('test_result.txt','w') { |f| f.puts 'Weapon provenance audit; native '+RUBY_VERSION }
  DataManager.init;DataManager.setup_new_game
  SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
  @actor=$game_actors[1];@actor.change_class(1);@actor.change_level(70,false);@actor.clear_equipments
  [101,156,167,277,361,391,415,463].each { |id| $game_party.gain_item($data_weapons[id],1) }
  @actor.learn_skill(14)
  [3,51,61].each { |id| $game_party.gain_item($data_items[id],80) }
  prep=RPG::Skill.new;prep.id=4995;prep.name='Пауза теста';prep.scope=11;$data_skills[prep.id]=prep;@actor.learn_skill(prep.id)
  item=RPG::Item.new;item.id=4995;item.name='Предмет от характеристик';item.scope=1;item.occasion=1;item.damage.type=1;item.damage.formula='a.atk + a.mat + a.agi';item.damage.variance=20;$data_items[item.id]=item;$game_party.gain_item(item,80)
  fixed=RPG::State.new;fixed.id=900;fixed.name='Фиксация теста';fixed.features=[RPG::BaseItem::Feature.new(53,0,1)];$data_states[900]=fixed
  troop=RPG::Troop.new;troop.id=79
  troop.members=(0..2).map do |i|
    e=RPG::Enemy.new;e.id=5000+i;e.name='Манекен '+i.to_s;e.battler_name='';e.params=[100000000,10000,50,20+i*20,50,20+i*20,50,50];$data_enemies[e.id]=e
    m=RPG::Troop::Member.new;m.enemy_id=e.id;m.x=150+i*150;m.y=150;m
  end
  $data_troops[79]=troop
  BS2Suite::Options.set('knowledge_threshold',0)
  BattleManager.setup(79,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
  @actor.instance_variable_set(:@ap,ATB::MAX_AP);reset_queue(@actor,2)
  @scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,@scene);@scene.start;@scene.start_actor_command_selection
  BS2Suite::HDDisplay.apply(BS2Suite::HDDisplay::DEFAULT)
  @cases=[]
  [101,277,391,167,nil].each do |w|
    [:normal,:magic,:knife,:item,:heal,:buff].each do |kind|
      [nil,391].each { |nom| @cases<<[kind,w,nom,:one,nil] }
    end
  end
  [361,415,463].each { |w| [nil,391,361].each { |nom| @cases<<[:normal,w,nom,:one,nil] } }
  [nil,391].each do |nom|
    [:one,:first,:last,:remaining].each { |slot| @cases<<[:tech,277,nom,slot,nil] }
    [:first,:last,:remaining].each { |slot| @cases<<[:magic,277,nom,slot,nil];@cases<<[:item,277,nom,slot,nil] }
    @cases<<[:knife,277,nom,:last,nil]
  end
  [:magic,:normal,:item].each { |kind| @cases<<[kind,277,391,:one,:locked] }
  @cases<<[:magic,101,391,:one,:poor_mp]
  @cases<<[:magic,277,391,:one,:missing]
  @cases<<[:magic,277,391,:one,:forced]
  @cases<<[:tech,277,391,:one,:forced]
  @cases<<[:chain,277,nil,:first,nil]
  @cases<<[:tech,277,nil,:one,:upgrade]
  @cases<<[:tech,277,391,:one,:upgrade]
  [nil,391].each { |n| @cases<<[:normal,482,n,:one,nil];@cases<<[:magic,482,n,:one,nil] }
  $game_party.gain_item($data_weapons[482],1)
  @cases.each_with_index do |spec,num|
    kind,worn,nom,slot,edge=spec;label=[num,kind,worn || 0,nom || 0,slot,edge].join(':')
    begin
      actor=@actor;actor.clear_states;actor.clear_buffs;actor.cool_time.clear
      actor.hzm_vxa_quickSkill_reset_use_count
      $game_troop.members.each { |e| e.clear_states;e.clear_buffs;e.recover_all }
      actor.change_equip(0,nil) unless worn
      BS2QoL::Model.change_weapon(actor,$data_weapons[worn]) if worn
      actor.recover_all
      BS2Suite::DirectWeapons.clear(actor)
      BS2Suite::DirectWeapons.select(actor,$data_weapons[nom]) if nom
      count=slot==:one ? 1 : 2;reset_queue(actor,count)
      actor.actions.each { |a| a.set_skill(4995) }
      index=[:last,:remaining].include?(slot) ? 1 : 0;actor.instance_variable_set(:@action_input_index,index)
      object=case kind
      when :magic;$data_skills[14]
      when :tech,:chain;$data_skills[105]
      when :knife;$data_items[51]
      when :heal;$data_items[3]
      when :buff;$data_items[61]
      when :item;$data_items[4995]
      else;$data_skills[actor.attack_skill_id]
      end
      action=actor.actions[index]
      v_card=nil;v_inline=nil
      if [:tech,:chain].include?(kind) && edge!=:forced
        $game_party.gain_item($data_weapons[104],1) if edge==:upgrade
        v_source=BS2Suite::Semantic.source_for(actor,105,101)
        v_before=Marshal.dump([actor,$game_party.instance_variable_get(:@weapons)])
        v_card=BS2QoL::PracticalCard.new(object,BS2Suite::Projection.weapon(actor,v_source),:ru)
        v_inline=BS2Suite::QuickDamage.lines(@scene,object,actor,v_source,$game_troop.members[0])
        check(v_before==Marshal.dump([actor,$game_party.instance_variable_get(:@weapons)]),label+' V preview does not equip live actor')
        @scene.start_actor_command_selection
        @scene.bs2v2_cast([:skill,105,101],:commands)
        @scene.instance_variable_get(:@enemy_window).hide.deactivate
        @scene.instance_variable_get(:@skill_window).hide.deactivate
      elsif kind==:normal
        action.set_attack
      elsif object.is_a?(RPG::Item)
        action.set_item(object.id)
      else
        action.set_skill(object.id)
      end
      action.target_index=0
      if kind==:chain
        second=$data_weapons.compact.find { |w| w.features.any? { |f| f.code==43 && f.data_id==151 } }
        $game_party.gain_item(second,1)
        actor.instance_variable_set(:@action_input_index,1);@scene.start_actor_command_selection
        @scene.bs2v2_cast([:skill,151,second.id],:commands)
        @scene.instance_variable_get(:@enemy_window).hide.deactivate
        actor.actions[1].target_index=0;actor.instance_variable_set(:@action_input_index,0)
      end
      if edge==:locked;actor.add_state(900)
      elsif edge==:poor_mp
        a=actor.skill_mp_cost(object);b=BS2Suite::Projection.weapon(actor,$data_weapons[391]).skill_mp_cost(object);actor.mp=[(a+b)/2,a].max
      elsif edge==:missing;actor.instance_variable_set(:@bs2s_direct_weapon_id,9999)
      elsif edge==:forced;action.instance_variable_set(:@forcing,true)
      end
      BS2Suite::DirectWeapons.arm(actor)
      if slot==:remaining
        actor.actions.shift;actor.instance_variable_set(:@action_input_index,0);index=0;action=actor.current_action
      end
      target=object.for_friend? ? actor : $game_troop.members[0]
      actor.hp=[actor.mhp/2,1].max if kind==:heal
      signature=lambda { |a| [a.equips.map { |e| e && e.id },(0..7).map { |i| a.param(i) },a.cri,a.hit,a.pha,a.rec,a.mcr] }
      before=Marshal.dump([actor,$game_party.instance_variable_get(:@items),$game_party.instance_variable_get(:@weapons),$game_troop.members])
      battle_flag=$game_temp.battle_equip
      srand(1234+num);expected_rand=rand;srand(1234+num)
      report=BS2Suite::SequenceForecast.new(actor);step=report.steps[index]
      card=BS2QoL::PracticalCard.new(object,actor,:ru)
      inline=BS2Suite::QuickDamage.lines(@scene,object,actor,nil,target)
      check(before==Marshal.dump([actor,$game_party.instance_variable_get(:@items),$game_party.instance_variable_get(:@weapons),$game_troop.members]),label+' preview immutable')
      check(rand==expected_rand,label+' preview RNG unchanged')
      check($game_temp.battle_equip==battle_flag,label+' global equipment flag restored')
      quick=BS2Suite::BattleSupport.quick?(object)
      HZM_VXA::QuickSkill.start if quick
      if slot==:last
        # Execute the earlier neutral slot before asking prepare about the last.
        actor.use_item(actor.current_action.item)
        actor.actions.shift;actor.instance_variable_set(:@action_input_index,0)
      end
      action.prepare
      live_stats=signature.call(actor);card_stats=signature.call(card.actor)
      live_weapon=actor.equips[0] && actor.equips[0].id
      forecast_weapon=step[:weapon] && step[:weapon].id
      check(live_weapon==forecast_weapon,label+' series weapon')
      check(live_stats==card_stats,label+' F7 stats')
      check(signature.call(v_card.actor)==live_stats,label+' V F7 before selection stats') if v_card && kind!=:chain
      if object.is_a?(RPG::Skill)
        check(card.actor.skill_mp_cost(object)==actor.skill_mp_cost(object),label+' F7 MP cost')
        check(step[:cost][1][0]==actor.skill_mp_cost(object),label+' series MP cost') if step[:cost]
      end
      if object.is_a?(RPG::Skill) && actor.usable?(object) && object.damage.to_hp?
        check(!card.forecast_lines.join.include?('Сейчас приём недоступен'),label+' F7 permits already selected ID')
      end
      prediction=BS2QoL::Forecast::Prediction.new(actor,target,object)
      mean=prediction.expected_formula
      mean*=prediction.stable ? prediction.repeats : 1 if mean
      if mean && object.for_opponent? && !object.for_random?
        inline_mean=inline.join[/[≈~]\s*(\d+)/,1]
        check(inline_mean && inline_mean.to_i==[mean.round,0].max,label+' inline mean')
        if v_inline && kind!=:chain
          v_mean=v_inline.join[/[≈~]\s*(\d+)/,1]
          check(v_mean && v_mean.to_i==[mean.round,0].max,label+' V inline before selection mean')
        end
        check(step[:rows].any? && (step[:rows].inject(0.0) { |s,r| s+r[:mean] }-mean).abs<0.01,label+' series mean')
      end
      # The native engine is the oracle for cost and a real hit, not another call
      # through the forecast. Samples are conditional on a native hit/critical.
      samples=0;cost=object.is_a?(RPG::Skill) ? actor.skill_mp_cost(object) : 0;mp=actor.mp
      actor.use_item(object)
      check(mp-actor.mp==cost,label+' native MP paid')
      target.item_apply(actor,object)
      row=prediction.rows.find { |r| r[:formula] }
      if row && target.result.hit?
        range=(target.result.critical ? row[:critical] : row[:normal])[:raw]
        damage=target.result.hp_damage
        check(damage>=range[0] && damage<=range[1],label+' native hit range');samples=1
      end
      HZM_VXA::QuickSkill.finish if quick
      @rows<<[label,object.id,quick ? 1 : 0,live_weapon || 0,forecast_weapon || 0,card.actor.equips[0] && card.actor.equips[0].id || 0,inline.join(' '),mean,samples]
    rescue Exception=>e
      @failures<<label+' EXCEPTION '+e.class.to_s+': '+e.message
      HZM_VXA::QuickSkill.finish if HZM_VXA::QuickSkill.quickSkill?
    end
  end
  # Cache invalidation must follow actual resources, formulas and family resolution.
  actor=@actor;actor.clear_states;actor.clear_buffs;actor.recover_all;actor.cool_time.clear
  BS2QoL::Model.change_weapon(actor,$data_weapons[277]);BS2Suite::DirectWeapons.clear(actor);reset_queue(actor,1)
  item=$data_items[4995];actor.input.set_item(item.id);actor.input.target_index=0
  target=$game_troop.members[0];target.clear_states;target.clear_buffs;target.recover_all
  $game_party.gain_item(item,10)
  before=BS2Suite::QuickDamage.lines(@scene,item,actor,nil,target).join
  count=$game_party.item_number(item);$game_party.lose_item(item,count)
  after=BS2Suite::QuickDamage.lines(@scene,item,actor,nil,target).join
  check(before.match(/[≈~]\s*\d+/) && after.include?('?'),'cache refreshes when a required item runs out')
  $game_party.gain_item(item,count)
  BS2Suite::DirectWeapons.select(actor,$data_weapons[391]);actor.learn_skill(14);actor.input.set_skill(14)
  before=BS2Suite::QuickDamage.lines(@scene,$data_skills[14],actor,nil,target).join[/≈ (\d+)/,1].to_i
  $game_party.gain_item($data_weapons[394],1)
  after=BS2Suite::QuickDamage.lines(@scene,$data_skills[14],actor,nil,target).join[/≈ (\d+)/,1].to_i
  check(after>before && actor.equips[0]==$data_weapons[277],'cache refreshes when nominated family gains a higher upgrade without equipping live actor')
  BS2Suite::DirectWeapons.clear(actor)
  variable=RPG::Skill.new;variable.id=4994;variable.name='Тест переменной';variable.scope=1;variable.hit_type=0;variable.damage.type=1;variable.damage.formula='a.mat + v[4999]';variable.damage.variance=0;$data_skills[variable.id]=variable;actor.learn_skill(variable.id);actor.input.set_skill(variable.id)
  $game_variables[4999]=0
  before=BS2Suite::QuickDamage.lines(@scene,variable,actor,nil,target).join[/≈ (\d+)/,1].to_i
  $game_variables[4999]=100
  after=BS2Suite::QuickDamage.lines(@scene,variable,actor,nil,target).join[/≈ (\d+)/,1].to_i
  check(after-before==100,'cache refreshes when a formula variable changes without actor stat changes')
  actor.use_item(variable);target.item_apply(actor,variable)
  check(target.result.hp_damage==after,'native hit agrees with the refreshed variable-dependent damage')
  File.open('weapon_audit.tsv','w') do |f|
    f.puts "case\titem\tquick\tlive_weapon\tseries_weapon\tf7_weapon\tinline\tlive_expected\tnative_samples"
    @rows.each { |r| f.puts r.join("\t") }
  end
  File.open('weapon_failures.txt','w') { |f| @failures.each { |s| f.puts s } }
  log('cases='+@cases.size.to_s+'; rows='+@rows.size.to_s+'; failures='+@failures.size.to_s)
  @failures.take(12).each { |s| log('FAIL '+s) }
  log('result='+(@failures.empty? ? 'PASS' : 'FAIL')+'; checks='+@checks.to_s)
  @scene.terminate;$game_party.on_battle_end
rescue Exception=>e
  log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
ensure
  SuiteCapture.close
end
end
