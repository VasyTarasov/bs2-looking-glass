# encoding: UTF-8
module BS2Suite
  module Macros
    LIMIT=BS2Modules::Loadouts::LIMIT
    ROWS=6
    GROUPS=4
    def self.address(index,group);(group-1)*LIMIT+index;end
    def self.data
      return @data if @data
      @data={};current=nil
      Store.read('macros',65536).each_line do |line|
        line=line.strip
        if m=/\A\[([0-9]{1,4}),(?:([1-4]),)?([1-8])\]\z/.match(line)
          current={'name'=>'Связка '+m[3],'key'=>m[3].to_i,'rows'=>[]};@data[[m[1].to_i,address(m[3].to_i,(m[2] || '1').to_i)]]=current
        elsif current && (m=/\Aname=(.{1,24})\z/.match(line))
          current['name']=m[1].gsub(/[\x00-\x1f\x7f]/,'')
        elsif current && (m=/\Akey=([0-9])\z/.match(line));current['key']=m[1].to_i
        elsif current && (m=/\Aexecutor=([0-9]{1,5})\z/.match(line));current['executor']=m[1].to_i
        elsif current && current['rows'].size<ROWS && (m=/\Arow=(item|skill|weapon|guard),([0-9]{1,5}),([0-9]{1,5}),([0-9])\z/.match(line))
          current['rows']<<{'kind'=>m[1],'id'=>m[2].to_i,'source'=>m[3].to_i,'target'=>m[4].to_i}
        end
      end
      @data
    end
    def self.get(actor,index,group=1)
      index=address(index,group);base=(group-1)*LIMIT
      return data[[actor.id,index]] if data[[actor.id,index]]
      used=data.select { |(id,n),v| id==actor.id && n>base && n<=base+LIMIT }.values.map { |s| s['key'] }
      key=index-base
      ((base+1)..(base+LIMIT)).each do |n|
        next if data[[actor.id,n]]
        key=used.include?(n-base) ? (1..9).to_a.push(0).find { |k| !used.include?(k) } : n-base
        used<<key
        break if n==index
      end
      {'name'=>'Связка '+(index-base).to_s,'key'=>key,'rows'=>[]}
    end
    def self.save(actor,index,value,group=1)
      return false unless (1..LIMIT).include?(index) && value['rows'].size<=ROWS && (0..9).include?(value['key'])
      return false unless (1..GROUPS).include?(group)
      index=address(index,group);base=(group-1)*LIMIT
      return false if data.any? { |(id,n),v| id==actor.id && n>base && n<=base+LIMIT && n!=index && v['key']==value['key'] }
      old=data.dup;data[[actor.id,index]]=BS2Modules.clone(value)
      text="format=2\n"
      data.keys.sort.each do |key|
        set=data[key];text+='['+[key[0],(key[1]-1)/LIMIT+1,(key[1]-1)%LIMIT+1].join(',')+"]\nname="+set['name'].gsub(/[\x00-\x1f\x7f]/,'')[0,24]+"\nkey="+set['key'].to_s+"\n"
        text+='executor='+set['executor'].to_s+"\n" if set['executor'].to_i>0
        set['rows'].each { |r| text+='row='+[r['kind'],r['id'],r['source'],r['target'] || 0].join(',')+"\n" }
      end
      return true if Store.write('macros',text)
      @data=old;false
    end
    def self.object(row,actor)
      case row['kind']
      when 'item';$data_items[row['id']]
      when 'skill';$data_skills[row['id']]
      when 'weapon';weapon=DirectWeapons.resolve(actor,row['id']);weapon && $data_skills[Projection.weapon(actor,weapon).attack_skill_id]
      when 'guard';$data_skills[actor.guard_skill_id]
      end
    end
    def self.source(row,actor)
      id=row['kind']=='weapon' ? row['id'] : row['source']
      id.to_i>0 ? DirectWeapons.resolve(actor,id) : nil
    end
    def self.label(row,actor)
      obj=object(row,actor);weapon=source(row,actor)
      return 'Нет источника / действия' unless obj
      row['kind']=='weapon' ? 'Атака: '+weapon.name : row['kind']=='guard' ? 'Оборона' : obj.name
    end
    def self.paid(set,actor);set['rows'].count { |r| o=object(r,actor);!o || !BattleSupport.quick?(o) };end
    def self.remaining(actor);[actor.actions.size-actor.instance_variable_get(:@action_input_index).to_i,0].max;end
    def self.problem(set,actor)
      return 'Пустая связка' if set['rows'].empty?
      return 'Нужно '+paid(set,actor).to_s+' действий; доступно '+remaining(actor).to_s if paid(set,actor)>remaining(actor)
      if set['executor'].to_i>0 && executor_allowed?(set,actor)
        final=DirectWeapons.resolve(actor,set['executor']);return 'Нет исполняющего оружия' unless final && DirectWeapons.can_switch?(actor,final)
      end
      counts=Hash.new(0)
      set['rows'].each do |r|
        obj=object(r,actor);return 'Нет действия / оружия' unless obj
        weapon=source(r,actor)
        return 'Нет оружия-источника' if (r['kind']=='weapon' || r['source'].to_i>0) && !weapon
        view=weapon ? Projection.weapon(actor,weapon) : Projection.copy(actor)
        return 'Смена оружия недоступна' if weapon && !DirectWeapons.can_switch?(actor,weapon)
        return 'КД '+view.cool_time[obj.id].to_i.to_s+': '+obj.name if obj.is_a?(RPG::Skill) && view.cool_time[obj.id].to_i>0
        return 'Навык не изучен' if r['kind']=='skill' && !view.skills.include?(obj)
        if obj.is_a?(RPG::Item)
          counts[obj.id]+=1;return 'Недостаточно предметов: '+obj.name if counts[obj.id]>$game_party.item_number(obj)
        end
      end
      nil
    end
    def self.action(actor,row,target)
      obj=object(row,actor);return nil unless obj
      action=Game_Action.new(actor)
      obj.is_a?(RPG::Item) ? action.set_item(obj.id) : action.set_skill(obj.id)
      if row['kind']=='weapon'
        action.instance_variable_set(:@bs2s_normal_attack,true)
        action.instance_variable_set(:@bs2s_normal_source,source(row,actor).id)
      end
      action.instance_variable_set(:@bs2s_macro_source,source(row,actor))
      action.target_index=if obj.for_friend?
        row['target'].to_i==0 ? actor.index : row['target'].to_i
      else;target;end
      action
    end
    def self.commit(scene,actor,set,target)
      reason=problem(set,actor);return reason if reason
      paid=[];free=[];token=Object.new
      set['rows'].each do |r|
        if BattleSupport.quick?(object(r,actor));free<<r.dup
        else
          a=action(actor,r,target);a.instance_variable_set(:@bs2s_macro_before,free);free=[]
          a.instance_variable_set(:@bs2s_macro_token,token);paid<<a
        end
      end
      if paid.empty?
        free.each { |r| scene.bs2s_macro_quick(actor,r,target) }
      else
        paid.last.instance_variable_set(:@bs2s_macro_after,free)
        paid.last.instance_variable_set(:@bs2s_macro_executor,set['executor']) if executor_allowed?(set,actor)
        paid.each { |a| a.instance_variable_set(:@bs2s_macro_target,target) }
        index=actor.instance_variable_get(:@action_input_index).to_i
        paid.each_with_index { |a,i| actor.actions[index+i]=a }
        actor.instance_variable_set(:@action_input_index,index+paid.size-1)
        Performance.bump
        scene.next_command
      end
      BS2QoL::Keyboard.consume;nil
    rescue StandardError=>e
      'Связка остановлена: '+e.message
    end
    def self.stop(actor,action,message)
      token=action.instance_variable_get(:@bs2s_macro_token)
      actor.actions.each do |a|
        next unless token && a.instance_variable_get(:@bs2s_macro_token).equal?(token)
        a.clear
        a.instance_variable_set(:@bs2s_macro_before,[]);a.instance_variable_set(:@bs2s_macro_after,[])
        a.instance_variable_set(:@bs2s_macro_token,nil);a.instance_variable_set(:@bs2s_macro_source,nil);a.instance_variable_set(:@bs2s_macro_executor,nil)
      end
      BS2QoL::Hotkeys.notice('Связка остановлена: '+message)
    end
    def self.executor_allowed?(set,actor)
      row=set['rows'].reverse.find { |r| o=object(r,actor);o && !BattleSupport.quick?(o) }
      row && (row['kind']=='item' || row['kind']=='guard')
    end
    def self.requirements(set,actor)
      view=Projection.copy(actor);index=actor.instance_variable_get(:@action_input_index).to_i
      queued=actor.actions.take(index).map { |a| a.dup }
      final_row=set['rows'].rindex { |r| o=object(r,actor);o && !BattleSupport.quick?(o) }
      final_position=nil
      set['rows'].each_with_index do |r,i|
        a=action(actor,r,0);next unless a
        a.instance_variable_set(:@bs2s_direct_count,actor.actions.size)
        if i==final_row
          final_position=queued.size
          a.instance_variable_set(:@bs2s_macro_executor,set['executor']) if executor_allowed?(set,actor)
        end
        queued<<a
      end
      view.instance_variable_set(:@bs2s_forecast_final_index,paid(set,actor)==remaining(actor) ? final_position : -1)
      view.instance_variable_set(:@actions,queued)
      report=defined?(BS2QoL::Forecast::Prediction) ? SequenceForecast.new(view) : nil
      costs=report && report.steps.drop(index).map { |s| s[:cost] && s[:cost][1] }
      exact=costs && costs.size==set['rows'].size && costs.all? { |c| c }
      if exact
        low=costs.inject(0) { |n,c| n+c[0] };high=costs.inject(0) { |n,c| n+c[1] }
        mp=low==high ? low.to_s : low.to_s+'–'+high.to_s
      else
        mp='~'+set['rows'].inject(0) { |n,r| o=object(r,actor);w=source(r,actor);v=w ? Projection.weapon(actor,w) : actor;n+(o.is_a?(RPG::Skill) ? v.skill_mp_cost(o) : 0) }.to_s
      end
      skills=set['rows'].map { |r| object(r,actor) }.select { |o| o.is_a?(RPG::Skill) }
      wait=skills.map { |o| Projection.copy(actor).cool_time[o.id].to_i }.max || 0
      cd=skills.map { |o| (o.cool_time || 0).to_i }.max || 0
      paid(set,actor).to_s+' действ. · ОМ '+mp+' · КД '+(wait>0 ? 'ждать '+wait.to_s : 'готово')+(cd>0 ? ' / '+cd.to_s : '')
    end
    def self.fill(scene,window,actor,group=nil)
      window.instance_variable_set(:@macro_group,group)
      window.records=if group
        (1..LIMIT).map { |i| get(actor,i,group) }.reject { |s| s['rows'].empty? }.map do |set|
          reason=problem(set,actor)
          [set['key'].to_s+' '+set['name']+' · '+requirements(set,actor)+(reason ? ' · '+reason : ''),set,!reason]
        end
      else
        (1..GROUPS).map do |n|
          sets=(1..LIMIT).map { |i| get(actor,i,n) }.reject { |s| s['rows'].empty? }
          sets.empty? ? nil : [n.to_s+' Группа '+n.to_s+' · '+sets.size.to_s+' связок',{'macro_group'=>n,'key'=>n},true]
        end.compact
      end
      window.refresh;window.select(0);window.activate
      scene.instance_variable_set(:@bs2s_macros_opened,Graphics.frame_count)
    end
    def self.open(scene,origin)
      actor=BattleManager.actor;return false unless actor && actor.input
      origin.deactivate
      window=MacroCommands.new
      scene.instance_variable_set(:@bs2s_macros,window)
      scene.instance_variable_set(:@bs2s_macros_opened,Graphics.frame_count)
      scene.instance_variable_set(:@bs2s_macros_origin,origin)
      fill(scene,window,actor)
      window.set_handler(:entry,lambda {
        set=window.current_ext
        if set && set['macro_group']
          fill(scene,window,actor,set['macro_group']);BS2QoL::Keyboard.consume;next
        end
        # Select one enemy for all single-target hostile rows; allies/self are
        # recorded per row. AoE and random targets keep native targeting.
        enemies=$game_troop.alive_members.reject { |e| e.hidden? }
        need=set['rows'].any? { |r| o=object(r,actor);o && o.for_opponent? && o.for_one? && !o.for_random? }
        if need && enemies.size>1
          scene.instance_variable_set(:@bs2s_macro_pending,set)
          close(scene,false)
          ew=scene.instance_variable_get(:@enemy_window);ew.refresh;ew.show.activate;ew.select(0)
          scene.instance_variable_set(:@bs2s_macro_targeting,true)
        else
          close(scene);reason=commit(scene,actor,set,enemies[0] ? enemies[0].index : 0)
          BS2QoL::Hotkeys.notice(reason) if reason
        end
      })
      window.set_handler(:cancel,lambda { window.instance_variable_get(:@macro_group) ? fill(scene,window,actor) : close(scene);BS2QoL::Keyboard.consume });true
    end
    def self.close(scene,restore=true)
      w=scene.instance_variable_get(:@bs2s_macros);w.dispose if w && !w.disposed?
      scene.instance_variable_set(:@bs2s_macros,nil)
      origin=scene.instance_variable_get(:@bs2s_macros_origin);origin.activate if restore && origin && !origin.disposed?
      BS2QoL::Keyboard.consume
    end
  end
  class MacroCommands < Window_Command
    attr_accessor :records
    def initialize;@records=[];super(12,72);self.z=480;BS2Modules.style(self);end
    def window_width;Graphics.width-24;end
    def battle_picker?;SceneManager.scene.is_a?(Scene_Battle);end
    def line_height;battle_picker? ? 40 : 24;end
    def visible_line_number;battle_picker? ? [[item_max,8].min,1].max : 12;end
    def refresh
      super
      desired=fitting_height(visible_line_number)
      if height!=desired;self.height=desired;create_contents;draw_all_items;end
    end
    def draw_item(index)
      return super unless battle_picker?
      rect=item_rect_for_text(index);parts=command_name(index).split(' · ')
      contents.font.size=18;change_color(normal_color,command_enabled?(index))
      draw_text(rect.x,rect.y,rect.width,20,parts.take(2).join(' · '))
      draw_text(rect.x,rect.y+20,rect.width,20,parts.drop(2).join(' · '))
    end
    def make_command_list;@records.each { |name,value,enabled| add_command(name,:entry,enabled!=false,value) };end
    def process_handling
      if active && open? && SceneManager.scene.is_a?(Scene_Battle)
        return if SceneManager.scene.instance_variable_get(:@bs2s_macros_opened)==Graphics.frame_count
        return if defined?(BS2Suite::ContextEffects) && BS2Suite::ContextEffects.route(SceneManager.scene,self)
        if BS2Suite::Keys.trigger?(:macros);process_cancel;return;end
        digit=BS2Suite::Palette.digit
        unless digit.nil?
          i=@records.index { |name,value,on| value.is_a?(Hash) && value['key']==digit }
          if i;select(i);process_ok;BS2QoL::Keyboard.consume;return;end
        end
      end
      super
    end
  end
  class MacroScene < Scene_MenuBase
    def start
      super;@actor=$game_party.menu_actor || $game_party.leader;@stage=:macro_groups;@macro_group=1;@slot=1;@row=0;@page=0
      @header=BS2Modules::Header.new;@list=MacroCommands.new
      @list.set_handler(:entry,method(:choose));@list.set_handler(:cancel,method(:back));redraw
    end
    def set;@draft || Macros.get(@actor,@slot,@macro_group);end
    def redraw
      rows=[];hint='Enter выбрать · Esc назад'
      case @stage
      when :macro_groups
        rows=(1..Macros::GROUPS).map { |g| [g.to_s+' Группа '+g.to_s,g] }
      when :sets
        rows=(1..Macros::LIMIT).map { |i| s=Macros.get(@actor,i,@macro_group);[s['key'].to_s+' '+s['name']+' · '+s['rows'].size.to_s+'/6',i] }
      when :edit
        rows=(0...Macros::ROWS).map { |i| [ (i+1).to_s+'. '+(set['rows'][i] ? Macros.label(set['rows'][i],@actor) : '—'),i] }
        rows += [['Переименовать',:name],['Кнопка слота: '+set['key'].to_s,:key],['Исполнитель: '+executor_name,:executor],['Сохранить',:save]]
        hint='V/B/M/N выбрать тип для строки · Enter редактировать · Esc назад'
      when :type
        rows=[['V — оружейные техники','V'],['B — предметы','B'],['M — изученные навыки','M'],['N — обычная атака оружием','N'],['Оборона',:guard],['Цель союзного действия: '+(set['rows'][@row] && set['rows'][@row]['target'].to_i>0 ? 'союзник '+set['rows'][@row]['target'].to_s : 'сам герой'),:target],['Удалить строку',:delete]]
      when :groups
        groups=@prefix=='N' ? DirectWeapons.groups(@actor) : Semantic.groups(@actor,@prefix)
        rows=groups.map { |g| [Semantic::DIGITS[g[:number]-1,1]+' '+g[:name],g[:number]] }+[['Полный доступный список',:all]]
      when :choices
        values=choices;count=[(values.size+9)/10,1].max;@page%=count
        rows=values[@page*10,10].to_a.each_with_index.map { |r,i| [((i+1)%10).to_s+' '+Macros.label(r,@actor),r] }
        hint=@prefix+' · '+(@page+1).to_s+'/'+count.to_s+' · Q/E / ←/→ страница · F7 справка'
      when :executor
        values=Semantic.owned(@actor).sort_by { |w| [w.name,w.id] };values=[nil]+values;@page%=[(values.size+9)/10,1].max
        rows=values[@page*10,10].to_a.each_with_index.map { |w,i| [((i+1)%10).to_s+' '+(w ? w.name : 'Снять исполнителя'),w ? w.id : 0] }
        hint='Цифра выбрать · Q/E страница · только последнее платное: предмет / оборона'
      when :key;rows=(0..9).map { |i| [i.to_s,i] }
      end
      @header.text=[[:macro_groups,:sets].include?(@stage) ? 'Связки — группа '+@macro_group.to_s+' · '+@actor.name : set['name'],hint]
      @list.records=rows;@list.refresh;@list.select(0);@list.activate
    end
    def executor_name
      return 'недоступен для последнего действия' unless Macros.executor_allowed?(set,@actor)
      w=DirectWeapons.resolve(@actor,set['executor']);w ? w.name : 'не назначен'
    end
    def choices
      if @group && @group!=:all
        rows=@prefix=='N' ? DirectWeapons.rows(@actor,@group) : Semantic.rows(@actor,@prefix,@group)
        return rows.select { |r| r[:object] && r[:present]!=false }.map do |r|
          o=r[:object];kind=o.is_a?(RPG::Weapon) ? 'weapon' : o.is_a?(RPG::Item) ? 'item' : 'skill'
          {'kind'=>kind,'id'=>o.id,'source'=>r[:source].is_a?(RPG::Weapon) ? r[:source].id : 0,'target'=>0}
        end
      end
      case @prefix
      when 'N';Semantic.owned(@actor).sort_by { |w| [w.name,w.id] }.map { |w| {'kind'=>'weapon','id'=>w.id,'source'=>w.id,'target'=>0} }
      when 'B';$game_party.items.select { |i| [0,1].include?(i.occasion) }.map { |i| {'kind'=>'item','id'=>i.id,'source'=>0,'target'=>0} }
      when 'M';@actor.skills.select { |s| @actor.skill_learn?(s) && [0,1].include?(s.occasion) }.map { |s| {'kind'=>'skill','id'=>s.id,'source'=>0,'target'=>0} }
      else
        weapon_rows=Semantic.owned(@actor).map do |w|
          w.features.select { |f| f.code==43 && $data_skills[f.data_id] && [0,1].include?($data_skills[f.data_id].occasion) }.map { |f| {'kind'=>'skill','id'=>f.data_id,'source'=>w.id,'target'=>0} }
        end.flatten.uniq { |r| r['id'] }
        armor_rows=@actor.skills.select { |s| !@actor.skill_learn?(s) && [0,1].include?(s.occasion) && Semantic.source_for(@actor,s.id).is_a?(RPG::Armor) }.map { |s| {'kind'=>'skill','id'=>s.id,'source'=>0,'target'=>0} }
        (weapon_rows+armor_rows).uniq { |r| r['id'] }
      end
    end
    def choose
      value=@list.current_ext
      case @stage
      when :macro_groups;@macro_group=value;@stage=:sets
      when :sets;@slot=value;@draft=BS2Modules.clone(Macros.get(@actor,@slot,@macro_group));@stage=:edit
      when :edit
        if value.is_a?(Integer);@row=value;@stage=:type
        elsif value==:name
          BS2Suite.edit_text(self,set['name'],24) { |s| @draft['name']=s if s && !s.strip.empty? }
        elsif value==:key;@stage=:key
        elsif value==:executor
          if Macros.executor_allowed?(set,@actor);@stage=:executor;@page=0;else;::Sound.play_buzzer;end
        elsif value==:save
          set.delete('executor') unless Macros.executor_allowed?(set,@actor)
          if Macros.save(@actor,@slot,@draft,@macro_group);@draft=nil;@stage=:sets
          else;BS2QoL::Hotkeys.notice('Не сохранено: кнопка занята или ошибка записи');end
        end
      when :type
        if value==:guard;assign({'kind'=>'guard','id'=>0,'source'=>0,'target'=>0})
        elsif value==:delete;set['rows'].delete_at(@row);@stage=:edit
        elsif value==:target
          row=set['rows'][@row];row['target']=(row['target'].to_i+1)%[$game_party.members.size,1].max if row
        else;@prefix=value;@page=0;@stage=:groups;end
      when :groups;@group=value;@page=0;@stage=:choices
      when :choices;assign(value)
      when :executor
        value>0 ? set['executor']=value : set.delete('executor');@stage=:edit
      when :key;set['key']=value;@stage=:edit
      end
      redraw
    end
    def assign(row)
      # Empty rows remain compact: six actual actions, never hidden gaps.
      @row=[@row,set['rows'].size].min
      set['rows'][@row]=row;@stage=:edit
    end
    def back
      if @stage==:macro_groups;return_scene;return
      elsif @stage==:sets;@stage=:macro_groups
      elsif @stage==:edit;@draft=nil;@stage=:sets
      elsif @stage==:choices;@stage=:groups
      elsif @stage==:groups;@stage=:type
      else;@stage=:edit;end
      redraw
    end
    def update
      super
      return unless @list.active
      digit=Palette.digit
      unless digit.nil?
        i=case @stage
        when :choices,:executor;(digit+9)%10
        when :macro_groups,:edit;digit-1
        when :sets;@list.records.index { |name,slot,on| Macros.get(@actor,slot,@macro_group)['key']==digit }
        when :key;digit
        when :groups;@list.records.index { |name,value,on| value.is_a?(Integer) && Semantic::DIGITS[value-1,1].to_i==digit }
        end
        if i && i>=0 && i<@list.item_max;@list.select(i);choose;BS2QoL::Keyboard.consume;return;end
      end
      if [:edit,:type,:choices,:groups].include?(@stage)
        prefix=Palette.letter
        if prefix
          @row=@list.index if @stage==:edit && @list.index<6
          @prefix=prefix;@stage=:groups;@page=0;redraw;BS2QoL::Keyboard.consume;return
        end
      end
      if [:choices,:executor].include?(@stage)
        if Input.trigger?(:L) || Input.trigger?(:R) || Input.trigger?(:LEFT) || Input.trigger?(:RIGHT)
          @page+=(Input.trigger?(:R) || Input.trigger?(:RIGHT)) ? 1 : -1;redraw
        elsif @stage==:choices && BS2Suite.enabled?('reference_cards') && Keys.trigger?(:reference)
          row=@list.current_ext;obj=row && Macros.object(row,@actor)
          if obj
            @list.deactivate
            actor=Macros.source(row,@actor);actor=actor ? Projection.weapon(@actor,actor) : @actor
            instance_variable_set(:@bs2q_reference_window,Window_BS2QReference.new(obj,actor))
            instance_variable_set(:@bs2q_reference_origin,@list);BS2QoL::Keyboard.consume
          end
        end
      end
    end
  end
