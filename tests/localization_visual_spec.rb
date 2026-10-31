# encoding: UTF-8
rgss_main do
  def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
  def png(path,w,h,rgba)
    raw=''.force_encoding('ASCII-8BIT');h.times { |y| raw<<"\0"<<rgba[y*w*4,w*4] }
    chunk=lambda { |tag,data| [data.bytesize].pack('N')+tag+data+[Zlib.crc32(tag+data)].pack('N') }
    bytes="\x89PNG\r\n\x1a\n".force_encoding('ASCII-8BIT')+chunk.call('IHDR',[w,h,8,6,0,0,0].pack('NNCCCCC'))+chunk.call('IDAT',Zlib::Deflate.deflate(raw))+chunk.call('IEND','')
    File.open(path,'wb') { |f| f.write(bytes) }
  end
  def capture(path)
    Graphics.transition(0);Graphics.brightness=255;3.times { Graphics.update }
    bitmap=Graphics.snap_to_bitmap;rgba=''.force_encoding('ASCII-8BIT')
    bitmap.height.times { |y| bitmap.width.times { |x| c=bitmap.get_pixel(x,y);rgba<<[c.red.to_i,c.green.to_i,c.blue.to_i,255].pack('C4') } }
    png(path,bitmap.width,bitmap.height,rgba);bitmap.dispose
  end
  def composite(path)
    hd=BS2Suite::HDDisplay;hd.poll(true)
    read=Win32API.new('Mods/BS2Suite/native/bs2_steam_bridge.dll','BS2_HDReadback',['P','I'],'I')
    read.call('',0);w,h=hd.status[6,2];raise 'Invalid native composite size' unless w>0 && h>0
    pixels=("\0"*(w*h*4)).force_encoding('ASCII-8BIT');size=0
    90.times { Graphics.update;size=read.call(pixels,pixels.bytesize);break if size==pixels.bytesize }
    raise 'No native composite' unless size==pixels.bytesize
    rgba=''.force_encoding('ASCII-8BIT');pixels.bytes.each_slice(4) { |b,g,r,a| rgba<<[r,g,b,255].pack('C4') }
    png(path,w,h,rgba)
  end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'Native English visual QA' }
    DataManager.init;DataManager.setup_new_game
    SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(Graphics.width,Graphics.height))
    actor=$game_party.leader;actor.change_class(1);actor.change_level(100,false);actor.recover_all;$game_party.menu_actor=actor
    compiled=0
    if defined?(RubyVM::InstructionSequence)
      Dir.glob('Mods/BS2Suite/en/**/*.rb').each do |file|
        RubyVM::InstructionSequence.compile(File.open(file,'rb') { |f| f.read }.force_encoding('UTF-8'),file);compiled+=1
      end
    end
    log('english_ruby_files_compiled='+compiled.to_s)
    scene=BS2Suite::SettingsScene.new;SceneManager.instance_variable_set(:@scene,scene);scene.start;4.times { scene.update_basic };capture('english-settings.png');scene.terminate
    [32,272].each do |id|
      object=id==32 ? $data_items[id] : $data_weapons[id]
      window=Window_BS2QReference.new(object,actor);window.openness=255;window.show
      capture('english-reference-'+id.to_s+'.png');window.dispose
    end
    if defined?(BS2Suite::HDDisplay)
      data=RPG::Enemy.new;data.id=5900;data.name='Training target';data.params=[1000000,100000,100,100,100,100,100,100];$data_enemies[5900]=data
      troop=RPG::Troop.new;troop.id=5900;m=RPG::Troop::Member.new;m.enemy_id=5900;m.x=400;m.y=220;troop.members=[m];$data_troops[5900]=troop
      $game_party.gain_item($data_items[32],5);$game_party.gain_item($data_items[61],5)
      BattleManager.setup(5900,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
      actor.instance_variable_set(:@actions,[Game_Action.new(actor)]);actor.instance_variable_set(:@action_input_index,0);actor.instance_variable_set(:@ap,ATB::MAX_AP)
      BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
      scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,scene);scene.start;scene.start_actor_command_selection
      raise 'HD mode failed' unless BS2Suite::HDDisplay.apply(BS2Suite::HDDisplay::DEFAULT.merge('width'=>1280,'height'=>720))
      scene.command_item;w=scene.instance_variable_get(:@item_window);w.refresh;w.select(w.instance_variable_get(:@data).index($data_items[32]));w.show.activate;w.openness=255
      8.times { scene.update_basic };BS2Suite::HDDisplay.battle_rows(scene);composite('english-hd-items.png');scene.terminate
    end
    log('result=PASS; checks=4')
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure;BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge);end
end
