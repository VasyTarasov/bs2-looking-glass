# encoding: UTF-8
module BS2Suite
  module HDDisplay
    DEFAULT={'width'=>1280,'height'=>720,'mode'=>0,'filter'=>0,'sidebar'=>1,'ui'=>100}.freeze
    PRESETS=[['HD',1280,720],['Full HD',1920,1080],['1440p',2560,1440],['4K',3840,2160],
      ['21:9',2560,1080],['21:9',3440,1440],['32:9',3840,1080],['32:9',5120,1440]].freeze
    class << self
      attr_reader :error,:current,:trial
      def data
        return @data if @data
        @data=DEFAULT.dup
        Store.read('hd_display',4096).each_line do |line|
          key,value=line.strip.split('=',2);next unless DEFAULT.has_key?(key) && value.to_s=~/\A[0-9]{1,4}\z/
          candidate=@data.merge(key=>value.to_i);@data=candidate if valid?(candidate)
        end
        @data
      end
      def valid?(value)
        value.is_a?(Hash) && (640..7680).include?(value['width']) && (480..4320).include?(value['height']) &&
          (0..2).include?(value['mode']) && (0..2).include?(value['filter']) && (0..1).include?(value['sidebar']) && (75..150).include?(value['ui'])
      end
      def boot
        return false unless SteamBridge.rendering?
        path=File.join(BS2Suite::ROOT,'native','bs2_steam_bridge.dll')
        @configure=Win32API.new(path,'BS2_HDConfigure',['I','I','I','I','I','I'],'I')
        @status=Win32API.new(path,'BS2_HDStatus',['P'],'I')
        @monitor=Win32API.new(path,'BS2_HDMonitor',['P'],'I')
        @presentation=Win32API.new(path,'BS2_HDPresentation',['I'],'I')
        @dpi=Win32API.new(path,'BS2_HDDPI',['P'],'I')
        @restart_dpi=Win32API.new(path,'BS2_HDRestartDPI',[],'I')
        @text=Win32API.new(path,'BS2_HDText',['P','I'],'I')
        @tick=Win32API.new('kernel32','GetTickCount',[],'L');@error=nil;true
      rescue StandardError=>e
        @error='HD-вывод недоступен: '+e.message;false
      end
      def status
        return [] unless @status
        buffer=([0]*16).pack('l*');return [] unless @status.call(buffer)==16
        buffer.unpack('l*')
      end
      def ready?;!!@configure;end
      def dpi
        return [] unless @dpi
        now=@tick.call
        return @dpi_value if @dpi_tick && ((now-@dpi_tick)&0xffffffff)<1000
        buffer=([0]*8).pack('l*');return [] unless @dpi.call(buffer)==8
        @dpi_tick=now;@dpi_value=buffer.unpack('l*')
      end
      def dpi_message
        dpi[7]==1 ? 'Для чёткого HD-текста: «Перезапустить для HD» в настройках экрана.' : nil
      end
      def restart_dpi
        if @restart_dpi && @restart_dpi.call==1
          SteamBridge.stop;SceneManager.exit;true
        else
          @error='Перезапуск недоступен; текущая сессия остаётся открытой.';false
        end
      end
      def resolution(width,height)
        buffer=([0]*6).pack('l*');@monitor.call(buffer);monitor=buffer.unpack('l*')
        data.merge('width'=>width,'height'=>height,'mode'=>monitor[1,2]==[width,height] ? 1 : 0)
      end
      def apply(value)
        return false unless ready?
        unless valid?(value);@error='Размер: 640…7680 × 480…4320; проверьте параметры режима.';return false;end
        if @configure.call(*%w(width height mode filter sidebar ui).map { |key| value[key] })!=1
          code=status[14]
          @error=code==4 ? 'Окно не помещается на мониторе. Выберите меньший размер или весь экран.' : 'Не удалось применить HD-режим ('+code.to_s+').'
          return false
        end
        @current=value.dup;@error=nil;@last_text=nil;poll(true);true
      end
      def start_trial(value)
        return false if @trial
        previous=(@current || data).dup
        return false unless apply(value)
        @trial={'previous'=>previous,'next'=>value.dup,'started'=>@tick.call};true
      end
      def confirm
        return false unless @trial
        next_data=@trial['next']
        unless Store.write('hd_display',next_data.keys.sort.map { |key| key+'='+next_data[key].to_s }.join("\n")+"\n")
          @error='Режим не записан. Верните прежний режим или повторите подтверждение.';return false
        end
        @data=next_data.dup;@trial=nil;true
      end
      def rollback
        return true unless @trial
        previous=@trial['previous'];@trial=nil
        return true if apply(previous)
        # A changed monitor can make the old window size unavailable. Restore its original placement.
        apply(DEFAULT.merge('mode'=>2))
      end
      def remaining
        return 0 unless @trial
        [15-((@tick.call-@trial['started'])&0xffffffff)/1000,0].max
      end
      def plain(text)
        text.to_s.gsub(/\\[A-Za-z]+\[[^\]]*\]/,'').gsub(/[\x00-\x1f]/,' ')[0,200]
      end
      def row(kind,text);kind+"\t"+plain(text);end
      def commands(window,limit=14)
        return [] unless window && !window.disposed?
        entries=window.instance_variable_get(:@list)
        if entries.is_a?(Array)
          first=[window.index-limit/2,0].max
          return entries[first,limit].to_a.each_with_index.map do |entry,i|
            name=entry[:name].is_a?(Array) ? entry[:name][0] : entry[:name]
            row(window.index==first+i ? 'A' : 'S',name.to_s+(entry[:enabled]==false ? ' · недоступно' : ''))
          end
        end
        values=window.instance_variable_get(:@data)
        return [] unless values.is_a?(Array)
        first=[window.index-limit/2,0].max
        values[first,limit].to_a.each_with_index.map { |object,i| row(window.index==first+i ? 'A' : 'S',object && object.respond_to?(:name) ? object.name : '—') }
      end
      def lines(scene)
        if @trial
          return [row('T','Проверка режима'),row('H','Оставить этот режим?'),row('S','Enter — сохранить'),row('S','Esc — вернуть прежний'),row('H','Автовозврат через '+remaining.to_s+' с')]
        end
        if scene && (window=scene.instance_variable_get(:@bs2q_reference_window)) && !window.disposed?
          card=window.card
          return [row('T',card.title),row('H',card.section_names[window.section])]+
            window.lines[window.offset,28].to_a.map { |text| row('S',text) }+
            [row('D','←/→ раздел · ↑/↓ текст · Q/E страница'),row('D','F7 / Esc закрыть')]
        end
        if scene && (window=scene.instance_variable_get(:@bs2s_palette)) && !window.disposed?
          return [row('T',window.banner),row('D','Цифра / Enter выбрать · Esc выйти')]+commands(window,18)+[row('D','F7 — подробная справка')]
        end
        if scene && (window=scene.instance_variable_get(:@bs2080_effects)) && !window.disposed?
          first=[window.index-8,0].max
          values=window.rows[first,18].to_a.each_with_index.map do |entry,i|
            label,icons,unit=entry
            name=label.to_s.empty? ? unit.name.to_s : label
            details=icons.compact.map { |icon,count,title| title+' · '+count }.join(' / ')
            row(window.index==first+i ? 'A' : 'S',name+': '+(details.empty? ? '—' : details))
          end
          return [row('T','Участники и эффекты')]+values+[row('D','Enter / F7 сведения · H / Esc закрыть')]
        end
        actor=$game_party && (($game_party.in_battle ? BattleManager.actor : nil) || $game_party.leader)
        rows=[row('T','BLACK SOULS II')]
        rows<<row('D',dpi_message) if dpi_message
        if actor
          rows+=[row('H',actor.name+' · ур. '+actor.level.to_s),row('S','HP '+actor.hp.to_s+' / '+actor.mhp.to_s),row('S','MP '+actor.mp.to_s+' / '+actor.mmp.to_s)]
          weapon=actor.equips[0];rows<<row('S',weapon ? weapon.name : 'Без оружия')
        end
        if scene
          active=scene.instance_variables.map { |key| scene.instance_variable_get(key) }.find do |value|
            value.is_a?(Window_Selectable) && !value.disposed? && value.active && value.visible && value.open?
          end
          if active
            rows<<row('H',scene.is_a?(Scene_Battle) ? 'Выбор действия' : 'Меню')
            rows+=commands(active,14)
          end
        end
        if actor && $game_party.in_battle
          if actor.actions.size>1
            rows<<row('H','Очередь')
            actor.actions.each_with_index { |action,i| rows<<row('S',(i+1).to_s+'. '+(action.item ? action.item.name : 'не выбрано')) }
          end
          if defined?(DirectWeapons)
            weapon=DirectWeapons.selected(actor)
            rows<<row('S','Последнее: '+weapon.name) if weapon
          end
          if defined?(CombatEffects)
            effects=CombatEffects.icons(actor)
            rows<<row('H','Эффекты героя') unless effects.empty?
            effects.take(8).each { |icon,turns,name| rows<<row('S',name+' · '+turns) }
            rows<<row('D','H — все участники и эффекты')
          end
        end
        rows<<row('D','V техники · B предметы · M магия · N оружие') if $game_party && $game_party.in_battle
        rows<<row('D','HD: '+status[6].to_s+' × '+status[7].to_s)
        rows
      end
      def restore_source
        (@hidden || []).each do |window,visible|
          window.visible=visible unless window.disposed?
        end
        @hidden=[]
      end
      def source_mode(scene)
        state=status
        # H keeps its compact native icon grid and counters. The HD sidebar adds names;
        # only its nested F7 reference takes over the enlarged HD reading area.
        modal=scene && (scene.instance_variable_get(:@bs2q_reference_window) || scene.instance_variable_get(:@bs2s_palette))
        use_hd=state[1]==1 && state[4]==1 && state[14]==0 && SteamBridge.stats[4]==1 && modal && !modal.disposed?
        if use_hd
          unless (@hidden || []).any? { |entry| entry[0].equal?(modal) }
            restore_source
            reference=scene.instance_variable_get(:@bs2q_reference_window)
            palette=scene.instance_variable_get(:@bs2s_palette)
            windows=[reference,reference && reference.instance_variable_get(:@plate),palette,scene.instance_variable_get(:@bs2s_palette_header),scene.instance_variable_get(:@bs2080_effects)].compact
            @hidden=windows.map { |window| [window,window.visible] }
            @hidden.each { |window,visible| window.visible=false }
          end
          @presentation.call(1)
        else
          restore_source;@presentation.call(0)
        end
      end
      def poll(force=false)
        return unless @text
        scene=SceneManager.scene
        modal=scene && (scene.instance_variable_get(:@bs2q_reference_window) || scene.instance_variable_get(:@bs2s_palette) || scene.instance_variable_get(:@bs2080_effects))
        view=modal && modal.object_id
        force=force || modal || @last_modal!=view || (scene && scene.is_a?(Scene_MenuBase)) || @trial
        @last_modal=view
        now=@tick.call
        return if !force && @last_tick && ((now-@last_tick)&0xffffffff)<100
        @last_tick=now
        rollback if @trial && remaining<=0
        source_mode(scene)
        return unless status[1]==1
        value=lines(scene).take(48).join("\n").encode('UTF-8')
        return if value==@last_text
        if @text.call(value,value.bytesize)==1;@last_text=value
        else;@error='Текст HD-панели не принят.';end
      rescue StandardError=>e
        restore_source;@presentation.call(0) if @presentation
        @error='HD-панель: '+e.message
      end
      def shutdown;restore_source;rollback;end
    end
  end
  class DisplayCommands < Window_Command
    def window_width;Graphics.width;end
    def visible_line_number;13;end
    def make_command_list
      add_command('Весь экран · разрешение монитора',:fullscreen)
      add_command('Перезапустить для чёткого HD',:restart_dpi,HDDisplay.dpi[7]==1)
      HDDisplay::PRESETS.each_with_index { |preset,i| add_command(preset[0]+' · '+preset[1].to_s+'×'+preset[2].to_s,:preset,true,i) }
      add_command('Своя ширина × высота…',:custom)
      add_command('Фильтр: '+['чёткие пиксели','сглаживание','целочисленный масштаб'][HDDisplay.data['filter']],:filter)
      add_command('Боковая HD-панель: '+(HDDisplay.data['sidebar']==1 ? 'вкл' : 'выкл'),:sidebar)
      add_command('Размер текста: '+HDDisplay.data['ui'].to_s+'%',:font)
      add_command('Вернуть исходное окно',:classic)
      add_command('Назад',:cancel)
    end
  end
  class DisplayScene < Scene_MenuBase
    def start
      super;@header=BS2Modules::Header.new;@commands=DisplayCommands.new(0,72);BS2Modules.style(@commands)
      @commands.set_handler(:cancel,method(:return_scene));@commands.set_handler(:preset,method(:preset));@commands.set_handler(:custom,method(:custom))
      @commands.set_handler(:restart_dpi,method(:restart_dpi))
      @commands.set_handler(:fullscreen,lambda { trial(HDDisplay.data.merge('mode'=>1)) })
      @commands.set_handler(:classic,lambda { trial(HDDisplay.data.merge('mode'=>2)) })
      @commands.set_handler(:filter,lambda { trial(HDDisplay.data.merge('filter'=>(HDDisplay.data['filter']+1)%3)) })
      @commands.set_handler(:sidebar,lambda { trial(HDDisplay.data.merge('sidebar'=>1-HDDisplay.data['sidebar'])) })
      @commands.set_handler(:font,lambda { trial(HDDisplay.data.merge('ui'=>HDDisplay.data['ui']>=150 ? 75 : HDDisplay.data['ui']+25)) })
      @commands.activate;redraw
    end
    def redraw
      @header.text=['Экран и HD-интерфейс',HDDisplay.error || HDDisplay.dpi_message || 'Enter выбрать · Esc назад · новый режим подтверждается за 15 секунд']
      @commands.refresh;@commands.activate;HDDisplay.poll(true)
    end
    def preset
      preset=HDDisplay::PRESETS[@commands.current_ext];trial(HDDisplay.resolution(preset[1],preset[2]))
    end
    def custom
      BS2Suite.edit_text(self,HDDisplay.data['width'].to_s+'x'+HDDisplay.data['height'].to_s,16) do |text|
        match=text && /\A\s*([0-9]{3,4})\s*[xх×]\s*([0-9]{3,4})\s*\z/i.match(text)
        if match;trial(HDDisplay.resolution(match[1].to_i,match[2].to_i))
        else;::Sound.play_buzzer;end
      end
      redraw
    end
    def restart_dpi
      @commands.deactivate
      @confirm=HDConfirmCommands.new(40,150)
      @confirm.set_handler(:cancel,method(:cancel_restart))
      @confirm.set_handler(:restart,lambda { cancel_restart unless HDDisplay.restart_dpi })
      @confirm.activate;@confirm.select(0)
    end
    def cancel_restart
      @confirm.dispose if @confirm && !@confirm.disposed?;@confirm=nil;redraw
    end
    def trial(value)
      unless HDDisplay.start_trial(value);::Sound.play_buzzer;redraw;return;end
      @commands.deactivate
      begin
        loop do
          Graphics.update;Input.update;HDDisplay.poll(true)
          break unless HDDisplay.trial
          @header.text=['Оставить этот режим? '+HDDisplay.remaining.to_s+' с','Enter сохранить · Esc вернуть прежний режим']
          if Input.trigger?(:B);HDDisplay.rollback;break
          elsif Input.trigger?(:C);break if HDDisplay.confirm
          end
        end
      ensure
        HDDisplay.rollback if HDDisplay.trial
        BS2QoL::Keyboard.consume;redraw
      end
    end
    def terminate
      HDDisplay.rollback if HDDisplay.trial
      super
    end
  end
  class HDConfirmCommands < Window_Command
    def window_width;Graphics.width-80;end
    def make_command_list
      add_command('Отмена — продолжить игру',:cancel)
      add_command('К титулу: несохранённый прогресс потеряется',:restart)
    end
  end
end
BS2Suite::HDDisplay.boot
module Graphics
  class << self
    alias bs2090_display_update update
    def update;BS2Suite::HDDisplay.poll;bs2090_display_update;end
  end
end
class Scene_Title
  alias bs2090_display_title start
  def start
    bs2090_display_title
    BS2Suite::HDDisplay.apply(BS2Suite::HDDisplay.data)
  end
end
class BS2Suite::SettingsCommands
  alias bs2090_display_commands make_command_list
  def make_command_list
    bs2090_display_commands
    @list.insert(2,{:name=>'Экран и HD-интерфейс (прототип)',:symbol=>:hd_display,:enabled=>BS2Suite::HDDisplay.ready?,:ext=>nil})
  end
end
class BS2Suite::SettingsScene
  alias bs2090_display_settings start
  def start;bs2090_display_settings;@commands.set_handler(:hd_display,lambda { SceneManager.call(BS2Suite::DisplayScene) });end
end
