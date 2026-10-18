# encoding: UTF-8
module BS2Suite
  # Kept in mod preferences, separately from the battle-local final nomination.
  module StartingWeapon
    def self.data
      return @data if @data
      @data={}
      Store.read('starting_weapons',8192).each_line do |line|
        match=/\A([0-9]{1,5})=([0-9]{1,5})\z/.match(line.strip)
        @data[match[1].to_i]=match[2].to_i if match && $data_weapons && $data_weapons[match[2].to_i]
      end
      @data
    end
    def self.selected(actor)
      actor && DirectWeapons.resolve(actor,data[actor.id])
    end
    def self.toggle(actor,weapon)
      return false unless actor && weapon.is_a?(RPG::Weapon) && Semantic.owned(actor).include?(weapon)
      before=data.dup
      root=WeaponFamilies.root(weapon.id)
      data[actor.id]==root ? data.delete(actor.id) : data[actor.id]=root
      ok=Store.write('starting_weapons',data.keys.sort.map { |id| id.to_s+'='+data[id].to_s }.join("\n")+"\n")
      @data=before unless ok
      ok
    end
    def self.begin_input(actor)
      return false unless actor && actor.actor? && actor.input && actor.input.item.nil? && actor.actions.all? { |a| !a.forcing && !a.item }
      return false if actor.confusion? || actor.auto_battle? || DirectWeapons.quick?
      @epochs ||= {}
      return false if @epochs[actor.id]==actor.actions
      @epochs[actor.id]=actor.actions.dup
      weapon=selected(actor)
      return false unless weapon && weapon!=actor.equips[0]
      ok=BS2QoL::Model.change_weapon(actor,weapon)
      BS2QoL::Hotkeys.notice(ok ? 'Начало хода: '+weapon.name : 'Стартовое оружие сейчас недоступно')
      ok
    end
    def self.route(window)
      return false unless window.active && window.visible && window.open? && Input.trigger?(:Z)
      scene=SceneManager.scene
      return false unless scene.is_a?(Scene_Equip) || scene.is_a?(Scene_Item)
      return false if defined?(BS2QoL::Reference) && BS2QoL::Reference.active?(scene)
      object=window.respond_to?(:item) && window.item
      return false unless object.is_a?(RPG::Weapon)
      return true if scene.instance_variable_get(:@bs2095_start_d)==Graphics.frame_count
      scene.instance_variable_set(:@bs2095_start_d,Graphics.frame_count)
      actor=scene.instance_variable_get(:@actor) || $game_party.menu_actor || $game_party.leader
      ok=toggle(actor,object)
      ok ? ::Sound.play_ok : ::Sound.play_buzzer
      text=ok ? (selected(actor) ? 'Начало хода: '+selected(actor).name : 'Стартовое оружие снято') : 'Не удалось назначить стартовое оружие'
      BS2QoL::Hotkeys.notice(text)
      window.update_help;BS2QoL::Keyboard.consume;true
    end
    def self.help(window)
      scene=SceneManager.scene
      return unless scene.is_a?(Scene_Equip) || scene.is_a?(Scene_Item)
      object=window.respond_to?(:item) && window.item
      help=window.instance_variable_get(:@help_window)
      return unless object.is_a?(RPG::Weapon) && help
      actor=scene.instance_variable_get(:@actor) || $game_party.menu_actor || $game_party.leader
      weapon=selected(actor)
      text=help.instance_variable_get(:@text).to_s.split("\n"+Keys.token(:Z)+': начало хода')[0]
      hint=Keys.token(:Z)+': начало хода'+(weapon && WeaponFamilies.root(weapon.id)==WeaponFamilies.root(object.id) ? ' ✓ (повтор снять)' : ' (назначить)')
      help.set_text(text+"\n"+hint)
    end
  end
  module SoloTarget
    def self.hero_only?(object,user,battle=false)
      hero=$game_party.leader
      return false unless object && user && hero && object.for_friend?
      return user==hero if object.for_user?
      members=battle ? $game_party.battle_members : $game_party.members
      valid=members.select { |a| object.for_dead_friend? ? a.dead? : a.alive? }
      valid.size==1 && valid[0]==hero
    end
  end
end
if BS2Suite.enabled?('semantic_groups')
[Window_ItemList,Window_EquipItem].each do |type|
  handling=('bs2095_start_handling_'+type.name).to_sym
  help=('bs2095_start_help_'+type.name).to_sym
  type.class_eval do
    alias_method handling,:process_handling
    define_method(:process_handling) do
      return if BS2Suite::StartingWeapon.route(self)
      send(handling)
    end
    alias_method help,:update_help
    define_method(:update_help) do
      send(help)
      BS2Suite::StartingWeapon.help(self)
    end
  end
end
class Scene_Battle
  alias bs2095_start_weapon_scene start
  def start
    BS2Suite::StartingWeapon.instance_variable_set(:@epochs,{})
    bs2095_start_weapon_scene
  end
  alias bs2095_start_weapon_input start_actor_command_selection
  def start_actor_command_selection
    bs2095_start_weapon_input
    actor=BattleManager.actor
    if BS2Suite::StartingWeapon.begin_input(actor)
      @actor_command_window.refresh;refresh_status
    end
  end
end
end
class Scene_Battle
  alias bs2095_solo_actor select_actor_selection
  def select_actor_selection
    bs2095_solo_actor
    actor=BattleManager.actor;object=actor && actor.input && actor.input.item
    if @actor_window.active && BS2Suite::SoloTarget.hero_only?(object,actor,true)
      @actor_window.select($game_party.leader.index)
      @actor_window.process_ok
    end
  end