end

if defined?(BS2Suite::HDDisplay)
module BS2Suite::HDDisplay
  class << self
    alias bs20997_macro_poll poll
    def poll(force=false)
      scene=SceneManager.scene
      bs20997_macro_poll(force || !!(scene && scene.instance_variable_get(:@bs2s_macros)))
    end
    alias bs20997_macro_lines lines
    def lines(scene)
      window=scene && scene.instance_variable_get(:@bs2s_macros)
      if window && !window.disposed? && window.active
        actor=BattleManager.actor;set=window.current_ext
        rows=[row('T','Связки'),row('D','Доступно действий: '+BS2Suite::Macros.remaining(actor).to_s)]
        window.records.each_with_index do |(name,value,on),i|
          parts=name.split(' · ')
          rows<<row(window.index==i ? 'A' : 'S',parts.take(2).join(' · '))
          rows+=wrap_lines([parts.drop(2).join(' · ')]).map { |text| row('D',text) } if parts.size>2
        end
        if set && set['rows']
          rows<<row('H',set['name'])
          rows+=set['rows'].each_with_index.map { |r,i| o=BS2Suite::Macros.object(r,actor);row('S',(i+1).to_s+'. '+BS2Suite::Macros.label(r,actor)+(o && BS2Suite::BattleSupport.quick?(o) ? ' · мгновенно' : '')) }
        end
        return rows+[row('D','Цифра / '+BS2Suite::Keys.token(:C)+' выбрать · '+BS2Suite::Keys.token(:macros)+' / '+BS2Suite::Keys.token(:B)+' закрыть · '+BS2Suite::Keys.token(:combat_effects)+' эффекты')]
      end
      bs20997_macro_lines(scene)
    end
    alias bs20997_macro_source_mode source_mode
    def source_mode(scene)
      bs20997_macro_source_mode(scene)
      window=scene && scene.instance_variable_get(:@bs2s_macros)
      if active? && window && !window.disposed? && window.active
        @hidden=[[window,window.visible]];window.visible=false;@presentation.call(1)
      end
    end
    alias bs20997_macro_battle_rows battle_rows
    def battle_rows(scene)
      rows=bs20997_macro_battle_rows(scene)
      rows<<row('D',BS2Suite::Keys.token(:macros)+' — связки')
      rows
    end
  end
