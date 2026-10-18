# encoding: UTF-8
module BS2Suite
  class SettingsCommands < Window_Command
    def window_width;Graphics.width;end
    def visible_line_number;15;end
    def make_command_list
      add_command('Выбор модулей (после перезапуска)',:modules)
      add_command('Назначения клавиш',:keys) if BS2Suite.enabled?('controls')
      if BS2Suite.enabled?('run_toggle')
        add_command('Предметы: '+(Options.get('fast_items')==1 ? 'почти мгновенно' : 'обычная скорость'),:fast_items)
        add_command('Бег: '+['удержание','переключение ('+Keys.token(:run)+')','всегда'][Options.get('run_mode')],:run)
      end
      if BS2Suite.enabled?('sound')
        %w(bgm bgs me se).each { |id| add_command(id.upcase+': '+Options.get(id).to_s+'%',id.to_sym) }
      end
      add_command('Заметки V/B/M: '+(Options.get('palette_notes')==1 ? 'вкл' : 'выкл'),:palette_notes)
      add_command('Заметки оружия N: '+(Options.get('weapon_notes')==1 ? 'вкл' : 'выкл'),:weapon_notes)
      add_command('Последний бой',:stats) if BS2Suite.enabled?('battle_stats')
      if BS2Suite.enabled?('debug')
        add_command('Записать замечание в журнал',:note)
        add_command('Диагностика: состояние журнала',:debug)
      end
      add_command('Назад',:cancel)
    end
  end
  class SettingsScene < Scene_MenuBase
    def start
      super
      @header=BS2Modules::Header.new;@header.text=['Модули удобства · '+VERSION,'Enter изменить · Esc назад. Выбор модулей применяется после перезапуска.']
      @commands=SettingsCommands.new(0,72);BS2Modules.style(@commands);@commands.activate
      @commands.set_handler(:cancel,method(:return_scene))
      @commands.set_handler(:modules,lambda { SceneManager.call(ModuleScene) })
      @commands.set_handler(:keys,lambda { SceneManager.call(KeysScene) })
      @commands.set_handler(:stats,lambda { SceneManager.call(StatsScene) }) if BS2Suite.enabled?('battle_stats')
      %w(palette_notes weapon_notes).each { |id| @commands.set_handler(id.to_sym,lambda { option(id,Options.get(id)==1 ? 0 : 1) }) }
      @commands.set_handler(:fast_items,lambda { option('fast_items',Options.get('fast_items')==1 ? 0 : 1) })
      @commands.set_handler(:run,lambda { option('run_mode',(Options.get('run_mode')+1)%3) })
      %w(bgm bgs me se).each { |id| @commands.set_handler(id.to_sym,lambda { option(id,(Options.get(id)+10)%110);BS2Suite::Sound.refresh }) } if BS2Suite.enabled?('sound')
      if BS2Suite.enabled?('debug')
        @commands.set_handler(:note,method(:note))
        @commands.set_handler(:debug,lambda { SceneManager.call(DebugScene) })
      end
    end
    def option(id,value)
      ::Sound.play_buzzer unless Options.set(id,value)
      @commands.refresh;@commands.activate
    end
    def note
      BS2Suite.edit_text(self,'',40) { |text| Debug.emit('user_note',{:text=>text,:state=>Debug.snapshot}) if text && !text.empty? }
      @commands.activate
    end
  end
  class ModuleCommands < Window_Command
    def initialize(selection)
      @selection=selection;super(0,72);BS2Modules.style(self)
    end
    def window_width;Graphics.width;end
    def visible_line_number;14;end
    def make_command_list
      IDS.each_with_index { |id,i| add_command((@selection.include?(id) ? '[✓] ' : '[ ] ')+NAMES[i],id.to_sym) }
    end
  end
  class ModuleScene < Scene_MenuBase
    def start
      super
      @selection=[]
      Store.read('modules').each_line { |l| @selection << $1 if l.strip =~ /\A([a-z_]+)=1\z/ && IDS.include?($1) }
      @header=BS2Modules::Header.new;@header.text=['Выбор модулей','Enter вкл/выкл · Esc назад · изменения после перезапуска игры']
      @commands=ModuleCommands.new(@selection)
      IDS.each { |id| @commands.set_handler(id.to_sym,lambda { toggle(id) }) }
      @commands.set_handler(:cancel,method(:return_scene))
    end
    def toggle(id)
      old=@selection.dup
      @selection.include?(id) ? @selection.delete(id) : @selection << id
      @selection << 'defeat' if id=='retry' && @selection.include?('retry') && !@selection.include?('defeat')
      @selection.delete('retry') if id=='defeat' && !@selection.include?('defeat')
      unless Store.write('modules',IDS.map { |key| key+'='+(@selection.include?(key) ? '1' : '0') }.join("\n")+"\n")
        @selection.replace(old);::Sound.play_buzzer
      end
      @commands.refresh;@commands.activate
    end
  end
  class KeyCommands < Window_Command
    def window_width;Graphics.width;end
    def visible_line_number;14;end
    def make_command_list
      Keys::DEFAULT.keys.each_with_index { |id,i| add_command(Keys::LABELS[i]+': '+Keys.token(id),id) }
      add_command('Восстановить стандартные назначения',:reset)
    end
  end
  class KeysScene < Scene_MenuBase
    def start
      super
      @header=BS2Modules::Header.new;@header.text=['Управление','Enter назначить · Esc назад · Shift/Ctrl+1…9: быстрые слоты (F6)']
      @commands=KeyCommands.new(0,72);BS2Modules.style(@commands)
      Keys::DEFAULT.keys.each { |action| @commands.set_handler(action,lambda { capture(action) }) }
      @commands.set_handler(:reset,method(:reset));@commands.set_handler(:cancel,method(:return_scene))
    end
    def reset
      if Store.write('keys','')
        Keys.instance_variable_set(:@data,nil);::Sound.play_ok
      else;::Sound.play_buzzer;end
      @commands.refresh;@commands.activate
    end
    def capture(action)
      @header.text=['Нажмите новую клавишу или сочетание Ctrl/Shift+клавиша','Esc — отмена. Занятые клавиши и быстрые слоты отклоняются.']
      begin
        loop do
          Graphics.update;Input.update
          break if BS2QoL::Keyboard.raw_fresh.include?(27)
          token=Keys.capture;next unless token
          if !/\A(?:CTRL|SHIFT)\+[1-9]\z/.match(token) && Keys.set(action,token)
            ::Sound.play_ok;break
          else
            ::Sound.play_buzzer
            @header.text=['Клавиша занята или настройка не записана','Нажмите другую клавишу. Esc — отмена.']
          end
        end
      ensure;Input.update;@commands.refresh;@commands.activate;end
      @header.text=['Управление','Enter назначить · Esc назад · Shift/Ctrl+1…9: быстрые слоты (F6)']
    end
  end
  class DebugScene < LinesScene
    def start
      super
      if Debug.error
        present('Диагностика',['Запись журнала остановлена: '+Debug.error,'Проверьте свободное место и права на папку BS2Suite/debug.','История не удаляется автоматически.'])
      else
        present('Диагностика',['Журнал записывается. Сессий и общего срока хранения не ограничиваем.','Папка: BS2Suite/debug/sessions',Keys.token(:note)+' — мгновенная отметка текущего состояния.','Замечание с текстом: Модули → Записать замечание.','После выхода используйте Collect-debug.cmd в пакете мода.','Отчёт включает журналы и настройки; личные сейвы не копирует.','Если процесс завершается вне Ruby, остаётся маркер незавершённой сессии. Точную причину сбоя ОС такой маркер не доказывает.'])
      end
    end
  end
end
class Window_MenuCommand
  alias bs2suite_settings_menu add_original_commands
  def add_original_commands
    bs2suite_settings_menu;add_command('Моды / опции',:bs2suite_settings)
  end
  def visible_line_number;[item_max,15].min;end
end
class Scene_Menu
  alias bs2suite_settings_commands create_command_window
  def create_command_window
    bs2suite_settings_commands
    @command_window.set_handler(:bs2suite_settings,lambda { SceneManager.call(BS2Suite::SettingsScene) })
  end
end
