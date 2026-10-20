# encoding: UTF-8
module BS2Suite
  module ForecastTrace
    def self.record(actor,report)
      return unless defined?(BS2Suite::Debug) && BS2Suite::Debug.recording?
      queue=actor.actions.map { |a| [a.item && a.item.class.to_s,a.item && a.item.id,a.target_index,a.instance_variable_get(:@bs2s_normal_source),a.forcing,(a.instance_variable_get(:@bs2s_macro_source) && a.instance_variable_get(:@bs2s_macro_source).id),a.instance_variable_get(:@bs2s_macro_executor)] }
      steps=report.steps.map { |s| [s[:index],s[:item] && s[:item].id,s[:reason],s[:followup_unknown],s[:conditional],s[:rows].size] }
      limits=report.limitations
      key=[actor.id,actor.hp,actor.mp,actor.tp,actor.equips.map { |e| e && e.id },actor.states.map { |v| v.id },actor.instance_variable_get(:@action_input_index),queue,steps,limits]
      @seen ||= {};now=BS2Suite::Performance.now
      return if @seen[key] && ((now-@seen[key])&0xffffffff)<30000
      @seen.shift while @seen.size>=64
      @seen[key]=now;@last=now
      known=$game_troop.alive_members.select { |b| BS2Suite::Knowledge.allowed?(b) }
      cooldown_table=$game_temp.instance_variable_get(:@cool_time)
      cooldown_rows=cooldown_table && cooldown_table.has_key?(actor) ? cooldown_table[actor].to_a : []
      fields={:actor=>actor.id,:slot=>actor.instance_variable_get(:@action_input_index),:queue=>queue,:steps=>steps,:limits=>limits,
        :resources=>[actor.hp,actor.mp,actor.tp],:params=>(0..7).map { |i| actor.param(i) },:equips=>actor.equips.map { |e| e && [e.class.to_s,e.id] },
        :states=>actor.states.map { |s| s.id },:buffs=>actor.instance_variable_get(:@buffs).dup,:cooldowns=>cooldown_rows,
        :difficulty=>$game_variables[Hi_ru_Difficulty::VARIABLES],:known_targets=>known.map { |b| [b.index,b.hp,b.mp,b.states.map { |s| s.id },b.instance_variable_get(:@buffs).dup] },
        :feature_sources=>actor.feature_objects.map { |o| [o.class.to_s,o.id] },:exception=>report.instance_variable_get(:@diagnostic_exception)}
      @pending ||= [];@pending<<fields;@pending.shift while @pending.size>8
      flush
    rescue StandardError
      # Diagnostics must never change or disable a forecast.
    end
    def self.flush
      return unless @pending && !@pending.empty? && defined?(BS2Suite::Debug) && BS2Suite::Debug.recording?
      now=BS2Suite::Performance.now
      return if @written && ((now-@written)&0xffffffff)<250
      BS2Suite::Debug.emit('forecast_result',@pending.shift);@written=now
    rescue StandardError
    end
  end
end
module Graphics
  class << self
    alias bs209992_diagnostic_update update
    def update
      bs209992_diagnostic_update
      BS2Suite::ForecastTrace.flush
    end
  end
end
if defined?(BS2Suite::SequenceForecast)
class BS2Suite::SequenceForecast
  alias bs209992_traced_initialize initialize
  def initialize(actor,weapon=nil)
    bs209992_traced_initialize(actor,weapon)
    BS2Suite::ForecastTrace.record(actor,self)
  end
  # Repetition and user TP gain are already propagated for every native hit.
  # They do not constitute an unmodelled common event or resource conversion.
  def special?(item)
    return true if item.damage.recover? || item.damage.drain?
    return true if item.for_user? && item.damage.to_hp? && item.damage.type!=0
    return true if item.effects.any? { |e| [41,42,43,44].include?(e.code) || e.code==21 && e.data_id==1 }
    !!(item.note =~ /使用後追加行動|行動後遅延発動|使用者効果|ステート変化|変換攻撃|付与時/)
  end
end
end
if BS2Suite.enabled?('semantic_groups') || BS2Suite.enabled?('action_queue')
class Scene_Battle
  def prior_command
    actor=BattleManager.actor
    return unless actor && actor.input && !BattleManager.in_turn?
    now=BS2Suite::Performance.now
    if @bs20999_cancel_actor.equal?(actor) && @bs20999_cancel_time && ((now-@bs20999_cancel_time)&0xffffffff)<=550
      @bs20999_cancel_time=nil
      return if BS2Suite::QueueEdit.cancel(self,actor)
    end
    @bs20999_cancel_actor=actor;@bs20999_cancel_time=now
    index=actor.instance_variable_get(:@action_input_index).to_i
    first=[index-1,0].max
    (first...actor.actions.size).each { |i| actor.actions[i]=Game_Action.new(actor) }
    actor.instance_variable_set(:@action_input_index,first)
    actor.instance_variable_set(:@bs2s_direct_final,nil)
    BS2Suite::Performance.bump
    BS2Suite::Debug.emit('queue_edit',{:actor=>actor.id,:from=>index,:to=>first,:operation=>'cancel_unpaid_tail'}) if defined?(BS2Suite::Debug)
    start_actor_command_selection
  end
  [:on_enemy_cancel,:on_actor_cancel].each do |method_name|
    alias_method ('bs209992_'+method_name.to_s).to_sym,method_name
    define_method(method_name) do
      actor=BattleManager.actor
      actor.input.clear if actor && actor.input && !BattleManager.in_turn?
      BS2Suite::Performance.bump
      send(('bs209992_'+method_name.to_s).to_sym)
    end
  end
end
end
class BS2Suite::SettingsCommands
  alias bs209992_highlight_commands make_command_list
  def make_command_list
    bs209992_highlight_commands
    add_command('Подсветка взаимодействий: '+(BS2Suite::Options.get('interaction_highlight')==1 ? 'вкл' : 'выкл')+' · '+BS2Suite::Keys.token(:interact_highlight),:interaction_highlight)
  end
end
class BS2Suite::SettingsScene
  alias bs209992_highlight_settings start
  def start
    bs209992_highlight_settings
    @commands.set_handler(:interaction_highlight,lambda { option('interaction_highlight',BS2Suite::Options.get('interaction_highlight')==1 ? 0 : 1) })
  end
end