end
end
module BS2Suite::VisualClock
  class << self
    alias bs20997_macro_modal modal?
    def modal?(scene)
      bs20997_macro_modal(scene) || (scene.is_a?(Scene_Battle) && !!scene.instance_variable_get(:@bs2s_macros))
    end
  end
end

BS2Suite::Keys::DEFAULT[:macros]='C'
BS2Suite::Keys::LABELS<<'Связки в бою'
BS2Suite::Keys.instance_variable_set(:@data,nil)
BS2Suite::ContextEffects::KEYS<<:@bs2s_macros if defined?(BS2Suite::ContextEffects) && !BS2Suite::ContextEffects::KEYS.include?(:@bs2s_macros)
class Window_MenuCommand
  alias bs20997_macro_menu add_original_commands
  def add_original_commands
    bs20997_macro_menu
    i=@list.index { |r| r[:symbol]==:bs2modules_loadouts }
    @list.insert(i ? i+1 : @list.size,{:name=>'Связки',:symbol=>:bs2s_macros,:enabled=>main_commands_enabled,:ext=>nil})
  end
end
class Scene_Menu
  alias bs20997_macro_menu_window create_command_window
  def create_command_window
    bs20997_macro_menu_window;@command_window.set_handler(:bs2s_macros,lambda { SceneManager.call(BS2Suite::MacroScene) })
  end
