# encoding: UTF-8
module BS2QoL
  module Hotkeys
    class << self
      def active(scene,name)
        window=scene.instance_variable_get(name)
        window && !window.disposed? && window.active && window.open? ? window : nil
      end
      def context(scene)
        return nil unless scene.is_a?(Scene_Battle)
        return nil if scene.instance_variable_get(:@bs2q_binding_window)
        return nil if $game_message && ($game_message.busy? || $game_message.visible)
        return nil if scene.instance_variable_get(:@hzm_vxa_quickSkill_active)
        return nil unless BattleManager.actor && BattleManager.actor.input
        return nil if active(scene,:@actor_window) || active(scene,:@enemy_window)
        return :items if active(scene,:@item_window)
        return :skills if active(scene,:@skill_window)
        return :commands if active(scene,:@actor_command_window)
        nil
      end
      def list?(window)
        window.is_a?(Window_BS2QCollection) ||
          (window.respond_to?(:bs2q_supported?) && window.bs2q_supported?)
      end
      def handle(window)
        return false unless BS2Suite.enabled?('combat_shortcuts')
        key=Keyboard.first
        return false unless key
        scene=SceneManager.scene
        return true if scene.instance_variable_get(:@bs2q_binding_window)
        if key=='F6' && list?(window)
          Keyboard.consume
          return open_binding(scene,window)
        end
        return false unless scene.is_a?(Scene_Battle)
        ctx=context(scene)
        return false unless ctx
        actor=BattleManager.actor
        binding=nil
        if ctx==:commands && /\A[1-6]\z/ =~ key
          Keyboard.consume
          symbols={ '1'=>:attack,'2'=>:skill,'3'=>:guard,'4'=>:item,'5'=>:escape,'6'=>:equip_change }
          return scene.bs2q_command(symbols[key])
        elsif /\AS[1-9]\z/ =~ key
          scope=ctx==:commands ? 'weapons' : (ctx==:items ? 'items' : Bindings.weapon_scope(actor))
          binding=Bindings.get(scope,key,actor)
        elsif /\AC[1-9]\z/ =~ key
          binding=Bindings.get('quick',key,actor)
          binding=nil if binding && ((ctx==:items && binding[0]!=:item) || (ctx==:skills && binding[0]!=:skill))
        else
          return false
        end
        Keyboard.consume
        if binding
          scene.bs2q_apply_binding(binding,ctx)
        else
          notice('Слот '+Bindings.label(key)+' не назначен')
          Sound.play_buzzer
        end
        true
      end
      def notice(text)
        @notice=text;@notice_until=Graphics.frame_count+100
      end
      def current_notice
        @notice if @notice_until && Graphics.frame_count<@notice_until
      end
      def actor_for(window)
        window.instance_variable_get(:@actor) || ($game_party && $game_party.menu_actor)
      end
      def open_binding(scene,window)
        object=window.item
        unless object && Model.kind(object)
          Sound.play_buzzer
          return true
        end
        actor=actor_for(window)
        window.deactivate
        popup=Window_BS2QBinding.new(object,actor)
        scene.instance_variable_set(:@bs2q_binding_window,popup)
        scene.instance_variable_set(:@bs2q_binding_origin,window)
        Sound.play_ok
        true
      end
      def update_modal(scene)
        popup=scene.instance_variable_get(:@bs2q_binding_window)
        return unless popup
        if Input.trigger?(:B)
          close_binding(scene)
        elsif Keyboard.first=='DELETE'
          Keyboard.consume
          scopes=popup.kind==:weapon ? ['weapons'] : [popup.kind==:item ? 'items' : Bindings.weapon_scope(popup.actor),'quick']
          scopes.each { |scope| Bindings.remove(scope,popup.kind,popup.object.id) }
          Sound.play_ok
          close_binding(scene)
        elsif Keyboard.first && /\A[SC][1-9]\z/ =~ Keyboard.first
          key=Keyboard.first;Keyboard.consume
          scope=if popup.kind==:weapon
            key[0,1]=='S' ? 'weapons' : nil
          elsif key[0,1]=='C'
            'quick'
          else
            popup.kind==:item ? 'items' : Bindings.weapon_scope(popup.actor)
          end
          if scope && Bindings.valid?(scope,key,popup.kind,popup.object.id)
            popup.propose(scope,key)
            Sound.play_cursor
          else
            Sound.play_buzzer
          end
        elsif Input.trigger?(:C) && popup.pending
          scope,key=popup.pending
          Bindings.set(scope,key,popup.kind,popup.object.id)
          Sound.play_ok
          close_binding(scene)
        end
      end
      def close_binding(scene)
        popup=scene.instance_variable_get(:@bs2q_binding_window)
        popup.dispose if popup && !popup.disposed?
        origin=scene.instance_variable_get(:@bs2q_binding_origin)
        origin.activate if origin && !origin.disposed?
        scene.instance_variable_set(:@bs2q_binding_window,nil)
        scene.instance_variable_set(:@bs2q_binding_origin,nil)
      end
      def hint_entries(scope,actor,kind=nil)
        Bindings.ensure_scope(scope,actor).keys.sort.map do |key|
          binding=Bindings.get(scope,key,actor)
          next if kind && binding[0]!=kind
          object=Bindings.object(binding)
          next unless object
          name=object.name
          name+=' ×'+$game_party.item_number(object).to_s if binding[0]==:item
          [Bindings.label(key),name]
        end.compact
      end
    end
  end
