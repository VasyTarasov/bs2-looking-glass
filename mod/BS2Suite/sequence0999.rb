# encoding: UTF-8
# Bounded, read-only transitions. Random target draws and repeated hits are
# separate transitions, so earlier self buffs and on-hit states affect later hits.
module BS2Suite
  class SequenceForecast
    def initialize(actor,weapon=nil)
      @actor=actor;@weapon=weapon || DirectWeapons.selected(actor);@steps=[];@totals={};@complete=true;@limitations=[]
      targets=$game_troop.alive_members.reject { |t| t.hidden? }
      stock=Hash[$game_party.items.map { |i| [i.id,$game_party.item_number(i)] }]
      branches=[{:user=>Projection.copy(actor),:targets=>Hash[targets.map { |t| [t.index,Projection.copy(t)] }],:weight=>1.0,:stock=>stock,:gold=>$game_party.gold}]
      final_index=actor.instance_variable_get(:@bs2s_forecast_final_index) || actor.actions.size-1
      stopped=false;prior_damage=false
      actor.actions.each_with_index do |action,index|
        item=action && action.item
        step={:index=>index,:item=>item,:rows=>[],:cost=>nil,:weapon=>actor.equips[0]};@steps<<step
        unless item;stopped=true;@complete=false;next;end
        if stopped;step[:reason]='Предыдущий переход не подтверждён';next;end
        if prior_damage && item.damage.formula.to_s =~ /[ab]\.(?:hp|mp|hp_rate|mp_rate)\b/
          step[:reason]='Формула зависит от ресурсов после урона';stopped=true;@complete=false;next
        end
        ids=if item.for_user? || (item.for_friend? && !item.for_dead_friend? && (item.for_all? || action.target_index==actor.index));[:self]
        elsif item.for_opponent?
          item.for_all? || item.for_random? ? targets.map { |t| t.index } : [targets.find { |t| t.index==action.target_index } && action.target_index]
        else;[];end
        if ids.empty? || ids.include?(nil)
          step[:reason]='Нужна цель; союзный переход не подтверждён';stopped=true;@complete=false;next
        end
        if ids.any? { |id| id!=:self && !Knowledge.allowed?(targets.find { |t| t.index==id }) }
          step[:reason]='Сведения о противнике ещё закрыты';stopped=true;@complete=false;next
        end
        costs=[];next_branches=[];failed=nil
        begin
          branches.each do |original|
            branch=copy_branch(original);user=branch[:user];restore=user.equips[0]
            plan=action.instance_variable_get(:@bs2s_support_plan)
            provider=action.instance_variable_get(:@bs2s_macro_source) || (plan && plan[:source])
            provider=nil unless provider.is_a?(RPG::Weapon)
            provider=DirectWeapons.sole_source(provider ? Projection.weapon(user,provider) : user,item,index,action) || provider
            user=Projection.weapon(user,provider) if provider && user.equips[0]!=provider
            override=DirectWeapons.resolve(user,action.instance_variable_get(:@bs2s_macro_executor))
            final=override || (index==final_index ? @weapon : nil)
            final=DirectWeapons.eligible_final(user,item,final,index,action) if final
            user=Projection.weapon(user,final) if final && user.equips[0]!=final
            branch[:user]=user
            step[:weapons] ||= [];step[:weapons]<<user.equips[0] unless step[:weapons].include?(user.equips[0]);step[:weapon]=step[:weapons][0]
            raise BS2QoL::Forecast::Unsupported,'Действие недоступно: КД, состояние, цена или ограничение' unless user.usable?(item)
            hp=mp=tp=gold=0;consumed=nil
            if item.is_a?(RPG::Skill)
              hp=user.skill_hp_cost(item);mp=user.skill_mp_cost(item);tp=user.skill_tp_cost(item);gold=item.gold_cost
              gold+=[branch[:gold]*item.gold_cost_rate/100,1].max if item.gold_cost_rate>0
              consumed=$data_items[item.item_cost]
            elsif item.consumable;consumed=item;end
            if hp>=user.hp || mp>user.mp || tp>user.tp || gold>branch[:gold] || (consumed && branch[:stock].fetch(consumed.id,0)<=0)
              raise BS2QoL::Forecast::Unsupported,'Не хватает ресурсов после предыдущих действий'
            end
            costs<<[hp,mp,tp,gold]
            sample=BS2QoL::Forecast::Prediction.new(user,ids[0]==:self ? user : branch[:targets][ids[0]],item)
            raise BS2QoL::Forecast::Unsupported,sample.error if sample.error
            repeats=sample.repeats
            raise BranchLimit if repeats>32
            user.instance_variable_set(:@hp,user.hp-hp);user.instance_variable_set(:@mp,user.mp-mp);user.instance_variable_set(:@tp,user.tp-tp)
            branch[:gold]-=gold;branch[:stock][consumed.id]-=1 if consumed
            user.cool_time[item.id]=item.cool_time if item.is_a?(RPG::Skill) && item.cool_time
            damage=Hash[ids.map { |id| [id,{:min=>0,:max=>0,:mean=>0.0}] }]
            work=[branch.merge(:damage=>damage)]
            # Native random draws choose a target before its item.repeats hits.
            selections=item.for_random? ? Array.new(item.number_of_targets) { nil } : ids
            selections.each do |fixed|
              outcomes=[]
              work.each do |b|
                options=fixed ? [[fixed,1.0]] : ids.map { |id| [id,b[:targets][id].tgr] }
                total=options.inject(0.0) { |n,p| n+p[1] };raise BranchLimit if total<=0
                options.each do |id,weight|
                  next if weight<=0
                  hits=[forecast_weighted(b,weight/total)]
                  repeats.times do
                    hits=forecast_hit(hits,id,item,step)
                    hits=forecast_merge(hits)
                  end
                  outcomes+=hits
                end
              end
              work=forecast_merge(outcomes)
            end
            if provider && plan && !action.instance_variable_get(:@bs2s_macro_source) && !final && restore
              work.each { |b| b[:user]=Projection.weapon(b[:user],restore) }
            end
            next_branches+=work
          end
          next_branches=forecast_merge(next_branches)
        rescue BranchLimit
          failed='Более 64 вероятностных исходов; результат скрыт'
        rescue BS2QoL::Forecast::Unsupported=>e
          failed=e.message
        end
        if failed
          step[:reason]=failed;stopped=true;@complete=false;next
        end
        step[:cost]=(0..3).map { |n| [costs.map { |c| c[n] }.min,costs.map { |c| c[n] }.max] }
        ids.each do |id|
          values=next_branches.map { |b| b[:damage][id] || {:min=>0,:max=>0,:mean=>0.0} }
          next unless next_branches.any? { |b| b[:damage].has_key?(id) }
          target=id==:self ? actor : targets.find { |t| t.index==id }
          step[:rows]<<{:target_index=>id,:name=>target.name,:resource=>item.damage.to_hp? ? 'HP' : 'MP',:min=>values.map { |v| v[:min] }.min,:max=>values.map { |v| v[:max] }.max,:mean=>next_branches.each_with_index.inject(0.0) { |n,(b,i)| n+b[:weight]*values[i][:mean] }}
        end
        branches=next_branches
        if special?(item) && !(item.for_user? && item.damage.to_hp? && item.damage.type==1 && !unsupported_note?(item) && item.effects.all? { |e| [11,12,13,21,22,31,32,33,34].include?(e.code) && !(e.code==21 && e.data_id==1) })
          stopped=true;@complete=false;@limitations<<item.name+': особые события после действия'
        end
        if step[:partial];stopped=true;@complete=false;@limitations<<item.name+': подтверждено только первое попадание';end
        prior_damage=true if item.damage.type!=0
      end
      if @complete
        @steps.each { |s| s[:rows].each { |r| t=@totals[[r[:name],r[:resource]]] ||= {:min=>0,:max=>0,:mean=>0.0};[:min,:max,:mean].each { |k| t[k]+=r[k] } } }
      end
    rescue StandardError=>e
      @complete=false;@limitations<<'Неподдерживаемый расчёт: '+e.class.to_s
    end
    def unsupported_note?(item)
      !!(item.note =~ /使用後追加行動|行動後遅延発動|使用者効果|ステート変化|変換攻撃|付与時/)
    end
    def forecast_copy(b)
      c=copy_branch(b);c[:damage]={};(b[:damage] || {}).each { |id,v| c[:damage][id]=v.dup };c
    end
    def forecast_weighted(b,p);c=forecast_copy(b);c[:weight]*=p;c;end
    def forecast_merge(branches)
      merged={}
      branches.each do |b|
        units=[b[:user]]+b[:targets].keys.sort.map { |id| b[:targets][id] }
        key=[units.map { |u| [u.hp,u.mp,u.tp,u.instance_variable_get(:@states).sort,u.instance_variable_get(:@buffs),u.actor? ? u.equips.map { |e| e && e.id } : nil,u.actor? ? u.cool_time.to_a.sort : nil] },b[:stock].to_a.sort,b[:gold]]
        old=merged[key]
        if old
          weight=old[:weight]+b[:weight]
          (old[:damage].keys | b[:damage].keys).each do |id|
            a=old[:damage][id] || {:min=>0,:max=>0,:mean=>0.0};c=b[:damage][id] || {:min=>0,:max=>0,:mean=>0.0}
            old[:damage][id]={:min=>[a[:min],c[:min]].min,:max=>[a[:max],c[:max]].max,:mean=>(a[:mean]*old[:weight]+c[:mean]*b[:weight])/weight}
          end
          old[:weight]=weight
        else;merged[key]=b;end
        raise BranchLimit if merged.size>MAX_BRANCHES
      end
      merged.values
    end
    def forecast_hit(branches,id,item,step)
      outcomes=[]
      branches.each do |b|
        user=b[:user];target=id==:self ? user : b[:targets][id]
        p=BS2QoL::Forecast::Prediction.new(user,target,item,true)
        raise BS2QoL::Forecast::Unsupported,p.error if p.error
        raise BS2QoL::Forecast::Unsupported,'Прикрытие требует отдельного перехода' unless p.target.source.equal?(target)
        if p.repeats>1 && (item.damage.formula =~ /b\.(?:hp|mp|hp_rate|mp_rate)\b/ || (id==:self && item.damage.formula =~ /a\.(?:hp|mp|hp_rate|mp_rate)\b/) || target.state?(Nana::STATE_KONJO))
          raise BS2QoL::Forecast::Unsupported,'Повторы зависят от урона предыдущего попадания'
        end
        miss=forecast_weighted(b,1-p.chance) if p.chance<1
        outcomes<<miss if miss && miss[:weight]>0
        next if p.chance<=0
        hit=forecast_weighted(b,p.chance)
        formula=p.rows.find { |r| r[:formula] }
        if formula
          normal=formula[:normal][:raw];crit=formula[:critical][:raw]
          lo=p.crit_chance==1 ? crit[0] : [normal[0],crit[0]].min
          hi=p.crit_chance>0 ? [normal[1],crit[1]].max : normal[1]
          damage=hit[:damage][id] ||= {:min=>0,:max=>0,:mean=>0.0}
          damage[:min]+=lo;damage[:max]+=hi;damage[:mean]+=p.expected_formula/p.chance
          if id==:self && item.damage.to_hp? && hi>0
            raise BS2QoL::Forecast::Unsupported,'Возможна смерть от собственного урона' if hi>=hit[:user].hp
            hit[:user].instance_variable_set(:@hp,hit[:user].hp-hi)
          end
          # A damage-dependent state removal happens before the item's effects.
          # Supported only for guaranteed positive HP damage; mixed zero/damage
          # and reflection/counters cannot safely propagate as one transition.
          if item.damage.to_hp? && hi>0
            if lo<=0 && target.states.any? { |s| s.remove_by_damage && s.chance_by_damage>0 }
              raise BS2QoL::Forecast::Unsupported,'Снятие состояния зависит от величины попадания'
            end
          end
        end
        effects=[hit]
        if formula && item.damage.to_hp? && formula[:normal][:raw][0]>0
          target.states.select { |s| s.remove_by_damage && s.chance_by_damage>0 }.each do |state|
            effects=forecast_effect(effects,id,RPG::UsableItem::Effect.new(22,state.id,state.chance_by_damage/100.0,0),p,item)
          end
        end
        item.effects.each { |e| effects=forecast_effect(effects,id,e,p,item) if [11,12,13,21,22,31,32,33,34].include?(e.code) }
        effects.each do |c|
          u=c[:user];u.instance_variable_set(:@tp,[[u.tp+item.tp_gain*u.tcr,0].max,u.max_tp].min) if item.tp_gain>0
        end
        outcomes+=effects
      end
      forecast_merge(outcomes)
    end
    # Reuse the reviewed state/buff probability rules while preserving the local
    # per-target damage accumulators through their weighted copies.
    def weighted(branch,p);forecast_weighted(branch,p);end
    def forecast_effect(branches,id,effect,prediction,item)
      forecast_merge(apply_effect(branches,id,effect,prediction,item))
    end
  end
end
