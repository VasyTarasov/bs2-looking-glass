# encoding: UTF-8
rgss_main do
load 'BS2QA_native_capture.rb'
@checks=0
def log(t);File.open('test_result.txt','a') { |f| f.puts t };end
def check(v,t);raise t unless v;@checks+=1;log('PASS '+t);end
def card(x,a=nil);BS2QoL::PracticalCard.new(x,a,:ru);end
def text(x,a=nil);card(x,a).sections.flatten.join(' ');end
def capture(path)
  Graphics.transition(0);Graphics.brightness=255
  if defined?(BS2Suite::HDDisplay) && BS2Suite::HDDisplay.active?
    hd=BS2Suite::HDDisplay;hd.poll(true)
    read=Win32API.new('Mods/BS2Suite/native/bs2_steam_bridge.dll','BS2_HDReadback',['P','I'],'I');read.call('',0)
    w,h=hd.status[6,2];pixels=("\0"*(w*h*4)).force_encoding('ASCII-8BIT');size=0
    90.times { Graphics.update;size=read.call(pixels,pixels.bytesize);break if size==pixels.bytesize }
    check(size==pixels.bytesize,'HD reference frame readback')
    header=[40,w,-h,1,32,0,pixels.bytesize,0,0,0,0].pack('LllSSLLLLLL')
    File.open(path,'wb') { |f| f.write('BM'+[54+pixels.bytesize,0,54].pack('L3')+header+pixels) }
  else
    4.times { Graphics.update };SuiteCapture.save(path)
  end
