# encoding: UTF-8
# Numeric, bounded, wall-clock diagnostics. No object enumeration, snapshots,
# remote process access or per-frame disk writes. Loaded only with diagnostics.
module BS2Suite::PerfTrace
  PERIOD=5000.0
  class << self
    def enabled?
      !@failed && !@publishing && BS2Suite::Debug.recording? && !BS2Suite::Debug.error &&
        BS2Suite::Options.get('performance_trace')==1
    end
    def now
      unless @counter
        @counter=Win32API.new('kernel32','QueryPerformanceCounter',['P'],'I')
        frequency=Win32API.new('kernel32','QueryPerformanceFrequency',['P'],'I')
        @buffer=([0,0]).pack('L2')
        raise 'Performance clock unavailable' if frequency.call(@buffer)==0
        pair=@buffer.unpack('L2');@frequency=pair[0]+pair[1]*4294967296.0
      end
      return nil if @failed || @counter.call(@buffer)==0
      pair=@buffer.unpack('L2');(pair[0]+pair[1]*4294967296.0)*1000.0/@frequency
    rescue StandardError
      @failed=true;nil
    end
    def context
      scene=SceneManager.scene
      modal=scene && [:@bs2s_palette,:@bs2q_reference_window,:@bs2080_effects,:@bs2092_journal,:@bs2092_enemy_chooser,:@bs2q_binding_window].find { |key| scene.instance_variable_get(key) }
      overlay=defined?(BS2Suite::SteamBridge) && BS2Suite::SteamBridge.active?
      backend=BS2QoL::Keyboard.backend
      [scene.class.to_s,$game_map && $game_map.map_id,modal && modal.to_s,
        backend ? backend.focused? : BS2QoL::Keyboard.focused?,!!overlay]
    end
    def reset_clock
      @previous=nil;@window_at=nil;@phases={};@frames={};@slow=[]
    end
    def break_interval;@previous=nil;end
    def measure(tag)
      return yield unless enabled?
      start=now;return yield unless start
      begin;yield
      ensure
        finish=now;record(tag,finish-start) if finish
      end
    end
    def record(tag,ms)
      return if @publishing || ms<0
      @phases ||= {};@slow ||= []
      return if !@phases.has_key?(tag) && @phases.size>=32
      row=(@phases[tag] ||= [0,0.0,0.0])
      row[0]+=1;row[1]+=ms;row[2]=ms if ms>row[2]
      if ms>=50
        @slow<<[tag,ms,context]
        @slow.sort_by! { |x| -x[1] };@slow=@slow.take(8)
      end
    rescue StandardError
      @failed=true
    end
    def begin_frame
      unless enabled?;reset_clock if @previous;return nil;end
      start=now;return nil unless start
      [start,context]
    rescue StandardError
      @failed=true;nil
    end
    def end_frame(stamp)
      return unless stamp
      finish=now;return unless finish
      start,ctx=stamp;@window_at ||= start;@frames ||= {};@phases ||= {};@slow ||= []
      record(:graphics_update,finish-start)
      if @previous && @previous[2]==ctx
        interval=start-@previous[0];logic=start-@previous[1]
        if interval>0 && (@frames.size<16 || @frames.has_key?(ctx))
          row=(@frames[ctx] ||= [0,0.0,0.0,0.0,Array.new(256,0),0,0,0,0,0.0])
          row[0]+=1;row[1]+=interval;row[2]+=logic;row[3]=interval if interval>row[3]
          row[4][[[((interval*2).floor),0].max,255].min]+=1
          row[5]+=1 if interval>33.333;row[6]+=1 if interval>100;row[7]+=1 if interval>1000
          if interval<=1000;row[8]+=1;row[9]+=interval;end
        end
      end
      @previous=[start,finish,ctx]
      publish(finish) if finish-@window_at>=PERIOD
    rescue StandardError
      @failed=true
    end
    def round(ms);(ms*1000).round/1000.0;end
    def percentile(hist,count,p)
      wanted=(count*p).ceil;sum=0
      hist.each_with_index do |n,i|
        sum+=n
        return i==255 ? '>=127.5' : (i+1)/2.0 if sum>=wanted
      end
      nil
    end
    def counters
      data={:native_resources=>BS2Suite::ResourceStats.sample}
      if GC.respond_to?(:stat)
        stat=GC.stat;data[:gc]={}
        [:count,:heap_used,:heap_live_slot,:heap_live_slots,:total_allocated_object,:total_allocated_objects].each { |key| data[:gc][key]=stat[key] if stat[key].is_a?(Numeric) }
      elsif GC.respond_to?(:count);data[:gc]={:count=>GC.count};end
      if $game_map
        data[:map_events]=$game_map.events.size
        data[:parallel_events]=$game_map.events.values.count { |event| event.trigger==4 }
      end
      if defined?(BS2Suite::SteamBridge)
        s=BS2Suite::SteamBridge.stats
        data[:renderer]={:captures=>s[2],:presents=>s[3],:gl_ready=>s[4],:errors=>s[5],:overlay_active=>s[20]}
      end
      if defined?(BS2Suite::HDDisplay)
        s=BS2Suite::HDDisplay.status;data[:hd]={:active=>s[1],:width=>s[6],:height=>s[7]}
      end
      data
    end
    def publish(finish=now)
      return false unless enabled? && finish && @window_at
      frames=@frames || {};phases=@phases || {};slow=@slow || [];elapsed=finish-@window_at
      @frames={};@phases={};@slow=[];@window_at=finish;@publishing=true
      begin
        data={:elapsed_ms=>round(elapsed),:frame_groups=>frames.map do |ctx,row|
          {:scene=>ctx[0],:map=>ctx[1],:modal=>ctx[2],:focused=>ctx[3],:overlay=>ctx[4],:intervals=>row[0],
            :fps=>round(1000.0*row[0]/row[1]),:mean_interval_ms=>round(row[1]/row[0]),:mean_logic_ms=>round(row[2]/row[0]),
            :fps_without_long_gaps=>row[9]>0 ? round(1000.0*row[8]/row[9]) : nil,
            :max_interval_ms=>round(row[3]),:p50_upper_ms=>percentile(row[4],row[0],0.5),:p95_upper_ms=>percentile(row[4],row[0],0.95),
            :over_33ms=>row[5],:over_100ms=>row[6],:over_1s=>row[7]}
        end,:phases=>Hash[phases.map { |tag,row| [tag,{:calls=>row[0],:total_ms=>round(row[1]),:mean_ms=>round(row[1]/row[0]),:max_ms=>round(row[2])}] }],
          :slow=>slow.map { |tag,ms,ctx| {:phase=>tag,:ms=>round(ms),:scene=>ctx[0],:map=>ctx[1],:modal=>ctx[2]} }}
        data.merge!(counters)
        BS2Suite::Debug.emit('performance',data)
      ensure
        @publishing=false
      end
      true
    rescue StandardError
      @failed=true;false
    end
    def wrap(owner,name,tag)
      return unless owner.method_defined?(name) || owner.private_method_defined?(name)
      old=('bs20995_profile_'+tag.to_s).to_sym
      owner.class_eval do
        alias_method old,name
        define_method(name) do |*args,&block|
          BS2Suite::PerfTrace.measure(tag) { send(old,*args,&block) }
        end
      end
    end
    def wrap_pause(owner,name,tag)
      return unless owner.method_defined?(name)
      old=('bs20995_pause_'+tag.to_s).to_sym
      owner.class_eval do
        alias_method old,name
        define_method(name) do |*args,&block|
          begin
            BS2Suite::PerfTrace.measure(tag) { send(old,*args,&block) }
          ensure
            BS2Suite::PerfTrace.break_interval
          end
        end
      end
    end
  end