end
class Scene_ItemBase
  alias bs2095_solo_menu determine_item
  def determine_item
    unless BS2Suite::SoloTarget.hero_only?(item,user)
      return bs2095_solo_menu
    end
    @actor_window.select_for_item(item)
    @actor_window.select($game_party.leader.index)
    on_actor_ok
    activate_item_window unless scene_changing?
  end
end
if defined?(BS2Suite::HDDisplay) && BS2Suite.enabled?('semantic_groups')
module BS2Suite::HDDisplay
  class << self
    alias bs2095_start_battle_rows battle_rows
    def battle_rows(scene)
      rows=bs2095_start_battle_rows(scene)
      actor=actor_for(scene);weapon=BS2Suite::StartingWeapon.selected(actor)
      rows<<row('D','Начало хода: '+weapon.name) if weapon
      rows
    end
  end
end
end
if defined?(BS2Suite::QuickDamage)
module BS2Suite::QuickDamage
  class << self
    def compact_means(values)
      values=values.sort
      return [] if values.empty?
      points=values.size>2 ? [values.first,values.inject(0.0) { |sum,v| sum+v }/values.size,values.last] : values
      output=[]
      points.each do |value|
        # Collapse visually indistinguishable values: one point or three percent.
        output<<value unless output.any? { |v| (value-v).abs <= [1.0,[v.abs,value.abs].max*0.03].max }
      end
      output.map { |v| '~'+[v.round,0].max.to_s }.join(', ')
    end
    def target_mean(object,actor,source,unit)
      view=source.is_a?(RPG::Weapon) ? BS2Suite::Projection.weapon(actor,source) : BS2Suite::Projection.copy(actor)
      index=actor.instance_variable_get(:@action_input_index).to_i
      if object.for_random?
        return nil if index>0
        final=BS2Suite::DirectWeapons.execution_weapon(actor,object,index) if index==actor.actions.size-1
        view=BS2Suite::Projection.weapon(view,final) if final
        targets=$game_troop.alive_members.reject { |e| e.hidden? }
        total=targets.inject(0.0) { |sum,t| sum+t.tgr };return nil if total<=0
        prediction=BS2QoL::Forecast::Prediction.new(view,unit,object);mean=prediction.expected_formula
        return nil unless mean
        partial=prediction.repeats>1 && !prediction.stable
        return [mean*(partial ? 1 : prediction.repeats)*object.number_of_targets*unit.tgr/total,partial]
      end
      action=Game_Action.new(actor);action.set_skill(object.id);action.target_index=unit.index
      BS2Suite::DirectWeapons.copy_action_context(actor.actions[index],action,object)
      action.instance_variable_set(:@bs2s_normal_attack,true)
      actions=actor.actions.map { |a| a.dup };actions[index]=action
      view.instance_variable_set(:@actions,actions)
      step=BS2Suite::SequenceForecast.new(view,BS2Suite::DirectWeapons.selected(actor)).steps[index]
      return nil unless step && !step[:rows].empty? && !step[:reason]
      row=step[:rows].find { |r| r[:target_index]==unit.index };return nil unless row
      [row[:mean],step[:partial]]
    end
    alias bs2095_single_calculate calculate
    def calculate(object,actor,source,targets,target,weapon)
      if weapon && !target && targets.size>1
        values=targets.map { |unit| target_mean(object,actor,source,unit) }
        return ['~? · серия пока не рассчитана'] if values.any? { |v| !v }
        return [compact_means(values.map { |v| v[0] })+' урона'+(values.any? { |v| v[1] } ? ' · первое попадание' : '')]
      end
      bs2095_single_calculate(object,actor,source,targets,target,weapon)
    end
  end
end
end
if BS2Suite.enabled?('semantic_groups') && BS2Suite.enabled?('reference_cards')
class BS2QoL::PracticalCard
  alias bs2095_execution_card initialize
  def initialize(object,actor=nil,language=:ru)
    if actor && (object.is_a?(RPG::Skill) || object.is_a?(RPG::Item)) && $game_party.in_battle && !BS2Suite::BattleSupport.quick?(object)
      index=actor.instance_variable_get(:@action_input_index).to_i
      source=BS2Suite::DirectWeapons.sole_source(actor,object,index)
      final=BS2Suite::DirectWeapons.execution_weapon(actor,object,index)
      @bs2096_sole_source=source
      if final && index==actor.actions.size-1 && actor.movable? && !actor.confusion? && (object.is_a?(RPG::Item) || actor.skills.include?(object))
        view=BS2Suite::Projection.weapon(actor,final)
        if view.usable?(object)
          # The source made this ID selectable. Losing its granting feature after
          # the final swap does not unselect an already chosen native action.
          view.instance_variable_set(:@skills,(view.instance_variable_get(:@skills)+[object.id]).uniq) if object.is_a?(RPG::Skill)
          actor=view;@bs2095_execution_weapon=final
        end
      end
    end
    if actor && object.is_a?(RPG::Skill) && $game_party.in_battle && actor.actions.any? { |a| a.item==object }
      # A selected ID remains executable after another queued choice changes gear.
      # Only the local display copy learns it; the live actor never gains a skill.
      unless actor.skills.include?(object)
        actor=BS2Suite::Projection.copy(actor)
        actor.instance_variable_set(:@skills,(actor.instance_variable_get(:@skills)+[object.id]).uniq)
      end
    end
    bs2095_execution_card(object,actor,language)
  end
  alias bs2095_execution_use practical_use
  def practical_use
    rows=bs2095_execution_use
    if @bs2095_execution_weapon
      rows<<(@bs2096_sole_source ? t('Источник единственной техники: ','Sole technique source: ') : t('Исполнение последнего действия: ','Final action weapon: '))+@bs2095_execution_weapon.name
    end
    rows
  end
end
end
