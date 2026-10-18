# encoding: UTF-8
class Scene_Battle
  alias bs2suite_windows create_all_windows
  def create_all_windows
    bs2suite_windows
    if (BS2Suite.enabled?('combat_shortcuts') || BS2Suite.enabled?('semantic_groups') || BS2Suite.enabled?('legacy_shortcuts'))
      y=@info_viewport.rect.y-84
      @bs2q_footer=Window_BS2QKeyHints.new(y)
      [@skill_window,@item_window].each { |w| w.height=y-w.y;w.create_contents }
    end
    @bs2q_plan=Window_BS2QPlan.new if BS2Suite.enabled?('action_queue')
  end
  alias bs2suite_skill command_skill
  def command_skill
    @skill_window.bs2q_only=false if @skill_window.respond_to?(:bs2q_only=)
    @skill_window.bs2q_all_types=true if (BS2Suite.enabled?('combat_shortcuts') || BS2Suite.enabled?('semantic_groups') || BS2Suite.enabled?('legacy_shortcuts'))
    bs2suite_skill
  end
  alias bs2suite_item command_item
  def command_item
    @item_window.bs2q_only=false if @item_window.respond_to?(:bs2q_only=)
    bs2suite_item
  end
  alias bs2suite_actor_selection start_actor_command_selection
  def start_actor_command_selection
    @bs2q_shortcut_origin=nil;bs2suite_actor_selection
  end
  alias bs2suite_battle_update update_basic
  def update_basic
    bs2suite_battle_update
    actor=BattleManager.actor
    @bs2q_queue_actor=actor if actor
    context=BS2QoL::Hotkeys.context(self)
    if @bs2q_footer
      context ? @bs2q_footer.display(self,actor,context) : @bs2q_footer.hide
    end
    return unless @bs2q_plan
    quick=defined?(HZM_VXA::QuickSkill) && HZM_VXA::QuickSkill.quickSkill?
    editing=context==:commands;executing=BattleManager.in_turn? && !quick
    if editing || executing
      @bs2q_plan.display(@bs2q_queue_actor,editing,@subject)
      bottom=@log_window.y+@log_window.standard_padding+@log_window.line_number*@log_window.line_height
      @bs2q_plan.y=editing ? 0 : [[bottom,72].max,@info_viewport.rect.y-@bs2q_plan.height].min
    else;@bs2q_plan.hide;end
  end
end
