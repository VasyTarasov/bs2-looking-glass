# encoding: UTF-8
# Current 0.99993 UI contract: original lore, focused reference and manual battle automation.
rgss_main do
  @checks=0
  def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
  def check(v,s);raise s unless v;@checks+=1;log('PASS '+s);end
  class DeclutterKeys
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
    read=Win32API.new('Mods/BS2Suite/native/bs2_steam_bridge.dll','BS2_HDReadback',['P','I'],'I')
    read.call('',0);w,h=hd.status[6,2];pixels=("\0"*(w*h*4)).force_encoding('ASCII-8BIT');size=0
    90.times { Graphics.update;size=read.call(pixels,pixels.bytesize);break if size==pixels.bytesize }
    raise 'Own composite not returned' unless size==pixels.bytesize
    rgba=''.force_encoding('ASCII-8BIT');pixels.bytes.each_slice(4) { |b,g,r,a| rgba<<[r,g,b,255].pack('C4') }
    png(path,w,h,rgba);[pixels,w,h]
  end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'Focused reference and native UI '+BS2Suite::VERSION }
    DataManager.init;DataManager.setup_new_game
    SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
    @raw=DeclutterKeys.new;BS2QoL::Keyboard.backend=@raw;BS2QoL::Keyboard.reset
    actor=$game_party.leader;actor.change_class(1);actor.change_level(200,false);actor.clear_equipments;actor.instance_variable_get(:@param_plus)[1]+=999999;actor.recover_all
    $game_party.menu_actor=actor
    helper=BS2Suite::CatalogUI;catalog=BS2Suite::CatalogV1
    objects=[$data_skills,$data_items,$data_weapons,$data_armors,$data_states].map { |xs| xs.compact.reject { |x| x.id==0 } }.flatten
    snapshot=Marshal.dump(objects.map { |o| o.description })
    help=Window_Help.new
    check(help.height==help.fitting_height(2),'standard help retains the original two-line height')
    objects.each do |object|
      help.set_item(object)
      check(help.instance_variable_get(:@text)==object.description,'original native lore unchanged '+catalog.uid(object).to_s)
    end
    help.set_item($data_items[23]);check(help.instance_variable_get(:@text)==$data_items[23].description,'Girl Scent keeps its original atmospheric description')
    check(snapshot==Marshal.dump(objects.map { |o| o.description }),'reference rendering does not rewrite database descriptions')
    help.dispose
    materials=objects.select { |o| helper.material?(o) }
    materials.each do |object|
      card=BS2QoL::PracticalCard.new(object,actor,:ru)
      check(card.sections==[['Материал для создания и улучшения.']],'material has no recipe examples or quantities '+object.id.to_s)
    end
    check(materials.include?($data_items[21]) && materials.include?($data_items[49]),'junk and candy use the generic material description')
    forbidden=/Авто:|Авто выключено|Неприкосновенный|Лимит автоприменений|Только при состоянии:|Нулевой запас|Сч[её]тчики расхода|Назначение определяется|назначение определяется|Например:|уменьшается на общих границах|Уменьшается на общих границах|без остальных вещей и состояний|можно отменить|режим магазина с переключателем/
    objects.each do |object|
      [:ru,:en].each do |locale|
        rows=helper.description(object,actor,false,locale)
        check(rows.join !~ forbidden,'focused static description '+catalog.uid(object).to_s+locale.to_s)
      end
    end
    [21,49,88,9,113,148,82].each do |id|
      object=[113,148,82].include?(id) ? $data_armors[id] : $data_items[id]
      card=BS2QoL::PracticalCard.new(object,actor,:ru)
      check(card.sections.flatten.join !~ forbidden,'F7 removes service commentary '+catalog.uid(object).to_s)
    end
    text=helper.description($data_armors[113]).join(' ')
    check(text.include?('MaxMP ×0') && text.include?('кроме MP') && !text.include?('Конфета') && helper.description($data_armors[113]).size<=5,'Black Goat retains its actual bonuses and zero MP without shop prose')
    check(helper.description($data_armors[148]).join.include?('блокируется (100%)'),'God Fish keeps the important blocked-healing drawback in the mod reference')
    (9..16).each { |id| check(helper.description($data_items[id]).join.include?('Расходуется выбранное количество') && !helper.description($data_items[id]).join.include?('Не расходуется'),'colored soul consumption wording '+id.to_s) }
    formula=helper.formula_lines($data_skills[95]).join(' ')
    check(formula.include?(helper::USER+'ATK'+helper::RESET) && formula.include?(helper::TARGET+'DEF'+helper::RESET) && !formula.include?('Параметры:'),'formula roles use colors instead of a repeated legend')
    text=helper.plain(helper.formula_lines($data_skills[152]).join(' '))
    check(text.include?('HP (тек.) × 1 ÷ 4') && text.include?('ATK × 6 − DEF × 2'),'current HP and exact integer-division expression remain visible')
    [492,493].each do |id|
      text=helper.plain(helper.formula_lines($data_skills[id]).join(' '))
      check(text.include?('Урон HP:') && text.include?('% MaxHP × REC') && !text.include?('10 +') && !text.include?('За попадание: 10') && !text.include?('плюс — восстановление'),'percentage effect does not show a meaningless base ten or sign tutorial '+id.to_s)
    end
    check(!BS2Suite::IDS.include?('defeat') && !BS2Suite::IDS.include?('retry') && !BS2Suite.const_defined?(:Retry) && !BS2Suite.const_defined?(:DefeatCommands),'defeat and retry implementation removed while battle statistics remains')
    check(defined?(BS2Suite::BattleRecord) && !Scene_Gameover.method_defined?(:bs2suite_defeat_start),'original Game Over has no mod overlay')
    support=BS2Suite::BattleSupport
    Store=BS2Suite::Store unless defined?(Store)
    Store.write('battle_support','a|'+actor.id.to_s+"|item|4\n")
    Store.write('battle_support_rules','r|'+actor.id.to_s+"|4|99|1|0\n")
    support.reset
    check(!support.toggle_object(actor,$data_items[4]) && support.definitions.empty?,'outside-battle item enabling is unavailable')
    settings=BS2Suite::SettingsCommands.new(0,72)
    symbols=settings.instance_variable_get(:@list).map { |row| row[:symbol] };settings.dispose
    check(!symbols.include?(:automation) && !symbols.include?(:experimental_support) && !support.const_defined?(:Rules),'reserve/limit/default-enabling functions are absent')
    data=RPG::Enemy.new;data.id=5900;data.name='QA target';data.params=[50000000,100000,20,20,20,20,20,20];$data_enemies[data.id]=data
    troop=RPG::Troop.new;troop.id=5900;member=RPG::Troop::Member.new;member.enemy_id=data.id;troop.members=[member];$data_troops[troop.id]=troop
    BattleManager.setup(troop.id,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
    actor.force_change_equip(0,$data_weapons[409]);[95,492,493].each { |id| actor.learn_skill(id) };actor.recover_all;action(actor,492)
    @scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,@scene);@scene.start;@scene.start_actor_command_selection
    check(!support.active? && support.expand(actor).empty?,'battle starts without inheriting stored auto selections')
    $game_party.gain_item($data_items[4],6)
    check(support.toggle_object(actor,$data_items[4]) && support.active? && support.expand(actor)==[$data_items[4]],'only the manually selected item is enabled')
    check(support.available?(actor,$data_items[4]),'old reserve99 and limit1 files cannot restrict stock')
    4.times do |period|
      actor.on_action_end;actor.result.clear;actor.add_state(2);support.new_epoch(actor)
      plan=support.next_plan(actor);check(plan && plan[:object]==$data_items[4],'cleanse remains available beyond old spending limit '+period.to_s)
      actor.use_item(plan[:object]);plan[:object].repeats.times { actor.item_apply(actor,plan[:object]) };support.record(plan)
      check(!actor.state?(2),'native poison cleanse executes '+period.to_s)
    end
    check($game_party.item_number($data_items[4])==2,'four real cleanses consume exactly four items')
    check(support.toggle_object(actor,$data_items[4]) && !support.active?,'the same selected item can be disabled in battle')
    action(actor,492);@scene.start_actor_command_selection;@scene.command_item
    item_window=@scene.instance_variable_get(:@item_window);item_window.show.activate;item_window.openness=255
    item_window.select(item_window.instance_variable_get(:@data).index($data_items[4]))
    frame;frame([68])
    check(support.configured?(actor,$data_items[4]) && support.expand(actor)==[$data_items[4]],'real D input enables exactly the selected native item row')
    frame;frame([68])
    check(!support.configured?(actor,$data_items[4]),'real D input disables the same selected row')
    frame;@scene.on_item_cancel
    # Irrelevant resurrection on the outgoing attacker must not block corpse-dragon damage.
    passive=RPG::State.new;passive.id=5901;passive.name='QA revival';passive.note='<自動蘇生:100,0>';$data_states[passive.id]=passive;actor.add_state(passive.id)
    action(actor,492);BS2Suite::Options.data['knowledge_threshold']=0
    target=$game_troop.members[0];step=helper.context($data_skills[492],actor,nil,target)
    check(step && !step[:reason] && step[:hit_count]==5,'one corpse-dragon command has its actual five native hits even with attacker revival')
    text=helper.plain(BS2QoL::PracticalCard.new($data_skills[492],actor,:ru).compact_forecast.join(' '))
    check(text.include?('Попаданий: 5') && text.include?('≈') && !text.include?('Повторная атака с дополнительными') && !text.include?('Число попаданий всей серии'),'corpse-dragon reference has a usable forecast rather than the unrelated repeated-attack refusal')
    row=step[:rows].find { |r| r[:resource]=='HP' && r[:target_index]==target.index }
    16.times do |seed|
      user=BS2Suite::Projection.copy(actor);victim=BS2Suite::Projection.copy(target);user.pay_skill_cost($data_skills[492]);total=0
      srand(93500+seed)
      5.times { victim.result.clear;victim.item_apply(user,$data_skills[492]);total+=victim.result.hp_damage }
      check(row && total.between?(row[:min],row[:max]),'native five-hit corpse-dragon damage is within the forecast '+seed.to_s)
    end
    target.add_state(passive.id);target.hp=1;BS2Suite::Performance.bump
    unsafe=helper.context($data_skills[492],actor,nil,target)
    check(unsafe && unsafe[:reason] && unsafe[:rows].empty?,'possible recipient death/revival still refuses a fabricated full series')
    target.recover_all;actor.recover_all;actor.add_state(passive.id);action(actor,492)
    # Static/live previews preserve the real battle and random stream.
    before=Marshal.dump([actor,$game_party,$game_troop,$game_variables,$game_switches]);srand(55293);expected=rand;srand(55293)
    3.times { helper.preview(@scene,$data_skills[492],actor,nil,target,nil,true,true) }
    check(before==Marshal.dump([actor,$game_party,$game_troop,$game_variables,$game_switches]) && rand==expected,'focused preview preserves state, queue and RNG')
    actor.learn_skill(15);actor.hp=[actor.mhp/2,1].max;action(actor,15)
    values=helper.results($data_skills[15],actor,nil,nil,nil,false,true)
    recovery=helper.damage_lines(values,:ru,true).join(' ')
    check(!recovery.include?('≈ -') && !recovery.include?('≈ −') && recovery.include?(actor.name),'healing is shown as a positive gain for the named recipient')
    friend=Game_Actor.new(2)
    other=helper.results($data_skills[15],actor,nil,friend,nil,false,true)
    check(other[0][1][:reason] && other[0][1][:rows].empty?,'an unsupported ally target cannot reuse the caster healing number')
    actor.recover_all;action(actor,492)
    ids=[22,32,33,34,56,57,58,59,60,61];ids.each { |id| $game_party.gain_item($data_items[id],20) }
    entries=ids.each_with_index.map { |id,i| {'prefix'=>'B','group'=>1,'digit'=>(i+1)%10,'kind'=>'item','id'=>id,'source'=>0} }
    BS2Suite::Semantic.customs['u9993']={'name'=>'QA full group','groups'=>{},'entries'=>entries,'behaviors'=>{}}
    BS2Suite::Semantic.state['active'][actor.id.to_s]='u9993'
    BS2Suite::Palette.open(@scene,@scene.instance_variable_get(:@actor_command_window),actor,'B')
    popup=BS2Suite::Palette.current(@scene);popup.acknowledge;popup.set_group(1)
    check(popup.entries.size==10 && popup.visible_line_number==10 && popup.y+popup.height<=Graphics.height,'all ten native rows fit without the added description window')
    popup.select(9);BS2Suite::Palette.update_header(@scene);check(popup.entry[:digit]==0 && popup.top_row==0,'digit zero remains on screen with all other digits')
    if defined?(BS2Suite::HDDisplay)
      hd=BS2Suite::HDDisplay;check(hd.apply(hd::DEFAULT.merge('width'=>1280,'height'=>720)),'native HD compositor applies')
      5.times { frame }
      original=BS2Suite::SequenceForecast.instance_method(:initialize);$declutter_sequence_calls=0
      BS2Suite::SequenceForecast.send(:define_method,:initialize) { |*args| $declutter_sequence_calls+=1;original.bind(self).call(*args) }
      helper.instance_variable_set(:@results,{});times=[]
      30.times do |i|
        popup.select(i%10);started=BS2Suite::Performance.now;rows=hd.palette_rows(popup);times<<((BS2Suite::Performance.now-started)&0xffffffff)
        check(rows.count { |row| row.start_with?("K\t","P\t") }==10,'HD keeps all ten commands during navigation '+i.to_s)
      end
      check($declutter_sequence_calls==0,'rapid selection starts no sequence forecasts')
      log('navigation_ms='+times.inspect)
      popup.select(9);hd.palette_rows(popup);helper.instance_variable_set(:@waiting_at,(BS2Suite::Performance.now-200)&0xffffffff)
      rows=hd.palette_rows(popup);count=$declutter_sequence_calls
      hd.palette_rows(popup)
      check(count>0 && $declutter_sequence_calls==count,'settled selection computes once and reuses the completed result')
      composite('declutter-hd-full-group.png')
      BS2Suite::Palette.close(@scene)
      action(actor,95);@scene.command_skill
      list=@scene.instance_variable_get(:@skill_window);list.stype_id=$data_skills[95].stype_id;list.refresh;list.show.activate;list.openness=255
      list.select(list.instance_variable_get(:@data).index($data_skills[95]));hd.poll(true)
      helper.instance_variable_set(:@waiting_at,(BS2Suite::Performance.now-200)&0xffffffff)
      check(hd.battle_rows(@scene).select { |r| r.start_with?("S\t") }.all? { |r| hd.measure(r.split("\t",2)[1])<=hd.text_width },'all wrapped formula rows fit the actual HD text width')
      pixels,w,h=composite('declutter-hd-formula.png');geometry=hd.geometry;blue=red=0
      h.times do |y|
        (geometry[6]...w).each do |x|
          offset=(y*w+x)*4;b,g,r=pixels[offset,3].bytes.to_a
          blue+=1 if [r,g,b]==[218,234,250];red+=1 if [r,g,b]==[250,224,224]
        end
      end
      check(blue>5 && red>5,'actual GPU composite contains both subtle formula-role colors')
      check(hd.measure(formula)==hd.measure(helper.plain(formula)),'color markers occupy no HD glyph width')
      log('gpu_role_pixels='+[blue,red].inspect)
    else
      canvas('declutter-native-full-group.png');BS2Suite::Palette.close(@scene)
      window=Window_BS2QReference.new($data_skills[95],actor)
      names=window.card.section_names;section=names.index('По целям') || names.index('Формула');window.instance_variable_set(:@section,section);window.refresh
      canvas('declutter-native-formula.png');window.dispose
    end
    @scene.terminate;$game_party.on_battle_end
    check(!support.active? && support.definitions.empty?,'battle end forgets all item enabling')
    log('result=PASS; checks='+@checks.to_s+'; native_descriptions='+objects.size.to_s+'; materials='+materials.size.to_s)
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure;BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge);end
end
