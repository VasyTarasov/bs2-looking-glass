# encoding: UTF-8
rgss_main do
load 'BS2QA_native_capture.rb'
module MapReturnQA
  class << self
    attr_reader :checks,:cycles
    def log(text);File.open('test_result.txt','a') { |f| f.puts text };end
    def check(value,label);raise 'Assertion: '+label unless value;@checks+=1;log('PASS '+label);end
    def setup
      @checks=0;@cycles=0;@phase=:map;@map=nil;@old_notice=nil
      @kinds=[:equip,:item,:save,:favorites]*3
    end
    def tick(scene)
      case scene
      when Scene_Map
        return unless @phase==:map
        @map ||= scene
        check(scene.equal?(@map),'native SceneManager resumes the same map object '+@cycles.to_s)
        notice=scene.instance_variable_get(:@bs2v2_notice)
        if @expired
          check(!notice,'expired notice does not recreate a closed window '+@cycles.to_s)
          @expired=false;BS2QoL::Hotkeys.notice('QA after expiry');return
        end
        check(notice && !notice.disposed?,'map owns a live notice after return '+@cycles.to_s)
        check(@old_notice.disposed? && !notice.equal?(@old_notice),'previous lifecycle notice is retired '+@cycles.to_s) if @old_notice
        if @cycles==@kinds.size
          SceneManager.exit;return
        end
        @old_notice=notice;@kind=@kinds[@cycles];@cycles+=1;@phase=:menu
        BS2QoL::Hotkeys.notice('QA return '+@cycles.to_s)
        scene.call_menu
      when Scene_Menu
        if @phase==:menu
          @phase=:child
          klass={:equip=>Scene_Equip,:item=>Scene_Item,:save=>Scene_Save,:favorites=>Scene_BS2QFavorites}[@kind]
          SceneManager.call(klass)
        elsif @phase==:back
          @phase=:map
          BS2QoL::Hotkeys.notice('QA resumed '+@cycles.to_s)
          if @cycles.even?
            BS2QoL::Hotkeys.instance_variable_set(:@notice_tick,(Win32API.new('kernel32','GetTickCount',[],'L').call-2000)&0xffffffff);@expired=true
          end
          scene.return_scene
        end
      else
        return unless @phase==:child
        @phase=:back
        if @kind==:save
          scene.bs2suite_file_ok
          check(File.file?(DataManager.make_filename(0)),'native save menu writes only the synthetic QA save')
        else
          scene.return_scene
        end
      end
    end
  end
end
[Scene_Map,Scene_Menu,Scene_Equip,Scene_Item,Scene_Save,Scene_BS2QFavorites].each do |klass|
  klass.class_eval do
    alias_method :map_return_qa_update,:update
    define_method(:update) do
      map_return_qa_update
      MapReturnQA.tick(self) unless scene_changing?
    end
  end
end
class Scene_Base
  def transition_speed;0;end
end
class << DataManager
  def make_filename(index);'MapReturnQA_'+index.to_s+'.rvdata2';end
end
begin
  File.open('test_result.txt','w') { |f| f.puts 'native map/menu/save lifecycle; ruby='+RUBY_VERSION }
  MapReturnQA.setup
  DataManager.init;DataManager.setup_new_game;Window_MenuCommand.init_command_position
  BS2Suite::Debug.start if defined?(BS2Suite::Debug)
  map=RPG::Map.new(20,15);map.tileset_id=$game_map.tileset.id;map.display_name='QA blank map'
  save_data(map,'Data/Map999.rvdata2');$game_map.setup(999);$game_player.moveto(5,5);$game_player.refresh
  $game_system.menu_disabled=false;$game_system.save_disabled=false
  BS2QoL::Hotkeys.notice('QA initial notice')
  SceneManager.goto(Scene_Map)
  SceneManager.scene.main while SceneManager.scene
  MapReturnQA.check(MapReturnQA.cycles==12,'twelve real menu round trips finish')
  GC.start
  MapReturnQA.check(ObjectSpace.each_object(Window).all? { |w| w.disposed? },'all windows are disposed at final exit')
  MapReturnQA.log('result=PASS; checks='+MapReturnQA.checks.to_s)
rescue Exception=>error
  MapReturnQA.log('result=FAIL; '+error.class.to_s+': '+error.message);MapReturnQA.log(error.backtrace.join("\n"))
ensure
  BS2Suite::Debug.close if defined?(BS2Suite::Debug)
  File.delete('Data/Map999.rvdata2') if File.file?('Data/Map999.rvdata2')
  (0...105).each { |i| p=DataManager.make_filename(i);File.delete(p) if File.file?(p) }
  SceneManager.exit;Graphics.transition(0);SuiteCapture.close;5.times { Graphics.update }
end
end