end
module BS2QoL::Hotkeys
  class << self
    alias bs20997_macro_handle handle
    def handle(window)
      scene=SceneManager.scene
      if scene.is_a?(Scene_Battle) && context(scene)==:commands && BS2Suite::Keys.trigger?(:macros)
        return BS2Suite::Macros.open(scene,window)
      end
      bs20997_macro_handle(window)
    end
  end
end
class Game_Action
  alias bs20997_macro_prepare prepare
  def prepare
    actor=subject;scene=SceneManager.scene
    if actor.actor? && !forcing && !BS2Suite::DirectWeapons.quick? && instance_variable_get(:@bs2s_macro_token)
      begin
        before=@bs2s_macro_before || [];@bs2s_macro_before=[]
        before.each { |row| scene.bs2s_macro_quick(actor,row,@bs2s_macro_target) }
        weapon=@bs2s_macro_source
        raise 'оружие-источник недоступно' if weapon && actor.equips[0]!=weapon && !BS2QoL::Model.change_weapon(actor,weapon)
        if @bs2s_macro_executor && !@bs2s_direct_applied
          final=BS2Suite::DirectWeapons.resolve(actor,@bs2s_macro_executor)
          raise 'исполняющее оружие недоступно' unless final && BS2Suite::DirectWeapons.eligible_final(actor,item,final,0,self) && (actor.equips[0]==final || BS2QoL::Model.change_weapon(actor,final))
          @bs2s_direct_applied=true
        end
      rescue StandardError=>e
        BS2Suite::Macros.stop(actor,self,e.message);return
      end
    end
    bs20997_macro_prepare
    if actor.actor? && @bs2s_macro_token && !BS2Suite::DirectWeapons.quick? && !valid?
      BS2Suite::Macros.stop(actor,self,'цена, КД, цель или ограничение действия')
    end
  end
