# encoding: UTF-8
module BS2Suite
  module SteamBridge
    class << self
      attr_reader :error
      def stats;@stats || [];end
      def input_status;@input_status || [];end
      def active?;@running && stats[20]==1;end
      def rendering?;@running && (Options.get('steam_mode')!=0 || BS2Suite.enabled?('hd_display')) && !@error;end
      def boot
        path=File.join(BS2Suite::ROOT,'native','bs2_steam_bridge.dll')
        unless File.file?(path);@error='Файл графического моста отсутствует.';return false;end
        @native_stats=Win32API.new(path,'BS2_Stats',['P'],'I')
        raw=([0]*22).pack('l*')
        raise 'Несовместимая версия моста' unless @native_stats.call(raw)==22
        @native_stop=Win32API.new(path,'BS2_Stop',[],'I')
        @native_input=Win32API.new(path,'BS2_InputStatus',['P'],'I')
        @native_tick=Win32API.new(path,'BS2_OverlayTick',[],'I')
        @native_focus=Win32API.new(path,'BS2_FocusStatus',['P'],'I')
        @native_restart_status=Win32API.new(path,'BS2_RestartStatus',['P'],'I')
        @native_restart=Win32API.new(path,'BS2_Restart',[],'I')
        @native_boot=Win32API.new(path,'BS2_Boot',['L','L'],'I')
        @native_shot=Win32API.new(path,'BS2_Screenshot',[],'I')
        size=Win32API.new(path,'BS2_SourceSize',['I','I'],'I')
        raise 'Не поддерживается размер исходного кадра' unless size.call(Graphics.width,Graphics.height)==1
        window=Win32API.new('user32','GetActiveWindow',[],'L').call
        raise 'Не удалось подключить вывод кадров' unless @native_boot.call(window,(BS2Suite.enabled?('hd_display') || Options.get('steam_mode')!=0 ? 1 : 0) | (BS2Suite.enabled?('steam_bridge') ? 2 : 0))==1
        @running=true;@error=nil;poll;true
      rescue StandardError=>e
        @error=e.message;false
      end
      def poll
        unless @running
          if @error && !@logged_error && defined?(BS2Suite::Debug) && BS2Suite::Debug.directory
            BS2Suite::Debug.emit('steam_bridge_error',{:error=>@error});@logged_error=true
          end
          return
        end
        @callbacks.call if @callbacks
        raw=([0]*22).pack('l*');@native_stats.call(raw);@stats=raw.unpack('l*')
        if stats[16]==1 && !@callbacks
          @callbacks=Win32API.new('steam_api','SteamAPI_RunCallbacks',[],'V')
        end
        raw=([0]*4).pack('l*')
        raise 'Несовместимая защита F12' unless @native_input.call(raw)==4
        @input_status=raw.unpack('l*')
        raw=([0]*4).pack('l*');@native_restart_status.call(raw);restart=raw.unpack('l*')
        if restart[1]==1 && !@restarting
          @restarting=true
          if @native_restart.call==1
            raw=([0]*4).pack('l*');@native_restart_status.call(raw)
            BS2Suite::Debug.emit('f12_restart',{:child_pid=>raw.unpack('l*')[2],:method=>'fresh_process'}) if defined?(BS2Suite::Debug)
            stop;SceneManager.exit;return
          end
          @restarting=false
          @restart_error='Не удалось перезапустить игру; текущая сессия остаётся открытой.'
          BS2QoL::Hotkeys.notice(@restart_error)
          raw=([0]*4).pack('l*');@native_restart_status.call(raw)
          BS2Suite::Debug.emit('f12_restart_failed',{:code=>raw.unpack('l*')[3]}) if defined?(BS2Suite::Debug)
        end
        signature=[stats[4],stats[5],stats[16],stats[18],stats[19],stats[20],input_status[1],input_status[3]]
        if signature!=@logged_status && defined?(BS2Suite::Debug) && BS2Suite::Debug.directory
          BS2Suite::Debug.emit('steam_bridge',{:gl_ready=>stats[4],:errors=>stats[5],:screenshots=>stats[16],:shot_result=>stats[18],:overlay_enabled=>stats[19],:overlay_active=>stats[20],:f12_guard=>input_status[1],:overlay_module=>input_status[3],:captures=>stats[2],:gdi_calls=>stats[10]})
          @logged_status=signature
        end
        @polls=(@polls || 0)+1
        if @polls==240 && BS2Suite.enabled?('debug')
          focus=([0]*4).pack('l*');@native_focus.call(focus)
          BS2Suite::Debug.emit('steam_bridge_probe',{:stats=>@stats,:input=>@input_status,:focus=>focus.unpack('l*'),:frame=>Graphics.frame_count})
          BS2Suite::Store.write('steam_startup','error='+@error.to_s+"\n"+'stats='+stats.inspect+"\n"+'input='+input_status.inspect+"\n")
        end
        if (Options.get('steam_mode')!=0 || BS2Suite.enabled?('hd_display')) && @stats[5].to_i>0 && @stats[4]!=1
          @error='OpenGL недоступен; включён обычный вывод игры.'
          stop
        end
      rescue StandardError=>e
        @error=e.message;stop
      end
      def stop
        @native_stop.call if @running && @native_stop
        @running=false
      end
      def hold_overlay
        return if @holding
        @holding=true
        begin
          while active?
            unless @native_tick.call==1
              @error='Не удалось продолжить отрисовку оверлея.';stop;break
            end
            poll
          end
        ensure
          @native_tick.call if @native_tick && !active?
          @holding=false
        end
      end
      def lines
        poll
        [@error || @restart_error || 'Экспериментальный графический мост включён.',
         'Режим: '+(BS2Suite.enabled?('hd_display') ? 'HD OpenGL' : Options.get('steam_mode')==0 ? 'только скриншоты' : 'OpenGL и скриншоты'),
         'Захвачено кадров: '+stats[2].to_i.to_s+' · показано OpenGL: '+stats[3].to_i.to_s,
         'Steam API скриншотов: '+(stats[16]==1 ? 'доступен' : 'недоступен'),
         'Чистый перезапуск по F12: '+(input_status[1]==1 ? 'включён' : 'НЕ ПОДКЛЮЧЕН'),
         'Графический модуль оверлея загружен: '+(input_status[3]==1 ? 'да' : 'нет'),
         'Overlay сообщает о подключении: '+(stats[19]==1 ? 'да' : 'нет'),
         'Последний скриншот: '+(stats[18]==1 ? 'Steam подтвердил запись' : stats[18]==-1 ? 'ожидание подтверждения' : stats[18].to_i==0 ? 'не запрашивался' : 'ошибка записи'),
         'F12 — перезапуск к титульному экрану. Кнопка снимка выбирается в Steam.',
         'Shift+Tab — оверлей Steam. Работа с HD, мышью и снимками подтверждена в игре пользователем.',
         'Steam Recording / повторы пока не подтверждены. Настройки записи Steam автоматически не меняются.',
         'Для отключения снимите модуль Steam и перезапустите игру.']
      end
    end
  end
  class SteamStatusScene < LinesScene
    def start;super;present('Steam',SteamBridge.lines);end
  end
