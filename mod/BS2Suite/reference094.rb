# encoding: UTF-8
class BS2QoL::PracticalCard
  alias bs2094_card_initialize initialize
  def initialize(object,actor=nil,language=:ru)
    bs2094_card_initialize(object,actor,language)
    return unless object.is_a?(RPG::Skill)
    ordered=t(['Применение','Эффекты','Особенности','Расчёт','По целям'],['Use','Effects','Special','Calculation','Targets'])
    pairs=@section_names.zip(@sections)
    pairs.sort_by! { |label,lines| ordered.index(label) || 99 }
    @section_names=pairs.map { |p| p[0] };@sections=pairs.map { |p| p[1] }
  end
  alias bs2094_editorial editorial
  def editorial
    if @object.is_a?(RPG::Skill) && @object.id==100
      return [t('Физический удар: ATK ×5 без вычитания ЗАЩ цели. Отдельно обходит Guard на 100%.','Physical hit: ATK x5 without subtracting target DEF. Separately bypasses Guard at 100%.'),
        t('Это два независимых свойства. Сопротивление стихии и физическому типу урона продолжает учитываться.','These are independent properties. Element and physical damage-rate resistance still apply.')]
    end
    bs2094_editorial
  end
  alias bs2094_use practical_use
  def practical_use
    rows=bs2094_use
    if @resolved.is_a?(RPG::Skill) && !@resolved.damage.none?
      formula=@resolved.damage.formula.to_s
      simple=formula !~ /param\(|eval|send\(|\.damage|\.defense/
      if simple
        rows<<t('ЗАЩ в формуле: ','DEF in formula: ')+(formula =~ /\bb\.def\b/ ? t('есть b.def; коэффициент — в расчёте.','contains b.def; see Calculation for the coefficient.') : t('не вычитается; это не отменяет Guard, PDR/MDR и стихии.','not subtracted; Guard, PDR/MDR and elements remain separate.'))
        rows<<t('МЗЩ в формуле: ','MDF in formula: ')+(formula =~ /\bb\.mdf\b/ ? t('учитывается явно.','explicitly included.') : t('не вычитается.','not subtracted.')) if @resolved.magical?
      end
    end
    if defined?(BS2Suite::BattleSupport) && BS2Suite::BattleSupport.gunbreak?(@object)
      rows<<t(BS2Suite::Keys.token(:Z)+' — авто Gun Break: выделите его в «Техники» или в V.',BS2Suite::Keys.token(:Z)+' — auto Gun Break: highlight it in Techniques or V.')
    end
    rows
  end
end
module BS2QoL::Reference
  class << self
    alias bs2094_neighbor_update update
    def update(scene)
      popup=scene.instance_variable_get(:@bs2q_reference_window)
      origin=scene.instance_variable_get(:@bs2q_reference_origin)
      if popup && defined?(BS2Suite::PaletteWindow) && origin.is_a?(BS2Suite::PaletteWindow) && origin.group && !origin.assignment && (Input.trigger?(:L) || Input.trigger?(:R))
        return if scene.instance_variable_get(:@bs2094_ref_frame)==Graphics.frame_count
        scene.instance_variable_set(:@bs2094_ref_frame,Graphics.frame_count)
        rows=origin.entries;delta=Input.trigger?(:R) ? 1 : -1
        next_index=origin.index
        rows.size.times do
          next_index=(next_index+delta)%rows.size
          break if rows[next_index][:object]
        end
        row=rows[next_index]
        if row && row[:object]
          section=popup.card.section_names[popup.section]
          origin.select(next_index)
          actor=row[:source].is_a?(RPG::Weapon) ? BS2Suite::Projection.weapon(origin.actor,row[:source]) : origin.actor
          popup.instance_variable_set(:@object,row[:object]);popup.instance_variable_set(:@actor,actor);popup.rebuild
          index=popup.card.section_names.index(section) || 0
          popup.instance_variable_set(:@section,index);popup.instance_variable_set(:@offset,0);popup.refresh
          ::Sound.play_cursor
        end
        BS2QoL::Keyboard.consume;return
      end
      bs2094_neighbor_update(scene)
    end
  end
end

# Average of variance endpoints is approximate; independent discrete probabilities
# are weighted explicitly. No item_apply, cost payment, state rolls or RNG calls.
class BS2QoL::Forecast::Prediction
  def expected_formula
    return nil if error || !@rows.any? { |r| r[:formula] }
    stored=@bypass
    means=[]
    [false,true].each do |critical|
      values=[]
      [0.0,1.0].each do |guard|
        @bypass=guard
        range=formula_range(critical,@item.damage.to_hp? ? 'HP' : 'MP')[:raw]
        values<<(range[0]+range[1])/2.0
      end
      means<<values[0]*(1-stored)+values[1]*stored
    end
    @chance*((1-@crit_chance)*means[0]+@crit_chance*means[1])
  ensure
    @bypass=stored unless stored.nil?
  end
end
if defined?(BS2Suite::HDDisplay) && defined?(BS2Suite::PaletteWindow)
module BS2Suite
  module QuickDamage
    def self.signature(unit)
      [unit.hp,unit.mp,unit.tp,(0..7).map { |i| unit.param(i) },unit.cri,unit.cev,unit.states.map { |s| s.id },unit.instance_variable_get(:@buffs).dup,unit.actor? ? unit.equips.map { |e| e && [e.class.to_s,e.id] } : unit.enemy_id]
    end
    def self.lines(scene,object,actor,source=nil,target=nil,weapon=nil)
      return [] unless object && actor && $game_party.in_battle && object.respond_to?(:damage) && object.damage.to_hp? && !object.damage.recover?
      targets=target ? [target] : $game_troop.alive_members.reject { |e| e.hidden? }
      return [] if object.for_one? && !object.for_random? && targets.size>1 && !target && !weapon
      return [] if targets.empty? || !object.for_opponent?
      return ['≈ ? · сведения о цели закрыты'] if targets.any? { |e| !Knowledge.allowed?(e) }
      key=[object.id,object.class.to_s,signature(actor),source && source.id,weapon && weapon.id,DirectWeapons.selected_id(actor),targets.map { |e| [e.index,signature(e)] },actor.actions.map { |a| [a.item && a.item.id,a.target_index] },actor.instance_variable_get(:@action_input_index),$game_variables[Hi_ru_Difficulty::VARIABLES]]
      key<<actor.actions.map { |a| [a.instance_variable_get(:@bs2s_direct_count),a.forcing,a.instance_variable_get(:@bs2s_normal_attack)] }
      key<<Projection.copy(actor).cool_time.dup
      key<<$game_party.gold
      key<<$game_party.instance_variable_get(:@items).dup
      resolved=DirectWeapons.selected(actor)
      key<<[resolved && resolved.id,resolved && DirectWeapons.can_switch?(actor,resolved)]
      key<<DirectWeapons.variable_signature(actor,object,targets)
      return @value if @key==key
      @key=key;@value=calculate(object,actor,source,targets,target,weapon)
    rescue StandardError
      ['≈ ? · особое правило расчёта']
    end
    def self.calculate(object,actor,source,targets,target,weapon)
      view=source.is_a?(RPG::Weapon) ? Projection.weapon(actor,source) : Projection.copy(actor)
      index=actor.instance_variable_get(:@action_input_index).to_i
      final=DirectWeapons.execution_weapon(actor,object,index) if index==actor.actions.size-1 && !BattleSupport.quick?(object)
      if object.for_random?
        view=Projection.weapon(view,final) if final
        weights=targets.inject(0.0) { |sum,t| sum+t.tgr };return ['≈ ?'] if weights<=0
        total=0.0;first=false
        targets.each do |unit|
          p=BS2QoL::Forecast::Prediction.new(view,unit,object);mean=p.expected_formula
          return ['≈ ? · особая формула'] unless mean
          first ||= p.repeats>1 && !p.stable
          total+=mean*(p.stable ? p.repeats : 1)*unit.tgr/weights*object.number_of_targets
        end
      else
        action=Game_Action.new(actor);object.is_a?(RPG::Item) ? action.set_item(object.id) : action.set_skill(object.id);action.target_index=targets[0].index
        DirectWeapons.copy_action_context(actor.actions[index],action,object)
        action.instance_variable_set(:@bs2s_normal_attack,true) if weapon
        actions=actor.actions.map { |a| a.dup };actions[index]=action
        view.instance_variable_set(:@actions,actions)
        report=SequenceForecast.new(view,DirectWeapons.selected(actor))
        step=report.steps[index]
        return ['≈ ? · серия пока не рассчитана'] unless step && !step[:rows].empty?
        total=step[:rows].inject(0.0) { |sum,row| sum+row[:mean] };first=step[:partial]
      end
      ['≈ '+[total.round,0].max.to_s+' урона'+(first ? ' · первое попадание' : object.for_all? ? ' суммарно' : '')]
    end
  end
end
module BS2Suite::HDDisplay
  class << self
    alias bs2094_damage_palette palette_rows
    def palette_rows(window)
      rows=bs2094_damage_palette(window);entry=window.entry
      if window.group && entry && entry[:object] && !window.assignment
        actor=window.actor;obj=entry[:object];weapon=nil;source=entry[:source]
        if obj.is_a?(RPG::Weapon)
          weapon=obj;source=obj;view=BS2Suite::Projection.weapon(actor,obj);obj=$data_skills[view.attack_skill_id]
        end
        extra=BS2Suite::QuickDamage.lines(SceneManager.scene,obj,actor,source,nil,weapon)
        at=rows.index { |r| r.start_with?("D\t") } || rows.size
        rows.insert(at,*extra.map { |text| row('S',text) })
      end
      rows
    end
    alias bs2094_damage_battle battle_rows
    def battle_rows(scene)
      rows=bs2094_damage_battle(scene);actor=actor_for(scene);return rows unless actor
      enemy_window=scene.instance_variable_get(:@enemy_window)
      skill_window=scene.instance_variable_get(:@skill_window);item_window=scene.instance_variable_get(:@item_window)
      window=[skill_window,item_window].find { |w| w && w.active && w.visible }
      target=enemy_window && enemy_window.active ? $game_troop.alive_members[enemy_window.index] : nil
      ally_window=scene.instance_variable_get(:@actor_window)
      selecting=target || (ally_window && ally_window.active)
      object=selecting ? actor.input && actor.input.item : window && window.item
      window=nil if selecting
      if object
        rows<<row('H',object.name)
        rows+=wrap_lines([BS2Suite::ShortNotes.describe(object)]).map { |s| row('S',s) } if BS2Suite::Options.get('palette_notes')==1
        rows+=BS2Suite::QuickDamage.lines(scene,object,actor,nil,target).map { |s| row('S',s) }
        if window && BS2Suite::BattleSupport.eligible?(object)
          rows<<row('D',BS2Suite::Keys.token(:Z)+' — авто выделенного предмета / Gun Break')
        end
      end
      rows
    end
  end
end
end
