# encoding: UTF-8
class Window_BS2QCollection < Window_Selectable
  attr_reader :kind, :actor
  attr_accessor :only
  def initialize(x,y,width,height)
    @kind = :weapon; @actor = nil; @data = []; @manage = false; @only = false
    super(x,y,width,height)
    self.z = 240
  end
  def setup(kind,actor,manage)
    @kind = kind; @actor = actor; @manage = manage; @only = !manage
    refresh
    select(item_max > 0 ? 0 : -1)
  end
  def item; @data[index]; end
  def item_max; @data ? @data.size : 0; end
  def col_max; 1; end
  def refresh
    @data = BS2QoL::Model.collection(@kind,@actor)
    @data = BS2QoL::Model.ordered(@data,true,@kind) if @only
    create_contents
    draw_all_items
  end
  def enabled?(object)
    if @manage
      return BS2QoL::Preferences.favorite?(@kind,object.id) ||
        BS2QoL::Preferences.ids(@kind).size < BS2QoL::MAX_FAVORITES
    end
    BS2QoL::Model.weapon_enabled?(@actor,object)
  end
  def current_item_enabled?; item && enabled?(item); end
  def draw_item(index)
    object = @data[index]
    return unless object
    rect = item_rect_for_text(index)
    favorite = BS2QoL::Preferences.favorite?(@kind,object.id)
    current = @kind == :weapon && @actor && @actor.equips[0] == object
    change_color(favorite ? text_color(17) : normal_color,enabled?(object))
    draw_text(rect.x,rect.y,20,line_height,favorite ? '*' : '')
    draw_icon(object.icon_index,rect.x+20,rect.y,enabled?(object))
    draw_text(rect.x+48,rect.y,rect.width-140,line_height,object.name)
    suffix = current ? 'Надето' : (@kind == :skill ? '' : '×'+$game_party.item_number(object).to_s)
    draw_text(rect.x+rect.width-90,rect.y,90,line_height,suffix,2)
  end
  def update_help
    return unless @help_window
    if item && item.description.to_s.empty?
      names = item.is_a?(RPG::Weapon) ? item.features.select { |f| f.code==43 }.map { |f| $data_skills[f.data_id] }.compact.map { |s| s.name } : []
      @help_window.set_text(item.name+"\n"+(names.empty? ? 'Описание в игре отсутствует.' : 'Навыки: '+names.join(', ')))
    else
      @help_window.set_item(item)
    end
  end
  def process_handling
    return unless open? && active
    return if defined?(BS2QoL::Hotkeys) && BS2QoL::Hotkeys.handle(self)
    if Input.trigger?(:X) && item
      return toggle_selected
    elsif Input.trigger?(:Y)
      @only = !@only
      Sound.play_cursor
      refresh
      select(item_max > 0 ? 0 : -1)
      return
    end
    super
  end
  def toggle_selected(play_sound = true)
    return unless item
    object = item
    if BS2QoL::Preferences.toggle(@kind,object.id)
      Sound.play_ok if play_sound
      refresh
      select(@data.index(object) || (item_max > 0 ? 0 : -1))
      update_help
    else
      Sound.play_buzzer
    end
  end
end

class Window_BS2QFooter < Window_Base
  def initialize(y)
    super(0,y,Graphics.width,fitting_height(1))
    self.z = 260
    @last_text = nil
    hide
  end
  def show_hint(only,manage = false)
    text = BS2QoL::Preferences.error ? 'Не удалось записать настройки; избранное действует до выхода.' :
      (manage ? 'Enter/A: избранное · S: фильтр · F6: назначить · Esc: назад' : 'F6: назначить · A: избранное · S: '+(only ? 'показать всё' : 'только избранное'))
    text=BS2Suite.key_text(text)
    if text != @last_text
      contents.clear
      contents.font.size = 18
      draw_text(0,0,contents_width,line_height,text)
      @last_text = text
    end
    show
  end
end