end
class BS2Suite::SequenceForecast
  alias bs20997_macro_forecast initialize
  def initialize(actor,weapon=nil)
    expanded=[];positions=[]
    actor.actions.each do |a|
      before=a.instance_variable_get(:@bs2s_macro_before) || []
      before.each do |r|
        virtual=BS2Suite::Macros.action(actor,r,a.instance_variable_get(:@bs2s_macro_target) || a.target_index)
        virtual.instance_variable_set(:@bs2s_forecast_late_skill,r['id']) if virtual && r['kind']=='skill'
        expanded<<virtual
      end
      positions<<expanded.size;expanded<<a.dup
      after=a.instance_variable_get(:@bs2s_macro_after) || []
      after.each do |r|
        virtual=BS2Suite::Macros.action(actor,r,a.instance_variable_get(:@bs2s_macro_target) || a.target_index)
        virtual.instance_variable_set(:@bs2s_forecast_late_skill,r['id']) if virtual && r['kind']=='skill'
        expanded<<virtual
      end
    end
    return bs20997_macro_forecast(actor,weapon) if expanded.size==actor.actions.size
    view=BS2Suite::Projection.copy(actor)
    expanded.each { |a| a.instance_variable_set(:@bs2s_direct_count,actor.actions.size) if a }
    view.instance_variable_set(:@actions,expanded)
    view.instance_variable_set(:@bs2s_forecast_final_index,positions.last)
    bs20997_macro_forecast(view,weapon)
    @steps=positions.map.with_index do |position,i|
      s=@steps[position] || {:item=>actor.actions[i].item,:rows=>[],:cost=>nil,:reason=>'Предыдущий переход не подтверждён'}
      s[:index]=i;s
    end
  end
