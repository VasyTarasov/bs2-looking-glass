# encoding: UTF-8
rgss_main do
  def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
  def capture(path)
    Graphics.transition(0);Graphics.brightness=255;4.times { Graphics.update }
    bitmap=Graphics.snap_to_bitmap;raw=''.force_encoding('ASCII-8BIT')
    bitmap.height.times do |y|
      raw<<"\0"
      bitmap.width.times { |x| color=bitmap.get_pixel(x,y);raw<<[color.red.to_i,color.green.to_i,color.blue.to_i,255].pack('C4') }
    end
    chunk=lambda { |tag,data| [data.bytesize].pack('N')+tag+data+[Zlib.crc32(tag+data)].pack('N') }
    bytes="\x89PNG\r\n\x1a\n".force_encoding('ASCII-8BIT')+chunk.call('IHDR',[bitmap.width,bitmap.height,8,6,0,0,0].pack('NNCCCCC'))+chunk.call('IDAT',Zlib::Deflate.deflate(raw))+chunk.call('IEND','')
    File.open(path,'wb') { |f| f.write(bytes) };bitmap.dispose
  end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'Version 1 native module-selector visual QA' }
    DataManager.init;DataManager.setup_new_game
    SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(Graphics.width,Graphics.height))
    scene=BS2Suite::ModuleScene.new;SceneManager.instance_variable_set(:@scene,scene);scene.start
    list=scene.instance_variable_get(:@commands)
    ['hd_display','macros','weapon_family_cleanup'].each do |id|
      list.select(BS2Suite::IDS.index(id));list.update_help
      3.times { scene.update_basic };capture('v1-modules-'+id+'.png')
    end
    scene.terminate
    log('result=PASS; checks=3')
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure
    BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  end
end