class Window_BS2QPlan < Window_Base
  def initialize
    super(Graphics.width-400,0,400,fitting_height(6))
    self.z=220;@signature=nil;hide
  end
  def display(actor,editing=true,subject=nil)
    return hide unless actor && actor.actions.size>1
    rows=BS2QoL::Model.queue(actor)
    weapon=actor.equips[0]
    playing=!editing && subject==actor
    signature=[weapon && weapon.id,rows,editing,playing,defined?(BS2Suite::QueueEdit) ? BS2Suite::Performance.context(actor) : nil]
    if signature!=@signature
      shown=rows.take(6)
      row_height=editing ? 24 : 20
      target_height=(shown.size+3)*row_height+standard_padding*2
      desired_width=editing ? 400 : 264
      if self.width!=desired_width
        self.width=desired_width;create_contents
      end
      self.x=editing ? Graphics.width-desired_width : 0
      if self.height!=target_height
        self.height=target_height;create_contents
      end
      contents.clear;contents.font.size=editing ? 17 : 16
      change_color(system_color)
      draw_text(0,0,contents_width,row_height,(editing ? 'План · слотов: ' : 'Осталось действий: ')+rows.size.to_s)
      draw_text(0,row_height,contents_width,row_height,weapon ? weapon.name : 'Без оружия')
      shown.each_with_index do |row,i|
        current=editing && row[:current]
        executing=playing && i==0
        change_color(current || executing ? text_color(17) : normal_color)
        text=current && !actor.actions[i].item ? 'Выберите действие' : row[:name]
        text+=BS2Suite::QueueEdit.mp(actor,i) if defined?(BS2Suite::QueueEdit)
        unless !editing || current || row[:name]=='—'
          item=actor.actions[i].item
          target=if item && item.for_all?
            'все'
          elsif item && item.for_user?
            'на себя'
          elsif row[:target] && row[:target]>=0
            list=item && item.for_opponent? ? $game_troop.members : $game_party.battle_members
            member=list[row[:target]]
            member && member.name
          end
          text+=' → '+target.to_s if target
        end
        prefix=executing ? '> ' : (current ? '> ' : '  ')
        draw_text(0,row_height*(i+2),contents_width,row_height,prefix+(i+1).to_s+'. '+text)
      end
      change_color(system_color)
      note=rows.size>6 ? 'Ещё слотов: '+(rows.size-6).to_s : (editing ? 'Оружие применяется по правилам игры' : 'Порядок — по правилам игры')
      draw_text(0,row_height*(shown.size+2),contents_width,row_height,note)
      @signature=signature
    end
    show
  end
end

class Scene_BS2QFavorites < Scene_MenuBase
  def start
    super
    create_help_window
    @help_window.set_text('Избранное: отметьте оружие, навыки и предметы.\nПорядок добавления сохраняется между запусками.'.gsub('\\n',"\n"))
    # A small dedicated command list avoids changing native category windows.
    @tabs = Window_BS2QTabs.new(@help_window.height)
    @tabs.set_handler(:weapon,method(:open_weapon))
    @tabs.set_handler(:skill,method(:open_skill))
    @tabs.set_handler(:item,method(:open_item))
    @tabs.set_handler(:cancel,method(:return_scene))
    footer_height = 48
    @footer = Window_BS2QFooter.new(Graphics.height-footer_height)
    y = @tabs.y+@tabs.height
    @collection = Window_BS2QCollection.new(0,y,Graphics.width,Graphics.height-y-footer_height)
    @collection.help_window = @help_window
    @collection.set_handler(:ok,method(:toggle_item))
    @collection.set_handler(:cancel,method(:close_collection))
    @collection.setup(:weapon,@actor,true)
    @collection.deactivate
    @footer.show_hint(false,true)
  end
  def open_weapon; open_kind(:weapon); end
  def open_skill; open_kind(:skill); end
  def open_item; open_kind(:item); end
  def open_kind(kind)
    @collection.setup(kind,@actor,true)
    @collection.activate
  end
  def toggle_item
    @collection.toggle_selected(false)
    @collection.activate
  end
  def close_collection
    @collection.unselect
    @collection.deactivate
    @tabs.activate
  end
  def update
    super
    @footer.show_hint(@collection.only,true)
  end
end

class Window_BS2QTabs < Window_HorzCommand
  def initialize(y); super(0,y); end
  def window_width; Graphics.width; end
  def col_max; 3; end
  def make_command_list
    add_command('Оружие',:weapon)
    add_command('Навыки',:skill)
    add_command('Предметы',:item)
  end
end
