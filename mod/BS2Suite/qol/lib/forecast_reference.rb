# encoding: UTF-8
module BS2QoL
  class ReferenceCard
    alias bs2q_before_forecast_initialize initialize
    def initialize(object,actor=nil,language=:ru)
      bs2q_before_forecast_initialize(object,actor,language)
      @sections.insert(2,forecast_lines)
    end
    def section_names
      t(['Обзор','Эффекты','Прогноз','Формула','Правила'],['Overview','Effects','Forecast','Formula','Rules'])
    end
    def forecast_name(target)
      name=target.name
      if language==:en && target.enemy?
        record=ReferenceData::EN[:enemy] && ReferenceData::EN[:enemy][target.enemy_id]
        name=record[0]+(target.instance_variable_get(:@plural) ? target.instance_variable_get(:@letter).to_s : '') if record
      end
      name+(target.enemy? ? ' #'+(target.index+1).to_s : '')
    end
    def forecast_range(range)
      range[0]==range[1] ? n(range[0]) : n(range[0])+'..'+n(range[1])
    end
    def forecast_amount(resource,range)
      if range[0]>=0
        t('Урон ','Damage to ')+resource+': '+forecast_range(range)
      elsif range[1]<=0
        t('Лечение ','Recover ')+resource+': '+forecast_range([-range[1],-range[0]])
      else
        t('Изменение ','Change to ')+resource+': '+forecast_range([-range[1],-range[0]])
      end
    end
    def forecast_targets
      x=@resolved
      return [] unless actor
      return $game_troop.alive_members if x.for_opponent? && $game_party.in_battle
      return [actor] if x.for_user?
      return actor.friends_unit.dead_members if x.for_dead_friend?
      return actor.friends_unit.alive_members if x.for_friend?
      []
    end
    def forecast_lines
      lines=[];x=@resolved
      unless actor
        return [t('Прогноз использует действующего персонажа и конкретную цель. В игре откройте F7 во время боя: здесь появятся числа для каждого врага.','Forecast needs an actual user and target. Open F7 in battle to see numbers for each enemy.')]
      end
      allowed=actor.movable? && actor.occasion_ok?(x)
      if x.is_a?(RPG::Skill)
        allowed&&=actor.skill_cost_payable?(@object) && actor.skill_cost_payable?(x) && read_cooldown(@object)==0 && read_cooldown(x)==0
        allowed&&=actor.skill_wtype_ok?(x) && !actor.skill_sealed?(x.id) && !actor.skill_type_sealed?(x.stype_id)
        allowed&&=actor.skills.include?(@object)
        allowed=false if x.note.include?('<アイテム扱い>') && actor.item_command_seal?
      else
        allowed&&=$game_party.item_number(x)>0 && (!$game_party.in_battle || !actor.item_command_seal?)
      end
      quick=quick_info(x);allowed=false if quick && quick[1]>=quick[0]
      unless allowed
        return [t('Сейчас приём недоступен. Причина указана в обзоре; формула и эффекты доступны отдельно. Цена, которой не хватает, не вычитается ради мнимого прогноза.','This action is currently unavailable. See overview for restrictions, and the other tabs for formula and effects. Unaffordable costs are not deducted to produce a hypothetical forecast.')]
      end
      targets=forecast_targets
      if targets.empty?
        return [t('Для численного прогноза нужна текущая цель. В бою здесь показывается каждый живой противник отдельно.','A numerical forecast needs a current target. In battle each living enemy is shown separately.')]
      end
      lines << t('Расчёт на сейчас, после списания цены. Другие действия ещё не учтены.','Calculated for the current situation, after paying the cost. Intervening actions are not included.')
      lines << t('Диапазон учитывает разброс. Обычный урон и крит показаны отдельно; промах, отмена или отражение могут дать 0 по выбранной цели.','Ranges include variance. Normal hits and criticals are separate; misses, cancellation or reflection can cause 0 to the selected target.')
      lines << t('Случайные цели: ','Random targets: ')+x.number_of_targets.to_s+t(' броска; враг может выбираться повторно.',' rolls; the same enemy can be selected again.') if x.for_random?
      targets.each do |target|
        lines << '— '+forecast_name(target)+' —'
        prediction=Forecast::Prediction.new(actor,target,x)
        if prediction.error
          lines << t('Численный прогноз недоступен: неподдерживаемое выражение или правило. См. формулу и эффекты.','Numerical forecast unavailable: unsupported expression or rule. See formula and effects.')
          next
        end
        actual=prediction.target.source
        lines << t('Прикрывает: ','Intercepted by: ')+forecast_name(actual) if actual!=target
        lines << 'HP '+n(prediction.target.values['hp'])+'/'+n(prediction.target.values['mhp'])+' | MP '+n(prediction.target.values['mp'])+'/'+n(prediction.target.values['mmp'])
        lines << t('Шанс подействовать: ','Chance to affect target: ')+pct(prediction.chance)+t('; крит при попадании: ','; critical on a hit: ')+pct(prediction.crit_chance)+'.'
        if prediction.counter>0 || prediction.reflection>0 || prediction.cancel>0
          lines << t('Контратака ','Counter ')+pct(prediction.counter)+'; '+t('отражение ','reflect ')+pct(prediction.reflection)+'; '+t('отмена навыка ','skill cancellation ')+pct(prediction.cancel)+'.'
          lines << t('Контратака/отражение проверяются до прикрытия, отмена — на получателе.','Counter/reflection checked before interception; cancellation checked on the recipient.')
        end
        if x.for_random?
          sum=targets.inject(0.0) { |r,enemy| r+enemy.tgr }
          lines << t('Шанс выбора на один бросок: ','Selection chance per roll: ')+pct(sum==0 ? 0 : target.tgr/sum)+'.'
        end
        if prediction.rows.empty?
          lines << t('Прямого урона/лечения HP или MP нет. Эффекты и события смотрите в соседнем разделе.','No direct HP/MP damage or recovery. See effects and events in the other section.')
        end
        prediction.rows.each do |row|
          prefix=row[:formula] ? t('Первое попадание. ','First hit. ') : t('Эффект восстановления. ','Recovery effect. ')
          data=row[:normal]
          # A damage-removable max-resource modifier can change the actual cap
          # during on_damage. Keep the raw amount and explicitly qualify the loss.
          loss=prediction.mutable_hp_cap? && row[:formula] ? data[:raw] : data[:loss]
          loss=[0,0] if prediction.chance==0
          lines << prefix+forecast_amount(row[:resource],loss)+'.'
          if row[:formula] && loss!=data[:raw] && prediction.chance>0
            lines << t('До ограничения текущими HP/MP: ','Before current HP/MP cap: ')+forecast_range(data[:raw])+'.'
          end
          if row[:formula] && prediction.crit_chance>0 && prediction.chance>0
            critical=prediction.mutable_hp_cap? ? row[:critical][:raw] : row[:critical][:loss]
            lines << t('При крите. ','On a critical. ')+forecast_amount(row[:resource],critical)+'.'
            if critical!=row[:critical][:raw]
              lines << t('Крит до ограничения HP/MP: ','Critical before HP/MP cap: ')+forecast_range(row[:critical][:raw])+'.'
            end
          end
          if row[:conditional]
            lines << t('Отдельный компонент по текущим характеристикам; предыдущие эффекты могут изменить лечение. Не складывайте его с предыдущим уроном как готовый итог.','Separate component at current stats; earlier effects can change recovery. Do not add it to previous damage as a finished total.')
          end
          if prediction.repeats>1 && prediction.stable && prediction.rows.size==1
            raw=data[:raw].map { |amount| amount*prediction.repeats }
            total=prediction.range(raw,row[:resource])[:loss]
            total=[0,0] if prediction.chance==0
            lines << t('Все ','All ')+prediction.repeats.to_s+t(' попаданий, без критов. ',' hits, no criticals. ')+forecast_amount(row[:resource],total)+'.'
            lines << t('Это условие «все попали». С промахами нижняя граница может стать 0.','This assumes every hit lands. Misses can reduce the lower bound to 0.')
          end
        end
        lines << t('Повторов: ','Repeats: ')+prediction.repeats.to_s+t('. Последующие попадания могут менять HP, состояния и множители; здесь точный расчёт первого попадания.','. Later hits may change resources, states and multipliers; the first-hit calculation is shown here.') if prediction.repeats>1 && !prediction.stable
        lines << t('Снятие состояния при уроне может изменить максимум HP/MP; фактическая потеря ресурса условна.','A state removed on damage can change maximum HP/MP; actual resource loss is conditional.') if prediction.mutable_hp_cap?
        unless x.damage.none?
          lines << t('Элемент ×','Element x')+n(prediction.element)+t('; категория урона ×','; damage type x')+n(prediction.rate)+t('; Guard: ','; Guard: ')+(prediction.target.guard? ? '÷ '+n(2*prediction.target.values['grd'])+t(', обход ',', bypass ')+pct(prediction.bypass) : t('нет','none'))+'.'
        end
        prediction.state_chances.each do |id,chance|
          lines << t('Состояние ','State ')+tagged($data_states[id])+': '+pct(chance)+t(' после попадания, если цель жива и эффект допустим.',' after a hit, if the target survives and the effect is valid.')
        end
      end
      lines << t('Дополнительные/отложенные действия, периодический урон, контратаки, сюжетные события и изменения между попаданиями не прибавляются к этому числу.','Follow-up/delayed actions, damage over time, counterattacks, story events and changes between hits are not added to this number.')
      lines
    end
  end
end