end
BS2Suite::SteamBridge.boot
if BS2Suite.enabled?('debug')
  BS2Suite::Store.write('steam_startup','error='+BS2Suite::SteamBridge.error.to_s+"\n"+'stats='+BS2Suite::SteamBridge.stats.inspect+"\n"+'input='+BS2Suite::SteamBridge.input_status.inspect+"\n")
end
at_exit { BS2Suite::SteamBridge.stop }
module Input
  class << self
    alias bs2080_steam_input update
    def update
      bs2080_steam_input
      BS2Suite::SteamBridge.poll
      if BS2Suite::SteamBridge.active?
        BS2QoL::Keyboard.consume
        BS2QoL::Keyboard.instance_variable_set(:@resync,true)
        BS2Suite::SteamBridge.hold_overlay
      end
    end
  end
end
class Scene_Base
  alias bs2080_steam_basic update_basic
  def update_basic
    BS2Suite::SteamBridge.poll
    BS2Suite::SteamBridge.hold_overlay if BS2Suite::SteamBridge.active?
    bs2080_steam_basic
  end
end
class BS2Suite::SettingsCommands
  alias bs2080_steam_commands make_command_list
  def make_command_list
    bs2080_steam_commands
    @list.insert(-2,{:name=>'Steam: состояние моста',:symbol=>:steam_status,:enabled=>true,:ext=>nil})
  end
end
class BS2Suite::SettingsScene
  alias bs2080_steam_start start
  def start
    bs2080_steam_start
    @commands.set_handler(:steam_status,lambda { SceneManager.call(BS2Suite::SteamStatusScene) })
  end
end
