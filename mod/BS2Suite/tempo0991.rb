# encoding: UTF-8
module BS2Suite
  module TempoHint
    def self.ticks(unit,ap=nil)
      view=BS2Suite::Projection.copy(unit) if defined?(BS2Suite::Projection)
      view ||= unit.dup
      gain=view.ap_gain_point*ATB::REFRESH_FRAME
      limit=view.chanting? ? view.instance_variable_get(:@max_chant_count) : ATB::MAX_AP
      current=ap.nil? ? (view.chanting? ? view.instance_variable_get(:@chant_count) : view.ap) : ap
      current=ATB::MAX_AP if !view.chanting? && current==ATB::MAX_AP-1
      return 1.0/0.0 if !gain || gain<=0 || !limit || !current
      [((limit-current)/gain.to_f).ceil,0].max
    end
    def self.calculate(actor)
      return [] unless actor && actor.actor?
      enemies=$game_troop.alive_members.reject { |e| e.hidden? }
      return [] if enemies.empty?
      return ['Темп: включите модуль групп для границы знаний о противниках'] unless defined?(BS2Suite::Knowledge)
      if defined?(BS2Suite::Knowledge) && enemies.any? { |e| !BS2Suite::Knowledge.allowed?(e) }
        return ['Темп: сведения о противниках пока закрыты']
      end
      view=defined?(BS2Suite::Projection) ? BS2Suite::Projection.copy(actor) : actor.dup
      last=actor.actions.rindex { |a| a.item }
      item=last && actor.actions[last].item
      if item && item.respond_to?(:chant) && item.chant
        return ['Темп: действие с подготовкой — итог пока не подтверждён']
      end
      if item && defined?(BS2Suite::DirectWeapons)
        weapon=BS2Suite::DirectWeapons.execution_weapon(actor,item,last,actor.actions[last])
        view=BS2Suite::Projection.weapon(view,weapon) if weapon
      end
      next_ap=item && item.respond_to?(:next_ap) ? item.next_ap : [0,0]
      slow=ticks(view,ATB::MAX_AP*next_ap[0]/100.0)
      fast=ticks(view,ATB::MAX_AP*[next_ap[0]+next_ap[1],100].min/100.0)
      ordered=enemies.map { |enemy| [ticks(enemy),enemy] }.sort_by { |time,enemy| [time,enemy.index] }
      definite=ordered.select { |time,enemy| time<fast }.map { |time,enemy| '#'+(enemy.index+1).to_s+' '+enemy.name }
      possible=ordered.select { |time,enemy| time>=fast && time<slow }.map { |time,enemy| '#'+(enemy.index+1).to_s+' '+enemy.name }
      rows=[definite.empty? ? 'По текущему темпу: следующий ГГ' : 'До следующего ГГ: '+definite.join(' → ')]
      rows[0]='По текущему темпу: ГГ или противник' if definite.empty? && !possible.empty?
      rows<<'Возможно раньше ГГ: '+possible.join(' → ') unless possible.empty?
      rows<<'По текущим эффектам; будущие изменения и повторные ходы врагов не предсказываются. Союзники не показаны.'
      rows
    end
    def self.lines(scene)
      return [] unless Options.get('tempo_hint')==1 && $game_party && $game_party.in_battle
      actor=BattleManager.actor || scene.instance_variable_get(:@bs2q_queue_actor)
      return [] unless actor && actor.input
      key=[defined?(BS2Suite::Performance) && BS2Suite::Performance.context(actor),actor.ap,$game_troop.alive_members.map { |e| [e.index,e.ap,e.instance_variable_get(:@chant_count)] }]
      return @lines if @key==key
      @key=key;@lines=calculate(actor)
    rescue StandardError
      ['Темп: особое правило, прогноз не подтверждён']
    end
    def self.tick
      scene=SceneManager.scene;return unless scene.is_a?(Scene_Battle)
      window=scene.instance_variable_get(:@bs20991_tempo)
      hd=defined?(BS2Suite::HDDisplay) && BS2Suite::HDDisplay.active?
      if Options.get('tempo_hint')!=1 || hd || BS2Suite::VisualClock.modal?(scene)
        window.hide if window;return
      end
      choosing=[:@actor_command_window,:@enemy_window,:@actor_window].any? do |key|
        control=scene.instance_variable_get(key);control && control.active && control.open?
      end
      unless choosing;window.hide if window;return;end
      rows=lines(scene)
      if rows.empty?;window.hide if window;return;end
      unless window
        window=BS2Suite::TempoWindow.new;scene.instance_variable_set(:@bs20991_tempo,window)
      end
      plan=scene.instance_variable_get(:@bs2q_plan)
      window.y=plan && plan.visible ? plan.y+plan.height : 0
      window.present(rows)
    end
  end
  class TempoWindow < Window_Base
    def initialize
      super(188,0,Graphics.width-188,82);BS2Modules.style(self);self.z=380
      contents.font.size=15
    end
    def present(rows)
      self.visible=true
      return if @rows==rows
      @rows=rows.dup;contents.clear
      rows.take(3).each_with_index { |text,i| draw_text(0,i*17,contents_width,17,BS2Modules.fit(self,text,contents_width)) }
    end
  end
end
if defined?(BS2Suite::HDDisplay)
module BS2Suite::HDDisplay
  class << self
    alias bs20991_tempo_battle battle_rows
    def battle_rows(scene)
      rows=bs20991_tempo_battle(scene)
      hints=BS2Suite::TempoHint.lines(scene)
      rows<<row('H','Темп после серии') unless hints.empty?
      rows+hints.map { |text| row('D',text) }
    end
  end
end
end
module Graphics
  class << self
    alias bs20991_tempo_graphics update
    def update
      bs20991_tempo_graphics
      BS2Suite::TempoHint.tick
    end
  end
end
