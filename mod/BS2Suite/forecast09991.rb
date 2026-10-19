# encoding: UTF-8
# This build applies the original hit before a counterattack. Reflection is only
# checked when that counter branch was not selected (native script 173).
class BS2QoL::Forecast::Prediction
  alias bs209991_initialize initialize
  def initialize(user,target,item,paid=false)
    bs209991_initialize(user,target,item,paid)
    return if @error
    @chance=(1.0-(1.0-@counter)*@reflection)*(1.0-@cancel)*hit_chance
    @chance=0 unless @target.source.item_test(user,item)
  rescue StandardError=>e
    @error='unverified calculation: '+e.class.to_s;@rows=[]
  end
  def expected_formula
    raise BS2QoL::Forecast::Unsupported,@error if @error
    return nil unless @rows.any? { |r| r[:formula] }
    normal=weighted_formula(false);critical=@crit_chance>0 ? weighted_formula(true) : normal
    @chance*((1-@crit_chance)*normal+@crit_chance*critical)
  end
  def weighted_formula(critical)
    value=@base*@element
    value*=@rate unless @item.certain?
    value*=@target.values['rec'] if @item.damage.recover?
    value*=Hi_ru_Difficulty::DIFFICULTY_SETTING[11][$game_variables[Hi_ru_Difficulty::VARIABLES]] if critical
    amp=[value.abs*@item.damage.variance/100,0].max.to_i
    # Integer variance is triangular, not uniform. Enumerate small distributions;
    # large linear ranges use their symmetric endpoints (rounding error < 1).
    nonlinear=@target.states.include?(Nana::STATE_KONJO) || @item.damage.to_mp? || (value-amp<0 && value+amp>0)
    raise BS2QoL::Forecast::Unsupported,'Среднее нелинейного урона с большим разбросом не подтверждено' if nonlinear && amp>512
    if amp<=64 || nonlinear
      sum=0.0;den=(amp+1.0)**2
      (-amp..amp).each { |d| sum+=transformed_mean(value+d)*(amp+1-d.abs)/den };sum
    else
      (transformed_mean(value-amp)+transformed_mean(value+amp))/2.0
    end
  end
  def transformed_mean(value)
    guards=@target.guard? && value>0 ? [[true,1-@bypass],[false,@bypass]] : [[false,1.0]]
    guards.inject(0.0) do |sum,(guard,weight)|
      raw=(guard ? value/(2*@target.values['grd']) : value).to_i
      raw=[@target.values['mp'],raw].min if @item.damage.to_mp?
      resource=@item.damage.to_hp? ? 'HP' : 'MP'
      if raw<0
        void=BS2QoL::Forecast.integer_chance(@target.rate_sum(resource+'回復無効'))
        reverse=BS2QoL::Forecast.integer_chance(@target.rate_sum(resource+'回復反転'))
        normal_value=@item.damage.to_hp? ? guts(raw) : raw
        reverse_value=@item.damage.to_hp? ? guts(-raw) : -raw
        mean=(1-void)*((1-reverse)*normal_value+reverse*reverse_value)
      else;mean=@item.damage.to_hp? ? guts(raw) : raw;end
      sum+weight*mean
    end
  end
end

module BS2Suite
  class EffectView09991
    attr_reader :source
    def initialize(source);@source=source;end
    def values;{'luk'=>@source.luk};end
    def actor?;@source.actor?;end
    def state_rate(id);@source.features_pi(Game_BattlerBase::FEATURE_STATE_RATE,id);end
    def debuff_rate(id);@source.features_pi(Game_BattlerBase::FEATURE_DEBUFF_RATE,id);end
    def immune_state?(id);@source.state_resist?(id);end
  end
  class EffectContext09991
    attr_reader :user,:target
    def initialize(user,target);@user=EffectView09991.new(user);@target=EffectView09991.new(target);end
  end
end

