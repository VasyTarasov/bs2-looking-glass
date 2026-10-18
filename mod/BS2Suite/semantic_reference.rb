# encoding: UTF-8
module BS2Suite
  module Knowledge
    class << self
      def counts
        return @counts if @counts
        @counts={}
        Store.read('encounters',131072).each_line do |line|
          m=/\A([0-9]{1,5})=([0-9]{1,6})\z/.match(line.strip)
          @counts[m[1].to_i]=m[2].to_i if m
        end
        @counts
      end
      def begin_attempt;@shown={};end
      def present
        @shown ||= {};changed=false
        $game_troop.members.each do |enemy|
          next if enemy.hidden? || @shown[enemy.enemy_id]
          @shown[enemy.enemy_id]=true
          counts[enemy.enemy_id]=[counts.fetch(enemy.enemy_id,0)+1,999999].min
          changed=true
        end
        Store.write('encounters',counts.keys.sort.map { |id| id.to_s+'='+counts[id].to_s }.join("\n")+"\n") if changed
      end
      def allowed?(enemy)
        return true unless enemy && enemy.enemy?
        threshold=Options.get('knowledge_threshold')
        threshold==0 || counts.fetch(enemy.enemy_id,0)>=threshold
      end
    end
  end

  # Finite probability branches for ordinary feature states and buff/debuff
  # effects. Complex events stop propagation instead of fabricating a total.
  class SequenceForecast
    attr_reader :steps,:totals,:complete,:weapon,:limitations
    MAX_BRANCHES=64
    class BranchLimit < StandardError;end
    def initialize(actor,weapon=nil)
      @actor=actor;@weapon=weapon || DirectWeapons.selected(actor);@steps=[];@totals={};@complete=true;@limitations=[]
      targets=$game_troop.alive_members
      stock=Hash[$game_party.items.map { |item| [item.id,$game_party.item_number(item)] }]
      branches=[{:user=>Projection.copy(actor),:targets=>Hash[targets.map { |t| [t.index,Projection.copy(t)] }],:weight=>1.0,:stock=>stock,:gold=>$game_party.gold}]
      actions=actor.actions
      final_index=actor.instance_variable_get(:@bs2s_forecast_final_index) || actions.size-1
      stopped=false;prior_damage=false
      actions.each_with_index do |action,index|
        item=action && action.item
        unless item
          @steps<<{:index=>index,:item=>nil,:rows=>[],:cost=>nil};@complete=false;stopped=true;next
        end
        support_plan=action.instance_variable_get(:@bs2s_support_plan)
        provider=action.instance_variable_get(:@bs2s_macro_source) || (support_plan && support_plan[:source])
        provider=nil unless provider.is_a?(RPG::Weapon)
        source_view=provider ? Projection.weapon(actor,provider) : actor
        protected_source=DirectWeapons.sole_source(source_view,item,index,action)
        provider=protected_source || provider
        preview_user=provider ? Projection.weapon(actor,provider) : actor
        final_swap=index==final_index ? DirectWeapons.eligible_final(preview_user,item,@weapon,index,action) : nil
        step={:index=>index,:item=>item,:rows=>[],:cost=>nil,:weapon=>final_swap || provider || actor.equips[0]}
        @steps<<step
        if stopped
          step[:reason]='Предыдущий слот не позволяет подтвердить продолжение';next
        end
        ids=if item.for_user? || (item.for_friend? && !item.for_dead_friend? && (item.for_all? || action.target_index==actor.index));[:self]
        elsif item.for_opponent? && !item.for_random?
          item.for_all? ? targets.map { |t| t.index } : [targets.find { |t| t.index==action.target_index } && action.target_index]
        else;[];end
        if ids.empty? || ids.include?(nil)
          step[:reason]='Нужна выбранная цель; случайные цели и союзники — в карточке приёма'
          stopped=true;@complete=false;next
        end
        if ids.any? { |id| id!=:self && !Knowledge.allowed?(targets.find { |t| t.index==id }) }
          step[:reason]='Сведения о противнике ещё закрыты';stopped=true;@complete=false;next
        end
        if prior_damage && item.damage.formula.to_s =~ /[ab]\.(?:hp|mp|hp_rate|mp_rate)\b/
          step[:reason]='Формула зависит от ресурсов после предыдущего урона; численный итог не подтверждён'
          stopped=true;@complete=false;next
        end
        costs=[];predictions={};next_branches=[];failed=false
        branches.each do |branch|
          user=branch[:user]
          restore_weapon=user.equips[0]
          user=Projection.weapon(user,provider) if provider && user.equips[0]!=provider
          final_swap=index==final_index ? DirectWeapons.eligible_final(user,item,@weapon,index,action) : nil
          user=Projection.weapon(user,final_swap) if final_swap && user.equips[0]!=final_swap
          actual_weapon=user.equips[0]
          step[:weapons] ||= []
          step[:weapons]<<actual_weapon unless step[:weapons].include?(actual_weapon)
          step[:weapon]=step[:weapons][0]
          branch=branch.merge(:user=>user)
          unless user.usable?(item)
            failed=true;step[:reason]='Действие недоступно в одной из ветвей: КД, состояние, цена или ограничение';break
          end
          hp=mp=tp=gold=0;consumed=nil
          if item.is_a?(RPG::Skill)
            hp=user.skill_hp_cost(item);mp=user.skill_mp_cost(item);tp=user.skill_tp_cost(item)
            gold=item.gold_cost
            gold+=[branch[:gold]*item.gold_cost_rate/100,1].max if item.gold_cost_rate>0
            consumed=$data_items[item.item_cost]
          elsif item.consumable
            consumed=item
          end
          if hp>=user.hp || mp>user.mp || tp>user.tp || gold>branch[:gold] || (consumed && branch[:stock].fetch(consumed.id,0)<=0)
            failed=true;step[:reason]='Не хватает ресурсов после предыдущих действий';break
          end
          costs<<[hp,mp,tp,gold]
          # Prediction pays costs in its own Snapshot. Effects use the paid copy.
          local_predictions={}
          ids.each do |id|
            target=id==:self ? user : branch[:targets][id]
            prediction=BS2QoL::Forecast::Prediction.new(user,target,item)
            if prediction.error;failed=true;next;end
            unless prediction.target.source.equal?(target)
              failed=true;step[:reason]='Прикрытие цели требует отдельного перехода';next
            end
            local_predictions[id]=prediction
            formula=prediction.rows.find { |r| r[:formula] }
            next unless formula
            n=prediction.repeats
            if n>1 && !prediction.stable
              step[:partial]=true;n=1
            end
            normal=formula[:normal][:raw];critical=formula[:critical][:raw]
            chance=prediction.chance;crit=prediction.crit_chance
            low=chance<1 ? 0 : (crit==1 ? critical[0] : normal[0])
            high=chance<=0 ? 0 : (crit>0 ? [normal[1],critical[1]].max : normal[1])
            mean=prediction.respond_to?(:expected_formula) ? prediction.expected_formula*n : chance*((1-crit)*(normal[0]+normal[1])/2.0+crit*(critical[0]+critical[1])/2.0)*n
            result=predictions[id] ||= {:min=>nil,:max=>nil,:mean=>0.0,:chance=>0.0,:target_index=>id,:name=>target.name,:resource=>formula[:resource]}
            lo=low*n;hi=high*n
            result[:min]=lo if result[:min].nil? || lo<result[:min]
            result[:max]=hi if result[:max].nil? || hi>result[:max]
            result[:mean]+=branch[:weight]*mean;result[:chance]+=branch[:weight]*chance
          end
          paid=copy_branch(branch)
          paid[:user].instance_variable_set(:@hp,[user.hp-hp,0].max)
          paid[:user].instance_variable_set(:@mp,[user.mp-mp,0].max)
          paid[:user].instance_variable_set(:@tp,[user.tp-tp,0].max)
          paid[:gold]-=gold
          paid[:stock][consumed.id]-=1 if consumed
          paid[:user].cool_time[item.id]=item.cool_time if item.is_a?(RPG::Skill) && item.cool_time
          effects=[paid]
          begin
          ids.each do |id|
            prediction=local_predictions[id];next unless prediction
            if item.tp_gain>0 && prediction.repeats>1 && prediction.stable && item.effects.empty?
              n=prediction.repeats;raise BranchLimit if n>=MAX_BRANCHES
              outcomes=[];p=prediction.chance
              effects.each do |b|
                combination=1.0
                (0..n).each do |hits|
                  weight=combination*(p**hits)*((1-p)**(n-hits))
                  if weight>0
                    c=weighted(b,weight);u=c[:user]
                    u.instance_variable_set(:@tp,[[u.tp+hits*item.tp_gain*u.tcr,0].max,u.max_tp].min)
                    outcomes<<c
                  end
                  combination=combination*(n-hits)/(hits+1)
                end
              end
              effects=outcomes;raise BranchLimit if effects.size>MAX_BRANCHES
              next
            end
            # A common hit/miss branch keeps the effects of the same hit correlated.
            hit=[];miss=[]
            effects.each do |b|
              miss<<weighted(b,1-prediction.chance) if prediction.chance<1
              hit<<weighted(b,prediction.chance) if prediction.chance>0
            end
            item.effects.each do |effect|
              if [11,12,13,21,22,31,32,33,34].include?(effect.code)
                hit=apply_effect(hit,id,effect,prediction,item)
                raise BranchLimit if hit.size+miss.size>MAX_BRANCHES
              end
            end
            # Native user TP gain happens after a successful hit's effects.
            # Variable repeated hits already stop propagation below.
            if item.tp_gain>0
              hit.each do |b|
                u=b[:user];gain=item.tp_gain*u.tcr
                u.instance_variable_set(:@tp,[[u.tp+gain,0].max,u.max_tp].min)
              end
            end
            effects=hit+miss
            if effects.size>MAX_BRANCHES
              failed=true;break
            end
          end
          if provider && !final_swap && restore_weapon
            effects=effects.map { |b| b.merge(:user=>Projection.weapon(b[:user],restore_weapon)) }
          end
          next_branches+=effects
          raise BranchLimit if next_branches.size>MAX_BRANCHES
          rescue BranchLimit
            failed=true;step[:reason]='Более 64 вероятностных исходов: численный результат скрыт';break
          end
        end
        if costs.any?
          step[:cost]=(0..3).map { |n| [costs.map { |c| c[n] }.min,costs.map { |c| c[n] }.max] }
        end
        step[:rows]=predictions.values
        step[:effects]=item.effects.select { |e| [21,32].include?(e.code) }.map { |e| e.code==21 ? 'состояние' : 'ослабление' }.uniq
        if failed || next_branches.size>MAX_BRANCHES
          step[:reason] ||= 'Есть недоступная ветвь или неподдерживаемое выражение'
          step[:rows]=[];step[:cost]=nil
          stopped=true;@complete=false
        else
          branches=next_branches
        end
        if special?(item) || step[:partial]
          @limitations<<item.name+': события, изменяющаяся серия или особые правила'
          stopped=true;@complete=false
        end
        if item.damage.to_hp? && item.damage.type!=0
          prior_damage=true
          if ids.any? { |id| id!=:self && branches.any? { |b| b[:targets][id].states.any? { |s| s.remove_by_damage && s.chance_by_damage>0 } } }
            stopped=true;@complete=false;@limitations<<'Снятие состояний при уроне меняет следующие действия'
          end
        end
      end
      if @complete
        @steps.each do |step|
          step[:rows].each do |row|
            key=[row[:name],row[:resource]]
            total=@totals[key] ||= {:min=>0,:max=>0,:mean=>0.0}
            %w(min max mean).each { |name| total[name.to_sym]+=row[name.to_sym] }
          end
        end
      end
    rescue StandardError=>error
      @complete=false;@limitations<<'Неподдерживаемый расчёт: '+error.class.to_s
    end
    def copy_branch(branch)
      {:user=>Projection.copy(branch[:user]),:targets=>Hash[branch[:targets].map { |k,v| [k,Projection.copy(v)] }],:weight=>branch[:weight],:stock=>branch[:stock].dup,:gold=>branch[:gold]}
    end
    def weighted(branch,p)
      copy=copy_branch(branch);copy[:weight]*=p;copy
    end
    def change_target(branch,id)
      target=id==:self ? branch[:user] : branch[:targets][id]
      yield target
      target.instance_variable_set(:@hp,[[target.hp,0].max,target.mhp].min)
      target.instance_variable_set(:@mp,[[target.mp,0].max,target.mmp].min)
    end
    def apply_effect(branches,id,effect,prediction,item)
      if [11,12,13].include?(effect.code)
        branches.each do |branch|
          change_target(branch,id) do |target|
            if effect.code==13
              target.instance_variable_set(:@tp,[[target.tp+effect.value1.to_i,0].max,target.max_tp].min)
            else
              resource=effect.code==11 ? :@hp : :@mp
              maximum=effect.code==11 ? target.mhp : target.mmp
              amount=(maximum*effect.value1+effect.value2)*target.rec
              amount*=prediction.user.source.pha if item.is_a?(RPG::Item)
              target.instance_variable_set(resource,target.instance_variable_get(resource)+amount.to_i)
            end
          end
        end
        return branches
      end
      if effect.code==21
        ids=effect.data_id==0 ? prediction.user.source.atk_states : [effect.data_id]
        ids.each do |state_id|
          next if state_id==1 # Instant death needs a survival/retarget adapter.
          chance=effect.value1
          ignored=item.note.include?('<強制付与>')
          chance*=prediction.user.source.atk_states_rate(state_id) if effect.data_id==0
          if effect.data_id==0 || prediction.user.actor?!=prediction.target.actor?
            chance*=prediction.target.state_rate(state_id) unless ignored || item.note.include?('<有効度無視ステート付与>')
            chance*=[1+(prediction.user.values['luk']-prediction.target.values['luk'])*0.001,0].max unless ignored || item.note.include?('<運無視ステート付与>')
          end
          chance=0 if prediction.target.immune_state?(state_id)
          branches=split(branches,chance) do |b|
            change_target(b,id) do |target|
              states=target.instance_variable_get(:@states)
              states<<state_id unless states.include?(state_id)
            end
          end
        end
        return branches
      end
      if effect.code==32
        ignored=item.note.include?('<強制付与>')
        rate=ignored || item.note.include?('<有効度無視弱体付与>') ? 1.0 : prediction.target.debuff_rate(effect.data_id)
        luck=ignored || item.note.include?('<運無視弱体付与>') ? 1.0 : [1+(prediction.user.values['luk']-prediction.target.values['luk'])*0.001,0].max
        chance=rate*luck
      elsif effect.code==22;chance=effect.value1
      else;chance=1.0;end
      split(branches,chance) do |b|
        change_target(b,id) do |target|
          buffs=target.instance_variable_get(:@buffs)
          case effect.code
          when 22;target.instance_variable_set(:@states,target.instance_variable_get(:@states).reject { |sid| sid==effect.data_id })
          when 31;buffs[effect.data_id]=[buffs[effect.data_id]+1,2].min
          when 32;buffs[effect.data_id]=[buffs[effect.data_id]-1,-2].max
          when 33;buffs[effect.data_id]=0 if buffs[effect.data_id]>0
          when 34;buffs[effect.data_id]=0 if buffs[effect.data_id]<0
          end
        end
      end
    end
    def split(branches,chance)
      chance=[[chance.to_f,0.0].max,1.0].min
      result=[]
      branches.each do |branch|
        if chance<1;result<<weighted(branch,1-chance);end
        if chance>0
          changed=weighted(branch,chance);yield changed;result<<changed
        end
        raise BranchLimit if result.size>MAX_BRANCHES
      end
      result
    end
    def special?(item)
      return true if item.tp_gain>0 && item.repeats>1 && !item.effects.empty?
      return true if item.damage.recover? || item.damage.drain?
      return true if item.for_user? && item.damage.to_hp? && item.damage.type!=0
      return true if item.effects.any? { |e| [41,42,43,44].include?(e.code) || (e.code==21 && e.data_id==1) }
      !!(item.note =~ /使用後追加行動|行動後遅延発動|使用者効果|ステート変化|変換攻撃|付与時/)
    end
  end

  if BS2Suite.enabled?('reference_cards')
  class SequenceCard < BS2QoL::ReferenceCard
    attr_reader :section_names
    def initialize(actor,language=:ru)
      @actor=actor;@language=language;@sections=[];@section_names=[]
      @object=RPG::Skill.new;@object.name='Связка и исполняющее оружие'
      report=SequenceForecast.new(actor)
      lines=['N действует перед последним выбранным действием. Ранее выбранные ID сохраняются.',
             'Диапазоны до ограничения HP цели; ~ средняя оценка с шансами попадания и крита.']
      selected=DirectWeapons.selected(actor)
      lines<<'Назначенный исполнитель: '+(selected ? selected.name : 'текущее оружие')
      lines<<'Единственная оружейная техника остаётся на своём источнике.' if actor.actions.size==1 && actor.actions[0].item && DirectWeapons.sole_source(actor,actor.actions[0].item,0,actor.actions[0])
      lines<<'Назначенное N оружие отсутствует; автоматическая подмена другим семейством отключена.' if DirectWeapons.selected_id(actor) && !selected
      report.steps.each do |step|
        unless step[:item];lines<<(step[:index]+1).to_s+'. Свободный слот';next;end
        platforms=step[:weapons] || [step[:weapon]]
        label=platforms.map { |w| w ? w.name : 'без оружия' }.uniq.join(' / ')
        label+=' (зависит от предыдущих эффектов)' if platforms.size>1
        lines<<(step[:index]+1).to_s+'. '+step[:item].name+' · '+label
        if step[:cost]
          parts=step[:cost].each_with_index.map { |v,i| v[1]>0 ? interval(v)+' '+%w(HP MP TP души)[i] : nil }.compact
          lines<<'Цена: '+(parts.empty? ? 'без HP/MP/TP/душ' : parts.join(', '))
        end
        step[:rows].each { |r| lines<<r[:name]+': '+interval([r[:min],r[:max]])+' '+r[:resource]+' · ~'+n(r[:mean])+' · попадание '+pct(r[:chance])+(step[:partial] ? ' · только первое попадание' : '') }
        lines<<step[:reason] if step[:reason]
      end
      if report.complete
        report.totals.each { |key,v| lines<<'Сумма · '+key[0]+': '+interval([v[:min],v[:max]])+' '+key[1]+' · ~'+n(v[:mean]) }
      else
        lines<<'Полный численный итог не подтверждён; неподдерживаемые переходы не подменяются текущими статами.'
      end
      add_section('Связка',lines)
      comparison=['Сравнение по текущему состоянию и выбранной очереди; победитель не выбирается.']
      candidates=([actor.equips[0],selected]+DirectWeapons.final_entries(actor).take(3).map { |r| DirectWeapons.resolve(actor,r['id']) }).compact.uniq.take(3)
      candidates.each do |weapon|
        view=Projection.weapon(actor,weapon)
        comparison<<weapon.name+': ATK '+view.atk.to_s+' · MAT '+view.mat.to_s+' · AGI '+view.agi.to_s
        other=SequenceForecast.new(actor,weapon)
        if other.complete && !other.totals.empty?
          other.totals.each { |key,v| comparison<<key[0]+': '+interval([v[:min],v[:max]])+' '+key[1]+' · ~'+n(v[:mean]) }
        else
          comparison<<'Сумма серии условна; отдельные свойства и цена — в карточке оружия/приёма.'
        end
        last=actor.actions.last
        if last && last.item && last.instance_variable_get(:@bs2s_normal_attack) && last.item.id!=view.attack_skill_id
          comparison<<'Выбранный ID '+last.item.id.to_s+' сохраняется. Доп. обычные атаки этого оружия могут не примениться.'
        end
      end
      add_section('Оружие N',comparison)
      add_section('Границы',['Учитываются текущие сопротивления и стандартные баффы/дебаффы между действиями в поддерживаемых ветвях.',
        'Не моделируется изменение HP от предыдущего урона, лечение, получение TP за попадания, общие события, дополнительные/отложенные удары и действия врага между слотами.',
        'Если следующая формула зависит от повреждённых HP/MP или особого события, численное продолжение отключается.',
        'Среднее приблизительное: округление, сложные серии и неучтённые вмешательства могут изменить результат.',
        'Неизвестные сведения о враге закрывают численный прогноз. Порог встреч меняется в профилях.',
        'N N снимает активное назначение, но сохраняет коллекции. Esc только закрывает меню.']+report.limitations)
    end
    def title;@object.name;end
    def interval(values);values[0]==values[1] ? n(values[0]) : n(values[0])+'…'+n(values[1]);end
    def add_section(name,lines);@section_names<<name;@sections<<lines;end
  end
  class SequenceWindow < Window_BS2QReference
    def rebuild
      @card=SequenceCard.new(@actor,BS2QoL::Reference.language)
      @section=[@section,@card.sections.size-1].min;@wrapped={};@offset=0;refresh
    end
  end
  module SequenceReference
    def self.open(scene,origin,actor)
      object=RPG::Skill.new;object.name='Связка и исполняющее оружие';object.icon_index=147
      origin.deactivate
      scene.instance_variable_set(:@bs2q_reference_window,SequenceWindow.new(object,actor))
      scene.instance_variable_set(:@bs2q_reference_origin,origin)
      BS2QoL::Keyboard.consume;true
    end
  end
  end
