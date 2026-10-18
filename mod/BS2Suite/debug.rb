# encoding: UTF-8
module BS2Suite::Debug
  CHUNK_BYTES=8*1024*1024 # New chunks, never deletion or a lifetime/session limit.
  WATCHED_COMMANDS=[101,102,103,111,117,121,122,123,125,126,127,128,201,301,311,312,313,314,315,316,317,318,319,321,331,332,333,334,339,340,351,352,353,354,355].freeze
  FLUSH_BOUNDARIES=%w(exception observer_error session_end session_exit scene_transition save_game_begin save_game_end load_game_begin load_game_end battle_setup battle_end bookmark user_note).freeze
  class << self
    attr_reader :directory,:error
    def json(v,depth=0)
      return '"[nested value]"' if depth>12
      case v
      when Hash;'{'+v.map { |k,x| json(k.to_s,depth+1)+':'+json(x,depth+1) }.join(',')+'}'
      when Array;'['+v.map { |x| json(x,depth+1) }.join(',')+']'
      when String,Symbol
        text=v.to_s.encode('UTF-16LE',:invalid=>:replace,:undef=>:replace,:replace=>'?').encode('UTF-8')
        '"'+text.gsub(/[\x00-\x1f"\\]/) { |c| c=='"' ? '\\"' : c=='\\' ? '\\\\' : '\\u%04x' % c.ord }+'"'
      when NilClass;'null'
      when TrueClass;'true'
      when FalseClass;'false'
      when Integer;v.to_s
      when Float;v.finite? ? v.to_s : 'null'
      else;json('['+v.class.to_s+']',depth+1)
      end
    end
    def start
      return if @file
      root=File.join(Dir.pwd,'BS2Suite');Dir.mkdir(root) unless File.directory?(root)
      root=File.join(root,'debug');Dir.mkdir(root) unless File.directory?(root)
      root=File.join(root,'sessions');Dir.mkdir(root) unless File.directory?(root)
      pid=Win32API.new('kernel32','GetCurrentProcessId',[],'L').call
      stamp=Time.now.utc.strftime('%Y%m%dT%H%M%SZ')+'_'+pid.to_s
      n=0;n+=1 while File.exist?(File.join(root,stamp+'_'+n.to_s))
      @directory=File.join(root,stamp+'_'+n.to_s);Dir.mkdir(@directory)
      @marker=File.join(@directory,'session.open')
      File.open(@marker,'wb') { |f| f.write('No clean shutdown recorded. This alone does not prove a game bug.');f.flush }
      @seq=0;@chunk=0;@conditions={};@conditions_since=nil
      @last_tick=@last_input_frame=@last_snapshot_at=@heartbeat_at=nil
      @last_snapshot=@tick_clock=@heartbeat_clock=nil;@max_gap=0.0
      open_chunk;@error=nil
      emit('session_start',{:version=>BS2Suite::VERSION,:modules=>BS2Suite::IDS.select { |id| BS2Suite.enabled?(id) },:ruby=>RUBY_VERSION,:resolution=>[Graphics.width,Graphics.height]})
      unfinished=Dir.glob(File.join(root,'*','session.open')).reject { |p| p==@marker }.map { |p| File.basename(File.dirname(p)) }
      emit('previous_unfinished_sessions',{:sessions=>unfinished}) unless unfinished.empty?
    rescue StandardError=>e
      @error=e.class.to_s;@file=nil
    end
    def open_chunk
      @file.close if @file && !@file.closed?
      @file=File.open(File.join(@directory,'events_%06d.jsonl' % @chunk),'ab');@chunk+=1
    end
    def emit(type,fields={})
      return unless @file
      flush_conditions if FLUSH_BOUNDARIES.include?(type.to_s)
      @seq+=1
      row={:seq=>@seq,:utc=>Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ'),:frame=>Graphics.frame_count,:type=>type,:data=>fields}
      line=json(row)+"\n"
      open_chunk if @file.size+line.bytesize>CHUNK_BYTES && @file.size>0
      @file.write(line);@file.flush
      true
    rescue StandardError=>e
      @error=e.class.to_s
      begin;@file.close if @file;rescue StandardError;end
      @file=nil;false
    end
    def flush_conditions
      entries=@conditions || {};@conditions={};@conditions_since=nil
      entries.each_value do |entry|
        next if entry[:count]<2
        emit('event_command_repeat',entry[:fields].merge(:count=>entry[:count]-1,:first_frame=>entry[:first],:last_frame=>entry[:last]))
      end
    end
    def condition_command(fields)
      return unless @file
      frame=Graphics.frame_count
      flush_conditions if @conditions_since && (frame<@conditions_since || frame-@conditions_since>=60)
      @conditions ||= {};@conditions_since ||= frame
      key=fields.values_at(:map,:event,:index,:code,:indent)
      entry=@conditions[key]
      if entry
        entry[:count]+=1;entry[:last]=frame
      else
        flush_conditions if @conditions.size>=256
        @conditions_since ||= frame
        @conditions[key]={:fields=>fields.dup,:count=>1,:first=>frame,:last=>frame}
        emit('event_command',fields)
      end
    end
    def close(status='clean')
      return unless @file
      emit('session_end',{:status=>status});@file.fsync;@file.close;@file=nil
      File.rename(@marker,File.join(@directory,status=='clean' ? 'session.closed' : 'session.failed')) if File.file?(@marker)
    rescue StandardError=>e;@error=e.class.to_s;end
    def battler(b)
      b.actor? ? 'actor:'+b.id.to_s : 'enemy:'+b.index.to_s
    end
    def snapshot
      return {} unless $game_party && $game_map
      {:scene=>SceneManager.scene.class.to_s,:map=>$game_map.map_id,:xy=>[$game_player.x,$game_player.y],:gold=>$game_party.gold,
       :party=>$game_party.members.map do |a|
         cooldowns=$game_temp && $game_temp.instance_variable_get(:@cool_time)
         counts=cooldowns && cooldowns.has_key?(a) ? cooldowns[a].dup : {}
         {:id=>a.id,:level=>a.level,:exp=>a.exp,:hp=>a.hp,:mp=>a.mp,:tp=>a.tp,:states=>a.states.map { |s| s.id },:state_turns=>a.instance_variable_get(:@state_turns),:buffs=>a.instance_variable_get(:@buffs),:cooldowns=>counts,:quick_skills=>a.instance_variable_get(:@hzm_vxa_quickSkill_can_use_skill),:actions=>a.actions.map { |action| item=action.item;[item ? [item.class.to_s,item.id] : nil,action.target_index] },:equips=>a.equips.map { |e| e ? [e.class.to_s,e.id] : nil }}
       end}
    end
    def input_tick
      return unless @file
      frame=Graphics.frame_count;return if @last_input_frame==frame
      @last_input_frame=frame;scene=SceneManager.scene
      raw=BS2QoL::Keyboard.raw_fresh
      emit('keys',{:vk=>raw,:scene=>scene.class.to_s}) unless raw.empty?
      if BS2Suite::Keys.trigger?(:note)
        emit('bookmark',snapshot)
        BS2QoL::Hotkeys.notice('Отметка записана в журнал. Текст — меню «Моды / опции».')
      end
    rescue StandardError=>e
      emit('observer_error',{:class=>e.class.to_s,:message=>e.message})
    end
    def tick(scene)
      return unless @file
      frame=Graphics.frame_count
      return if @last_tick==frame
      clock=Time.now.to_f
      @max_gap=[@max_gap,(clock-@tick_clock)*1000].max if @tick_clock && @last_tick && frame==@last_tick+1 && clock>=@tick_clock
      @tick_clock=clock
      @last_tick=frame
      flush_conditions if @conditions_since && (frame<@conditions_since || frame-@conditions_since>=60)
      if !@last_snapshot_at || frame<@last_snapshot_at || frame-@last_snapshot_at>=60
        now=snapshot;serialized=json(now)
        emit('state',now) if serialized!=@last_snapshot
        @last_snapshot=serialized;@last_snapshot_at=frame
      end
      if !@heartbeat_at || frame<@heartbeat_at || frame-@heartbeat_at>=600
        data={:scene=>scene.class.to_s,:focused=>BS2QoL::Keyboard.focused?,:max_update_gap_ms=>(@max_gap*100).round/100.0}
        data[:native_resources]=BS2Suite::ResourceStats.sample if defined?(BS2Suite::ResourceStats)
        if @heartbeat_at && frame>@heartbeat_at && @heartbeat_clock && clock>@heartbeat_clock
          data[:observed_fps]=((frame-@heartbeat_at)/(clock-@heartbeat_clock)*100).round/100.0
          data[:elapsed_ms]=((clock-@heartbeat_clock)*1000).round
        end
        emit('heartbeat',data);@heartbeat_at=frame;@heartbeat_clock=clock;@max_gap=0.0
      end
    rescue StandardError=>e
      emit('observer_error',{:class=>e.class.to_s,:message=>e.message})
    end
  end
end
module Input
  class << self
    alias bs2suite_debug_input update
    def update;bs2suite_debug_input;BS2Suite::Debug.input_tick;end
  end
end
module SceneManager
  class << self
    alias bs2suite_debug_run run
    def run
      BS2Suite::Debug.start
      begin
        bs2suite_debug_run
      rescue Exception=>e
        ordinary=e.is_a?(SystemExit) || ['RGSSReset','Reset'].include?(e.class.to_s)
        BS2Suite::Debug.emit(ordinary ? 'session_exit' : 'exception',{:class=>e.class.to_s,:message=>e.message,:backtrace=>e.backtrace})
        BS2Suite::Debug.close(ordinary ? 'clean' : 'exception')
        raise
      ensure;BS2Suite::Debug.close;end
    end
    [:goto,:call,:return].each do |name|
      alias_method(('bs2suite_debug_'+name.to_s).to_sym,name)
      define_method(name) do |*args|
        BS2Suite::Debug.emit('scene_transition',{:operation=>name,:from=>@scene.class.to_s,:to=>args.map { |x| x.to_s }})
        send(('bs2suite_debug_'+name.to_s).to_sym,*args)
      end
    end
  end
end
class Scene_Base
  alias bs2suite_debug_update update_basic
  def update_basic;bs2suite_debug_update;BS2Suite::Debug.tick(self);end
end
[Game_Switches,Game_Variables,Game_SelfSwitches].each do |klass|
  klass.class_eval do
    alias_method :bs2suite_debug_set,:[]=
    define_method(:[]=) do |id,value|
      previous=self[id];result=bs2suite_debug_set(id,value)
      BS2Suite::Debug.emit('variable',{:group=>self.class.to_s,:id=>id,:before=>previous,:after=>self[id]}) if previous!=self[id]
      result
    end
  end
end
class Game_BattlerBase
  [:hp,:mp,:tp].each do |name|
    alias_method(('bs2suite_debug_'+name.to_s+'=').to_sym,(name.to_s+'=').to_sym)
    define_method((name.to_s+'=').to_sym) do |value|
      previous=send(name);result=send(('bs2suite_debug_'+name.to_s+'=').to_sym,value)
      BS2Suite::Debug.emit('resource',{:battler=>BS2Suite::Debug.battler(self),:resource=>name,:before=>previous,:after=>send(name)}) if previous!=send(name)
      result
    end
  end
end
class Game_Battler
  [:add_state,:remove_state,:add_buff,:add_debuff,:remove_buff].each do |name|
    alias_method(('bs2suite_debug_'+name.to_s).to_sym,name)
    define_method(name) do |*args|
      before=[@states.dup,@buffs.dup]
      result=send(('bs2suite_debug_'+name.to_s).to_sym,*args)
      after=[@states.dup,@buffs.dup]
      BS2Suite::Debug.emit('effects',{:battler=>BS2Suite::Debug.battler(self),:operation=>name,:arguments=>args,:before=>before,:after=>after}) if before!=after
      result
    end
  end
  alias bs2suite_debug_apply item_apply
  def item_apply(user,item)
    BS2Suite::Debug.emit('effect_begin',{:user=>BS2Suite::Debug.battler(user),:target=>BS2Suite::Debug.battler(self),:object=>[item.class.to_s,item.id]})
    result=bs2suite_debug_apply(user,item)
    BS2Suite::Debug.emit('effect_end',{:target=>BS2Suite::Debug.battler(self),:hp=>hp,:mp=>mp,:states=>@states,:missed=>@result.missed,:evaded=>@result.evaded,:critical=>@result.critical,:hp_damage=>@result.hp_damage,:mp_damage=>@result.mp_damage})
    result
  end
end
class Game_Interpreter
  alias bs2suite_debug_command execute_command
  def execute_command
    command=@list && @list[@index]
    if command && BS2Suite::Debug::WATCHED_COMMANDS.include?(command.code)
      fields={:map=>@map_id,:event=>@event_id,:index=>@index,:code=>command.code,:indent=>command.indent}
      if command.code==111;BS2Suite::Debug.condition_command(fields)
      else;BS2Suite::Debug.emit('event_command',fields);end
    end
    bs2suite_debug_command
  end
end
class Game_Party
  alias bs2suite_debug_item gain_item
  def gain_item(item,amount,include_equip=false)
    before=item_number(item);result=bs2suite_debug_item(item,amount,include_equip)
    after=item_number(item)
    BS2Suite::Debug.emit('inventory',{:object=>[item.class.to_s,item.id],:requested=>amount,:before=>before,:after=>after}) if item && before!=after
    result
  end
  alias bs2suite_debug_gold gain_gold
  def gain_gold(amount)
    before=gold;result=bs2suite_debug_gold(amount)
    BS2Suite::Debug.emit('gold',{:requested=>amount,:before=>before,:after=>gold}) if before!=gold
    result
  end
end
class Game_Actor
  [:learn_skill,:forget_skill,:change_equip].each do |name|
    alias_method(('bs2suite_debug_'+name.to_s).to_sym,name)
    define_method(name) do |*args|
      result=send(('bs2suite_debug_'+name.to_s).to_sym,*args)
      BS2Suite::Debug.emit('actor_change',{:id=>id,:operation=>name,:arguments=>args.map { |a| a.is_a?(RPG::BaseItem) ? [a.class.to_s,a.id] : a },:skills=>@skills,:equips=>equips.map { |e| e ? [e.class.to_s,e.id] : nil }})
      result
    end
  end
end
module DataManager
  class << self
    [:save_game,:load_game].each do |name|
      alias_method(('bs2suite_debug_'+name.to_s).to_sym,name)
      define_method(name) do |index|
        return false unless index.is_a?(Integer) && index>=0 && index<DataManager.savefile_max
        BS2Suite::Debug.emit(name.to_s+'_begin',{:slot=>index+1})
        result=send(('bs2suite_debug_'+name.to_s).to_sym,index)
        BS2Suite::Debug.emit(name.to_s+'_end',{:slot=>index+1,:success=>result});result
      end
    end
  end
end
module BattleManager
  class << self
    alias bs2suite_debug_setup setup
    def setup(*args)
      BS2Suite::Debug.emit('battle_setup',{:arguments=>args});bs2suite_debug_setup(*args)
    end
    alias bs2suite_debug_end battle_end
    def battle_end(result)
      BS2Suite::Debug.emit('battle_end',{:result=>result,:turn=>$game_troop.turn_count});bs2suite_debug_end(result)
    end
  end
end