end
class Scene_Battle
  # Use native costs, effects, limits, events and RNG. This nested action never
  # advances AP or consumes a paid queue slot; there are at most six rows.
  def bs2s_macro_quick(actor,row,target)
    action=BS2Suite::Macros.action(actor,row,target)
    raise 'предмет / источник недоступен' unless action
    raise 'действие перестало быть мгновенным' unless BS2Suite::BattleSupport.quick?(action.item)
    weapon=action.instance_variable_get(:@bs2s_macro_source)
    raise 'оружие-источник недоступно' if weapon && actor.equips[0]!=weapon && !BS2QoL::Model.change_weapon(actor,weapon)
    raise 'цена, КД или лимит: '+action.item.name unless actor.usable?(action.item)
    actions=actor.actions;subject=@subject
    window=@actor_command_window;window_state=window && [window.active,window.openness]
    window.deactivate.close if window
    old_active=@hzm_vxa_quickSkill_active;@hzm_vxa_quickSkill_active=true
    HZM_VXA::QuickSkill.start;actor.instance_variable_set(:@actions,[action]);@subject=actor
    action.prepare
    raise 'действие недоступно' unless action.valid?
    bs20997_macro_execute
    process_event
    raise 'герой не может продолжить' unless actor.alive?
  ensure
    HZM_VXA::QuickSkill.finish if actions
    actor.instance_variable_set(:@actions,actions) if actions
    @subject=subject if actions
    @hzm_vxa_quickSkill_active=old_active if actions
    if actions && window && !window.disposed? && window_state && !scene_changing?
      window.openness=window_state[1];window.activate if window_state[0] && actor.alive?
    end
  end
  alias bs20997_macro_execute execute_action
  def execute_action
    action=@subject && @subject.current_action
    bs20997_macro_execute
    if action && action.instance_variable_get(:@bs2s_macro_token) && !BS2Suite::DirectWeapons.quick?
      after=action.instance_variable_get(:@bs2s_macro_after) || [];action.instance_variable_set(:@bs2s_macro_after,[])
      begin
        after.each { |r| bs2s_macro_quick(@subject,r,action.instance_variable_get(:@bs2s_macro_target)) }
      rescue StandardError=>e;BS2Suite::Macros.stop(@subject,action,e.message);end
    end
  end
  alias bs20997_macro_enemy_ok on_enemy_ok
  def on_enemy_ok
    return bs20997_macro_enemy_ok unless @bs2s_macro_targeting
    @bs2s_macro_targeting=false;target=@enemy_window.enemy.index;@enemy_window.hide.deactivate
    @actor_command_window.activate;set=@bs2s_macro_pending;@bs2s_macro_pending=nil
    reason=BS2Suite::Macros.commit(self,BattleManager.actor,set,target);BS2QoL::Hotkeys.notice(reason) if reason
  end
  alias bs20997_macro_enemy_cancel on_enemy_cancel
  def on_enemy_cancel
    return bs20997_macro_enemy_cancel unless @bs2s_macro_targeting
    @bs2s_macro_targeting=false;@bs2s_macro_pending=nil;@enemy_window.hide.deactivate;@actor_command_window.activate
  end
  alias bs20997_macro_terminate terminate
  def terminate
    BS2Suite::Macros.close(self,false);bs20997_macro_terminate
  end
end
