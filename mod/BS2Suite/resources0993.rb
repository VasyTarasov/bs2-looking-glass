# encoding: UTF-8
# The verified native AP-gauge script owns a Graphics.width x Graphics.height
# bitmap for EACH HP/MP/TP/AP strip, but disposes only its Sprite. Release
# the owned backing allocation at teardown instead of waiting for Ruby GC.
class Sprite_Enemy_Gauge
  alias bs20993_resource_initialize initialize
  def initialize(*args)
    bs20993_resource_initialize(*args)
    original=self.bitmap
    # Native draw_gauge only draws a six-pixel strip. Keep its coordinate system
    # and clipping (custom widths beyond the original screen were clipped too).
    width=[[@gauge_width.to_i,1].max,Graphics.width].min
    begin
      @bs20993_owned_bitmap=Bitmap.new(width,6)
      self.bitmap=@bs20993_owned_bitmap
    ensure
      original.dispose if original && !original.disposed?
    end
  end
  alias bs20993_resource_dispose dispose
  def dispose
    begin
      bs20993_resource_dispose
    ensure
      buffer=@bs20993_owned_bitmap
      buffer.dispose if buffer && !buffer.disposed?
      @bs20993_owned_bitmap=nil
    end
  end
end
class Scene_Battle
  alias bs20993_resource_terminate terminate
  def terminate
    bs20993_resource_terminate
    # Reclaim discarded native-render wrappers at the completed teardown,
    # never during input/ATB ticks. Live/shared cached assets remain referenced.
    GC.start
  end
end
module BS2Suite
  # Content-free telemetry from this process only; no memory contents, saves,
  # command line or other process inspection. Called by enabled diagnostics.
  module ResourceStats
    def self.sample
      @process ||= Win32API.new('kernel32','GetCurrentProcess',[],'L')
      @memory ||= Win32API.new('psapi','GetProcessMemoryInfo',['L','P','L'],'I')
      @gui ||= Win32API.new('user32','GetGuiResources',['L','L'],'L')
      @handles ||= Win32API.new('kernel32','GetProcessHandleCount',['L','P'],'I')
      process=@process.call;raw=([44]+[0]*10).pack('L*');handles=[0].pack('L')
      return {} if @memory.call(process,raw,raw.bytesize)==0
      fields=raw.unpack('L*');@handles.call(process,handles)
      {:private_bytes=>fields[10],:working_set_bytes=>fields[3],:gdi_objects=>@gui.call(process,0),
        :user_objects=>@gui.call(process,1),:process_handles=>handles.unpack('L')[0]}
    rescue StandardError
      {}
    end
  end
end