if defined?(BS2Suite::SequenceForecast)
class BS2Suite::SequenceForecast
  # Reject transitions whose native hooks are not simulated. A direct hit may
  # still be shown, but it must never masquerade as the entire action/series.
  alias bs209991_forecast_hit forecast_hit
  def forecast_hit(branches,id,item,step)
    count=step[:hit_count] || 1
    @forecast09991_predictions={}
    branches.each do |b|
      user=b[:user];target=id==:self ? user : b[:targets][id]
      if target.instance_variable_get(:@bs2s_forecast_may_die)
        raise BS2QoL::Forecast::Unsupported,'Цель могла погибнуть; следующие попадания/перевыбор не подтверждены'
      end
      floor=target.instance_variable_get(:@bs2s_forecast_hp_floor)
      uncertain=floor && floor<target.hp
      if uncertain && target.state?(Nana::STATE_KONJO)
        raise BS2QoL::Forecast::Unsupported,'Выживание зависит от HP после предыдущего урона'
      end
      members=id==:self ? user.friends_unit.alive_members : b[:targets].values
      if !item.certain? && members.any? { |m| !m.equal?(target) && m.substitute? } && (floor || target.hp)<target.mhp/4
        raise BS2QoL::Forecast::Unsupported,'Прикрытие после изменения HP требует отдельного перехода'
      end
      notes=([user,target].map { |u| u.feature_objects.map { |o| o.note.to_s } }.flatten+[item.note]).join("\n")
      if (uncertain || user.instance_variable_get(:@bs2s_forecast_hp_uncertain)) && notes =~ /(?:self|a|b|user)\.(?:hp|mp|hp_rate|mp_rate)\b/
        raise BS2QoL::Forecast::Unsupported,'Особое правило зависит от ресурсов после урона'
      end
      if count>1 && (notes =~ /変換攻撃|自動蘇生|全回避時スキル|使用後追加行動|行動後遅延発動|使用者効果|遅延発動/ || item.damage.drain? || item.damage.recover? || item.effects.any? { |e| [41,42,43,44].include?(e.code) || e.code==21 && e.data_id==1 })
        raise BS2QoL::Forecast::Unsupported,'Повторная атака с дополнительными событиями/переносом ресурсов: полный урон не подтверждён'
      end
      formula_text=item.damage.formula.to_s
      [[user,'(?:a|user)'],[target,'b']].each do |unit,side|
        hp_unknown=unit.instance_variable_get(:@bs2s_forecast_hp_uncertain) || (unit.instance_variable_get(:@bs2s_forecast_hp_floor) && unit.instance_variable_get(:@bs2s_forecast_hp_floor)<unit.hp)
        mp_unknown=unit.instance_variable_get(:@bs2s_forecast_mp_uncertain)
        tp_unknown=unit.instance_variable_get(:@bs2s_forecast_tp_uncertain)
        if (hp_unknown && formula_text =~ /\b#{side}\.(?:hp|hp_rate)\b/) || (mp_unknown && formula_text =~ /\b#{side}\.(?:mp|mp_rate)\b/) || (tp_unknown && formula_text =~ /\b#{side}\.tp\b/)
          raise BS2QoL::Forecast::Unsupported,'Формула зависит от неизвестного остатка ресурсов после попадания'
        end
      end
      if item.damage.to_mp? && target.instance_variable_get(:@bs2s_forecast_mp_uncertain)
        raise BS2QoL::Forecast::Unsupported,'Следующий урон MP зависит от неизвестного остатка MP'
      end
      target.instance_variable_set(:@bs2s_forecast_removed_states,[])
      p=BS2QoL::Forecast::Prediction.new(user,target,item,true)
      raise BS2QoL::Forecast::Unsupported,p.error if p.error
      @forecast09991_predictions[b.object_id]=p
      if p.chance>0 && p.state_chances.any? { |sid,chance| sid==target.death_state_id && chance>0 }
        raise BS2QoL::Forecast::Unsupported,'Мгновенная смерть между попаданиями не рассчитана' if count>1
        step[:direct_only]=true;step[:followup_unknown]='Эффект мгновенной смерти не входит в прямой урон'
      end
      if p.counter>0 || p.reflection>0
        raise BS2QoL::Forecast::Unsupported,'Ответный урон между попаданиями не рассчитан' if count>1
        step[:followup_unknown]='Ответный урон может изменить продолжение серии'
      end
      if notes =~ /変換攻撃|自動蘇生|全回避時スキル|使用後追加行動|行動後遅延発動|使用者効果|遅延発動/
        step[:direct_only]=true;step[:followup_unknown]='Дополнительные события не входят в прямой урон'
      end
      formula=p.rows.find { |r| r[:formula] }
      if formula && p.chance>0
        target.instance_variable_set(:@bs2s_forecast_mp_uncertain,true) if item.damage.to_mp?
        target.instance_variable_set(:@bs2s_forecast_tp_uncertain,true) if item.damage.to_hp? && formula[:normal][:raw][1]>0
        if id==:self && item.damage.to_hp?
          normal=formula[:normal][:raw];critical=formula[:critical][:raw]
          lo=p.crit_chance<=0 ? normal[0] : p.crit_chance>=1 ? critical[0] : [normal[0],critical[0]].min
          hi=p.crit_chance>=1 ? critical[1] : p.crit_chance>0 ? [normal[1],critical[1]].max : normal[1]
          user.instance_variable_set(:@bs2s_forecast_hp_uncertain,true) if lo!=hi
        end
      end
      if formula && p.chance>0 && item.damage.to_hp? && id!=:self
        maximum=[formula[:normal][:raw][1],p.crit_chance>0 ? formula[:critical][:raw][1] : 0].max
        floor=target.instance_variable_get(:@bs2s_forecast_hp_floor) || target.hp
        # Bound death conservatively without substituting mean HP into formulas.
        target.instance_variable_set(:@bs2s_forecast_hp_floor,[floor-maximum,0].max)
        if maximum>=floor
          target.instance_variable_set(:@bs2s_forecast_may_die,true)
          step[:followup_unknown]='Возможная смерть цели меняет продолжение серии'
        end
      end
      if item.damage.drain? || item.damage.recover? || item.effects.any? { |e| [41,42,43,44].include?(e.code) || e.code==21 && e.data_id==1 }
        step[:followup_unknown]='Особые эффекты/ресурсы после действия не подтверждены'
        step[:direct_only]=true if item.effects.any? { |e| e.code==44 }
      end
    end
    bs209991_forecast_hit(branches,id,item,step)
  ensure
    @forecast09991_predictions=nil
  end
  # Recompute resistance/luck after each earlier effect, from the current branch.
  def forecast_effect(branches,id,effect,prediction,item)
    if [11,12].include?(effect.code)
      branches.each do |b|
        target=id==:self ? b[:user] : b[:targets][id]
        resource=effect.code==11 ? 'HP' : 'MP';snapshot=BS2QoL::Forecast::Snapshot.new(target)
        if snapshot.rate_sum(resource+'回復無効')>0 || snapshot.rate_sum(resource+'回復反転')>0
          raise BS2QoL::Forecast::Unsupported,'Восстановление под запретом/инверсией: переход ресурсов не подтверждён'
        end
      end
    end
    result=[]
    branches.each do |b|
      user=b[:user];target=id==:self ? user : b[:targets][id]
      context=BS2Suite::EffectContext09991.new(user,target)
      result+=apply_effect([b],id,effect,context,item)
    end
    forecast_merge(result)
  end
  alias bs209991_change_target change_target
  def change_target(branch,id)
    target=id==:self ? branch[:user] : branch[:targets][id]
    before=target.instance_variable_get(:@states).dup
    yield target
    added=target.instance_variable_get(:@states)-before
    # Native add_state rejects restriction-removable states on restricted units;
    # applying a restriction removes existing such states and refreshes resists.
    states=target.instance_variable_get(:@states)
    removed=(target.instance_variable_get(:@bs2s_forecast_removed_states) || [])+(before-states)
    added.each { |sid| states.delete(sid) if removed.include?(sid) || $data_states[sid].remove_by_restriction && before.any? { |old| $data_states[old].restriction>0 } }
    if target.restriction>0
      removed+=states.select { |sid| $data_states[sid].remove_by_restriction }
      states.reject! { |sid| $data_states[sid].remove_by_restriction }
    end
    target.instance_variable_set(:@bs2s_forecast_removed_states,removed.uniq)
    resists=target.state_resist_set;states.reject! { |sid| resists.include?(sid) }
    target.instance_variable_set(:@hp,[[target.hp,0].max,target.mhp].min)
    target.instance_variable_set(:@mp,[[target.mp,0].max,target.mmp].min)
    floor=target.instance_variable_get(:@bs2s_forecast_hp_floor)
    target.instance_variable_set(:@bs2s_forecast_hp_floor,[floor,target.hp].min) if floor
  end
end
end

if defined?(BS2Suite::SequenceForecast)
module BS2Suite::ForecastContext
  def self.step(object,actor,source=nil,unit=nil,weapon=nil,selected=false)
    return nil unless object && actor
    view=source.is_a?(RPG::Weapon) ? BS2Suite::Projection.weapon(actor,source) : BS2Suite::Projection.copy(actor)
    index=actor.instance_variable_get(:@action_input_index).to_i
    return nil unless actor.actions[index]
    action=Game_Action.new(view)
    if object.is_a?(RPG::Item);action.set_item(object.id)
    elsif selected
      action.instance_variable_get(:@item).object=object
      original=actor.actions[index];action.instance_variable_set(:@default_use_skill_id,original.default_use_skill_id)
    else;action.set_skill(object.id);end
    action.target_index=unit.index if unit
    BS2Suite::DirectWeapons.copy_action_context(actor.actions[index],action,object)
    if weapon
      action.instance_variable_set(:@bs2s_normal_attack,true);action.instance_variable_set(:@bs2s_normal_source,weapon.id)
    end
    actions=actor.actions.map { |a| a.dup };actions[index]=action
    view.instance_variable_set(:@actions,actions)
    BS2Suite::SequenceForecast.new(view,BS2Suite::DirectWeapons.selected(actor)).steps[index]
  end
end
if defined?(BS2Suite::QuickDamage)
module BS2Suite::QuickDamage
  def self.candidate_step(object,actor,source,unit,weapon=nil,selected=false)
    BS2Suite::ForecastContext.step(object,actor,source,unit,weapon,selected)
  end
end
end

class BS2QoL::PracticalCard
  alias bs209991_context_initialize initialize
  def initialize(object,actor=nil,language=:ru)
    # Capture the selection platform before older F7 wrappers project the final
    # executor. That executor belongs only to its action, not to preceding slots.
    @forecast09991_actor=actor
    if actor && $game_party.in_battle && object.is_a?(RPG::Skill)
      @forecast09991_resolved=$data_skills[object.skill_change_state(actor,object.id)] || object
    end
    bs209991_context_initialize(object,actor,language)
  end
  def forecast09991_context?
    @forecast09991_actor && @forecast09991_actor.actor? && $game_party.in_battle && @object.is_a?(RPG::UsableItem)
  end
  def forecast09991_steps
    return @forecast09991_steps if @forecast09991_steps
    user=@forecast09991_actor;x=@object.is_a?(RPG::Skill) ? $data_skills[@object.skill_change_state(user,@object.id)] : @object
    targets=if x.for_user?;[user]
    elsif x.for_opponent?;$game_troop.alive_members.reject { |e| e.hidden? }
    elsif x.for_friend?;[user]
    else;[];end
    shared=nil
    @forecast09991_steps=targets.map do |target|
      hidden=target.enemy? && !BS2Suite::Knowledge.allowed?(target)
      step=hidden ? nil : (shared || BS2Suite::ForecastContext.step(@object,user,nil,target))
      shared=step if !hidden && (x.for_all? || x.for_random?)
      [target,step,hidden]
    end
  end
  alias bs209991_snapshot_compact_forecast compact_forecast
  def compact_forecast
    return bs209991_snapshot_compact_forecast unless forecast09991_context?
    if @resolved.damage.none? && @resolved.effects.any? { |e| [11,12,13].include?(e.code) }
      return bs209991_snapshot_compact_forecast if @forecast09991_actor.instance_variable_get(:@action_input_index).to_i==0
      return [t('? Лечение/восстановление после предыдущих действий: численный итог не подтверждён. Эффекты — в соседнем разделе.','? Recovery after preceding actions: total unverified; see Effects.')]
    end
    rows=[t('Исполнение с учётом выбранной серии; среднее включает попадания, криты и поддержанные предыдущие эффекты.','Execution after the selected sequence; mean includes hit/critical chances and supported prior effects.'),
      t('Диапазон и среднее — прямой урон до ограничения HP цели. Это не гарантия конкретного броска.','Range and mean are direct damage before target HP caps, not a guaranteed roll.')]
    forecast09991_steps.each do |target,step,hidden|
      rows<<'— '+forecast_name(target)+' —'
      if hidden;rows<<t('? Сведения о цели ещё закрыты.','? Target knowledge is locked.');next;end
      unless step && !step[:reason]
        rows<<'? '+(step && step[:reason] || t('Нет редактируемого действия.','No editable action slot.'));next
      end
      row=step[:rows].find { |r| r[:target_index]==(target.equal?(@forecast09991_actor) ? :self : target.index) }
      if row
        rows<<forecast_amount(row[:resource],[row[:min],row[:max]])+'; ~'+n(row[:mean].round)+'.'
      elsif @resolved.damage.none?
        rows<<t('Без прямого урона; поддержанные эффекты учтены для продолжения.','No direct damage; supported effects are carried forward.')
      else;rows<<t('? Численный результат не подтверждён.','? Numerical result is unverified.');end
      weapons=step[:weapons] || [step[:weapon]]
      rows<<t('Оружие исполнения: ','Execution weapon: ')+weapons.compact.map { |w| w.name }.uniq.join(' / ')
      rows<<t('Показан только прямой урон; полный итог действия неизвестен.','Direct damage only; full action total is unknown.') if step[:direct_only]
      rows<<step[:followup_unknown] if step[:followup_unknown]
      rows<<t('Условный прогноз: возможные сценарные изменения боя не моделируются.','Conditional forecast: scripted battle changes are not modelled.') if step[:conditional]
    end
    rows<<t('? Для этого контекста нет расчёта серии.','? No sequence calculation for this context.') if forecast09991_steps.empty?
    rows
  end
  alias bs209991_snapshot_cost practical_cost
  def practical_cost
    return bs209991_snapshot_cost unless forecast09991_context? && @resolved.is_a?(RPG::Skill)
    steps=forecast09991_steps.reject { |target,step,hidden| hidden }.map { |target,step,hidden| step }
    costs=steps.map { |s| s && !s[:reason] && s[:cost] }
    if costs.empty? || costs.any? { |c| !c }
      return bs209991_snapshot_cost if @forecast09991_actor.instance_variable_get(:@action_input_index).to_i==0
    end
    return [t('Цена исполнения: ? — переход серии не подтверждён.','Execution cost: ? — sequence transition unverified.')] if costs.empty? || costs.any? { |c| !c }
    conditional=steps.any? { |s| s && s[:conditional] }
    values=(0..3).map do |i|
      low=costs.map { |c| c[i][0] }.min;high=costs.map { |c| c[i][1] }.max
      high>0 ? forecast_range([low,high])+' '+%w(HP MP TP souls)[i] : nil
    end.compact
    [t(conditional ? 'Условная цена после предыдущих действий: ' : 'Цена исполнения после предыдущих действий: ','Execution cost after preceding actions: ')+(values.empty? ? t('без затрат','free') : values.join(', '))]
  end
  alias bs209991_snapshot_formula practical_formula
  def practical_formula
    lines=bs209991_snapshot_formula
    if forecast09991_context? && @forecast09991_actor.instance_variable_get(:@action_input_index).to_i>0
      lines.reject! { |s| s.start_with?(t('Сейчас у пользователя: ','Current user: ')) }
      lines<<t('Числа исполнения берутся из ветвей выбранной серии; см. «По целям».','Execution values come from the selected sequence branches; see Targets.')
    end
    lines
  end
end
end
if defined?(BS2Suite::Projection)
class Game_Actor
  alias bs209991_live_index index
  def index
    origin=instance_variable_get(:@bs2s_origin_actor)
    instance_variable_get(:@bs2s_projection) && origin ? origin.bs209991_live_index : bs209991_live_index
  end
end
end
if defined?(BS2Suite::SequenceForecast)
class BS2Suite::SequenceForecast
  alias bs209991_normal_state_effect apply_effect
  def apply_effect(branches,id,effect,prediction,item)
    return bs209991_normal_state_effect(branches,id,effect,prediction,item) unless effect.code==21 && effect.data_id==0
    ids=prediction.user.source.atk_states
    ids.each do |sid|
      next if sid==1 # Guarded as an unknown death transition before this adapter.
      result=[]
      branches.each do |b|
        user=b[:user];target=id==:self ? user : b[:targets][id]
        chance=effect.value1*user.atk_states_rate(sid)
        ignored=item.note.include?('<強制付与>')
        chance*=target.features_pi(Game_BattlerBase::FEATURE_STATE_RATE,sid) unless ignored || item.note.include?('<有効度無視ステート付与>')
        chance*=[1+(user.luk-target.luk)*0.001,0].max unless ignored || item.note.include?('<運無視ステート付与>')
        chance=0 if target.state_resist?(sid)
        result+=split([b],chance) do |c|
          change_target(c,id) do |recipient|
            states=recipient.instance_variable_get(:@states);states<<sid unless states.include?(sid)
          end
        end
      end
      branches=forecast_merge(result)
    end
    branches
  end
end
end
if defined?(BS2Suite::SequenceForecast)
class BS2QoL::PracticalCard
  alias bs209991_use_context practical_use
  def practical_use
    rows=bs209991_use_context
    if forecast09991_context? && @forecast09991_actor.instance_variable_get(:@action_input_index).to_i>0
      prefixes=['Исполнение последнего действия: ','Источник единственной техники: ','Final action weapon: ','Sole technique source: ']
      rows.reject! { |s| prefixes.any? { |prefix| s.start_with?(prefix) } }
      weapons=forecast09991_steps.map { |target,step,hidden| step && !hidden && !step[:reason] ? (step[:weapons] || [step[:weapon]]) : [] }.flatten.compact.uniq
      rows<<t('Оружие исполнения серии: ','Sequence execution weapon: ')+(weapons.empty? ? '?' : weapons.map { |w| w.name }.join(' / '))
    end
    rows
  end
end
end
