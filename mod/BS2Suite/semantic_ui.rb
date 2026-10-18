# encoding: UTF-8
module BS2Suite
  class PaletteWindow < Window_Command
    attr_reader :actor,:prefix,:group,:page,:entries,:assignment,:transition
    def initialize(actor,prefix,assignment=nil)
      @actor=actor;@prefix=prefix;@group=nil;@page=0;@assignment=assignment;@entries=[]
      @transition=assignment ? [] : Semantic.pending_moves(actor,prefix)
      super(12,64);self.z=430;BS2Modules.style(self);activate
    end
    def window_width;Graphics.width-24;end
    def visible_line_number;[[item_max,10].min,1].max;end
    def line_height;26;end
    def refresh
      super
      desired=fitting_height(visible_line_number)
      if height!=desired
        self.height=desired;create_contents;draw_all_items
      end
    end
    def make_command_list
      if @transition && @transition.any?
        @entries=[]
        add_command('Enter — открыть новую раскладку',:entry,true)
        @transition.each { |text| add_command(text,:entry,false) }
        return
      end
      if !@group
        groups=if @assignment
          (1..10).map { |n| {:number=>n,:name=>@prefix=='N' ? DirectWeapons.label(DirectWeapons.behavior(@actor,n)) : 'Группа '+n.to_s} }
        elsif @prefix=='N';DirectWeapons.groups(@actor)
        else;Semantic.groups(@actor,@prefix)
        end
        @entries=groups.map { |g| {:digit=>Semantic::DIGITS[g[:number]-1,1].to_i,:group_number=>g[:number],:name=>g[:name]} }
      elsif @assignment
        @entries=(0..9).to_a.sort_by { |n| Semantic::DIGITS.index(n.to_s) }.map do |n|
          old=(@prefix=='N' ? DirectWeapons.rows(@actor,@group,@page) : Semantic.rows(@actor,@prefix,@group)).find { |r| r[:digit]==n }
          {:digit=>n,:name=>old && old[:object] ? 'Заменит: '+old[:object].name : 'Свободно',:old=>old}
        end
      else
        @entries=@prefix=='N' ? DirectWeapons.rows(@actor,@group,@page) : Semantic.rows(@actor,@prefix,@group)
      end
      @entries.each do |row|
        text=row[:name] || (row[:object] ? row[:object].name : 'Недоступно')
        suffix=if row[:object].is_a?(RPG::Item);' ×'+$game_party.item_number(row[:object]).to_s
        elsif row[:object].is_a?(RPG::Skill)
          view=row[:source].is_a?(RPG::Weapon) ? Projection.weapon(@actor,row[:source]) : @actor
          ' · выбор: '+view.skill_mp_cost(row[:object]).to_s+' MP'
        else;'';end
        hint=ShortNotes.for_row(row,@prefix)
        suffix+=' · '+hint unless hint.empty?
        suffix=' · недоступно' if row.has_key?(:present) && !row[:present]
        enabled=(!row.has_key?(:present) || row[:present]) && (!row.has_key?(:usable) || row[:usable])
        add_command(row[:digit].to_s+'  '+text+suffix,:entry,enabled,row)
      end
      add_command('Нет открытых позиций',:empty,false) if @entries.empty?
    end
    def set_prefix(prefix)
      @prefix=prefix;@group=nil;@page=0;refresh;select(0)
      @transition=@assignment ? [] : Semantic.pending_moves(@actor,prefix)
      refresh
    end
    def set_group(group)
      @group=group;@page=0;refresh;select(0)
    end
    def up
      @group=nil;@page=0;refresh;select(0)
    end
    def cycle_page(delta)
      count=@prefix=='N' ? DirectWeapons.pages(@actor,@group) : 1
      @page=(@page+delta)%count;refresh;select(0)
    end
    def item;current_ext && current_ext[:object];end
    def entry;current_ext;end
    def banner
      return 'Обновилась раскладка · изменившиеся последовательности' if @transition && @transition.any?
      suffix=@group ? ' → '+Semantic::DIGITS[@group-1,1] : ''
      title=@prefix+suffix+' · '+Semantic.title(@actor)
      if @prefix=='N' && @group && !@assignment
        current=DirectWeapons.groups(@actor).find { |g| g[:number]==@group }
        title=@prefix+suffix+' · '+current[:name] if current
      end
      title+=' · назначить '+@assignment.name if @assignment
      title+=' · стр. '+(@page+1).to_s if @prefix=='N' && @group && DirectWeapons.pages(@actor,@group)>1
      title
    end
    def acknowledge
      Semantic.acknowledge(@actor,@prefix);@transition=[];refresh;select(0)
    end
  end
  module Palette
    class << self
      def current(scene);scene.instance_variable_get(:@bs2s_palette);end
      def letter
        keys=BS2QoL::Keyboard
        return nil unless (keys.raw_down & [18,91,92]).empty?
        {:palette_v=>'V',:palette_b=>'B',:palette_m=>'M',:palette_n=>'N'}.each { |action,value| return value if Keys.trigger?(action) }
        nil
      end
      def digit
        return nil unless (BS2QoL::Keyboard.raw_down & [16,17,18,91,92]).empty?
        raw=BS2QoL::Keyboard.raw_fresh.find { |k| (48..57).include?(k) }
        raw ? raw-48 : nil
      end
      def open(scene,origin,actor,prefix,assignment=nil)
        return false unless actor
        Semantic.sync(actor) unless $game_party.in_battle
        origin.deactivate
        popup=PaletteWindow.new(actor,prefix,assignment)
        header=BS2Modules::Header.new;header.z=440
        scene.instance_variable_set(:@bs2s_palette,popup)
        scene.instance_variable_set(:@bs2s_palette_header,header)
        scene.instance_variable_set(:@bs2s_palette_origin,origin)
        scene.instance_variable_set(:@bs2s_palette_opened,Graphics.frame_count)
        scene.instance_variable_set(:@bs2s_pending,nil)
        update_header(scene)
        BS2QoL::Keyboard.consume;::Sound.play_ok;true
      end
      def update_header(scene)
        popup=current(scene);return unless popup
        header=scene.instance_variable_get(:@bs2s_palette_header)
        pending=scene.instance_variable_get(:@bs2s_pending)
        hint=if popup.transition.any?;'Enter продолжить · Esc выйти · цифры пока не выполняют команды'
        elsif pending;'Enter сохранить · Esc отменить назначение'
        elsif popup.prefix=='N' && popup.group && DirectWeapons.pages(popup.actor,popup.group)>1;DirectWeapons.label(DirectWeapons.behavior(popup.actor,popup.group))+' · Q/E, ←/→ группы · N N снять · F7 справка'
        elsif popup.prefix=='N' && popup.group;DirectWeapons.label(DirectWeapons.behavior(popup.actor,popup.group))+' · N N снять · Esc выйти · F7 справка'
        elsif popup.prefix=='N' && Semantic.customs[Semantic.mode(popup.actor)];'Действие указано у группы · N N снять · Esc выйти · F7 справка'
        elsif popup.prefix=='N';'1 сейчас · 2/3 последнее · 4…0 оружейные группы · N N снять'
        else;'Цифра выбрать · повтор буквы назад · Esc выйти · F7 справка';end
        header.text=[BS2Modules.fit(header,popup.banner,header.contents_width),BS2Modules.fit(header,hint,header.contents_width)]
      end
      def close(scene,restore=true)
        [:@bs2s_palette,:@bs2s_palette_header].each do |key|
          window=scene.instance_variable_get(key);window.dispose if window && !window.disposed?
          scene.instance_variable_set(key,nil)
        end
        origin=scene.instance_variable_get(:@bs2s_palette_origin)
        origin.activate if restore && origin && !origin.disposed?
        scene.instance_variable_set(:@bs2s_pending,nil)
        BS2QoL::Keyboard.consume
      end
      def commands(scene)
        context=BS2QoL::Hotkeys.context(scene)
        scene.on_skill_cancel if context==:skills
        scene.on_item_cancel if context==:items
        scene.instance_variable_get(:@actor_command_window).activate
      end
      def choose(scene,row)
        popup=current(scene);return unless popup && row
        return if popup.transition.any?
        if !popup.group
          popup.set_group(row[:group_number]);update_header(scene);::Sound.play_cursor;return
        end
        if popup.assignment
          scene.instance_variable_set(:@bs2s_pending,row[:digit]);update_header(scene);::Sound.play_cursor;return
        end
        object=row[:object]
        unless object && row[:present]
          ::Sound.play_buzzer;BS2QoL::Hotkeys.notice('Нет предмета, изучения или источника');return
        end
        actor=popup.actor;prefix=popup.prefix;group=popup.group
        close(scene);commands(scene)
        if prefix=='N'
          if DirectWeapons.behavior(actor,group)=='now'
            if actor.equips[0]==object || BS2QoL::Model.change_weapon(actor,object)
              ::Sound.play_equip;BS2QoL::Hotkeys.notice('Сейчас: '+object.name)
              scene.instance_variable_get(:@actor_command_window).refresh;scene.refresh_status
            else;::Sound.play_buzzer;end
          elsif DirectWeapons.select(actor,object)
            ::Sound.play_ok;BS2QoL::Hotkeys.notice('Последнее действие: '+object.name+' · N N снять')
          else;::Sound.play_buzzer;end
        elsif prefix=='V'
          scene.bs2v2_cast([:skill,object.id,row[:source].is_a?(RPG::Weapon) ? row[:source].id : nil],:commands)
        else
          scene.bs2q_apply_binding([row[:kind],object.id],:commands)
        end
      end
      def update(scene)
        popup=current(scene);return unless popup
        return if scene.instance_variable_get(:@bs2s_palette_handled)==Graphics.frame_count
        scene.instance_variable_set(:@bs2s_palette_handled,Graphics.frame_count)
        return if defined?(BS2QoL::Reference) && BS2QoL::Reference.active?(scene)
        return if scene.instance_variable_get(:@bs2s_palette_opened)==Graphics.frame_count
        unless BS2QoL::Keyboard.focused?
          close(scene);return
        end
        key=letter
        if key
          if key==popup.prefix
            if key!='N' && popup.group
              popup.up;scene.instance_variable_set(:@bs2s_pending,nil);update_header(scene);::Sound.play_cursor
            else
              DirectWeapons.clear(popup.actor) if key=='N' && !popup.assignment
              BS2QoL::Hotkeys.notice('Привязка исполняющего оружия снята') if key=='N' && !popup.assignment
              close(scene);::Sound.play_cancel
            end
          else
            popup.set_prefix(key);scene.instance_variable_set(:@bs2s_pending,nil);update_header(scene)
          end
        elsif Input.trigger?(:B)
          close(scene)
          ::Sound.play_cancel
        elsif popup.transition.any?
          if Input.trigger?(:C);popup.acknowledge;update_header(scene);::Sound.play_ok;end
        elsif BS2QoL::Keyboard.raw_fresh.include?(8) && popup.group
          popup.up;update_header(scene);::Sound.play_cursor
        elsif popup.assignment && BS2Suite.enabled?('legacy_shortcuts') && BS2QoL::Keyboard.first.to_s =~ /\A(?:CS|C|S)[0-9]\z/
          chord=BS2QoL::Keyboard.first
          origin=scene.instance_variable_get(:@bs2s_palette_origin)
          object=popup.assignment;actor=popup.actor
          scope=if object.is_a?(RPG::Weapon);chord.start_with?('S') ? 'weapons' : nil
          elsif chord.start_with?('CS');object.is_a?(RPG::Skill) && Semantic.source_for(actor,object.id) ? 'cast' : nil
          elsif chord.start_with?('C');object.is_a?(RPG::Skill) ? BS2QoL::Bindings.skill_scope(actor,object) : 'quick'
          else;object.is_a?(RPG::Item) ? 'items' : BS2QoL::Bindings.weapon_scope(actor);end
          if scope && BS2QoL::Bindings.valid?(scope,chord,BS2QoL::Model.kind(object),object.id)
            close(scene);BS2QoL::Hotkeys.open_binding(scene,origin)
            scene.instance_variable_get(:@bs2q_binding_window).propose(scope,chord)
          else;::Sound.play_buzzer;end
        elsif BS2QoL::Keyboard.first=='F7' && popup.item && BS2Suite.enabled?('reference_cards')
          row=popup.entry
          actor=row[:source].is_a?(RPG::Weapon) ? Projection.weapon(popup.actor,row[:source]) : popup.actor
          popup.deactivate
          scene.instance_variable_set(:@bs2q_reference_window,Window_BS2QReference.new(popup.item,actor))
          scene.instance_variable_set(:@bs2q_reference_origin,popup)
          BS2QoL::Keyboard.consume
        elsif Input.trigger?(:C) && !scene.instance_variable_get(:@bs2s_pending).nil?
          n=scene.instance_variable_get(:@bs2s_pending)
          if Semantic.assign(popup.actor,popup.prefix,popup.group,n,popup.assignment,nil,popup.page)
            BS2QoL::Hotkeys.notice('Назначение сохранено в пользовательском профиле');::Sound.play_ok;close(scene)
          else;::Sound.play_buzzer;end
        elsif !digit.nil?
          number=digit
          row=popup.entries.find { |r| r[:digit]==number }
          row ? choose(scene,row) : ::Sound.play_buzzer
          BS2QoL::Keyboard.consume
        elsif Input.trigger?(:C)
          choose(scene,popup.entry)
        elsif popup.group && !popup.assignment && (Input.trigger?(:L) || Input.trigger?(:R) || Input.trigger?(:LEFT) || Input.trigger?(:RIGHT))
          popup.cycle_group((Input.trigger?(:R) || Input.trigger?(:RIGHT)) ? 1 : -1);update_header(scene)
        end
      end
      def handle(window)
        scene=SceneManager.scene
        return false if defined?(BS2QoL::Reference) && BS2QoL::Reference.active?(scene)
        return true if current(scene)
        return false if scene.instance_variable_get(:@bs2q_binding_window)
        if BS2QoL::Keyboard.first=='F6' && BS2QoL::Hotkeys.list?(window)
          object=window.item;actor=scene.is_a?(Scene_Battle) ? BattleManager.actor : BS2QoL::Hotkeys.actor_for(window)
          return false unless object && actor
          kind=BS2QoL::Model.kind(object)
          prefix=kind==:weapon ? 'N' : kind==:item ? 'B' : actor.skill_learn?(object) ? 'M' : 'V'
          return open(scene,window,actor,prefix,object)
        end
        return false unless scene.is_a?(Scene_Battle)
        context=BS2QoL::Hotkeys.context(scene);return false unless context
        prefix=letter
        return open(scene,window,BattleManager.actor,prefix) if prefix
        if BS2QoL::Keyboard.first=='F7' && context==:commands && BS2Suite.enabled?('reference_cards')
          return SequenceReference.open(scene,window,BattleManager.actor)
        end
        false
      end
    end
  end
