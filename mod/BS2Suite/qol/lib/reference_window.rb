# encoding: UTF-8
class Window_BS2QReference < Window_Base
  attr_reader :card,:section,:offset,:lines
  def initialize(object,actor)
    super(8,8,Graphics.width-16,Graphics.height-16)
    self.z=500;self.opacity=0;self.contents_opacity=255
    @plate=Sprite.new;@plate.z=self.z-1;@plate.x=x;@plate.y=y
    @plate.bitmap=Bitmap.new(width,height)
    @plate.bitmap.fill_rect(0,0,width,height,Color.new(112,103,81))
    @plate.bitmap.fill_rect(1,1,width-2,height-2,Color.new(16,20,24))
    contents.font.name='Segoe UI' if Font.exist?('Segoe UI')
    @object=object;@actor=actor;@section=0;@offset=0
    rebuild
  end
  def rebuild
    @card=BS2QoL::ReferenceCard.new(@object,@actor,BS2QoL::Reference.language)
    @section=[@section,@card.sections.size-1].min
    @wrapped={};@offset=0
    refresh
  end
  def line_height;22;end
  def normal_color;Color.new(235,234,227);end
  def system_color;Color.new(218,196,150);end
  def dispose
    if @plate
      @plate.bitmap.dispose;@plate.dispose;@plate=nil
    end
    super
  end
  def page_size;((contents.height-112)/line_height).floor;end
  def wrap(text)
    # Measure actual glyphs; split long formulas as well as prose. Never shrink text.
    rows=[];line=''
    text.gsub(/\\[A-Za-z]+\[[^\]]*\]/,'').each_char do |char|
      if text_size(line+char).width>contents.width-16
        split=line.rindex(' ')
        if split && split>line.size/2
          rows << line[0,split];line=line[split+1,line.size].to_s+char
        else
          rows << line;line=char
        end
      else
        line+=char
      end
    end
    rows << line unless line.empty?
    rows.empty? ? [''] : rows
  end
  def refresh
    contents.clear;contents.font.size=18
    change_color(system_color);contents.font.size=20
    draw_icon(@object.respond_to?(:icon_index) ? @object.icon_index : 125,0,0)
    draw_text(30,0,contents.width-110,26,@card.title)
    draw_text(contents.width-72,0,72,26,@card.language.to_s.upcase,2)
    width=contents.width/@card.sections.size
    @card.section_names.each_with_index do |label,i|
      contents.fill_rect(i*width,32,width-4,26,Color.new(90,70,42,180)) if i==@section
      change_color(i==@section ? normal_color : system_color)
      draw_text(i*width+4,32,width-8,26,label,1)
    end
    contents.font.size=18;change_color(normal_color)
    @lines=@wrapped[@section] ||= @card.sections[@section].map { |s| wrap(s) }.flatten
    @offset=[[@offset,0].max,[@lines.size-page_size,0].max].min
    @lines[@offset,page_size].to_a.each_with_index { |text,i| draw_text(4,68+i*line_height,contents.width-8,line_height,text) }
    change_color(system_color);contents.font.size=15
    position=(@offset+1).to_s+'-'+[@offset+page_size,@lines.size].min.to_s+'/'+@lines.size.to_s
    draw_text(4,contents.height-44,contents.width-8,20,@card.t('←/→ раздел   ↑/↓ текст   Q/E страница','Left/Right section   Up/Down scroll   Q/E page'))
    draw_text(4,contents.height-24,contents.width-100,20,BS2Suite::Keys.token(:language)+' RU / EN · '+BS2Suite::Keys.token(:reference)+' / '+BS2Suite::Keys.token(:B)+' '+@card.t('закрыть','close'))
    draw_text(contents.width-96,contents.height-24,92,20,position,2)
    if BS2QoL::Reference.error
      draw_text(4,contents.height-44,contents.width-8,20,@card.t('Язык изменён; настройка не записана.','Language changed; preference could not be saved.'))
    end
  end
  def move_section(delta)
    @section=(@section+delta)%@card.sections.size;@offset=0;refresh
  end
  def scroll(delta);@offset+=delta;refresh;end
