# encoding: UTF-8
rgss_main do
  @checks=0
  def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
  def check(v,s);raise s unless v;@checks+=1;log('PASS '+s);end
  def copy(x);Marshal.load(Marshal.dump(x));end
  class Game_Battler
    alias bs209991_audit_execute execute_damage
    def execute_damage(user)
      bs209991_audit_execute(user)
      @forecast_audit_hit=[result.hp_damage,result.mp_damage,result.critical]
    end
  end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'catalogue first-hit audit '+BS2Suite::VERSION }
    DataManager.init;DataManager.setup_new_game
    actor=$game_party.leader;actor.change_class(1);actor.change_level(200,false);actor.clear_equipments
    actor.instance_variable_get(:@param_plus)[0]=2000000;actor.instance_variable_get(:@param_plus)[1]=9000;actor.recover_all
    record=RPG::Enemy.new;record.id=5000;record.name='QA audit';record.params=[2000000,9000,150,80,150,80,150,100];record.features=[];$data_enemies[5000]=record
    enemy=Game_Enemy.new(0,5000)
    BattleManager.setup(79,true,false);$game_party.on_battle_start
    $game_troop.instance_variable_set(:@enemies,[enemy])
    scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,scene)
    state=RPG::State.new;state.id=5000;state.name='QA audit multipliers';state.features=[RPG::BaseItem::Feature.new(21,2,1.5),RPG::BaseItem::Feature.new(22,2,0.35),RPG::BaseItem::Feature.new(23,6,0.7),RPG::BaseItem::Feature.new(23,7,0.65),RPG::BaseItem::Feature.new(11,1,0.8)];$data_states[5000]=state
    audit={:records=>0,:damaging_records=>0,:contexts=>0,:predictions=>0,:explicit_unknown=>0,:native_samples=>0,:range_matches=>0,:no_hit=>0,:errors=>[], :unsupported=>[]}
    objects=($data_skills+$data_items).compact
    audit[:records]=objects.size
    objects.each do |item|
      next if item.damage.none?
      audit[:damaging_records]+=1
      3.times do |context|
        a=context==2 ? copy(enemy) : copy(actor)
        b=item.for_user? ? a : (item.for_friend? ? (a.actor? ? copy(actor) : copy(enemy)) : (a.actor? ? copy(enemy) : copy(actor)))
        [a,b].uniq.each do |u|
          u.recover_all;u.hp=u.mhp/2;u.mp=u.mmp*3/4;u.tp=75
          u.add_state(5000) if context==1
        end
        prediction=BS2QoL::Forecast::Prediction.new(a,b,item)
        audit[:contexts]+=1
        if prediction.error
          audit[:explicit_unknown]+=1;audit[:unsupported]<<[item.class.to_s,item.id,context,prediction.error];next
        end
        audit[:predictions]+=1
        f=prediction.rows.find { |r| r[:formula] }
        unless f;audit[:errors]<<[item.class.to_s,item.id,context,'missing formula row'];next;end
        8.times do |seed|
          user=copy(a);target=b.equal?(a) ? user : copy(b)
          user.pay_skill_cost(item) if item.is_a?(RPG::Skill)
          target.instance_variable_set(:@forecast_audit_hit,nil)
          srand(190000+seed)
          begin
            target.item_apply(user,item)
          rescue StandardError=>e
            audit[:errors]<<[item.class.to_s,item.id,context,e.class.to_s];break
          end
          audit[:native_samples]+=1
          hit=target.instance_variable_get(:@forecast_audit_hit)
          if hit
            actual=item.damage.to_hp? ? hit[0] : hit[1]
            range=hit[2] ? f[:critical][:raw] : f[:normal][:raw]
            if actual.between?(*range);audit[:range_matches]+=1
            else;audit[:errors]<<[item.class.to_s,item.id,context,seed,actual,range];break;end
          else;audit[:no_hit]+=1;end
          $game_temp.clear_common_event
        end
      end
    end
    File.open('forecast_catalog.json','wb') { |f| f.write(BS2Suite::Debug.json(audit)) } if defined?(BS2Suite::Debug)
    # No player names, game content or personal saves are exported.
    File.open('forecast_catalog_counts.txt','w') { |f| audit.each { |k,v| f.puts k.to_s+'='+v.to_s unless [:errors,:unsupported].include?(k) } }
    log('catalogue errors='+audit[:errors].inspect)
    log('unsupported contexts='+audit[:unsupported].inspect)
    check(audit[:records]==1389 && audit[:damaging_records]==648,'every one of 1389 skill/item records is classified; all 648 formula-damage records exercised')
    check(audit[:contexts]==1944,'all damage records audited as hero, buffed hero and enemy user')
    check(audit[:errors].empty?,'every supported native first-hit result lies in its predicted conditional range')
    check(audit[:range_matches]>10000,'broad oracle audit contains over ten thousand actual damaging/healing native outcomes')
    log('result=PASS; checks='+@checks.to_s)
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure
    BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  end
end