end
begin
  File.open('test_result.txt','w') { |f| f.puts 'reference098 native '+RUBY_VERSION }
  DataManager.init;DataManager.setup_new_game
  SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
  actor=$game_actors[1];actor.change_class(1);actor.change_level(70,false);actor.clear_equipments;actor.recover_all
  db=BS2Suite::Reference098
  check(db.size==2401,'compact source view contains every action, item, equipment and state ID')
  counts={};ordered=['Применение','Эффекты','Особенности','Расчёт','По целям']
  snapshot=Marshal.dump([actor,$game_party.instance_variable_get(:@items),$game_party.instance_variable_get(:@weapons),$game_party.instance_variable_get(:@armors)])
  srand(9831);expected=rand;srand(9831)
  [[:skill,$data_skills],[:item,$data_items],[:weapon,$data_weapons],[:armor,$data_armors]].each do |kind,list|
    counts[kind]=0
    list.compact.reject { |o| o.name.to_s.empty? }.each do |o|
      c=card(o);flat=c.sections.flatten.join(' ');counts[kind]+=1
      check(db.get(o) && !BS2Suite::ShortNotes.describe(o).empty?,'covered '+kind.to_s+':'+o.id.to_s)
      check(!c.sections.empty? && c.sections.all? { |ls| !ls.empty? },'nonempty sections '+kind.to_s+':'+o.id.to_s)
      check(flat.valid_encoding? && flat !~ /<[^>]*(?:クールタイム|ダメージ率|ステート)/,'clean UTF8 '+kind.to_s+':'+o.id.to_s)
      if kind==:skill
        indices=c.section_names.map { |n| ordered.index(n) }.compact
        check(indices==indices.sort && !c.section_names.include?('По целям'),'journal-safe ordered action '+o.id.to_s)
        check(o.damage.none? || flat.include?(o.damage.formula.to_s.strip),'formula preserved '+o.id.to_s)
      end
    end
  end
  check(counts=={:skill=>990,:item=>246,:weapon=>371,:armor=>241},'all named records covered, including enemy-only actions')
  $data_skills.compact.select { |o| o.name.to_s.empty? }.each do |o|
    check(!card(o).title.to_s.empty? && !card(o).sections.empty?,'unnamed service action remains inspectable '+o.id.to_s)
  end
  check(Marshal.dump([actor,$game_party.instance_variable_get(:@items),$game_party.instance_variable_get(:@weapons),$game_party.instance_variable_get(:@armors)])==snapshot,'reading whole reference preserves actor and inventory')
  check(rand==expected,'reading whole reference does not advance RNG')
  t=text($data_skills[14]);check(t.include?('Свет') && t.include?('Магический') && t.include?('a.mat * 5 - b.mdf * 2'),'Soul Arrow element hit-type and formula')
  t=text($data_skills[100]);check(t.include?('без вычитания ЗАЩ') && t.include?('Guard на 100%') && t.include?('не игнорирует сопротивление'),'Armor Pierce separates DEF, Guard and inactive PDR tag')
  t=text($data_skills[874]);check(t.include?('a.atk * 6 - b.def * 0.5') && t.include?('Ганблэйд Огн.') && t.include?('Смена Патрона'),'Cross Section preserves actual formula followup and variants')
  t=text($data_armors[82]);check(t.include?('0,64') || t.include?('0.64'),'Steel Protection compounded reduction')
  t=text($data_armors[232]);check(t.include?('×9') && t.include?('Регенерации MP') && t.include?('2–2'),'Indomitable state and duration without invented MP regeneration')
  if defined?(BS2Modules::Effects)
    $game_party.gain_item($data_armors[232],1);slot=actor.equip_slots.index(4);actor.change_equip(slot,$data_armors[232])
    source=BS2Modules::Effects.sources(actor).find { |r| r[:name]==BS2Modules.label($data_armors[232]) }
    check(source[:details].join.include?('×9') && !source[:details].join.include?('ЗАЩ+900%'),'equipment effect inspection also removes conflicting original description')
    actor.add_state(45);entry=BS2Modules::Effects.active(actor).find { |r| r[:kind]==:state && r[:id]==45 }
    check(entry[:details].join.include?('Крит 30 п.п.'),'active effect inspection uses verified state properties with live duration')
    actor.clear_states;actor.change_equip(slot,nil);actor.recover_all
  end
  t=text($data_skills[838]);check(t.include?('нулевых MP') && t.include?('0 урона'),'zero MP resentment exception')
  check(text($data_items[35]).include?('50 за предмет') && text($data_items[72]).include?('250000 за предмет'),'currency amounts compiled from exact common-event commands')
  check(BS2Suite::ShortNotes.describe($data_items[9]).include?('20') && BS2Suite::ShortNotes.describe($data_skills[32]).include?('всей группы'),'colored souls and group cooldown short notes')
  help=Window_Help.new;help.set_item($data_skills[100])
  check(help.instance_variable_get(:@text).include?('без вычитания ЗАЩ') && help.instance_variable_get(:@text).include?('F7'),'native help uses verified summary and preserves F7 hint');help.dispose
  help=Window_Help.new;collection=Window_BS2QCollection.new(0,72,640,300)
  collection.instance_variable_set(:@data,[$data_skills[40]]);collection.help_window=help;collection.select(0);collection.update_help
  check(help.instance_variable_get(:@text).include?(db.brief($data_skills[40])),'favorites also describe service entries without original descriptions');collection.dispose;help.dispose
  t=text($data_skills[14]);check(t.include?('крит ×3 сейчас'),'critical factor is read from active difficulty table')
  t=text($data_skills[593]);check(t.include?('проверка №2') && !t.include?('задержка 1 +'),'delay explains check-before-decrement off-by-one')
  # An unobserved creature never receives an AI catalogue through the UI view.
  enemy=Game_Enemy.new(0,1)
  check(db.get(enemy).nil? && db.by_id(:enemy,1).nil?,'runtime view contains no enemy strategy or drop table')
  if BS2Suite.enabled?('semantic_groups')
    BS2Suite::Options.set('knowledge_threshold',5)
    c=card(enemy);check(c.sections.flatten.join.include?('ещё неизвестны'),'existing encounter secrecy survives new data')
    BS2Suite::Options.set('knowledge_threshold',0)
    $game_party.gain_item($data_weapons[391],1);actor.change_equip(0,$data_weapons[391]);actor.learn_skill(14)
    c=card($data_skills[14],actor)
    check(c.sections.flatten.join.include?('12 MP') && c.actor.mat==actor.mat,'live MP multiplier still used, not static base cost')
  end
  # Open the real journal modal, not just a detached action constructor.
  troop=RPG::Troop.new;troop.id=79;member=RPG::Troop::Member.new;member.enemy_id=1;member.x=300;member.y=200;troop.members=[member];$data_troops[79]=troop
  BattleManager.setup(79,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
  enemy=$game_troop.members[0];actor.make_actions;BattleManager.instance_variable_set(:@actor_index,0)
  $game_temp.cool_time[actor][14]=5;$game_temp.cool_time[enemy][14]=7
  BattleManager.turn_end
  check($game_temp.cool_time[actor][14]==4 && $game_temp.cool_time[enemy][14]==6,'cooldown tick affects both sides at common battle turn end')
  @scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,@scene);@scene.start
  if defined?(BS2Suite::HDDisplay)
    BS2Suite::HDDisplay.apply(BS2Suite::HDDisplay::DEFAULT)
    90.times { Graphics.update;Input.update;break if BS2Suite::HDDisplay.active? }
    check(BS2Suite::HDDisplay.active?,'HD display is actually active for reference QA')
  end
  BS2Suite::CombatJournal.append(enemy,$data_skills[58],actor,nil)
  origin=@scene.instance_variable_get(:@actor_command_window);origin.openness=255
  check(BS2Suite::CombatJournal.open(@scene,origin),'real journal opens')
  BS2Suite::CombatJournal.details(@scene)
  popup=@scene.instance_variable_get(:@bs2q_reference_window)
  check(popup.card.object==$data_skills[58] && popup.card.actor.nil? && popup.card.sections.flatten.join.include?('a.atk * 3 - b.def * 2'),'journal F7 opens enemy-only action without hero projection')
  check(!popup.card.section_names.include?('По целям'),'journal does not invent historical target forecast')
  capture('BS2QA_reference_enemy.bmp')
  BS2QoL::Reference.close(@scene);BS2Suite::CombatJournal.close(@scene)
  # Standard reference window wrapping: no title or section is silently absent.
  popup=Window_BS2QReference.new($data_skills[874],nil)
  @scene.instance_variable_set(:@bs2q_reference_window,popup)
  popup.card.sections.each_with_index do |ls,i|
    popup.instance_variable_set(:@section,i);popup.refresh
    check(popup.lines.all? { |s| popup.text_size(s).width<=popup.contents.width-8 },'wrapped lines fit section '+i.to_s)
  end
  popup.instance_variable_set(:@section,0);popup.refresh;capture('BS2QA_reference_use.bmp');popup.dispose
  @scene.instance_variable_set(:@bs2q_reference_window,nil)
  @scene.terminate;$game_party.on_battle_end
  log('result=PASS; checks='+@checks.to_s)
rescue Exception=>e
  log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
ensure
  SuiteCapture.close
end
end
