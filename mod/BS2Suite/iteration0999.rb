# encoding: UTF-8
if defined?(BS2Suite::QuickDamage)
module BS2Suite::QuickDamage
  class << self
    def candidate_step(object,actor,source,unit,weapon=nil)
      view=source.is_a?(RPG::Weapon) ? BS2Suite::Projection.weapon(actor,source) : BS2Suite::Projection.copy(actor)
      index=actor.instance_variable_get(:@action_input_index).to_i
      return nil unless actor.actions[index]
      action=Game_Action.new(view)
      object.is_a?(RPG::Item) ? action.set_item(object.id) : action.set_skill(object.id)
      action.target_index=unit.index if unit
      BS2Suite::DirectWeapons.copy_action_context(actor.actions[index],action,object)
      if weapon
        action.instance_variable_set(:@bs2s_normal_attack,true)
        action.instance_variable_set(:@bs2s_normal_source,weapon.id)
      end
      actions=actor.actions.map { |a| a.dup };actions[index]=action;view.instance_variable_set(:@actions,actions)
      BS2Suite::SequenceForecast.new(view,BS2Suite::DirectWeapons.selected(actor)).steps[index]
    end
    def candidate_mean(object,actor,source,unit,weapon=nil)
      step=candidate_step(object,actor,source,unit,weapon)
      return nil unless step && !step[:reason]
      r=step[:rows].find { |v| v[:target_index]==unit.index };r && [r[:mean],step[:partial],step[:direct_only],step[:conditional]]
    end
    def target_mean(object,actor,source,unit);candidate_mean(object,actor,source,unit,source);end
    def calculate(object,actor,source,targets,target,weapon)
      if object.for_one? && !object.for_random? && !target && targets.size>1
        values=targets.map { |unit| candidate_mean(object,actor,source,unit,weapon) }
        return ['~? · серия пока не рассчитана'] if values.any? { |v| !v }
        return [compact_means(values.map { |v| v[0] })+' урона'+(values.any? { |v| v[3] } ? ' · условно' : '')+(values.any? { |v| v[2] } ? ' · прямой урон; итог ?' : '')]
      end
      step=candidate_step(object,actor,source,targets[0],weapon,!!target && !source && !weapon)
      return ['~? · '+(step && step[:reason] || 'серия пока не рассчитана')] unless step && !step[:reason] && !step[:rows].empty?
      means=step[:rows].select { |r| r[:target_index]!=:self }.map { |r| r[:mean] }
      total=means.inject(0.0) { |n,v| n+v }
      suffix=(step[:conditional] ? ' · условно' : '')+(step[:direct_only] ? ' · прямой урон; итог ?' : '')
      if (object.for_all? || (weapon && object.for_random? && !target)) && means.size>1
        [compact_means(object.for_random? ? means : [means.min,means.max])+' по цели · Σ~'+total.round.to_s+' всего'+suffix]
      else
        ['≈ '+[total.round,0].max.to_s+' урона'+(object.for_random? || object.for_all? ? ' суммарно' : '')+suffix]
      end
    end
  end
end
end

if BS2Suite.enabled?('semantic_groups') || BS2Suite.enabled?('action_queue')
module BS2Suite::QueueEdit
  def self.cancel(scene,actor)
    return false unless actor && actor.input && actor.actions.any? { |a| a.item }
    # Allocate empty actions without rerolling the native action count or speed.
    actor.instance_variable_set(:@actions,Array.new(actor.actions.size) { Game_Action.new(actor) })
    actor.instance_variable_set(:@action_input_index,0)
    actor.instance_variable_set(:@bs2s_direct_final,nil)
    BS2Suite::Performance.bump
    scene.start_actor_command_selection
    BS2QoL::Hotkeys.notice('Серия сброшена; уже использованные предметы сохраняют свои эффекты')
    BS2QoL::Keyboard.consume;true
  end
  def self.mp(actor,index)
    action=actor.actions[index];return '' unless action && action.item.is_a?(RPG::Skill)
    @cost_cache ||= {};key=BS2Suite::Performance.context(actor)
    if @cost_cache.has_key?(key) && @cost_cache[key].has_key?(index);return @cost_cache[key][index];end
    @cost_cache.clear if @cost_cache.size>=64
    cache=@cost_cache[key] ||= {}
    unless cache.has_key?(:report)
      cache[:report]=defined?(BS2QoL::Forecast::Prediction) && defined?(BS2Suite::SequenceForecast) ? BS2Suite::SequenceForecast.new(actor) : nil
    end
    step=cache[:report] && cache[:report].steps[index]
    range=step && step[:cost] && step[:cost][1]
    if range
      text=range[0]==range[1] ? range[0].to_s : range[0].to_s+'–'+range[1].to_s
      text='~'+text if step[:conditional]
    else;text='~'+actor.skill_mp_cost(action.item).to_s;end
    cache[index]=' · '+text+' ОМ'
  end
end
class Scene_Battle
  alias bs20999_prior_command prior_command
  def prior_command
    actor=BattleManager.actor;now=BS2Suite::Performance.now
    if actor && @bs20999_cancel_actor.equal?(actor) && @bs20999_cancel_time && ((now-@bs20999_cancel_time)&0xffffffff)<=550
      @bs20999_cancel_time=nil
      return if BS2Suite::QueueEdit.cancel(self,actor)
    end
    @bs20999_cancel_actor=actor;@bs20999_cancel_time=now
    bs20999_prior_command
  end
  alias bs20999_selected_command next_command
  def next_command
    @bs20999_cancel_time=nil;bs20999_selected_command
  end
end
end
