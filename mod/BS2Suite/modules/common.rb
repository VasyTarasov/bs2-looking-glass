# encoding: UTF-8
module BS2Modules
  PARAMS = ['Макс. ОЗ','Макс. ОМ','Атака','Защита','Магия','Маг. защита','Скорость','Удача']
  def self.label(object, fallback='Эффект')
    return 'Пусто' unless object
    name = object.name.to_s.strip
    name.empty? ? fallback + ' #' + object.id.to_s : name
  end
  def self.num(value); ('%.3f' % value).sub(/\.?0+\z/,''); end
  def self.pct(value); num(value * 100) + '%'; end
  def self.clone(value); Marshal.load(Marshal.dump(value)); end
  def self.skin
    return @skin if @skin && !@skin.disposed?
    @skin=Bitmap.new(128,128)
    @skin.fill_rect(0,0,64,64,Color.new(19,22,29,255))
    border=Color.new(79,87,105,255)
    @skin.fill_rect(64,0,64,1,border);@skin.fill_rect(64,63,64,1,border)
    @skin.fill_rect(64,0,1,64,border);@skin.fill_rect(127,0,1,64,border)
    @skin.fill_rect(64,64,32,32,Color.new(65,91,130,180))
    colors=[Color.new(232,235,241),Color.new(153,193,240),Color.new(240,133,133),Color.new(157,211,164)]
    32.times { |i| @skin.fill_rect(64+(i%8)*8,96+(i/8)*8,8,8,colors[i%4]) }
    @skin
  end
  def self.style(window)
    window.windowskin=skin
    window.tone=Tone.new(0,0,0,0)
    window.opacity=255;window.back_opacity=255
    window.contents.font.name='Segoe UI'
    window.contents.font.size=20
    window.contents.font.shadow=false;window.contents.font.outline=false
  end
  def self.fit(window,text,width)
    text=text.to_s
    return text if window.text_size(text).width<=width
    text=text[0,text.size-1] while !text.empty? && window.text_size(text+'…').width>width
    text+'…'
  end

  # All persisted data is bounded plain text. Never eval or Marshal-load profiles.
  def self.write_text(path, text)
    Dir.mkdir(File.dirname(path)) unless File.directory?(File.dirname(path))
    temp = path + '.tmp'
    File.open(temp, 'wb') { |f| f.write(text); f.flush }
    # MoveFileEx replaces an existing file atomically on Windows / Ruby 1.9.2.
    move = Win32API.new('kernel32', 'MoveFileExW', ['P','P','L'], 'I')
    wide = lambda { |s| (File.expand_path(s) + "\0").encode('UTF-16LE') }
    raise IOError, 'Cannot replace settings' if move.call(wide.call(temp),wide.call(path),9) == 0
    true
  rescue StandardError
    false
  end

  class Lines < Window_Selectable
    attr_reader :lines
    def initialize(x,y,w,h)
      @lines=[]
      super
      self.z=410
      BS2Modules.style(self)
    end
    def item_max; @lines ? @lines.size : 0; end
    def item_height; 24; end
    def set_lines(lines)
      self.contents.font.size=20
      @lines=[]
      lines.each do |text|
        text.to_s.split("\n",-1).each do |paragraph|
          line=''
          paragraph.each_char do |char|
            if text_size(line+char).width > contents_width-8 && !line.empty?
              @lines << line; line=''
            end
            line += char
          end
          @lines << line
        end
      end
      @lines=['Нет записей.'] if @lines.empty?
      create_contents
      BS2Modules.style(self)
      self.contents.font.size=20
      refresh
      select(0)
      self.top_row=0
    end
    def draw_item(index)
      change_color(normal_color)
      draw_text(item_rect_for_text(index),@lines[index])
    end
  end

  class List < Window_Selectable
    attr_reader :rows
    def initialize(x,y,w,h)
      @rows=[]
      super
      self.z=410
      BS2Modules.style(self)
    end
    def item_max; @rows.size; end
    def item_height; 48; end
    def set_rows(rows)
      @rows=rows
      create_contents;BS2Modules.style(self);refresh;select(0);self.top_row=0
    end
    def draw_item(index)
      row=@rows[index];r=item_rect_for_text(index)
      contents.font.size=20
      change_color(normal_color)
      draw_text(r.x,r.y,r.width,24,BS2Modules.fit(self,row[:name],r.width))
      change_color(system_color)
      contents.font.size=17
      draw_text(r.x,r.y+24,r.width,24,BS2Modules.fit(self,row[:summary],r.width))
    end
  end

  class Header < Window_Base
    def initialize
      super(0,0,Graphics.width,72)
      self.z=410
      BS2Modules.style(self)
    end
    def text=(lines)
      contents.clear;contents.font.size=20
      lines.each_with_index { |s,i| draw_text(0,i*24,contents_width,24,i==1 ? BS2Suite.key_text(s) : s) }
    end
  end
end