end

module BS2QoL::Hotkeys
  class << self
    alias bs2s_palette_handle handle
    def handle(window)
      return true if BS2Suite::Palette.handle(window)
      bs2s_palette_handle(window)
    end
  end
end
class Scene_Base
  alias bs2s_palette_update update_basic
  def update_basic
    bs2s_palette_update
    BS2Suite::Palette.update(self)
  end
  alias bs2s_palette_terminate terminate
  def terminate
    BS2Suite::Palette.close(self,false) if @bs2s_palette
    bs2s_palette_terminate
  end
end
class Scene_Battle
  alias bs2s_palette_start start
  def start
    $game_party.battle_members.each { |actor| BS2Suite::Semantic.sync(actor) }
    bs2s_palette_start
  end
  alias bs2s_palette_battle_basic update_basic
  def update_basic
    bs2s_palette_battle_basic
    BS2Suite::Palette.update(self)
  end
end
class Window_BS2QKeyHints
  alias bs2s_old_display display
  def display(scene,actor,context)
    return hide unless actor
    left=context==:commands ? scene.instance_variable_get(:@actor_command_window).width : 0
    if x!=left || width!=Graphics.width-left
      self.x=left;self.width=Graphics.width-left;create_contents;@bs2s_signature=nil
    end
    weapon=BS2Suite::DirectWeapons.selected(actor)
    selected_id=BS2Suite::DirectWeapons.selected_id(actor)
    signature=[actor.id,context,weapon && weapon.id,selected_id,BS2Suite::Semantic.title(actor),BS2QoL::Hotkeys.current_notice]
    return show if signature==@bs2s_signature
    contents.clear;contents.font.size=15;change_color(system_color)
    labels=[:palette_v,:palette_b,:palette_m,:palette_n].map { |key| BS2Suite::Keys.token(key) }
    text=labels[0]+' техники · '+labels[1]+' предметы · '+labels[2]+' магия · '+labels[3]+' оружие · F7 связка · '+BS2Suite::Keys.token(:combat_effects)+' эффекты'
    draw_text(0,0,contents_width,18,BS2QoL::Hotkeys.current_notice || text)
    change_color(normal_color)
    draw_text(0,20,contents_width,18,'Профиль: '+BS2Suite::Semantic.title(actor))
    note=weapon ? 'Назначено N: '+weapon.name+' · N N снять' : selected_id ? 'Назначенное оружие отсутствует · N N снять' : 'Исполняющее оружие не назначено'
    draw_text(0,40,contents_width,18,note)
    @bs2s_signature=signature;show
  end
