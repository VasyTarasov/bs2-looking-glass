# encoding: UTF-8
class Window_ItemList
  include BS2QoL::ListControls
  alias bs2q_original_make_item_list make_item_list
  def make_item_list
    bs2q_original_make_item_list
    kind = is_a?(Window_BattleItem) ? :item : nil
    @data = BS2QoL::Model.ordered(@data,@bs2q_only,kind) if bs2q_supported?
    @data.reject! { |object| object.respond_to?(:occasion) && ![0,1].include?(object.occasion) } if $game_party.in_battle
  end
  alias bs2q_original_draw_item draw_item
  def draw_item(index)
    bs2q_original_draw_item(index)
    bs2q_mark(index) if bs2q_supported?
  end
  alias bs2q_original_process_handling process_handling
  def process_handling
    return if bs2q_inputs
    bs2q_original_process_handling
  end
end

class Window_BattleItem
  alias bs2q_original_enable? enable?
  def enable?(item)
    return false if @bs2q_only && (!item || $game_party.item_number(item) <= 0)
    bs2q_original_enable?(item)
  end
end

class Window_SkillList
  include BS2QoL::ListControls
  alias bs2q_original_include? include?
  def include?(item)
    if item && @actor && @actor.respond_to?(:skill_seal) && @actor.skill_seal.include?(item.id)
      return bs2q_original_include?(item) if @stype_id==AB_SSS2::STI && !$game_party.in_battle && !@bs2q_all_types && !@bs2q_only
      return false
    end
    return false if item && $game_party.in_battle && ![0,1].include?(item.occasion)
    return item && BS2QoL::Preferences.favorite?(:skill,item.id) if @bs2q_only
    return item && (!$game_party.in_battle || [0,1].include?(item.occasion)) if @bs2q_all_types
    bs2q_original_include?(item)
  end
  alias bs2q_original_make_item_list make_item_list
  def make_item_list
    bs2q_original_make_item_list
    @data = BS2QoL::Model.ordered(@data,@bs2q_only,:skill) if bs2q_supported?
    @data.select! { |object| object && include?(object) }
    @data.reject! { |object| object && ![0,1].include?(object.occasion) } if $game_party.in_battle
  end
  alias bs2q_original_enable? enable?
  def enable?(skill)
    return false if @bs2q_only && (!@actor || !@actor.skills.include?(skill))
    bs2q_original_enable?(skill)
  end
  alias bs2q_original_draw_item draw_item
  def draw_item(index)
    bs2q_original_draw_item(index)
    bs2q_mark(index) if bs2q_supported?
  end
  alias bs2q_original_process_handling process_handling
  def process_handling
    return if bs2q_inputs
    bs2q_original_process_handling
  end
end

class Window_MenuCommand
  alias bs2q_original_add_original_commands add_original_commands
  def add_original_commands
    bs2q_original_add_original_commands
    add_command('Избранное',:bs2q_favorites,main_commands_enabled) if BS2Suite.enabled?('combat_shortcuts')
  end
end
class Scene_Menu
  alias bs2q_original_create_command_window create_command_window
  def create_command_window
    bs2q_original_create_command_window
    @command_window.set_handler(:bs2q_favorites,method(:bs2q_open_favorites))
  end
  def bs2q_open_favorites; SceneManager.call(Scene_BS2QFavorites); end
end

class Window_EquipItem
  alias bs2q_equip_original_make_item_list make_item_list
  def make_item_list
    bs2q_equip_original_make_item_list
    @data=BS2QoL::Model.ordered(@data,@bs2q_only,:weapon) if bs2q_supported?
  end
end

