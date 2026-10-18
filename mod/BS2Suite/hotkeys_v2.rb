# encoding: UTF-8
module BS2QoL::Hotkeys
  class << self
    def handle(window)
      return false unless BS2Suite.enabled?('combat_shortcuts') || BS2Suite.enabled?('semantic_groups') || BS2Suite.enabled?('legacy_shortcuts')
      key=BS2QoL::Keyboard.first;return false unless key
      scene=SceneManager.scene
      return true if scene.instance_variable_get(:@bs2q_binding_window)
      if key=='F6' && list?(window)
        BS2QoL::Keyboard.consume;return open_binding(scene,window)
      end
      return false unless scene.is_a?(Scene_Battle)
      ctx=context(scene);return false unless ctx
      actor=BattleManager.actor
      if ctx==:commands && /\A[1-6]\z/=~key
        BS2QoL::Keyboard.consume
        return scene.bs2q_command({'1'=>:attack,'2'=>:skill,'3'=>:guard,'4'=>:item,'5'=>:escape,'6'=>:equip_change}[key])
      elsif BS2Suite.enabled?('legacy_shortcuts') && /\ACS[0-9]\z/=~key
        binding=BS2QoL::Bindings.get('cast',key,actor)
      elsif BS2Suite.enabled?('legacy_shortcuts') && /\AS[0-9]\z/=~key
        scope=ctx==:commands ? 'weapons' : ctx==:items ? 'items' : BS2QoL::Bindings.weapon_scope(actor)
        binding=BS2QoL::Bindings.get(scope,key,actor)
      elsif BS2Suite.enabled?('legacy_shortcuts') && /\AC[0-9]\z/=~key
        binding=ctx==:items ? BS2QoL::Bindings.ensure_scope('quick',actor)[key] : BS2QoL::Bindings.get('quick',key,actor)
        binding=nil if binding && ((ctx==:items && binding[0]!=:item) || (ctx==:skills && binding[0]!=:skill))
      else
        return false
      end
      BS2QoL::Keyboard.consume
      if binding
        if key.start_with?('CS')
          scene.bs2v2_cast(binding,ctx)
        else
          scene.bs2q_apply_binding(binding,ctx)
        end
      else
        notice('Слот '+BS2QoL::Bindings.label(key)+' не назначен');Sound.play_buzzer
      end
      true
    end
    def update_modal(scene)
      popup=scene.instance_variable_get(:@bs2q_binding_window);return unless popup
      key=BS2QoL::Keyboard.first
      if Input.trigger?(:B)
        close_binding(scene)
      elsif key=='DELETE'
        BS2QoL::Keyboard.consume
        scopes=popup.kind==:weapon ? ['weapons'] : popup.kind==:item ? ['items','quick'] : [BS2QoL::Bindings.weapon_scope(popup.actor),'quick','cast']
        scopes.each { |scope| BS2QoL::Bindings.remove(scope,popup.kind,popup.object.id) }
        Sound.play_ok;close_binding(scene)
      elsif key && /\A(?:CS|S|C)[0-9]\z/=~key
        BS2QoL::Keyboard.consume
        scope=if popup.kind==:weapon
          key.start_with?('S') ? 'weapons' : nil
        elsif key.start_with?('CS')
          popup.kind==:skill && BS2QoL::Bindings.source_weapon(popup.actor,popup.object) ? 'cast' : nil
        elsif key.start_with?('C')
          popup.kind==:skill ? BS2QoL::Bindings.skill_scope(popup.actor,popup.object) : 'quick'
        else
          popup.kind==:item ? 'items' : BS2QoL::Bindings.weapon_scope(popup.actor)
        end
        if scope && BS2QoL::Bindings.valid?(scope,key,popup.kind,popup.object.id)
          popup.propose(scope,key);Sound.play_cursor
        else
          notice('Для автосмены нужна принадлежащая вам пушка с этой техникой');Sound.play_buzzer
        end
      elsif Input.trigger?(:C) && popup.pending
        scope,key=popup.pending
        source=scope=='cast' ? BS2QoL::Bindings.source_weapon(popup.actor,popup.object) : nil
        if BS2QoL::Bindings.set(scope,key,popup.kind,popup.object.id,source && source.id)
          Sound.play_ok;close_binding(scene)
        else
          Sound.play_buzzer
        end
      end
    end
    alias bs2v2_hint_entries hint_entries
    def hint_entries(scope,actor,kind=nil)
      if scope=='quick'
        BS2QoL::Bindings.migrate_quick(actor)
        keys=(BS2QoL::Bindings.ensure_scope('quick',actor).keys+BS2QoL::Bindings.ensure_scope(BS2QoL::Bindings.weapon_scope(actor),actor).keys.grep(/\AC/)).uniq.sort
        return keys.map do |key|
          value=BS2QoL::Bindings.get('quick',key,actor);object=BS2QoL::Bindings.object(value)
          next unless object && (!kind || value[0]==kind)
          [BS2QoL::Bindings.label(key),object.name+(value[0]==:item ? ' ×'+$game_party.item_number(object).to_s : '')]
        end.compact
      end
      bs2v2_hint_entries(scope,actor,kind)
    end
  end
