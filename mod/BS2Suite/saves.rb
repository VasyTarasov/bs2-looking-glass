# encoding: UTF-8
module BS2Suite::Saves
  LIMIT=100
  def self.labels
    return @labels if @labels
    @labels={}
    BS2Suite::Store.read('save_labels').each_line do |line|
      m=/\A([0-9]{1,3})=([a-f0-9]{0,320})\z/.match(line.strip)
      next unless m && m[1].to_i<LIMIT
      text=[m[2]].pack('H*').force_encoding('UTF-8')
      @labels[m[1].to_i]=text if text.valid_encoding?
    end
    @labels
  end
  def self.label(index);labels[index].to_s;end
  def self.rename(index,text)
    return false unless (0...LIMIT).include?(index)
    old=labels[index];labels[index]=text.to_s.gsub(/[\x00-\x1f\x7f]/,'')[0,40]
    return true if BS2Suite::Store.write('save_labels',labels.keys.sort.map { |i| i.to_s+'='+labels[i].unpack('H*')[0] }.join("\n")+"\n")
    labels[index]=old;false
  end
  def self.valid_header?(head)
    head.is_a?(Hash) && head[:playtime_s].is_a?(String) && head[:playtime_s].valid_encoding?
  end
  def self.valid_contents?(contents)
    return false unless contents.is_a?(Hash)
    expected=DataManager.make_save_contents
    expected.all? { |key,value| contents.has_key?(key) && contents[key].is_a?(value.class) }
  end
  def self.rows(mode)
    list=(0...LIMIT).map do |i|
      header=DataManager.load_header(i)
      time=DataManager.savefile_time_stamp(i)
      {:id=>i,:header=>header,:time=>time,:exists=>File.file?(DataManager.make_filename(i))}
    end
    case mode
    when 1;list.sort_by { |r| [r[:exists] ? 0 : 1,-r[:time].to_i,r[:id]] }
    when 2;list.sort_by { |r| [label(r[:id]).empty? ? 1 : 0,label(r[:id]).downcase,r[:id]] }
    else;list;end
  end
  def self.replace(path,temp)
    move=Win32API.new('kernel32','MoveFileExW',['P','P','L'],'I')
    wide=lambda { |p| (File.expand_path(p)+"\0").encode('UTF-16LE') }
    raise IOError,'Could not replace save' if move.call(wide.call(temp),wide.call(path),9)==0
  end
  def self.write(index)
    return false unless index.is_a?(Integer) && (0...LIMIT).include?(index) && !$game_party.in_battle
    path=DataManager.make_filename(index);temp=path+'.bs2suite.tmp'
    system=$game_system;before=Marshal.dump(system)
    begin
      system.on_before_save
      File.open(temp,'wb') do |f|
        Marshal.dump(DataManager.make_save_header,f)
        Marshal.dump(DataManager.make_save_contents,f)
        f.flush;f.fsync
      end
      # Validate both objects before replacing a usable save.
      File.open(temp,'rb') { |f| raise IOError,'Invalid save header' unless Marshal.load(f).is_a?(Hash);raise IOError,'Invalid save body' unless Marshal.load(f).is_a?(Hash) }
      replace(path,temp)
      DataManager.instance_variable_set(:@last_savefile_index,index)
      @error=nil
      true
    rescue StandardError=>e
      restored=Marshal.load(before)
      system.instance_variables.each { |key| system.send(:remove_instance_variable,key) }
      restored.instance_variables.each { |key| system.instance_variable_set(key,restored.instance_variable_get(key)) }
      @error=e.class.to_s+': '+e.message
      false
    ensure
      begin;File.delete(temp) if File.file?(temp);rescue StandardError;end
    end
  end
  def self.error;@error;end
  class List < Window_Selectable
    attr_reader :rows
    def initialize
      @rows=[];super(0,72,Graphics.width,Graphics.height-72);BS2Modules.style(self)
    end
    def item_max;@rows.size;end
    def item_height;72;end
    def set_rows(rows,id=0)
      @rows=rows;create_contents;BS2Modules.style(self);refresh
      select(@rows.index { |r| r[:id]==id } || 0)
    end
    def selected_row;@rows[index];end
    def draw_item(index)
      r=item_rect_for_text(index);row=@rows[index];head=row[:header];id=row[:id]
      contents.font.size=20;change_color(normal_color)
      name='Слот %03d' % (id+1);description=BS2Suite::Saves.label(id)
      name+=' — '+description unless description.empty?
      draw_text(r.x,r.y,r.width,24,name)
      contents.font.size=17;change_color(system_color)
      if head
        line=row[:time].strftime('%d.%m.%Y %H:%M:%S')+' · '+head[:playtime_s].to_s+' · '+head[:bs2_map].to_s
        draw_text(r.x,r.y+24,r.width,24,BS2Modules.fit(self,line,r.width))
        party=head[:bs2_party].to_s
        draw_text(r.x,r.y+48,r.width,24,BS2Modules.fit(self,party,r.width))
      else
        draw_text(r.x,r.y+24,r.width,24,row[:exists] ? 'Файл не читается — выберите другой слот' : 'Свободно')
      end
    end
  end