end

module BS2Suite::Debug
  class << self
    def recording?;!!@file;end
    alias bs20995_profile_close close
    def close(*args)
      BS2Suite::PerfTrace.publish
      bs20995_profile_close(*args)
    ensure
      BS2Suite::PerfTrace.reset_clock
    end
  end
end

module Graphics
  class << self
    alias bs20995_profile_graphics update
    def update
      stamp=BS2Suite::PerfTrace.begin_frame
      result=bs20995_profile_graphics
      BS2Suite::PerfTrace.end_frame(stamp)
      result
    end
  end
end

trace=BS2Suite::PerfTrace
[[Game_Map,:update,:map_logic],[Spriteset_Map,:update,:map_sprites],
 [Spriteset_Battle,:update,:battle_sprites],[Scene_Base,:update_all_windows,:windows],
 [Game_Interpreter,:update,:interpreters]].each { |owner,name,tag| trace.wrap(owner,name,tag) }
[[BS2Suite::Debug,:emit,:diagnostic_log],[BS2Suite::Debug,:snapshot,:diagnostic_snapshot],
 [BS2Suite::Debug,:tick,:diagnostic_tick]].each { |owner,name,tag| trace.wrap(class << owner;self;end,name,tag) }
[[defined?(BS2Suite::HDDisplay) && BS2Suite::HDDisplay,:poll,:hd_panel],
 [defined?(BS2Suite::SteamBridge) && BS2Suite::SteamBridge,:poll,:steam_poll],
 [defined?(BS2Suite::QuickDamage) && BS2Suite::QuickDamage,:lines,:damage_preview],
 [defined?(BS2Suite::TempoHint) && BS2Suite::TempoHint,:result,:tempo_preview],
 [defined?(BS2Suite::Palette) && BS2Suite::Palette,:update,:palette]].each do |owner,name,tag|
  trace.wrap(class << owner;self;end,name,tag) if owner
end
graphics_class=class << Graphics;self;end
[:transition,:fadein,:fadeout,:wait].each { |name| trace.wrap_pause(graphics_class,name,('graphics_'+name.to_s).to_sym) }
[:save_game,:load_game].each { |name| trace.wrap_pause(class << DataManager;self;end,name,name) }
trace.wrap(class << GC;self;end,:start,:explicit_gc)
if defined?(BS2Suite::SteamBridge)
  module BS2Suite::SteamBridge
    class << self
      alias bs20995_overlay_pause hold_overlay
      def hold_overlay
        return bs20995_overlay_pause unless active?
        begin;BS2Suite::PerfTrace.measure(:steam_overlay_wait) { bs20995_overlay_pause }
        ensure;BS2Suite::PerfTrace.break_interval;end
      end
    end
  end
end

class BS2Suite::SettingsCommands
  alias bs20995_trace_commands make_command_list
  def make_command_list
    bs20995_trace_commands
    row=@list.pop
    add_command('Диагностика производительности: '+(BS2Suite::Options.get('performance_trace')==1 ? 'вкл' : 'выкл'),:performance_trace)
    @list<<row
  end
end
class BS2Suite::SettingsScene
  alias bs20995_trace_settings start
  def start
    bs20995_trace_settings
    @commands.set_handler(:performance_trace,lambda { option('performance_trace',BS2Suite::Options.get('performance_trace')==1 ? 0 : 1) })
  end
end