end

class Window_Selectable
  alias bs2q_keys_base_handling process_handling
  def process_handling
    return if open? && active && BS2QoL::Hotkeys.handle(self)
    bs2q_keys_base_handling
  end
end

class Scene_Base
  alias bs2q_keys_base_update_basic update_basic
  def update_basic
    bs2q_keys_base_update_basic
    BS2QoL::Hotkeys.update_modal(self)
  end
  alias bs2q_keys_base_terminate terminate
  def terminate
    BS2QoL::Hotkeys.close_binding(self) if @bs2q_binding_window
    bs2q_keys_base_terminate
  end
end

class Scene_Battle
  def bs2q_command(symbol)
    index=@actor_command_window.instance_variable_get(:@list).index { |r| r[:symbol]==symbol }
    unless index
      BS2QoL::Hotkeys.notice('Команда сейчас недоступна')
      Sound.play_buzzer
      return true
    end
    @actor_command_window.select(index)
    @actor_command_window.process_ok
    true
  end
  def bs2q_apply_binding(binding,context)
    kind,id=binding
    actor=BattleManager.actor
    object=BS2QoL::Bindings.object(binding)
    if kind==:weapon
      if BS2QoL::Model.change_weapon(actor,object)
        Sound.play_equip
        @actor_command_window.refresh
        refresh_status
        BS2QoL::Hotkeys.notice('Оружие: '+object.name)
      else
        Sound.play_buzzer
        BS2QoL::Hotkeys.notice('Смена оружия сейчас недоступна')
      end
      return true
    end
    symbol=kind==:item ? :item : :skill
    rows=@actor_command_window.instance_variable_get(:@list)
    row=rows.find { |r| r[:symbol]==symbol }
    usable=object && row && row[:enabled]
    usable &&= actor.skills.include?(object) && !actor.skill_seal.include?(object.id) && actor.usable?(object) if kind==:skill
    usable &&= $game_party.item_number(object)>0 && $game_party.usable?(object) if kind==:item
    unless usable
      Sound.play_buzzer
      BS2QoL::Hotkeys.notice(object ? 'Недоступно: '+object.name : 'Объект отсутствует')
      return true
    end
    if context==:commands
      index=rows.index(row)
      @actor_command_window.select(index)
      @actor_command_window.deactivate
      kind==:item ? command_item : command_skill
    end
    window=kind==:item ? @item_window : @skill_window
    window.bs2q_only=false
    window.bs2q_all_types=true if kind==:skill
    window.refresh
    index=window.instance_variable_get(:@data).index(object)
    unless index
      Sound.play_buzzer
      return true
    end
    @bs2q_shortcut_origin=context==:commands ? kind : nil
    @bs2q_auto_target=true
    window.select(index)
    window.process_ok
    true
  ensure
    @bs2q_auto_target=false
  end
  alias bs2q_native_on_enemy_cancel on_enemy_cancel
  def on_enemy_cancel
    origin=@bs2q_shortcut_origin
    bs2q_native_on_enemy_cancel
    if origin
      origin==:skill ? on_skill_cancel : on_item_cancel
      @skill_window.deactivate
      @item_window.deactivate
      @bs2q_shortcut_origin=nil
    end
  end
  alias bs2q_native_on_actor_cancel on_actor_cancel
  def on_actor_cancel
    origin=@bs2q_shortcut_origin
    bs2q_native_on_actor_cancel
    if origin
      origin==:skill ? on_skill_cancel : on_item_cancel
      @skill_window.deactivate
      @item_window.deactivate
      @bs2q_shortcut_origin=nil
    end
  end
