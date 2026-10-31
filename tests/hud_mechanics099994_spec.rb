# encoding: UTF-8
# Current 0.99993 UI contract: original lore, focused reference and manual battle automation.
rgss_main do
  @checks=0
  def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
  def check(v,s);raise s unless v;@checks+=1;log('PASS '+s);end
  class HUDRepairKeys
    attr_accessor :keys
    def initialize;@keys=[];end
    def down;@keys;end
    def focused?;true;end
  end
  def frame(keys=[]);@raw.keys=keys;@scene.update_basic;end
  def action(actor,id)
    a=Game_Action.new(actor);a.set_skill(id);a.target_index=0
    actor.instance_variable_set(:@actions,[a]);actor.instance_variable_set(:@action_input_index,0);actor.cool_time.clear
    BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
    actor.instance_variable_set(:@ap,ATB::MAX_AP);BS2Suite::Performance.bump;a
  end
  def png(path,w,h,rgba)
    raw=''.force_encoding('ASCII-8BIT');h.times { |y| raw<<"\0"<<rgba[y*w*4,w*4] }
    chunk=lambda { |tag,data| [data.bytesize].pack('N')+tag+data+[Zlib.crc32(tag+data)].pack('N') }
    value="\x89PNG\r\n\x1a\n".force_encoding('ASCII-8BIT')+chunk.call('IHDR',[w,h,8,6,0,0,0].pack('NNCCCCC'))+chunk.call('IDAT',Zlib::Deflate.deflate(raw))+chunk.call('IEND','')
    File.open(path,'wb') { |file| file.write(value) }
  end
  def canvas(path)
    Graphics.transition(0);Graphics.brightness=255;Graphics.update;bitmap=Graphics.snap_to_bitmap;rgba=''.force_encoding('ASCII-8BIT')
    bitmap.height.times { |y| bitmap.width.times { |x| c=bitmap.get_pixel(x,y);rgba<<[c.red.to_i,c.green.to_i,c.blue.to_i,c.alpha.to_i].pack('C4') } }
    png(path,bitmap.width,bitmap.height,rgba);bitmap.dispose
  end
  def composite(path)
    hd=BS2Suite::HDDisplay;Graphics.transition(0);Graphics.brightness=255;hd.poll(true)
    log('HD_DIAGNOSTIC='+[hd.error,SceneManager.scene.class.to_s,hd.instance_variable_get(:@last_text).to_s[0,200]].inspect);check(hd.error.nil? && !hd.instance_variable_get(:@last_text).to_s.empty?,'HD accepts nonempty final compositor text')
    marker=Sprite.new;marker.bitmap=Bitmap.new(2,2);marker.bitmap.fill_rect(0,0,2,2,Color.new(1,2,3));6.times { |i| marker.x=i;Graphics.update }
    read=Win32API.new('Mods/BS2Suite/native/bs2_steam_bridge.dll','BS2_HDReadback',['P','I'],'I')
    read.call('',0);w,h=hd.status[6,2];pixels=("\0"*(w*h*4)).force_encoding('ASCII-8BIT');size=0
    90.times { Graphics.update;size=read.call(pixels,pixels.bytesize);break if size==pixels.bytesize }
    raise 'Own composite not returned' unless size==pixels.bytesize
    rgba=''.force_encoding('ASCII-8BIT');pixels.bytes.each_slice(4) { |b,g,r,a| rgba<<[r,g,b,255].pack('C4') }
    png(path,w,h,rgba);marker.bitmap.dispose;marker.dispose;[pixels,w,h]
  end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'HUD mechanics and per-recipient fallback '+BS2Suite::VERSION }
    DataManager.init;DataManager.setup_new_game
    SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
    @raw=HUDRepairKeys.new;BS2QoL::Keyboard.backend=@raw;BS2QoL::Keyboard.reset
    actor=$game_party.leader;actor.change_class(1);actor.change_level(200,false);actor.clear_equipments
    actor.instance_variable_get(:@param_plus)[2]+=4000;actor.instance_variable_get(:@param_plus)[4]+=4000;actor.instance_variable_get(:@param_plus)[0]+=100000000;actor.instance_variable_get(:@param_plus)[1]+=1000000;actor.recover_all
    $game_party.menu_actor=actor;helper=BS2Suite::CatalogUI
    # These assertions concern the rendered HUD paths, rather than nonempty F7 sections.
    static=lambda { |o| helper.plain(helper.static_rows(o,actor).join(' ')) }
    [14,15,36,78,81,95,109,193,969].each do |id|
      s=$data_skills[id];next unless s
      text=static.call(s)
      check(text.include?(s.damage.recover? ? 'Лечение HP' : 'Урон HP') && text.include?('За попадание:'),'damage/healing meaning and formula available before entering battle '+id.to_s) unless s.damage.none?
    end
    check(static.call($data_items[78]).include?('Восстановление HP: 50%') && static.call($data_items[78]).include?('Восстановление MP: 50%'),'Turtle Soup describes both native resource effects in the menu')
    check(static.call($data_items[51]).include?('50 +') && static.call($data_items[51]).include?('AGI'),'Throwing Knife keeps its actual damage formula')
    check(static.call($data_items[30]).include?('150') && static.call($data_items[30]).include?('Огонь'),'Fire Bomb has actual damage and element')
    check(static.call($data_armors[111]).include?('восстановление HP/MP ×2'),'Miracle Ring recovery multiplier retained')
    [133,147].each { |id| check(static.call($data_armors[id]).include?('Дополнительная команда: шанс '+(id==133 ? '10' : '50')+'%'),'ring extra-command mechanic restored '+id.to_s) }
    check(static.call($data_weapons[379]).include?('шанс 30%') && static.call($data_weapons[379]).include?('Цена MP ×2'),'Andor keeps its extra command and real cost drawback')
    check(helper.description($data_armors[157]).size==1 && static.call($data_armors[157]).include?('+25%'),'My Struggle groups six start-of-battle buffs once')
    check(helper.description($data_armors[232]).size==1 && static.call($data_armors[232]).include?('DEF/MDF ×9') && static.call($data_armors[232]).include?('HP +100%'),'Indomitable describes the actual initial state once')
    check(static.call($data_items[52]).include?('Слабость: блокирует восстановление HP') && static.call($data_armors[221]).include?('Слабость: блокирует восстановление HP'),'weakness explained for both the mushroom and the ring')
    check(static.call($data_armors[123]).include?('Акробатика:') && static.call($data_armors[123]).include?('+70'),'Dark Wood Ring explains its granted action')
    check(helper.description($data_armors[34])==['Физ./маг. уклонение +5 п.п.'],'equal evasion bonuses share one line')
    abyss=helper.description($data_armors[12]);check(abyss.size<12 && abyss.join.include?('Разрывание') && abyss.join.include?('Прерывание'),'large state resistance groups retain their complete affected set')
    check(static.call($data_skills[12]).include?('+70') && static.call($data_skills[12]).include?('AGI ×1.5'),'Dodge has actionable bonuses')
    check(static.call($data_skills[13]).include?('урон ×2'),'Break explains vulnerability')
    [969,971].each do |id|
      text=static.call($data_skills[id]);check(!text.include?('Техническая запись') && text.include?(id==969 ? '×1.5' : '×5.0625'),'anonymous rapier states expose their actual damage multiplier '+id.to_s)
    end
    check(static.call($data_weapons[451]).include?('Бойня: 4') && !static.call($data_weapons[451]).include?('фиксируется'),'Butcher saw has a direct conditional hit count')
    check(static.call($data_weapons[463]).include?('от 1 до 8') && !static.call($data_weapons[463]).include?('Стак 7 →'),'God Angels describes its stack range compactly')
    objects=[$data_items,$data_skills,$data_weapons,$data_armors].map { |xs| xs.compact.select { |o| o.id>0 && !o.name.strip.empty? } }.flatten
    rows=[]
    objects.each do |o|
      [:ru,:en].each do |locale|
        text=helper.plain(helper.static_rows(o,actor,locale).join(' '))
        check(!text.empty? && text !~ /Техническая запись state:|Technical entry state:/,'no technical placeholder in static HUD '+o.class.to_s+o.id.to_s+locale.to_s)
        rows<<[o.class.to_s,o.id,locale.to_s,text.empty?]
      end
    end
    File.open('hud-coverage.txt','w') { |f| rows.select { |r| r[-1] }.each { |r| f.puts r.inspect } }
    # Three original Alice templates, including the native counter trait.
    BattleManager.setup(620,true,false);$game_party.on_battle_start;BS2Suite::Options.data['knowledge_threshold']=0
    $game_troop.members.each_with_index { |e,i| i<3 ? (e.transform(561+i);e.appear;e.recover_all) : e.hide }
    actor.recover_all;[81,109,193,969,971].each { |id| actor.learn_skill(id) }
    @scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,@scene);@scene.start
    actor.instance_variable_set(:@ap,ATB::MAX_AP);BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
    original=Marshal.dump([actor,$game_party,$game_troop,$game_variables,$game_switches]);srand(38294);expected=rand;srand(38294)
    [81,109,193].each do |id|
      actor.cool_time.clear;action(actor,id)
      $game_troop.alive_members.each do |target|
        first=BS2Suite::ForecastContext.step($data_skills[id],actor,nil,target,nil,false,true)
        check(first && !first[:reason] && first[:hit_count]==1 && first[:rows].size==1 && first[:rows][0][:target_index]==target.index,'one-target first-hit fallback for original AoE '+id.to_s+'/'+target.index.to_s)
        predicted=first[:rows][0]
        16.times do |seed|
          user=BS2Suite::Projection.copy(actor);victim=BS2Suite::Projection.copy(target);user.pay_skill_cost($data_skills[id]);srand(994000+seed)
          victim.result.clear;victim.item_apply(user,$data_skills[id]);actual=victim.result.hp_damage
          check(actual.between?(predicted[:min],predicted[:max]),'native first-hit oracle '+id.to_s+'/'+target.index.to_s+'/'+seed.to_s)
        end
      end
      values=helper.results($data_skills[id],actor,nil,nil,nil,false,true);text=helper.damage_lines(values,:ru,true).join(' ')
      check(text.include?('≈') && !text.include?('Прогноз недоступен'),'AoE preview remains useful despite another recipient counter '+id.to_s)
    end
    # Rendering itself must not change resources/states or the RNG stream.
    action(actor,81);before=Marshal.dump([actor,$game_party,$game_troop,$game_variables,$game_switches]);srand(38294);expected=rand;srand(38294)
    3.times { helper.preview(@scene,$data_skills[81],actor,nil,nil,nil,false,true) }
    check(before==Marshal.dump([actor,$game_party,$game_troop,$game_variables,$game_switches]) && rand==expected,'new previews preserve all observed state and RNG')
    if defined?(BS2Suite::HDDisplay)
      hd=BS2Suite::HDDisplay;check(hd.apply(hd::DEFAULT.merge('width'=>1280,'height'=>720)),'HD compositor enabled');5.times { frame }
      # Real menu selection must carry formula/effects, not just a title and F7.
      menu=Scene_Item.new;window=Window_ItemList.new(0,100,400,300);menu.instance_variable_set(:@item_window,window);window.category=:item
      [30,51,78].each do |id|
        $game_party.gain_item($data_items[id],3);window.refresh;window.select(window.instance_variable_get(:@data).index($data_items[id]));window.show.activate;window.openness=255
        text=helper.plain(hd.menu_rows(menu).join(' '));check(text.include?(id==78 ? '50%' : id==30 ? '150' : 'AGI'),'real menu HUD has meaningful item mechanics '+id.to_s)
      end
      window.dispose
      [969,971].each do |id|
        action(actor,id);@scene.command_skill;@scene.on_skill_ok if false
        skill=@scene.instance_variable_get(:@skill_window);skill.hide.deactivate
        enemy=@scene.instance_variable_get(:@enemy_window);enemy.show.activate;enemy.openness=255;enemy.select(1)
        text=helper.plain(hd.battle_rows(@scene).join(' '));check(!text.include?('Техническая запись') && text.include?(id==969 ? '×1.5' : '×5.0625'),'real target-selection HUD exposes the rapier effect '+id.to_s)
        composite('hud-repair-target-'+id.to_s+'.png');enemy.hide.deactivate
      end
      action(actor,81);@scene.instance_variable_get(:@skill_window).hide.deactivate;enemy=@scene.instance_variable_get(:@enemy_window);enemy.show.activate;enemy.openness=255;enemy.select(1)
      hd.battle_rows(@scene);helper.instance_variable_set(:@waiting_at,(BS2Suite::Performance.now-200)&0xffffffff);hd.battle_rows(@scene)
      check(!helper.plain(hd.battle_rows(@scene).join(' ')).include?('Попаданий: 3'),'AoE target count cannot masquerade as repeats per target')
      composite('hud-repair-three-alices.png')
    end
    @scene.terminate;$game_party.on_battle_end
    log('result=PASS; checks='+@checks.to_s+'; native_first_hit_applications=144')
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure;BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge);end
end