end
if BS2Suite.enabled?('reference_cards')
  class BS2QoL::PracticalCard
    alias bs2082_arsenal_equipment equipment_card
    def equipment_card
      bs2082_arsenal_equipment
      return unless @object.is_a?(RPG::Weapon)
      root=BS2Suite::WeaponFamilies.root(@object.id)
      note=BS2Suite::ArsenalCatalog::NOTES[root]
      lines=[note,
        t('N: цифра — надеть сейчас; D на строке — назначить последним. N N снимает назначение. ID приёма сохраняется.',
          'N: digit equips now; D on a row nominates the final weapon. N N clears it. Selected skill ID stays unchanged.')]
      if root==361
        lines<<t('Дополнительные выстрелы Ганса требуют его выбранной обычной атаки. Чужой ID не превращается в пулемётную серию.',
          'Hans extra shots require his selected normal attack. Equipping the gun does not turn another skill into a burst.')
      elsif root==379
        lines<<t('Дополнительное действие относится к следующему формированию очереди. Уже выбранные слоты не добавляются; расход MP повышен.',
          'Extra actions apply when the next queue is generated. Existing slots are not expanded; MP costs are increased.')
      elsif root==482
        lines<<t('Надевание не превращает формулу другого навыка в урон от HP. Смена максимума HP может ограничить текущие HP.',
          'Equipping does not change another skill into HP-based damage. A maximum-HP change can clamp current HP.')
      end
      add(t('Оружие N','Weapon shelves'),lines)
    end
  end