end
class Scene_Battle
  def bs2v2_cast(binding,context)
    actor=BattleManager.actor;skill=BS2QoL::Bindings.object(binding)
    unless context==:commands && actor && skill && !actor.skill_seal.include?(skill.id)
      BS2QoL::Hotkeys.notice('Автосмена: вернитесь к командам; скрытые техники недоступны');Sound.play_buzzer;return true
    end
    weapon=BS2Suite::WeaponFamilies.resolve(binding[2],actor,skill.id) if binding[2]
    unless weapon && (weapon==actor.equips[0] || BS2QoL::Model.weapon_enabled?(actor,weapon))
      BS2QoL::Hotkeys.notice('Нет подходящего оружия или смена запрещена');Sound.play_buzzer;return true
    end
    old=actor.equips[0];resources=[actor.hp,actor.mp,actor.tp]
    changed=weapon!=old
    return true if changed && !BS2QoL::Model.change_weapon(actor,weapon)
    usable=actor.skills.include?(skill) && actor.usable?(skill)
    unless usable
      if changed
        flag=$game_temp.battle_equip
        begin
          $game_temp.battle_equip=true;actor.change_equip(0,old)
        ensure
          $game_temp.battle_equip=flag
        end
        actor.hp,actor.mp,actor.tp=resources
      end
      BS2QoL::Hotkeys.notice('Техника недоступна: ресурсы, КД или ограничение');Sound.play_buzzer;return true
    end
    @actor_command_window.refresh;refresh_status
    BS2QoL::Hotkeys.notice(weapon.name+' → '+skill.name)
    bs2q_apply_binding([:skill,skill.id],context)
  end
  alias bs2v2_select_enemy select_enemy_selection
  def select_enemy_selection
    bs2v2_select_enemy
    if @enemy_window.active && @enemy_window.item_max==1
      @enemy_window.select(0);@enemy_window.deactivate;on_enemy_ok
    end
  end
end
class Window_BS2QBinding
  alias bs2v2_binding_init initialize
  def initialize(object,actor)
    bs2v2_binding_init(object,actor)
    self.opacity=0;self.contents_opacity=255
    @bs2v2_plate=Sprite.new;@bs2v2_plate.z=self.z-1;@bs2v2_plate.x=x;@bs2v2_plate.y=y
    @bs2v2_plate.bitmap=Bitmap.new(width,height)
    @bs2v2_plate.bitmap.fill_rect(0,0,width,height,Color.new(112,103,81))
    @bs2v2_plate.bitmap.fill_rect(1,1,width-2,height-2,Color.new(16,20,24))
  end
  alias bs2v2_binding_dispose dispose
  def dispose
    if @bs2v2_plate
      @bs2v2_plate.bitmap.dispose;@bs2v2_plate.dispose;@bs2v2_plate=nil
    end
    bs2v2_binding_dispose
  end
  def redraw
    contents.clear;contents.font.size=18;change_color(system_color)
    draw_text(0,0,contents_width,24,'Назначить: '+@object.name)
    change_color(normal_color)
    lines=if @kind==:weapon
      ['Shift+0…9 — оружие; привязка переживает заточку.']
    elsif @kind==:item
      ['Ctrl+0…9 — общий слот; Shift+0…9 — список предметов.']
    else
      scope=BS2QoL::Bindings.skill_scope(@actor,@object)
      ['Ctrl+0…9 — '+(scope=='quick' ? 'общий навык' : 'профиль текущего оружия')+'.','Ctrl+Shift+0…9 — сменить оружие и выбрать технику.']
    end
    lines.each_with_index { |line,i| draw_text(0,30+i*24,contents_width,24,line) }
    draw_text(0,82,contents_width,24,BS2Suite.key_text('Сочетание → Enter · Esc отмена · Delete удалить'))
    if @pending
      scope,key=@pending;previous=BS2QoL::Bindings.object(BS2QoL::Bindings.ensure_scope(scope,@actor)[key])
      label=scope=='cast' ? BS2QoL::Bindings.source_weapon(@actor,@object).name+' → ' : scope.start_with?('weapon') ? 'Для этого оружия: ' : 'Общее: '
      change_color(text_color(17));draw_text(0,116,contents_width,24,BS2QoL::Bindings.label(key)+' → '+@object.name)
      contents.font.size=16;draw_text(0,142,contents_width,24,label)
      draw_text(0,166,contents_width,24,previous ? 'Заменит: '+previous.name : 'Свободный слот · Enter сохранить')
    end
  end
end
