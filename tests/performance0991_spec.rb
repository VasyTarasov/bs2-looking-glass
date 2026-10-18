# encoding: UTF-8
rgss_main do
@checks=0
def log(t);File.open('test_result.txt','a') { |f| f.puts t };end
def check(v,t);raise t unless v;@checks+=1;log('PASS '+t);end
begin
  File.open('test_result.txt','w') { |f| f.puts 'palette timing; native '+RUBY_VERSION }
  DataManager.init;DataManager.setup_new_game
  SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
  actor=$game_actors[1];actor.change_class(1);actor.change_level(70,false);actor.clear_equipments
  BS2Suite::Arsenal093::CATEGORIES.map { |g| g[1] }.flatten.each { |id| $game_party.gain_item($data_weapons[id],1) }
  BS2Suite::SemanticCatalog::RECORDS.select { |r| r[:prefix]=='M' }.each { |r| r[:variants].each { |id| actor.learn_skill(id) } }
  actor.change_equip(0,$data_weapons[361]);actor.recover_all
  8.times { |id| actor.add_buff(id,5) }
  BS2Suite::Semantic.sync(actor);BS2Suite::DirectWeapons.sync(actor)
  BS2Suite::Options.set('knowledge_threshold',0)
  troop=RPG::Troop.new;troop.id=79
  troop.members=(0..2).map do |i|
    enemy=RPG::Enemy.new;enemy.id=5000+i;enemy.name='QA '+i.to_s;enemy.params=[50000,100,50,40+i*20,50,40+i*10,80,50];$data_enemies[enemy.id]=enemy
    member=RPG::Troop::Member.new;member.enemy_id=enemy.id;member.x=150+i*160;member.y=180;member
  end
  $data_troops[79]=troop;BattleManager.setup(79,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
  actor.instance_variable_set(:@ap,ATB::MAX_AP);actor.instance_variable_set(:@actions,[Game_Action.new(actor)]);actor.instance_variable_set(:@action_input_index,0)
  BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
  scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,scene);scene.start;scene.start_actor_command_selection
  command=scene.instance_variable_get(:@actor_command_window);command.openness=255
  hd=BS2Suite::HDDisplay;hd.apply(hd::DEFAULT.merge('width'=>960,'height'=>720))
  90.times { Graphics.update;Input.update;break if hd.active? };check(hd.active?,'real HD active')
  clock=Win32API.new('kernel32','GetTickCount',[],'L');results=[]
  %w(V M N).each do |prefix|
    BS2Suite::Semantic.acknowledge(actor,prefix);BS2Suite::Palette.open(scene,command,actor,prefix)
    popup=BS2Suite::Palette.current(scene)
    groups=prefix=='N' ? BS2Suite::DirectWeapons.groups(actor) : BS2Suite::Semantic.groups(actor,prefix)
    group=groups.max_by { |g| (prefix=='N' ? BS2Suite::DirectWeapons.rows(actor,g[:number]) : BS2Suite::Semantic.rows(actor,prefix,g[:number])).size }
    popup.set_group(group[:number]);hd.palette_rows(popup)
    before=clock.call;30.times { hd.palette_rows(popup) };stable=(clock.call-before)&0xffffffff
    before=clock.call
    30.times { |i| popup.select(i%popup.entries.size);hd.palette_rows(popup) }
    moving=(clock.call-before)&0xffffffff
    results<<prefix+' stable_30_ms='+stable.to_s+' selection_30_ms='+moving.to_s
    check(popup.entries.size<=10 && !popup.entries.empty?,prefix+' fixture uses a real bounded group')
    BS2Suite::Palette.close(scene)
  end
  File.open('performance.txt','w') { |f| results.each { |line| f.puts line } }
  results.each { |line| log(line) }
  scene.terminate;$game_party.on_battle_end
  log('result=PASS; checks='+@checks.to_s)
rescue Exception=>e
  log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
ensure
  BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
end
end
