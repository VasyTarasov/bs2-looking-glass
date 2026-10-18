# encoding: UTF-8
# Follow-up UI and lifecycle corrections. Loaded after optional modules.
module BS2QoL::Hotkeys
  class << self
    def notice(text)
      @notice=text;@notice_tick=Win32API.new('kernel32','GetTickCount',[],'L').call
      @notice_frame=Graphics.frame_count;@notice_until=@notice_frame+100
    end
    def clear_notice;@notice=nil;@notice_tick=nil;@notice_until=nil;end
    def current_notice
      return nil unless @notice && @notice_tick
      now=Win32API.new('kernel32','GetTickCount',[],'L').call
      if ((now-@notice_tick)&0xffffffff)>=1700 || Graphics.frame_count<@notice_frame
        clear_notice;return nil
      end
      @notice
    end
  end
end
module DataManager
  class << self
    alias bs2080_extract extract_save_contents
    def extract_save_contents(contents)
      BS2QoL::Hotkeys.clear_notice
      bs2080_extract(contents)
    end
  end
end
# Some native battle paths update the same command window twice per frame.
class Window_ActorCommand
  alias bs2080_cursor_move process_cursor_move
  def process_cursor_move
    return if @bs2080_cursor_frame==Graphics.frame_count
    @bs2080_cursor_frame=Graphics.frame_count
    bs2080_cursor_move
  end
end
if BS2Suite.enabled?('semantic_groups')
  module BS2Suite::Semantic
    class << self
      def acknowledged_layouts
        @acknowledged_layouts ||= BS2Suite::Store.read('layout_seen',131072).lines.map { |l| l.strip }.select { |l| l=~/\A[0-9A-Za-z:_,.\-]+\z/ }.take(512)
      end
      def layout_stamp(actor,prefix)
        layout=state['layouts'][layout_key(actor,prefix)]
        return '' unless layout
        layout_key(actor,prefix)+':'+layout['groups'].map { |g| g['keys'].join(',') }.join('.')
      end
      alias bs2080_pending_moves pending_moves
      def pending_moves(actor,prefix)
        return [] if acknowledged_layouts.include?(layout_stamp(actor,prefix))
        bs2080_pending_moves(actor,prefix)
      end
      alias bs2080_acknowledge acknowledge
      def acknowledge(actor,prefix)
        stamp=layout_stamp(actor,prefix)
        unless stamp.empty? || acknowledged_layouts.include?(stamp)
          acknowledged_layouts<<stamp
          acknowledged_layouts.shift while acknowledged_layouts.size>256 || acknowledged_layouts.join("\n").bytesize>120000
          BS2Suite::Store.write('layout_seen',acknowledged_layouts.join("\n")+"\n")
        end
        bs2080_acknowledge(actor,prefix)
      end
    end
  end
end
# Shop buy windows expose their item through @data[index], not item().
if BS2Suite.enabled?('reference_cards')
  class Window_ShopBuy
    def item;@data && @data[index];end
  end
  # Direct F7 also works while selecting an ally target.
  module BS2QoL::Reference
    class << self
      alias bs2080_object_for object_for
      def object_for(window)
        return window.actor if window.is_a?(Window_BattleActor) && window.respond_to?(:actor)
        bs2080_object_for(window)
      end
    end
  end
end
# Only presentation time changes. Costs, quick-item limits and target effects
# stay in the native use_item/invoke_item pipeline.
if BS2Suite.enabled?('run_toggle')
  class Scene_Battle
    alias bs2080_use_item use_item
    def use_item
      object=@subject && @subject.current_action && @subject.current_action.item
      @bs2080_fast_item=BS2Suite::Options.get('fast_items')==1 && object.is_a?(RPG::Item) && !object.effects.any? { |e| e.code==44 }
      bs2080_use_item
    ensure
      @bs2080_fast_item=false
    end
    alias bs2080_base_wait base_wait
    def base_wait(duration);@bs2080_fast_item ? (duration>0 ? 1 : 0) : bs2080_base_wait(duration);end
    alias bs2080_show_animation show_animation
    def show_animation(targets,animation_id)
      return if @bs2080_fast_item
      bs2080_show_animation(targets,animation_id)
    end
  end
end
BS2Suite.load_part('soul_batch') if BS2Suite.enabled?('soul_batch')
BS2Suite.load_part('equipped_upgrade') if BS2Suite.enabled?('equipped_upgrade')
BS2Suite.load_part('equipment_details') if BS2Suite.enabled?('reference_cards')
BS2Suite.load_part('combat_effects') if BS2Suite.enabled?('effects')

# Native BattleCommand_Custom expects [text, icon], even for added commands.
class Window_ActorCommand
  alias bs2080_command_names make_command_list
  def make_command_list
    bs2080_command_names
    @list.reject! { |row| [:bs2_enemy_info,:bs2modules_effects].include?(row[:symbol]) }
    @list.each do |row|
      if row[:symbol]==:bs2_enemy_info
        row[:name]=[BS2Suite::Keys.token(:enemy_info)+' Враги',137]
      elsif row[:symbol]==:bs2modules_effects
        row[:name]=['Эффекты героя',125]
      elsif row[:name].is_a?(String)
        row[:name]=[row[:name],0]
      end
    end
  end
end
