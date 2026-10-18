# encoding: UTF-8
module BS2Suite
  module Keys
    BASE={'BACKSPACE'=>8,'TAB'=>9,'ENTER'=>13,'SHIFT'=>16,'CTRL'=>17,'ESC'=>27,'SPACE'=>32,'PAGEUP'=>33,'PAGEDOWN'=>34,'END'=>35,'HOME'=>36,'LEFT'=>37,'UP'=>38,'RIGHT'=>39,'DOWN'=>40,'INSERT'=>45,'DELETE'=>46}
    ('0'..'9').each { |s| BASE[s]=s.ord };('A'..'Z').each { |s| BASE[s]=s.ord }
    (3..11).each { |n| BASE['F'+n.to_s]=111+n }
    DEFAULT={:UP=>'UP',:DOWN=>'DOWN',:LEFT=>'LEFT',:RIGHT=>'RIGHT',:C=>'ENTER',:B=>'ESC',:A=>'SHIFT',:X=>'A',:Y=>'S',:Z=>'D',:L=>'Q',:R=>'E',:bind=>'F6',:reference=>'F7',:language=>'F8',:field=>'F10',:note=>'F9',:stats=>'F5',:run=>'TAB',:attack=>'1',:skills=>'2',:guard=>'3',:items=>'4',:escape=>'5',:equip=>'6',:quicksave=>'F3',:enemy_info=>'F4',:palette_v=>'V',:palette_b=>'B',:palette_m=>'M',:palette_n=>'N',:combat_effects=>'H'}
    LOGICAL=[:UP,:DOWN,:LEFT,:RIGHT,:C,:B,:A,:X,:Y,:Z,:L,:R]
    NATIVE={:UP=>[38],:DOWN=>[40],:LEFT=>[37],:RIGHT=>[39],:C=>[13,32,90],:B=>[27,88,96],:A=>[16],:X=>[65],:Y=>[83],:Z=>[68],:L=>[81,33],:R=>[69,87,34]}
    LABELS=['Вверх','Вниз','Влево','Вправо','Подтвердить','Отмена / меню','Бег (удержание)','Избранное','Фильтр избранного','Доп. клавиша D','Предыдущая страница','Следующая страница','Назначить быстрый слот','Открыть справку','Язык справки','Полевые навыки','Отметка в журнале','Журнал боя / последняя статистика','Переключить бег','Атака','Техники','Защита','Предметы','Бежать из боя','Сменить оружие','Быстрое сохранение (5 слотов)','Противники и сопротивления','Оружейные группы','Предметные группы','Магия и изученные приёмы','Выбор оружия N','Все эффекты участников боя']
    def self.data
      return @data if @data
      @data=DEFAULT.dup
      Store.read('keys').each_line do |line|
        m=/\A([A-Za-z_]+)=([A-Z0-9+]+)\z/.match(line.strip)
        @data[m[1].to_sym]=m[2] if m && DEFAULT.has_key?(m[1].to_sym) && valid?(m[2])
      end
      @data[:R]='E' if @data[:R]=='W' && !@data.any? { |k,v| k!=:R && v.split('+')[-1]=='E' }
      # New palette defaults must not reset a player's existing control map.
      [:palette_v,:palette_b,:palette_m,:palette_n,:combat_effects].each do |action|
        token=@data[action]
        conflict=@data.any? { |other,value| other!=action && (value==token || (LOGICAL.include?(other) && value.split('+')[-1]==token.split('+')[-1])) }
        if conflict
          choices=%w(V B M N G H J K L O P R T U I CTRL+F3 CTRL+F4 CTRL+F5 CTRL+F6 CTRL+F7 CTRL+F8 CTRL+F9)
          spare=choices.find { |candidate| !@data.any? { |other,value| other!=action && (value==candidate || (LOGICAL.include?(other) && value.split('+')[-1]==candidate.split('+')[-1])) } }
          @data[action]=spare if spare
        end
      end
      invalid=@data.values.uniq.size!=@data.size
      @data.each do |action,token|
        invalid ||= !!/\A(?:CTRL\+SHIFT|CTRL|SHIFT)\+[0-9]\z/.match(token)
        invalid ||= ['CTRL','SHIFT'].include?(token) && action!=:A
        invalid ||= @data.any? { |other,value| other!=action && (LOGICAL.include?(other) || LOGICAL.include?(action)) && value.split('+')[-1]==token.split('+')[-1] }
      end
      @data=DEFAULT.dup if invalid
      @data
    end
    def self.valid?(token)
      parts=token.split('+');return false unless (1..2).include?(parts.size)
      BASE.has_key?(parts[-1]) && (parts.size==1 || ['CTRL','SHIFT'].include?(parts[0])) && !(parts.size==2 && ['CTRL','SHIFT'].include?(parts[-1]))
    end
    def self.token(action);BS2Suite.enabled?('controls') ? data[action] : DEFAULT[action];end
    def self.set(action,token)
      return false unless DEFAULT.has_key?(action) && valid?(token)
      return false if /\A(?:CTRL\+SHIFT|CTRL|SHIFT)\+[0-9]\z/.match(token)
      return false if ['CTRL','SHIFT'].include?(token) && action!=:A
      # Navigation and global mod commands cannot steal one another's input.
      other=data.keys.find { |a| a!=action && data[a]==token }
      return false if other
      base=token.split('+')[-1]
      return false if data.keys.any? { |a| a!=action && (LOGICAL.include?(a) || LOGICAL.include?(action)) && data[a].split('+')[-1]==base }
      old=data[action];data[action]=token
      return true if Store.write('keys',data.map { |k,v| k.to_s+'='+v }.join("\n")+"\n")
      data[action]=old;false
    end
    def self.held?(token,down,strict=false)
      parts=token.split('+');base=BASE[parts[-1]]
      return false unless base && down.include?(base)
      return down.include?(parts[0]=='CTRL' ? 17 : 16) if parts.size==2
      return true if ['SHIFT','CTRL'].include?(token)
      !strict || (!down.include?(16) && !down.include?(17))
    end
    def self.trigger?(action)
      BS2QoL::Keyboard.raw_fresh.any? { |vk| vk==BASE[token(action).split('+')[-1]] } && held?(token(action),BS2QoL::Keyboard.raw_down,true)
    end
    def self.capture
      k=BS2QoL::Keyboard
      code=k.raw_fresh.find { |v| BASE.values.include?(v) && ![16,17].include?(v) }
      return nil unless code
      name=BASE.key(code)
      (k.raw_down.include?(17) ? 'CTRL+' : k.raw_down.include?(16) ? 'SHIFT+' : '')+name
    end
    def self.remap_token(token)
      aliases={:bind=>'F6',:reference=>'F7',:language=>'F8',:attack=>'1',:skills=>'2',:guard=>'3',:items=>'4',:escape=>'5',:equip=>'6',:quicksave=>'F3',:enemy_info=>'F4',:palette_v=>'V',:palette_b=>'B',:palette_m=>'M',:palette_n=>'N',:combat_effects=>'H'}
      aliases.each { |action,pseudo| return pseudo if trigger?(action) }
      token
    end
  end