end

module BattleManager
  class << self
    alias bs2s_knowledge_setup setup
    def setup(*args)
      BS2Suite::Knowledge.begin_attempt
      bs2s_knowledge_setup(*args)
    end
  end
end
class Scene_Battle
  alias bs2s_knowledge_start start
  def start
    bs2s_knowledge_start
    BS2Suite::Knowledge.present
  end
  alias bs2s_modal_battle_update update
  def update
    if @bs2s_palette && !(defined?(BS2QoL::Reference) && BS2QoL::Reference.active?(self))
      Graphics.update;Input.update;@bs2s_palette.update;BS2Suite::Palette.update(self);return
    end
    bs2s_modal_battle_update
    BS2Suite::Knowledge.present
  end
end
if BS2Suite.enabled?('reference_cards')
  class BS2QoL::PracticalCard
    alias bs2s_knowledge_enemy enemy_card
    def enemy_card
      if BS2Suite::Knowledge.allowed?(@object)
        bs2s_knowledge_enemy
      else
        add(t('Сведения','Knowledge'),[name(@object),t('Точные параметры и сопротивления ещё неизвестны. Повторная встреча или настройка профиля откроет их.','Exact stats and resistances are not yet known. Another encounter or the profile setting will reveal them.')])
        values=@object.states.select { |s| s.icon_index>0 }.map { |s| name(s) }
        add(t('Состояния','States'),values.empty? ? [t('Наблюдаемых состояний нет.','No visible states.')] : values)
      end
    end
    alias bs2s_knowledge_forecast forecast_lines
    def forecast_lines
      if $game_party.in_battle && @resolved && @resolved.for_opponent? && $game_troop.alive_members.any? { |enemy| !BS2Suite::Knowledge.allowed?(enemy) }
        return [t('Численный прогноз закрыт: сведения о цели ещё неизвестны. Формула, собственные параметры и цена доступны отдельно.','Numerical forecast hidden: target information is not yet known. Formula, own stats and cost remain available.')]
      end
      bs2s_knowledge_forecast
    end
  end
  class BS2Suite::EnemyInfoList
    def make_command_list
      $game_troop.alive_members.each do |enemy|
        suffix=BS2Suite::Knowledge.allowed?(enemy) ? ' · HP '+enemy.hp.to_s : ' · сведения закрыты'
        add_command(enemy.name+suffix,:enemy,true,enemy)
      end
    end
  end
end