end

module BS2QoL
  module Reference
    class << self
      def active?(scene);!!scene.instance_variable_get(:@bs2q_reference_window);end
      def eligible?(scene,window)
        return false if scene.instance_variable_get(:@bs2q_binding_window)
        return false if $game_message && ($game_message.busy? || $game_message.visible)
        return false if scene.is_a?(Scene_Battle) && ![:skills,:items].include?(Hotkeys.context(scene))
        window.respond_to?(:item) && supported?(window.item) &&
          (window.is_a?(Window_ItemList) || window.is_a?(Window_SkillList) || window.is_a?(Window_BS2QCollection))
      end
      def open(scene,window)
        return false unless eligible?(scene,window)
        actor=if scene.is_a?(Scene_Battle)
          BattleManager.actor
        elsif scene.is_a?(Scene_ItemBase)
          scene.user
        else
          Hotkeys.actor_for(window)
        end
        popup=Window_BS2QReference.new(window.item,actor)
        window.deactivate
        scene.instance_variable_set(:@bs2q_reference_window,popup)
        scene.instance_variable_set(:@bs2q_reference_origin,window)
        Sound.play_ok
        true
      end
      def close(scene,restore=true)
        popup=scene.instance_variable_get(:@bs2q_reference_window)
        popup.dispose if popup && !popup.disposed?
        origin=scene.instance_variable_get(:@bs2q_reference_origin)
        origin.activate if restore && origin && !origin.disposed?
        scene.instance_variable_set(:@bs2q_reference_window,nil)
        scene.instance_variable_set(:@bs2q_reference_origin,nil)
        Keyboard.consume
        # Prevent close/cancel keys from reaching the reactivated list this frame.
        Input.update
      end
      def update(scene)
        popup=scene.instance_variable_get(:@bs2q_reference_window)
        return unless popup
        if Input.trigger?(:B) || Keyboard.first=='F7'
          close(scene);Sound.play_cancel
        elsif Keyboard.first=='F8'
          Keyboard.consume
          self.language=language==:ru ? :en : :ru
          popup.rebuild;Sound.play_cursor
        elsif Input.trigger?(:LEFT)
          popup.move_section(-1);Sound.play_cursor
        elsif Input.trigger?(:RIGHT)
          popup.move_section(1);Sound.play_cursor
        elsif Input.repeat?(:DOWN)
          popup.scroll(1)
        elsif Input.repeat?(:UP)
          popup.scroll(-1)
        elsif Input.trigger?(:R)
          popup.scroll(popup.page_size)
        elsif Input.trigger?(:L)
          popup.scroll(-popup.page_size)
        else
          Keyboard.consume
        end
      end
    end
  end
  module Hotkeys
    class << self
      alias bs2q_reference_handle handle
      def handle(window)
        scene=SceneManager.scene
        return true if Reference.active?(scene)
        if Keyboard.first=='F7' && Reference.eligible?(scene,window)
          Keyboard.consume
          return Reference.open(scene,window)
        end
        bs2q_reference_handle(window)
      end
      alias bs2q_reference_context context
      def context(scene)
        Reference.active?(scene) ? nil : bs2q_reference_context(scene)
      end
    end
  end
end

class Scene_Base
  alias bs2q_reference_update update_basic
  def update_basic
    bs2q_reference_update
    BS2QoL::Reference.update(self)
  end
  alias bs2q_reference_terminate terminate
  def terminate
    BS2QoL::Reference.close(self,false) if @bs2q_reference_window
    bs2q_reference_terminate
  end
end

# Keep the normal description intact, with a discoverable reference key in lists.
class Window_Help
  alias bs2q_reference_set_item set_item
  def set_item(item)
    if BS2QoL::Reference.supported?(item)
      prefix='['+BS2Suite::Keys.token(:reference)+(BS2QoL::Reference.language==:en ? ' Details] ' : ' Справка] ')
      set_text(prefix+item.description)
    else
      bs2q_reference_set_item(item)
    end
  end
end