end
class BS2QoL::WindowsKeys
  def down
    return [] unless focused?
    ((8..18).to_a+(27..46).to_a+(48..90).to_a+(96..123).to_a+[91,92]).select { |vk| (@async.call(vk)&0x8000)!=0 }
  end
end
module BS2QoL::Keyboard
  class << self
    def raw_down;@raw_down || [];end
    def raw_fresh;@raw_fresh || [];end
    def focused?;!!@focused;end
    def update
      frame=Graphics.frame_count
      if @frame==frame
        @triggers=[];@raw_fresh=[];return
      end
      @frame=frame;@backend ||= BS2QoL::WindowsKeys.new
      @focused=@backend.focused?
      unless @focused
        @previous=[];@triggers=[];@raw_down=[];@raw_fresh=[];@resync=true;return
      end
      current=@backend.down
      unless @backend.focused?
        @focused=false;@previous=[];@triggers=[];@raw_down=[];@raw_fresh=[];@resync=true;return
      end
      @raw_down=current;@error=nil
      if @resync || !@previous
        @previous=current;@raw_fresh=[];@triggers=[];@resync=false;return
      end
      @raw_fresh=current-@previous;@previous=current;@triggers=[]
      return if (current & [18,91,92]).any? 
      @raw_fresh.sort.each do |vk|
        prefix=current.include?(16) && current.include?(17) ? 'CS' : current.include?(16) ? 'S' : current.include?(17) ? 'C' : ''
        if (48..57).include?(vk)
          @triggers << prefix+(vk-48).to_s
        elsif prefix.empty?
          @triggers << 'F'+(vk-111).to_s if (113..122).include?(vk)
          @triggers << 'DELETE' if vk==46
        end
      end
      if BS2Suite.enabled?('controls')
        pseudo=BS2Suite::Keys.remap_token(nil)
        # A moved command does not remain on its old physical key.
        reserved={'F6'=>:bind,'F7'=>:reference,'F8'=>:language,'1'=>:attack,'2'=>:skills,'3'=>:guard,'4'=>:items,'5'=>:escape,'6'=>:equip}
        @triggers.reject! { |t| reserved[t] && BS2Suite::Keys.token(reserved[t])!=BS2Suite::Keys::DEFAULT[reserved[t]] }
        @triggers.unshift(pseudo) if pseudo
      end
    rescue StandardError
      @triggers=[];@raw_fresh=[];@raw_down=[];@error=:keyboard_failed
    end
  end
