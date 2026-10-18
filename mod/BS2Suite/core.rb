# encoding: UTF-8
module BS2Suite
  def self.key_text(text)
    map={'F5'=>:stats,'F6'=>:bind,'F7'=>:reference,'F8'=>:language,'F9'=>:note,'F10'=>:fullscreen,'Enter'=>:C,'Esc'=>:B,'Q'=>:L,'E'=>:R,'A'=>:X,'S'=>:Y}
    text.to_s.gsub(/\b(F10|F11|F[5-9]|Enter|Esc|Q|E|A|S)\b/) { |key| Keys.token(map[key]) }
  end
  NAMES=['Избранное и штатные команды','Очередь действий','Справка / прогноз RU+EN','Каталог эффектов','Комплекты','Изученные книги','Полевые навыки','Удобные сохранения','Окно поражения','Повтор боя','Статистика боя','Управление','Переключаемый бег','Громкость','Диагностика','Группы V/B/M и оружие N','Legacy: прежние сочетания (Advanced)','Массовое использование душ','Прокачка экипированного оружия','Steam: OpenGL / скриншоты (эксперимент)','HD-экран и интерфейс (прототип)','Убирать дубли снаряжения']
  module Store
    def self.path(name);File.join(Dir.pwd,'BS2Suite',name+'.ini');end
    def self.read(name,limit=32768)
      path=path(name)
      text=File.file?(path) && File.size(path)<=limit ? File.open(path,'rb') { |f| f.read }.force_encoding('UTF-8') : ''
      text.valid_encoding? ? text : ''
    rescue StandardError;'';end
    def self.write(name,text)
      result=BS2Modules.write_text(path(name),text)
      BS2Suite::Debug.emit('settings_write',{:file=>name,:success=>result}) if defined?(BS2Suite::Debug)
      result
    end
  end
  module Options
    # Register every option before the first lazy read (sound/HD can trigger it
    # during bootstrap). Late-added defaults used to discard saved 0.991 keys.
    DEFAULTS={'instant_battle_ctrl'=>1,'navigation_aliases'=>1,'adaptive_priority'=>1,'priority_window'=>20,'tempo_hint'=>1,'experimental_support'=>0,'crisp_hd'=>1,'palette_notes'=>1,'weapon_notes'=>1,'bgm'=>100,'bgs'=>100,'me'=>100,'se'=>100,'run_mode'=>0,'fast_items'=>0,'steam_mode'=>1,'pad_fallback'=>1,'knowledge_threshold'=>2}
    def self.data
      return @data if @data
      @data=DEFAULTS.dup
      Store.read('options').each_line do |line|
        m=/\A([a-z_]+)=([0-9]{1,3})\z/.match(line.strip)
        next unless m && DEFAULTS.has_key?(m[1])
        v=m[2].to_i
        @data[m[1]]=v if (m[1]=='scale' ? (1..4).include?(v) : m[1]=='run_mode' ? (0..2).include?(v) : m[1]=='pad_fallback' ? (0..1).include?(v) : (0..100).include?(v))
      end
      @data
    end
    def self.get(key);data[key];end
    def self.set(key,value)
      return false unless DEFAULTS.has_key?(key) && value.is_a?(Integer)
      range=key=='scale' ? (1..4) : key=='run_mode' ? (0..2) : key=='pad_fallback' ? (0..1) : (0..100)
      return false unless range.include?(value)
      old=data[key];data[key]=value
      return true if Store.write('options',data.keys.sort.map { |k| k+'='+data[k].to_s }.join("\n")+"\n")
      data[key]=old;false
    end
  end
  class LinesScene < Scene_MenuBase
    def start
      super
      @header=BS2Modules::Header.new
      @lines=BS2Modules::Lines.new(0,72,Graphics.width,Graphics.height-72)
      @lines.set_handler(:cancel,method(:return_scene));@lines.activate
    end
    def present(title,lines)
      @header.text=[title,'↑/↓ прокрутка · Q/E страница · Esc назад']
      @lines.set_lines(lines)
    end
  end
  class TextEdit < Window_NameEdit
    def initialize(actor,max_char)
      super
      self.x=8;self.width=Graphics.width-16;create_contents;refresh
    end
    def face_width;0;end
    def draw_actor_face(*args);end
    def char_width;12;end
  end
  class TextInput < Window_NameInput
    RU1=('АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ 0123456789.,!?:;+-/()').chars.to_a
    RU2=('абвгдеёжзийклмнопрстуфхцчшщъыьэюя 0123456789.,!?:;+-/()').chars.to_a
    def table
      [LATIN1,LATIN2,RU1+Array.new(88-RU1.size,' ')+['abc','OK'],RU2+Array.new(88-RU2.size,' ')+['ABC','OK']]
    end
    def process_handling
      return unless open? && active
      if Input.trigger?(:B) && @edit_window.name.empty?
        deactivate;call_handler(:cancel)
      else;super;end
    end
  end
  # No actor or mod class is persisted: a tiny temporary name proxy only.
  def self.edit_text(scene,initial,max,&done)
    edit=TextEdit.new(Struct.new(:name).new(initial),max);edit.z=800
    input=TextInput.new(edit);input.z=800
    BS2Modules.style(edit);edit.refresh;BS2Modules.style(input);input.refresh
    result=nil;closed=false
    input.set_handler(:ok,lambda { result=edit.name;closed=true })
    input.set_handler(:cancel,lambda { closed=true })
    begin
      until closed
        Graphics.update;Input.update;input.update;edit.update
      end
    ensure;input.dispose;edit.dispose;Input.update;end
    done.call(result) if done
    result
  end
end