end

module BS2Suite
  class ProfileCommands < Window_Command
    def initialize(actor);@actor=actor;super(0,72);BS2Modules.style(self);end
    def window_width;Graphics.width;end
    def visible_line_number;12;end
    def make_command_list
      add_command('С прогрессией',:select_profile,true,'progression')
      add_command('Продвинутый — ранние варианты доступны',:select_profile,true,'advanced')
      Semantic.customs.each { |id,p| add_command(p['name'],:select_profile,true,id) }
      add_command('Создать копию текущего',:copy)
      add_command('Создать пустой профиль',:new)
      add_command('Редактор групп и оружия',:edit)
      add_command('Переименовать свой профиль',:rename,!!Semantic.customs[Semantic.mode(@actor)])
      add_command('Сведения о врагах: '+(Options.get('knowledge_threshold')==0 ? 'показывать сразу' : 'с '+Options.get('knowledge_threshold').to_s+'-й встречи'),:knowledge)
      add_command('Назад',:cancel)
    end
  end
  class ProfileScene < Scene_MenuBase
    def start
      super;@actor=$game_party.menu_actor;Semantic.sync(@actor)
      @header=BS2Modules::Header.new
      @commands=ProfileCommands.new(@actor)
      @commands.set_handler(:select_profile,method(:select_profile))
      @commands.set_handler(:copy,lambda { made=Semantic.clone_profile(@actor);made ? ::Sound.play_ok : ::Sound.play_buzzer;redraw })
      @commands.set_handler(:new,lambda { made=Semantic.clone_profile(@actor,true);made ? ::Sound.play_ok : ::Sound.play_buzzer;redraw })
      @commands.set_handler(:edit,lambda { SceneManager.call(ProfileEditorScene) })
      @commands.set_handler(:rename,method(:rename_profile))
      @commands.set_handler(:knowledge,lambda { old=Options.get('knowledge_threshold');Options.set('knowledge_threshold',old>=5 ? 0 : old==0 ? 2 : old+1);redraw })
      @commands.set_handler(:cancel,method(:return_scene));redraw
    end
    def redraw
      @header.text=['Группы: '+Semantic.title(@actor),'Авторские профили копируются при редактировании · Enter выбрать · Esc назад']
      @commands.refresh;@commands.activate
    end
    def select_profile
      Semantic.set_mode(@actor,@commands.current_ext);redraw
    end
    def rename_profile
      BS2Suite.edit_text(self,Semantic.title(@actor),40) { |value| Semantic.renamed(@actor,value) if value && !value.strip.empty? }
      redraw
    end
  end
  class EditorCommands < Window_Command
    attr_accessor :rows
    def initialize;@rows=[];super(0,72);BS2Modules.style(self);end
    def window_width;Graphics.width;end
    def visible_line_number;13;end
    def make_command_list
      @rows.each { |row| add_command(row[:name],:entry,true,row) }
    end
  end
  class ProfileEditorScene < Scene_MenuBase
    def start
      super;@actor=$game_party.menu_actor;@stage=:prefix;@prefix=nil;@group=1;@digit=1;@page=0
      @header=BS2Modules::Header.new;@commands=EditorCommands.new
      @commands.set_handler(:entry,method(:choose));@commands.set_handler(:cancel,method(:back));redraw
    end
    def redraw
      rows=[]
      if @stage==:prefix
        rows=Semantic::PREFIXES.map { |p| {:name=>p+' — '+{'V'=>'оружейные техники','M'=>'изученные навыки','B'=>'предметы','N'=>'оружие'}[p],:value=>p} }
      elsif @stage==:group
        known=@prefix=='N' ? DirectWeapons.groups(@actor) : Semantic.groups(@actor,@prefix)
        rows=(1..10).map do |n|
          existing=known.find { |g| g[:number]==n }
          label=existing ? existing[:name] : 'Новая группа'
          {:name=>Semantic::DIGITS[n-1,1]+' — '+label,:value=>n}
        end
      elsif @stage==:slot
        existing=@prefix=='N' ? DirectWeapons.rows(@actor,@group,@page) : Semantic.rows(@actor,@prefix,@group)
        rows=Semantic::DIGITS.chars.map do |d|
          old=existing.find { |r| r[:digit]==d.to_i }
          {:name=>d+' — '+(old && old[:object] ? old[:object].name : 'Свободно'),:value=>d.to_i}
        end

        rows<<{:name=>'Переименовать группу',:value=>:rename}
      else
        values=case @prefix
        when 'N';Semantic.owned(@actor)
        when 'B';$game_party.items.select { |i| [0,1].include?(i.occasion) }
        when 'M';@actor.skills.select { |s| @actor.skill_learn?(s) && [0,1].include?(s.occasion) }
        else
          ids=Semantic.owned(@actor).map { |w| w.features.select { |f| f.code==43 }.map { |f| f.data_id } }.flatten.uniq
          ids.map { |id| $data_skills[id] }.compact
        end
        rows=[{:name=>'Очистить позицию',:value=>nil}]+values.map { |object| {:name=>object.name,:value=>object} }
      end
      @commands.rows=rows;@commands.refresh;@commands.select(0);@commands.activate
      @header.text=['Редактор · '+Semantic.title(@actor),[@prefix,@stage==:slot || @stage==:object ? @group.to_s : nil,@stage==:object ? @digit.to_s : nil].compact.join(' → ')+' · Enter выбрать · Esc назад']
    end
    def editable
      Semantic.customs[Semantic.mode(@actor)] || Semantic.clone_profile(@actor)
    end
    def choose
      value=@commands.current_ext[:value]
      case @stage
      when :prefix;@prefix=value;@stage=:group
      when :group;@group=value;@page=0;@stage=:slot
      when :slot
        if value==:page
          @page=(@page+1)%[DirectWeapons.pages(@actor,@group)+1,32].min
        elsif value==:behavior
          if editable
            mode=DirectWeapons.behavior(@actor,@group)=='last' ? 'now' : 'last'
            Semantic.set_behavior(@actor,@group,mode) ? ::Sound.play_ok : ::Sound.play_buzzer
          end
        elsif value==:rename
          if editable
            p=Semantic.customs[Semantic.mode(@actor)]
            key=@prefix+@group.to_s
            BS2Suite.edit_text(self,p['groups'][key] || 'Моя группа',40) do |text|
              if text && !text.strip.empty?
                old=p['groups'][key];p['groups'][key]=Semantic.clean_name(text)
                unless Semantic.persist
                  old ? p['groups'][key]=old : p['groups'].delete(key)
                  ::Sound.play_buzzer
                end
              end
            end
          end
        else;@digit=value;@stage=:object;end
      when :object
        if value
          success=Semantic.assign(@actor,@prefix,@group,@digit,value,nil,@prefix=='N' ? @page : 0)
        else
          success=editable && Semantic.remove(@actor,@prefix,@group,@digit,@prefix=='N' ? @page : 0)
        end
        success ? ::Sound.play_ok : ::Sound.play_buzzer;@stage=:slot
      end
      redraw
    end
    def back
      if @stage==:prefix;return_scene;return;end
      @stage={:group=>:prefix,:slot=>:group,:object=>:slot}[@stage];redraw
    end
  end
end
class BS2Suite::SettingsCommands
  alias bs2s_profile_commands make_command_list
  def make_command_list
    bs2s_profile_commands
    @list.insert(0,{:name=>'Боевые группы V/B/M и оружие N',:symbol=>:profiles,:enabled=>true,:ext=>nil})
  end
end
class BS2Suite::SettingsScene
  alias bs2s_profile_settings_start start
  def start
    bs2s_profile_settings_start
    @commands.set_handler(:profiles,lambda { SceneManager.call(BS2Suite::ProfileScene) })
  end
end