end
if BS2Suite.enabled?('controls')
  module Input
    class << self
      alias bs2suite_trigger trigger?
      alias bs2suite_press press?
      alias bs2suite_repeat repeat?
      alias bs2suite_input_update update
      def update
        bs2suite_input_update
        return if @bs2suite_frame==Graphics.frame_count
        @bs2suite_frame=Graphics.frame_count
        @bs2suite_holds ||= {}
        BS2Suite::Keys::LOGICAL.each do |action|
          down=BS2QoL::Keyboard.focused? && BS2Suite::Keys.held?(BS2Suite::Keys.token(action),BS2QoL::Keyboard.raw_down)
          @bs2suite_holds[action]=down ? (@bs2suite_holds[action] || 0)+1 : 0
        end
      end
      def bs2suite_native_allowed?(action)
        BS2Suite::Options.get('pad_fallback')==1 && (BS2QoL::Keyboard.raw_down & BS2Suite::Keys::NATIVE[action]).empty?
      end
      def trigger?(action)
        return bs2suite_trigger(action) unless BS2Suite::Keys::LOGICAL.include?(action)
        n=(@bs2suite_holds || {})[action] || 0
        (n==1 && BS2QoL::Keyboard.raw_fresh.include?(BS2Suite::Keys::BASE[BS2Suite::Keys.token(action).split('+')[-1]])) || (bs2suite_native_allowed?(action) && bs2suite_trigger(action))
      end
      def press?(action)
        return bs2suite_press(action) unless BS2Suite::Keys::LOGICAL.include?(action)
        ((@bs2suite_holds || {})[action] || 0)>0 || (bs2suite_native_allowed?(action) && bs2suite_press(action))
      end
      def repeat?(action)
        return bs2suite_repeat(action) unless BS2Suite::Keys::LOGICAL.include?(action)
        n=(@bs2suite_holds || {})[action] || 0
        trigger?(action) || (n>=24 && n%6==0) || (bs2suite_native_allowed?(action) && bs2suite_repeat(action))
      end
      def dir4
        x=(press?(:RIGHT) ? 1 : 0)-(press?(:LEFT) ? 1 : 0);y=(press?(:DOWN) ? 1 : 0)-(press?(:UP) ? 1 : 0)
        return y>0 ? 2 : 8 if y!=0
        x==0 ? 0 : x>0 ? 6 : 4
      end
      def dir8
        x=(press?(:RIGHT) ? 1 : 0)-(press?(:LEFT) ? 1 : 0);y=(press?(:DOWN) ? 1 : 0)-(press?(:UP) ? 1 : 0)
        return dir4 if x==0 || y==0
        y>0 ? (x>0 ? 3 : 1) : (x>0 ? 9 : 7)
      end
    end
  end
end