end

class Window_BS2QBinding < Window_Base
  attr_reader :object,:actor,:kind,:pending
  def initialize(object,actor)
    @object=object;@actor=actor;@kind=BS2QoL::Model.kind(object);@pending=nil
    super(40,(Graphics.height-216)/2,Graphics.width-80,216)
    self.z=400
    redraw
  end
  def propose(scope,key)
    @pending=[scope,key]
    redraw
  end
  def redraw
    contents.clear
    contents.font.size=19
    change_color(system_color)
    draw_text(0,0,contents_width,24,'Назначить: '+@object.name)
    change_color(normal_color)
    line=@kind==:weapon ? 'Shift+1…9: смена оружия из боевых команд' :
      (@kind==:item ? 'Shift+1…9: из предметов · Ctrl+1…9: напрямую' :
      'Shift+1…9: для этого оружия · Ctrl+1…9: общий слот')
    draw_text(0,32,contents_width,24,line)
    draw_text(0,58,contents_width,24,BS2Suite.key_text('Нажмите сочетание, затем Enter. Esc — отмена.'))
    draw_text(0,84,contents_width,24,'Delete — убрать назначения выбранного объекта.')
    if @pending
      scope,key=@pending
      previous=BS2QoL::Bindings.object(BS2QoL::Bindings.get(scope,key,@actor))
      change_color(text_color(17))
      draw_text(0,118,contents_width,24,BS2QoL::Bindings.label(key)+' → '+@object.name)
      change_color(normal_color)
      draw_text(0,144,contents_width,24,previous ? 'Заменит: '+previous.name+' · '+BS2Suite::Keys.token(:C)+' — подтвердить' : BS2Suite::Keys.token(:C)+' — сохранить назначение')
    end
  end
end

class Window_BS2QKeyHints < Window_Base
  def initialize(y)
    super(0,y,Graphics.width,84)
    self.z=260;@signature=nil;hide
  end
  def display(scene,actor,context)
    return hide unless actor
    left=context==:commands ? scene.instance_variable_get(:@actor_command_window).width : 0
    desired_width=Graphics.width-left
    if self.x!=left || self.width!=desired_width
      self.x=left;self.width=desired_width;create_contents;@signature=nil
    end
    if context==:commands
      top='Shift: оружие · Ctrl: приём · Ctrl+Shift: авто'
      first=BS2QoL::Hotkeys.hint_entries('weapons',actor)
      second=BS2QoL::Hotkeys.hint_entries('quick',actor)
    elsif context==:items
      top='Предметы: Shift+цифра · Ctrl+цифра напрямую · F6 назначить · A избранное'
      first=BS2QoL::Hotkeys.hint_entries('items',actor)
      second=BS2QoL::Hotkeys.hint_entries('quick',actor,:item)
    else
      top='Ctrl: приём для оружия / общий навык · F6 назначить'
      first=BS2QoL::Hotkeys.hint_entries(BS2QoL::Bindings.weapon_scope(actor),actor)
      second=BS2QoL::Hotkeys.hint_entries('quick',actor,:skill)
    end
    top=BS2Suite.key_text(top)
    notice=BS2QoL::Hotkeys.current_notice
    notice='Запись не удалась; прежнее назначение сохранено.' if BS2QoL::Bindings.error
    signature=[top,first,second,notice]
    if signature!=@signature
      contents.clear;contents.font.size=15
      change_color(system_color)
      draw_text(0,0,contents_width,18,notice || top)
      change_color(normal_color)
      [first,second].each_with_index do |entries,row|
        if entries.empty?
          draw_text(0,18*(row+1),contents_width,18,'F6 на выбранной строке — назначить клавиши')
        else
          columns=self.width<600 ? 2 : 3
          entries.take(columns).each_with_index do |entry,i|
            text=entry.join(' ')
            text+=' …' if i==columns-1 && entries.size>columns
            draw_text(i*contents_width/columns,18*(row+1),contents_width/columns-4,18,text)
          end
        end
      end
      @signature=signature
    end
    show
  end
end

