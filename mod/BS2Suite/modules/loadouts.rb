# encoding: UTF-8
module BS2Modules
  module Loadouts
    LIMIT=8
    class << self
      attr_reader :error
      def path;File.join(Dir.pwd,'BS2Modules','loadouts.ini');end
      def data
        return @data if @data
        @data={};@error=nil
        return @data unless File.file?(path)
        raise IOError,'Profile too large' if File.size(path)>131072
        raw=File.open(path,'rb') { |f| f.read }.force_encoding('UTF-8')
        raise IOError,'Invalid encoding' unless raw.valid_encoding?
        @data=parse(raw)
      rescue StandardError
        @error=:read_failed;@data={};@read_failed=true
        @data
      end
      def parse(text)
        return {} unless text.is_a?(String) && text.valid_encoding?
        result={};current=nil
        text.each_line do |line|
          line=line.strip
          if line =~ /\A\[actor\.(\d+)\.set\.([1-8])\]\z/
            key=[$1.to_i,$2.to_i];current=nil
            if key[0]>0 && key[0]<=9999
              current={:name=>'Комплект '+key[1].to_s,:slots=>{}}
              result[key]=current
            end
          elsif line.start_with?('[')
            current=nil
          elsif current && line =~ /\Aname=(.{1,24})\z/
            current[:name]=$1.gsub(/[\x00-\x1f\x7f]/,'')
          elsif current && line =~ /\Aslot=(\d+),(\d+),(\d+)\z/
            index,type,id=$1.to_i,$2.to_i,$3.to_i
            current[:slots][index]=[type,id] if index<16 && type>0 && type<16 && id<100000
          end
        end
        result
      end
      def persist
        text="format=1\n"
        data.keys.sort.each do |key|
          set=data[key]
          text+='[actor.'+key[0].to_s+'.set.'+key[1].to_s+"]\nname="+set[:name]+"\n"
          set[:slots].keys.sort.each { |i| text+='slot='+[i,*set[:slots][i]].join(',')+"\n" }
        end
        return false if @read_failed
        okay=BS2Modules.write_text(path,text)
        @error=okay ? nil : :write_failed
        okay
      end
      def get(actor,index);data[[actor.id,index]];end
      def slots(actor)
        actor.equip_slots.each_index.select { |i| actor.equip_slots[i]!=0 }
      end
      def save(actor,index,name=nil)
        return false if $game_party.in_battle || !(1..LIMIT).include?(index)
        old=get(actor,index)
        name=(name || (old && old[:name]) || 'Комплект '+index.to_s).to_s.gsub(/[\x00-\x1f\x7f]/,'')[0,24].strip
        name='Комплект '+index.to_s if name.empty?
        set={:name=>name,:slots=>{}}
        slots(actor).each { |i| set[:slots][i]=[actor.equip_slots[i],actor.equips[i] ? actor.equips[i].id : 0] }
        replace([actor.id,index],set)
      end
      def replace(key,value)
        previous=BS2Modules.clone(data)
        value ? data[key]=value : data.delete(key)
        return true if persist
        @data=previous
        false
      end
      def rename(actor,index,name)
        old=get(actor,index);return false unless old
        text=name.to_s.gsub(/[\x00-\x1f\x7f]/,'')[0,24].strip
        return false if text.empty?
        set=BS2Modules.clone(old);set[:name]=text
        replace([actor.id,index],set)
      end
      def delete(actor,index);replace([actor.id,index],nil);end
      def slot_name(actor,index)
        type=actor.equip_slots[index]
        label=Vocab.etype(type).to_s
        if actor.equip_slots.count(type)>1
          label+=' '+(actor.equip_slots[0..index].count(type)).to_s
        end
        label
      end
      def item(id);id==0 ? nil : $data_armors[id];end
      def blocked(actor)
        return 'Комплекты доступны только вне боя.' if $game_party.in_battle || $game_temp.battle_equip
        return 'Персонаж отсутствует в группе.' unless $game_party.members.include?(actor)
        return 'Дождитесь завершения события.' if $game_map.interpreter.running? || $game_message.busy?
        nil
      end
      def expected(actor,set)
        raise ArgumentError,'Профиль не содержит все слоты этого персонажа.' unless set && set[:slots].keys.sort==slots(actor).sort
        result=actor.equips.dup
        set[:slots].each do |i,pair|
          type,id=pair
          raise ArgumentError,'Изменился набор слотов. Сохраните комплект заново.' unless actor.equip_slots[i]==type && type!=0
          object=item(id)
          raise ArgumentError,'Вещь отсутствует в базе игры.' if id!=0 && !object
          raise ArgumentError,'Тип предмета не совпадает со слотом.' if object && object.etype_id!=type
          result[i]=object
        end
        result
      end
      # Execute the exact same ordinary equip operations for preview and commit.
      # Every intermediate step must preserve all other slots and item counts.
      def execute(actor,target)
        indices=slots(actor).select { |i| actor.equips[i]!=target[i] }
        indices.each { |i| raise ArgumentError,'Слот заблокирован: '+slot_name(actor,i) unless actor.equip_change_ok?(i) }
        # Releasing all changed slots first permits ring permutations and exact
        # multiplicity checks. Reject dependencies which would auto-drop weapons.
        indices.each { |i| step(actor,i,nil) }
        indices.each do |i|
          object=target[i];next unless object
          raise ArgumentError,'Недоступно для персонажа: '+BS2Modules.label(object) unless actor.equippable?(object)
          raise ArgumentError,'Не хватает экземпляров: '+BS2Modules.label(object) if $game_party.item_number(object)<1
          step(actor,i,object)
        end
        raise ArgumentError,'Итоговая экипировка изменилась из-за ограничений.' unless actor.equips==target
        true
      end
      def step(actor,index,object)
        raise ArgumentError,'Слот заблокирован: '+slot_name(actor,index) unless actor.equip_change_ok?(index)
        previous=actor.equips.dup;old=previous[index]
        if old && $game_party.item_number(old)>=$game_party.max_item_number(old)
          raise ArgumentError,'Нет места в инвентаре: '+BS2Modules.label(old)
        end
        wanted=previous.dup;wanted[index]=object
        actor.change_equip(index,object)
        raise ArgumentError,'Смена затронет другие слоты или оружие. Измените комплект вручную.' unless actor.equips==wanted
      end
      def preview(actor,set)
        reason=blocked(actor);return {:ok=>false,:errors=>[reason]} if reason
        real_party=$game_party
        target=expected(actor,set)
        problems=[]
        target.compact.select { |x| x.is_a?(RPG::Armor) }.uniq.each do |object|
          required=target.count(object)
          available=real_party.item_number(object)+actor.equips.count(object)
          if required>available
            problems << 'Не хватает: '+BS2Modules.label(object)+' (нужно '+required.to_s+', доступно '+available.to_s+').'
          end
        end
        slots(actor).each do |i|
          problems << 'Слот заблокирован: '+slot_name(actor,i) if actor.equips[i]!=target[i] && !actor.equip_change_ok?(i)
        end
        return {:ok=>false,:errors=>problems} unless problems.empty?
        copy=BS2Modules.clone(actor)
        $game_party=BS2Modules.clone(real_party)
        execute(copy,target)
        before=(0..7).map { |i| actor.param(i) }
        after=(0..7).map { |i| copy.param(i) }
        {:ok=>true,:errors=>[],:before=>before,:after=>after,:hp=>[actor.hp,copy.hp],:mp=>[actor.mp,copy.mp],:target=>target}
      rescue StandardError => e
        {:ok=>false,:errors=>[e.message]}
      ensure
        $game_party=real_party if real_party
      end
      def apply(actor,set)
        result=preview(actor,set)
        return result unless result[:ok]
        backup=BS2Modules.clone(actor)
        inventory={}
        [:@items,:@weapons,:@armors].each { |key| inventory[key]=BS2Modules.clone($game_party.instance_variable_get(key)) }
        begin
          execute(actor,result[:target])
          {:ok=>true,:errors=>[]}
        rescue StandardError => e
          actor.instance_variables.each { |key| actor.remove_instance_variable(key) unless backup.instance_variable_defined?(key) }
          seen={}
          backup.instance_variables.each do |key|
            actor.instance_variable_set(key,reconnect(backup.instance_variable_get(key),backup,actor,seen))
          end
          inventory.each { |key,value| $game_party.instance_variable_set(key,value) }
          {:ok=>false,:errors=>['Комплект не применён: '+e.message]}
        end
      end
      # A copied Game_Action points back to its copied owner. Restore those
      # cycles to the existing live actor, whose identity the engine retains.
      def reconnect(value,backup,actor,seen)
        return actor if value.equal?(backup)
        return value if seen[value.object_id]
        seen[value.object_id]=true
        if value.is_a?(Array)
          value.map! { |entry| reconnect(entry,backup,actor,seen) }
        elsif value.is_a?(Hash)
          pairs=value.map { |key,entry| [reconnect(key,backup,actor,seen),reconnect(entry,backup,actor,seen)] }
          value.clear;pairs.each { |key,entry| value[key]=entry }
        elsif !value.is_a?(Module)
          value.instance_variables.each { |key| value.instance_variable_set(key,reconnect(value.instance_variable_get(key),backup,actor,seen)) }
        end
        value
      end
      def lines(actor,set,result=nil)
        return ['Свободное место.','Выберите «Сохранить», чтобы записать текущую защитную экипировку.'] unless set
        lines=[set[:name],'Щит, головной убор, броня и кольца.','Оружие сохраняется текущим.','']
        set[:slots].keys.sort.each do |i|
          object=item(set[:slots][i][1])
          lines << slot_name(actor,i)+': '+(set[:slots][i][1]==0 ? 'Пусто' : BS2Modules.label(object,'Нет в базе'))
        end
        result ||= preview(actor,set)
        lines << ''
        if result[:ok]
          lines << 'Изменения параметров:'
          result[:before].each_with_index do |v,i|
            delta=result[:after][i]-v
            lines << PARAMS[i]+': '+v.to_s+' → '+result[:after][i].to_s+' ('+(delta>0 ? '+' : '')+delta.to_s+')' if delta!=0
          end
          lines << 'ОЗ после смены: '+result[:hp][1].to_s if result[:hp][0]!=result[:hp][1]
          lines << 'ОМ после смены: '+result[:mp][1].to_s if result[:mp][0]!=result[:mp][1]
          lines << 'Enter → «Применить» → подтверждение.'
        else
          lines << 'Сейчас применить нельзя:'
          lines += result[:errors]
          lines << 'Ни один слот не изменён.'
        end
        lines
      end
    end
  end

  class SetActions < Window_Command
    attr_accessor :filled,:can_apply
    def initialize
      super((Graphics.width-224)/2,100)
      BS2Modules.style(self);refresh
      self.z=430;hide;deactivate
    end
    def window_width;224;end
    def make_command_list
      add_command('Применить',:apply,@filled && @can_apply)
      add_command('Сохранить текущий',:save)
      add_command('Переименовать',:rename,@filled)
      add_command('Удалить',:delete,@filled)
      add_command('Назад',:cancel)
    end
  end
  class Confirm < Window_Command
    def initialize
      super((Graphics.width-224)/2,200)
      BS2Modules.style(self);refresh
      self.z=450;hide;deactivate
    end
    def window_width;224;end
    def make_command_list
      add_command('Отмена',:cancel)
      add_command('Подтвердить',:confirm)
    end
  end
  class SetName < Window_NameEdit
    def face_width;0;end
    def draw_actor_face(*args);end
    def char_width;12;end
  end
  class SetNameInput < Window_NameInput
    def table;[LATIN1,LATIN2];end
    def process_handling
      return unless open? && active
      if Input.trigger?(:B) && @edit_window.name.empty?
        deactivate;call_handler(:cancel)
      else
        super
      end
    end
  end
  class LoadoutsScene < Scene_MenuBase
    def start
      super
      @actor=$game_party.menu_actor || $game_party.members[0]
      @header=Header.new
      @list=List.new(0,72,216,Graphics.height-72)
      @detail=Lines.new(216,72,Graphics.width-216,Graphics.height-72)
      @list.set_handler(:ok,method(:actions))
      @list.set_handler(:cancel,method(:return_scene))
      @detail.set_handler(:cancel,method(:back_list))
      @actions=SetActions.new
      [:apply,:save,:rename,:delete].each { |name| @actions.set_handler(name,lambda { request(name) }) }
      @actions.set_handler(:cancel,method(:back_list))
      @confirm=Confirm.new
      @confirm.set_handler(:cancel,method(:back_actions))
      @confirm.set_handler(:confirm,method(:perform))
      @list.activate;rebuild
    end
    def index;@list.index+1;end
    def set;Loadouts.get(@actor,index);end
    def rebuild
      selected=[@list.index,0].max
      @header.text=['Комплекты — '+@actor.name,'Q/E персонаж  ·  → подробности  ·  Enter действия  ·  Esc назад']
      @list.set_rows((1..Loadouts::LIMIT).map { |i| s=Loadouts.get(@actor,i);{:name=>s ? s[:name] : 'Комплект '+i.to_s,:summary=>s ? 'Сохранён' : 'Свободно'} })
      @list.select(selected);@last=-1;show_detail
      if Loadouts.error
        @header.text=['Профили не удалось прочитать или записать.','Предыдущий файл сохранён. Закройте меню и проверьте доступ к папке.']
      end
    end
    def show_detail
      return if @last==@list.index
      @last=@list.index
      @detail.set_lines(Loadouts.lines(@actor,set))
    end
    def actions
      result=set && Loadouts.preview(@actor,set)
      @actions.filled=!!set;@actions.can_apply=result && result[:ok]
      @actions.refresh;@actions.select(0);@actions.show.activate
    end
    def back_list
      @actions.hide.deactivate;@confirm.hide.deactivate;@detail.deactivate;@list.activate
    end
    def back_actions
      @confirm.hide.deactivate;@actions.show.activate
    end
    def request(action)
      @pending=action
      if action==:rename
        begin_name;return
      end
      @actions.deactivate
      @detail.set_lines(['Подтверждение: '+{:apply=>'применить комплект',:save=>'сохранить текущую экипировку',:delete=>'удалить профиль'}[action],
        set ? set[:name] : 'Комплект '+index.to_s,'']+Loadouts.lines(@actor,set))
      @confirm.select(0);@confirm.show.activate
    end
    def perform
      case @pending
      when :apply
        result=Loadouts.apply(@actor,set)
        message=result[:ok] ? ['Комплект применён.'] : result[:errors]
      when :save
        okay=Loadouts.save(@actor,index)
        message=[okay ? 'Комплект сохранён.' : 'Не удалось записать профиль. Предыдущая запись сохранена.']
      when :delete
        okay=Loadouts.delete(@actor,index)
        message=[okay ? 'Профиль удалён.' : 'Не удалось записать изменение.']
      end
      back_list;rebuild
      @detail.set_lines(message+['']+Loadouts.lines(@actor,set))
    end
    def begin_name
      proxy=Struct.new(:name).new(set[:name])
      @name_edit=SetName.new(proxy,24);@name_edit.z=460
      @name_input=SetNameInput.new(@name_edit);@name_input.z=460
      BS2Modules.style(@name_edit);@name_edit.refresh
      BS2Modules.style(@name_input);@name_input.refresh
      @name_input.set_handler(:ok,method(:end_name))
      @name_input.set_handler(:cancel,method(:cancel_name))
    end
    def end_name
      okay=Loadouts.rename(@actor,index,@name_edit.name)
      cancel_name;rebuild
      @detail.set_lines(['Имя не сохранено. Предыдущая запись сохранена.']) unless okay
    end
    def cancel_name
      @name_edit.dispose;@name_input.dispose
      @name_edit=nil;@name_input=nil
      back_list
    end
    def update
      super
      if @list.active
        if Input.trigger?(:RIGHT)
          @list.deactivate;@detail.activate
        elsif Input.trigger?(:L) || Input.trigger?(:R)
          members=$game_party.members;i=members.index(@actor) || 0
          @actor=members[(i+(Input.trigger?(:R) ? 1 : -1))%members.size]
          rebuild
        end
      end
      show_detail
    end
  end
end