end
module DataManager
  class << self
    def savefile_max;BS2Suite::Saves::LIMIT;end
    def save_game(index);BS2Suite::Saves.write(index);end
    def save_game_without_rescue(index);BS2Suite::Saves.write(index);end
    alias bs2suite_safe_header load_header
    def load_header(index)
      return nil unless index.is_a?(Integer) && (0...BS2Suite::Saves::LIMIT).include?(index)
      head=bs2suite_safe_header(index)
      BS2Suite::Saves.valid_header?(head) ? head : nil
    rescue StandardError;nil;end
    alias bs2suite_safe_load load_game_without_rescue
    def load_game_without_rescue(index)
      return false unless index.is_a?(Integer) && (0...BS2Suite::Saves::LIMIT).include?(index)
      File.open(make_filename(index),'rb') do |file|
        raise IOError,'Invalid save header' unless BS2Suite::Saves.valid_header?(Marshal.load(file))
        raise IOError,'Invalid save body' unless BS2Suite::Saves.valid_contents?(Marshal.load(file))
      end
      previous=make_save_contents;frame=Graphics.frame_count;last=@last_savefile_index
      begin
        result=bs2suite_safe_load(index)
        unless result
          extract_save_contents(previous);Graphics.frame_count=frame;@last_savefile_index=last
        end
        result
      rescue StandardError
        extract_save_contents(previous);Graphics.frame_count=frame;@last_savefile_index=last
        raise
      end
    end
    def latest_savefile_index
      readable=(0...savefile_max).select do |index|
        begin
          File.open(make_filename(index),'rb') do |file|
            BS2Suite::Saves.valid_header?(Marshal.load(file)) && BS2Suite::Saves.valid_contents?(Marshal.load(file))
          end
        rescue StandardError;false;end
      end
      readable.max_by { |index| [savefile_time_stamp(index),-index] } || 0
    end
    alias bs2suite_save_header make_save_header
    def make_save_header
      head=bs2suite_save_header
      location=$game_map.display_name.to_s.strip
      head[:bs2_map]=location.empty? ? 'Карта '+$game_map.map_id.to_s : location
      head[:bs2_party]=$game_party.members.map { |a| a.name+' ур. '+a.level.to_s }.join(' · ')
      head
    end
  end
end
class Scene_File
  def start
    super
    @bs2_mode=0;@header=BS2Modules::Header.new
    @bs2_files=BS2Suite::Saves::List.new
    @bs2_files.set_rows(BS2Suite::Saves.rows(@bs2_mode),first_savefile_index)
    @bs2_files.set_handler(:ok,method(:bs2suite_file_ok))
    @bs2_files.set_handler(:cancel,method(:on_savefile_cancel));@bs2_files.activate
    bs2suite_file_header
  end
  def bs2suite_file_header
    mode=['номер','новые сначала','подпись'][@bs2_mode]
    @header.text=[help_window_text,'A: сортировка ('+mode+') · S: подпись · Q/E страница · Esc назад']
  end
  def bs2suite_file_ok
    @index=@bs2_files.selected_row[:id]
    # A corrupted existing file is never overwritten without first moving elsewhere.
    if is_a?(Scene_Save) && @bs2_files.selected_row[:exists] && !@bs2_files.selected_row[:header]
      Sound.play_buzzer;@bs2_files.activate;return
    end
    on_savefile_ok
    @bs2_files.activate unless scene_changing?
  end
  def update
    super
    return unless @bs2_files.active
    if Input.trigger?(:X)
      id=@bs2_files.selected_row[:id];@bs2_mode=(@bs2_mode+1)%3
      @bs2_files.set_rows(BS2Suite::Saves.rows(@bs2_mode),id);bs2suite_file_header
    elsif Input.trigger?(:Y)
      id=@bs2_files.selected_row[:id];@bs2_files.deactivate
      BS2Suite.edit_text(self,BS2Suite::Saves.label(id),40) do |text|
        Sound.play_buzzer if text && !BS2Suite::Saves.rename(id,text)
      end
      @bs2_files.set_rows(BS2Suite::Saves.rows(@bs2_mode),id);@bs2_files.activate
    end
  end
  def terminate;super;end
end

