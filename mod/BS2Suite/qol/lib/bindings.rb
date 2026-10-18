# encoding: UTF-8
module BS2QoL
  module Bindings
    class << self
      attr_reader :error
      def path; File.join(Dir.pwd,'BS2QoL','bindings.ini'); end
      def valid_scope?(scope)
        ['weapons','items','quick'].include?(scope) || !!(/\Aweapon(?:0|[1-9][0-9]{0,4})\z/ =~ scope)
      end
      def valid?(scope,chord,kind,id)
        return false unless valid_scope?(scope) && id.is_a?(Integer) && id>0 && id<100000
        return kind==:weapon && !!(/\AS[1-9]\z/ =~ chord) if scope=='weapons'
        return [:item,:skill].include?(kind) && !!(/\AC[1-9]\z/ =~ chord) if scope=='quick'
        kind==(scope=='items' ? :item : :skill) && !!(/\AS[1-9]\z/ =~ chord)
      end
      def parse(text)
        result={}
        text.to_s.each_line do |line|
          if match=/\Ascope=([a-z0-9]+)\z/.match(line.strip)
            result[match[1]] ||= {} if valid_scope?(match[1]) && (result.has_key?(match[1]) || result.size<1024)
          elsif match=/\Abind=([a-z0-9]+),([SC][1-9]),(weapon|item|skill),([0-9]+)\z/.match(line.strip)
            scope,chord,kind,id=match[1],match[2],match[3].to_sym,match[4].to_i
            (result[scope] ||= {})[chord]=[kind,id] if valid?(scope,chord,kind,id) && (result.has_key?(scope) || result.size<1024)
          end
        end
        result
      end
      def data
        return @data if @data
        @data={}
        if File.file?(path) && File.size(path)<=1048576
          @data=parse(File.open(path,'rb') { |f| f.read })
        end
        @data
      rescue StandardError
        @error=:read_failed
        @data ||= {}
      end
      def weapon_scope(actor)
        weapon=actor && actor.equips[0]
        'weapon'+(weapon ? weapon.id : 0).to_s
      end
      def weapon_skills(actor)
        weapon=actor && actor.equips[0]
        weapon ? weapon.features.select { |f| f.code==43 }.map { |f| f.data_id }.uniq : []
      end
      def ensure_scope(scope,actor=nil)
        return data[scope] if data.has_key?(scope)
        entries={}
        objects=case scope
        when 'weapons'; Preferences.ids(:weapon).map { |id| [:weapon,id] }
        when 'items'; Preferences.ids(:item).map { |id| [:item,id] }
        when 'quick'
          items=Preferences.ids(:item).map { |id| [:item,id] }
          spells=Preferences.ids(:skill).select { |id| actor && $data_skills[id] && actor.skill_learn?($data_skills[id]) }.map { |id| [:skill,id] }
          items+spells
        else
          weapon=$data_weapons[scope.sub('weapon','').to_i]
          ids=weapon ? weapon.features.select { |f| f.code==43 }.map { |f| f.data_id }.uniq : []
          ids.map { |id| [:skill,id] }
        end
        objects.take(9).each_with_index { |object,i| entries[(scope=='quick' ? 'C' : 'S')+(i+1).to_s]=object }
        data[scope]=entries
        persist
        entries
      end
      def get(scope,chord,actor=nil); ensure_scope(scope,actor)[chord]; end
      def set(scope,chord,kind,id)
        return false unless valid?(scope,chord,kind,id)
        (data[scope] ||= {})[chord]=[kind,id]
        persist
        true
      end
      def remove(scope,kind,id)
        entries=data[scope] ||= {}
        entries.delete_if { |key,value| value==[kind,id] }
        persist
      end
      def label(chord)
        return '' unless chord
        (chord[0,1]=='S' ? 'Shift+' : 'Ctrl+')+chord[-1,1]
      end
      def object(binding); binding && Model.database(binding[0])[binding[1]]; end
      def persist
        directory=File.dirname(path)
        Dir.mkdir(directory) unless File.directory?(directory)
        text="version=1\n"
        data.keys.sort.each do |scope|
          text+='scope='+scope+"\n"
          data[scope].keys.sort.each do |chord|
            kind,id=data[scope][chord]
            text+='bind='+[scope,chord,kind,id].join(',')+"\n"
          end
        end
        File.open(path+'.tmp','wb') { |f| f.write(text);f.flush }
        if File.file?(path)
          File.open(path+'.bak','wb') { |f| f.write(File.open(path,'rb') { |old| old.read }) }
        end
        File.rename(path+'.tmp',path)
        @error=nil
        true
      rescue StandardError
        @error=:write_failed
        false
      end
    end
  end

  class WindowsKeys
    def initialize
      @foreground=Win32API.new('user32','GetForegroundWindow',[],'L')
      @owner=Win32API.new('user32','GetWindowThreadProcessId',['L','P'],'L')
      @process=Win32API.new('kernel32','GetCurrentProcessId',[],'L').call
      @async=Win32API.new('user32','GetAsyncKeyState',['I'],'I')
    end
    def focused?
      window=@foreground.call
      return false if window==0
      owner=[0].pack('L')
      @owner.call(window,owner)!=0 && owner.unpack('L')[0]==@process
    end
    def down
      return [] unless focused?
      ([0x10,0x11,0x12,0x5B,0x5C,0x75,0x76,0x77,0x2E]+(0x31..0x39).to_a).select { |vk| (@async.call(vk)&0x8000)!=0 }
    end
  end

  module Keyboard
    class << self
      attr_accessor :backend
      attr_reader :error
      def update
        frame=Graphics.frame_count
        if @frame==frame
          @triggers=[]
          return
        end
        @frame=frame
        @backend ||= WindowsKeys.new
        unless @backend.focused?
          @previous=[];@triggers=[];@resync=true
          return
        end
        current=@backend.down
        unless @backend.focused?
          @previous=[];@triggers=[];@resync=true
          return
        end
        @error=nil
        if @resync || !@previous
          @previous=current;@triggers=[];@resync=false
          return
        end
        fresh=current-@previous
        @previous=current
        @triggers=[]
        return if current.include?(0x12) || current.include?(0x5B) || current.include?(0x5C)
        modified=current.include?(0x10) || current.include?(0x11)
        @triggers << 'F6' if fresh.include?(0x75) && !modified
        @triggers << 'F7' if fresh.include?(0x76) && !modified
        @triggers << 'F8' if fresh.include?(0x77) && !modified
        @triggers << 'DELETE' if fresh.include?(0x2E) && !modified
        return if current.include?(0x10) && current.include?(0x11)
        fresh.select { |vk| (0x31..0x39).include?(vk) }.sort.each do |vk|
          prefix=current.include?(0x10) ? 'S' : (current.include?(0x11) ? 'C' : '')
          @triggers << prefix+(vk-0x30).to_s
        end
      rescue StandardError
        @triggers=[];@error=:keyboard_failed
      end
      def first; (@triggers || [])[0]; end
      def consume; @triggers=[]; end
      def reset
        @frame=nil;@previous=nil;@triggers=[];@resync=false;@error=nil
      end
    end
  end
end

module Input
  class << self
    alias bs2q_keyboard_native_update update
    def update
      bs2q_keyboard_native_update
      BS2QoL::Keyboard.update
    end
  end
end

