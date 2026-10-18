# encoding: UTF-8
# QA only. Capture only a window owned by this isolated Game.exe.
module SuiteCapture
  # Close only the QA process's own window through the normal WM_CLOSE path.
  # A bare Ruby exit after manually driven scenes can leave RGSS waiting on
  # the private desktop; do not use ExitProcess or treat a timeout as success.
  def self.close
    window=Win32API.new('user32','GetActiveWindow',[],'L').call
    pid=Win32API.new('kernel32','GetCurrentProcessId',[],'L').call;owner=[0].pack('L')
    Win32API.new('user32','GetWindowThreadProcessId',['L','P'],'L').call(window,owner)
    raise 'Not own QA window' unless window!=0 && owner.unpack('L')[0]==pid
    Win32API.new('user32','PostMessage',['L','L','L','L'],'I').call(window,0x10,0,0)
  end
  def self.save(path,window=nil,width=640,height=480)
    api=lambda { |dll,name,args,result| Win32API.new(dll,name,args,result) }
    window ||= api.call('user32','GetActiveWindow',[],'L').call
    pid=api.call('kernel32','GetCurrentProcessId',[],'L').call;owner=[0].pack('L')
    api.call('user32','GetWindowThreadProcessId',['L','P'],'L').call(window,owner)
    raise 'Not own QA window' unless window!=0 && owner.unpack('L')[0]==pid
    dc=api.call('user32','GetDC',['L'],'L').call(window)
    mem=api.call('gdi32','CreateCompatibleDC',['L'],'L').call(dc)
    bmp=api.call('gdi32','CreateCompatibleBitmap',['L','I','I'],'L').call(dc,width,height)
    select=api.call('gdi32','SelectObject',['L','L'],'L');old=select.call(mem,bmp)
    ok=api.call('gdi32','BitBlt',['L','I','I','I','I','L','I','I','L'],'I').call(mem,0,0,width,height,dc,0,0,0x00CC0020)
    select.call(mem,old)
    pixels=("\0"*(width*height*4)).force_encoding('ASCII-8BIT')
    header=[40,width,-height,1,32,0,pixels.bytesize,0,0,0,0].pack('LllSSLLLLLL')
    rows=api.call('gdi32','GetDIBits',['L','L','I','I','P','P','I'],'I').call(mem,bmp,0,height,pixels,header,0)
    raise 'Native capture failed' unless ok!=0 && rows==height
    File.open(path,'wb') { |f| f.write('BM'+[54+pixels.bytesize,0,54].pack('L3')+header+pixels) }
  ensure
    api.call('gdi32','DeleteObject',['L'],'I').call(bmp) if bmp
    api.call('gdi32','DeleteDC',['L'],'I').call(mem) if mem
    api.call('user32','ReleaseDC',['L','L'],'I').call(window,dc) if dc
  end
end
