# encoding: UTF-8
module BS2Suite::AutoStealth
  SKILL=120
  class << self
    def actor_id
      return @actor_id unless @actor_id.nil?
      text=BS2Suite::Store.read('auto_stealth').strip
      @actor_id=text=~/\A[1-9][0-9]{0,3}\z/ ? text.to_i : 0
    end
    def toggle(actor)
      value=actor_id==actor.id ? 0 : actor.id
      return false unless BS2Suite::Store.write('auto_stealth',value.to_s)
      @actor_id=value;@reason=nil;true
    end
    def remaining;[$game_player.instance_variable_get(:@stealth_count).to_i,0].max;end
    def status
      return 'выключено' if actor_id==0
      return remaining.to_s+' шагов' if remaining>0
      @reason || 'ожидает применения'
    end
    def update(scene)
      return if actor_id==0 || !scene.is_a?(Scene_Map) || $game_party.in_battle || remaining>0
      return if $game_system.menu_disabled || $game_map.interpreter.running? || $game_message.busy? || $game_message.visible || scene.scene_changing? || $game_player.transfer? || $game_temp.common_event_reserved?
      actor=$game_party.members.find { |a| a.id==actor_id };skill=$data_skills[SKILL]
      return @reason='персонаж недоступен' unless actor
      return @reason='навык недоступен' unless actor.skills.include?(skill) && !actor.skill_seal.include?(skill.id)
      return @reason='не хватает MP или действует запрет' unless actor.usable?(skill)
      actor.use_item(skill)
      skill.repeats.times { actor.item_apply(actor,skill) } if skill.for_user?
      # The normal use path pays, applies the map stealth tag and reserves
      # common event 31; self targeting follows the native menu path.
      @reason=nil
      BS2Suite::Debug.emit('auto_stealth',{:actor=>actor.id,:skill=>SKILL,:steps=>remaining}) if defined?(BS2Suite::Debug)
    end
  end
end
class BS2Suite::FieldScene
  alias bs2v2_field_update update
  def update
    bs2v2_field_update
    if @item_window.active && Input.trigger?(:Z) && item && item.id==BS2Suite::AutoStealth::SKILL
      BS2Suite::AutoStealth.toggle(@actor) ? Sound.play_ok : Sound.play_buzzer
      @help_window.set_item(item);@item_window.refresh
    end
  end
end
class BS2Suite::FieldHelp
  alias bs2v2_field_item set_item
  def set_item(item)
    bs2v2_field_item(item)
    if item && item.id==BS2Suite::AutoStealth::SKILL
      set_text(BS2Suite::Keys.token(:Z)+' — автообновление: '+BS2Suite::AutoStealth.status+' · MP за каждое применение' + "\n"+item.description)
    end
  end
end
class Scene_Map
  alias bs2v2_auto_map_update update
  def update
    BS2Suite::AutoStealth.update(self)
    bs2v2_auto_map_update
    BS2Suite::AutoStealth.update(self)
  end
end
