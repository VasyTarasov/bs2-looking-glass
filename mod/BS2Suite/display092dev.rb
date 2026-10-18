# encoding: UTF-8
module BS2Suite::HDDisplay
  class << self
    def monitor_size
      buffer=([0]*6).pack('l*')
      @monitor && @monitor.call(buffer)==6 ? buffer.unpack('l*')[1,2] : [1280,720]
    end
    def data
      return @data if @data
      size=monitor_size
      @data=DEFAULT.merge('width'=>size[0],'height'=>size[1],'mode'=>1,'launch'=>0,'filter'=>0)
      raw=BS2Suite::Store.read('hd_display',4096)
      raw.each_line do |line|
        key,value=line.strip.split('=',2)
        next unless @data.has_key?(key) && value.to_s=~/\A[0-9]{1,4}\z/
        candidate=@data.merge(key=>value.to_i)
        @data=candidate if valid?(candidate) && (0..1).include?(candidate['launch'])
      end
      # Preserve an existing fullscreen preference on the first migration.
      @data['launch']=1 if !raw.empty? && raw !~ /^launch=/ && @data['mode']==1
      @data['filter']=0
      @data
    end
    def iconic?
      hwnd=BS2Suite::SteamBridge.stats[14]
      @is_iconic ||= Win32API.new('user32','IsIconic',['L'],'I')
      hwnd && hwnd!=0 && @is_iconic.call(hwnd)!=0
    end
    def persist(value)
      value=value.merge('filter'=>0)
      return false unless BS2Suite::Store.write('hd_display',value.keys.sort.map { |k| k+'='+value[k].to_s }.join("\n")+"\n")
      @data=value.dup;true
    end
    alias bs2092dev_start_trial start_trial
    def start_trial(value)
      bs2092dev_start_trial(value.merge('filter'=>0))
    end
    def preferred
      value=data.merge('filter'=>0)
      value['mode']=value.values_at('width','height')==monitor_size ? 1 : 0 if value['mode']==2
      value
    end
    def startup
      desired=data['launch']==1 ? preferred : data.merge('mode'=>2)
      @desired=desired.dup;@repair_budget=12;@repair_tick=nil
      return true if iconic?
      apply(desired)
    end
    alias bs2092dev_apply apply
    def apply(value)
      value=value.merge('filter'=>0) if value.is_a?(Hash) && value['mode']!=2
      before=@desired
      @desired=value.dup if value.is_a?(Hash) && valid?(value)
      ok=bs2092dev_apply(value)
      if ok && !@repairing
        @desired=value.dup;@repair_budget=12;@repair_tick=nil
      end
      @desired=before unless ok
      ok
    end
    def matches_desired?
      state=status
      return false if state.size!=16
      return state[1]==0 if @desired['mode']==2
      size=@desired['mode']==1 ? monitor_size : @desired.values_at('width','height')
      state[1]==1 && state[2]==@desired['mode'] && state[6,2]==size && state[3]==0
    end
    def maintain
      return if @repairing || !ready? || !@desired
      minimized=iconic?
      @repair_budget=12 if @was_iconic && !minimized
      @was_iconic=minimized
      return if minimized || @trial || @repair_budget.to_i<=0
      return if matches_desired?
      now=@tick.call
      return if @repair_tick && ((now-@repair_tick)&0xffffffff)<250
      @repair_tick=now;@repair_budget-=1;@repairing=true
      begin
        bs2092dev_apply(@desired)
      ensure
        @repairing=false
      end
    end
    alias bs2092dev_poll poll
    def poll(force=false)
      maintain
      bs2092dev_poll(force)
    end
    def toggle
      return false if @trial || !ready? || iconic?
      value=status[1]==1 ? data.merge('mode'=>2) : preferred
      unless apply(value)
        BS2QoL::Hotkeys.notice(error);return false
      end
      # Toggling never erases the chosen HD size or changes the launch checkbox.
      BS2QoL::Keyboard.consume;true
    end
    def route
      return if (BS2QoL::Keyboard.raw_down & [18,91,92]).any?
      return unless BS2Suite::Keys.trigger?(:fullscreen)
      return if @hotkey_frame==Graphics.frame_count
      @hotkey_frame=Graphics.frame_count
      toggle
    end
  end
end
module Input
  class << self
    alias bs2092dev_display_input update
    def update
      bs2092dev_display_input
      BS2Suite::HDDisplay.route
    end
  end
end
class BS2Suite::DisplayCommands
  alias bs2092dev_display_list make_command_list
  def make_command_list
    bs2092dev_display_list
    @list.reject! { |row| row[:symbol]==:filter }
    @list.insert(1,{:name=>'Полный экран при запуске: '+(BS2Suite::HDDisplay.data['launch']==1 ? '[✓]' : '[ ]'),:symbol=>:launch,:enabled=>true,:ext=>nil})
    @list.insert(2,{:name=>'Чёткий HD: обязательно в HD-режимах',:symbol=>:crisp_required,:enabled=>false,:ext=>nil})
  end
end
class BS2Suite::DisplayScene
  alias bs2092dev_display_start start
  def start
    bs2092dev_display_start
    @commands.set_handler(:launch,lambda {
      hd=BS2Suite::HDDisplay
      ::Sound.play_buzzer unless hd.persist(hd.data.merge('launch'=>1-hd.data['launch']))
      redraw
    })
  end
end
