# encoding: UTF-8
module BS2Suite
  class FieldList < Window_SkillList
    def include?(skill);skill && [0,2].include?(skill.occasion) && @actor && !@actor.skill_seal.include?(skill.id);end
    def make_item_list
      super
      @data.reject! { |skill| !skill || ![0,2].include?(skill.occasion) || !@actor || !@actor.skills.include?(skill) || @actor.skill_seal.include?(skill.id) }
    end
  end
  class FieldHelp < Window_Help
    def set_item(item)
      super
      set_text('Полевые навыки · Q/E персонаж · Esc назад'+"\n"+@text.to_s)
    end
  end
  class FieldScene < Scene_Skill
    def create_help_window
      @help_window=FieldHelp.new;@help_window.viewport=@viewport;BS2Modules.style(@help_window)
    end
    def create_status_window
      super
      @status_window.x=0;@status_window.width=Graphics.width;@status_window.create_contents
      BS2Modules.style(@status_window);@status_window.refresh
    end
    def start
      super
      @command_window.hide.deactivate
      @item_window.refresh;@item_window.activate;@item_window.select(0)
      @help_window.set_text('Полевые навыки · Q/E персонаж · Enter применить · Esc назад') unless item
    end
    def create_item_window
      y=@status_window.y+@status_window.height
      @item_window=FieldList.new(0,y,Graphics.width,Graphics.height-y)
      @item_window.actor=@actor;@item_window.viewport=@viewport
      BS2Modules.style(@item_window)
      @item_window.help_window=@help_window
      @item_window.set_handler(:ok,method(:on_item_ok))
      @item_window.set_handler(:cancel,method(:return_scene))
      @item_window.set_handler(:pageup,method(:prev_actor))
      @item_window.set_handler(:pagedown,method(:next_actor))
      @command_window.skill_window=@item_window
    end
    def on_actor_change
      @status_window.actor=@actor;@item_window.actor=@actor
      @command_window.actor=@actor;@command_window.hide.deactivate
      @item_window.refresh;@item_window.select(0);@item_window.activate
    end
  end
end
class Window_MenuCommand
  alias bs2suite_field_menu add_original_commands
  def add_original_commands
    bs2suite_field_menu;add_command('Полевые навыки',:bs2suite_field,main_commands_enabled)
  end
end
class Scene_Menu
  alias bs2suite_field_commands create_command_window
  def create_command_window
    bs2suite_field_commands
    @command_window.set_handler(:bs2suite_field,lambda { SceneManager.call(BS2Suite::FieldScene) })
  end
end
class Scene_Map
  alias bs2suite_field_update update
  def update
    bs2suite_field_update
    if BS2Suite::Keys.trigger?(:field) && !$game_system.menu_disabled && !$game_map.interpreter.running? && !$game_message.busy? && !$game_player.moving? && !scene_changing?
      Sound.play_ok;SceneManager.call(BS2Suite::FieldScene)
    end
  end
end
