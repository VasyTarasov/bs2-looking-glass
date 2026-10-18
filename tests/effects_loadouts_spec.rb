# encoding: UTF-8
@checks=0
module Input
  class << self
    attr_accessor :spec_key
    def trigger?(key);@spec_key==key;end
    def repeat?(key);@spec_key==key;end
    def press?(key);@spec_key==key;end
  end
end
def log(text);File.open('test_result.txt','a') { |f| f.puts text };end
def check(value,label);raise 'Assertion: '+label unless value;@checks+=1;log('PASS '+label);end
def snapshot(actor)
  cooldowns=$game_temp.instance_variable_get(:@cool_time).map { |b,h| [b.actor? ? b.id : b.index,h.to_a.sort] }
  Marshal.dump([actor,$game_party.instance_variable_get(:@items),$game_party.instance_variable_get(:@weapons),$game_party.instance_variable_get(:@armors),cooldowns])
end
def capture(name)
  bitmap=Graphics.snap_to_bitmap
  raw=''.force_encoding('ASCII-8BIT')
  bitmap.height.times do |y|
    raw << "\0"
    bitmap.width.times do |x|
      c=bitmap.get_pixel(x,y);raw << [c.red.to_i,c.green.to_i,c.blue.to_i,c.alpha.to_i].pack('C4')
    end
  end
  chunk=lambda { |tag,data| [data.bytesize].pack('N')+tag+data+[Zlib.crc32(tag+data)].pack('N') }
  png="\x89PNG\r\n\x1a\n".force_encoding('ASCII-8BIT')+chunk.call('IHDR',[bitmap.width,bitmap.height,8,6,0,0,0].pack('NNCCCCC'))+chunk.call('IDAT',Zlib::Deflate.deflate(raw))+chunk.call('IEND','')
  File.open(name,'wb') { |f| f.write(png) };bitmap.dispose
end
def key(value,window)
  Input.spec_key=value;window.update;Input.spec_key=nil
end
begin
  File.open('test_result.txt','w') { |f| f.puts 'ruby='+RUBY_VERSION }
  DataManager.init;DataManager.setup_new_game
  Window_MenuCommand.init_command_position
  actor=$game_party.members[0];actor.change_class(1);actor.change_level(30,false);actor.name='Гримм'
  SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(Graphics.width,Graphics.height))
  check(defined?(BS2Modules::LOADED),'modules load on native Ruby')
  load 'Mods/BS2Suite/main.rb'
  check(BS2Modules::VERSION=='0.7.1-alpha','bootstrap idempotent')
  menu=Window_MenuCommand.new
  commands=menu.instance_variable_get(:@list).map { |x| x[:symbol] }
  check(commands.include?(:bs2modules_effects)==BS2Modules.enabled?('effects'),'effects menu selection independent')
  check(commands.include?(:bs2modules_loadouts)==BS2Modules.enabled?('loadouts'),'loadouts menu selection independent')
  menu.dispose
  check(!!defined?(BS2Modules::Effects)==BS2Modules.enabled?('effects'),'disabled effects code not loaded')
  check(!!defined?(BS2Modules::Loadouts)==BS2Modules.enabled?('loadouts'),'disabled loadouts code not loaded')
  $game_party.gain_item($data_weapons[384],1);actor.change_equip(0,$data_weapons[384])
  if BS2Modules.enabled?('effects')
    effects=BS2Modules::Effects
    [2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,86].each { |id| actor.add_state(id) }
    unless actor.state?(86)
      actor.add_new_state(86);actor.reset_state_counts(86)
    end
    # Native fixture includes iconless states, parameter changes, cooldown and
    # quick-action usage. Direct counters represent a known mid-combat snapshot.
    actor.add_buff(2,3);actor.add_debuff(3,2)
    $game_temp.cool_time[actor][14]=3
    actor.instance_variable_set(:@hzm_vxa_quickSkill_can_use_skill,[95])
    counts=$game_temp.instance_variable_get(:@cool_time)
    before=snapshot(actor);keys_before=counts.keys.size
    srand(1541);expected=rand;srand(1541)
    rows=effects.active(actor);sources=effects.sources(actor)
    check(rand==expected,'effect reads preserve RNG')
    check(snapshot(actor)==before,'effect model preserves actor, inventory, counters')
    check(counts.keys.size==keys_before,'cooldown inspection does not insert default hash keys')
    state_ids=actor.states.map { |s| s.id }
    check(rows.select { |r| r[:kind]==:state }.map { |r| r[:id] }==state_ids,'every active state listed in engine order')
    check(rows.any? { |r| r[:id]==86 && r[:name].include?('86') },'unnamed iconless state remains visible')
    check(rows.any? { |r| r[:kind]==:buff && r[:id]==2 } && rows.any? { |r| r[:kind]==:buff && r[:id]==3 },'buff and debuff included')
    check(rows.any? { |r| r[:kind]==:cooldown && r[:id]==14 },'active cooldown included')
    check(sources.any? { |r| r[:name]==$data_weapons[384].name },'equipped weapon effects have exact source')
    # Exhaustively render all current database feature codes and state notes.
    check($data_states.compact.all? { |s| s.features.all? { |f| effects.feature(f).is_a?(String) } && effects.special(s).is_a?(Array) },'all database state traits and notes render')
    panel=BS2Modules::EffectsPanel.new(actor)
    check(panel.list.item_max>6,'long effect list exceeds icon bar without truncation')
    panel.list.select(panel.list.item_max-1);panel.update
    check(panel.list.top_row>0,'last effect is reachable by scrolling')
    key(:RIGHT,panel)
    check(panel.tab==1 && panel.list.rows.any? { |r| r[:kind]==:source },'source section opens with right arrow')
    key(:LEFT,panel)
    key(:C,panel)
    check(panel.detail.active && !panel.list.active,'Enter focuses independently scrollable details')
    key(:B,panel)
    check(panel.list.active && !panel.closed,'Escape returns from detail to list')
    panel.list.select(0);panel.update;Graphics.update
    capture('effects.png')
    panel.dispose
    actor.clear_states;actor.clear_buffs
    BattleManager.setup(5,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
    actor.make_actions
    scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,scene)
    scene.start
    BattleManager.instance_variable_set(:@actor_index,0)
    command=scene.instance_variable_get(:@actor_command_window);command.setup(actor)
    symbols=command.instance_variable_get(:@list).map { |x| x[:symbol] }
    check(symbols.include?(:bs2modules_effects),'effects command available in battle')
    check(!symbols.include?(:bs2modules_loadouts),'loadout application absent from battle')
    before=snapshot(actor);actions=actor.actions.object_id
    class << Input
      attr_accessor :modal_test,:modal_frames
      alias bs2modules_test_update update
      def update
        bs2modules_test_update
        if @modal_test
          @modal_frames=(@modal_frames || 0)+1
          @spec_key=(@modal_frames>=20 ? :B : nil)
        end
      end
    end
    Input.modal_test=true;Input.modal_frames=0
    srand(161);expected=rand;srand(161)
    scene.bs2modules_effects
    Input.modal_test=false;Input.spec_key=nil
    check(rand==expected,'modal battle panel consumes no combat RNG')
    check(snapshot(actor)==before && actor.actions.object_id==actions,'modal battle panel preserves state, ATB and queue')
    check(command.active,'closing effects resumes command entry')
    scene.terminate
    $game_party.on_battle_end
    SceneManager.instance_variable_set(:@scene,nil)
  end
  if BS2Modules.enabled?('loadouts')
    sets=BS2Modules::Loadouts
    actor.clear_states;actor.clear_buffs
    # Select equippable, ordinary armors from this real translated database.
    armor_slots=sets.slots(actor)
    check(actor.equip_slots==[0,1,2,3,4,4,4,4],'actual shield, head, body, four ring slots verified')
    armor_slots.each { |i| actor.change_equip(i,nil) }
    chosen={}
    [1,2,3,4].each do |type|
      choices=$data_armors.compact.select { |a| a.etype_id==type && actor.equippable?(a) && a.features.none? { |f| [51,52,53,54,55].include?(f.code) } }
      check(choices.size>=2,'real equipment fixtures available for type '+type.to_s)
      chosen[type]=choices[0,2]
      chosen[type].each { |a| $game_party.gain_item(a,10) }
    end
    armor_slots.each { |i| actor.change_equip(i,chosen[actor.equip_slots[i]][0]) }
    weapon=actor.equips[0]
    check(sets.save(actor,1,'Защита'),'named loadout persisted')
    set=sets.get(actor,1)
    check(!set[:slots].has_key?(0) && set[:slots].size==7,'weapon excluded, all defensive slots captured')
    sets.instance_variable_set(:@data,nil)
    check(sets.get(actor,1)[:name]=='Защита','Cyrillic names survive restart of profile store')
    check(sets.rename(actor,1,'Тест защиты'),'rename persists')
    armor_slots.each { |i| actor.change_equip(i,chosen[actor.equip_slots[i]][1]) }
    set=sets.get(actor,1)
    before=snapshot(actor);srand(434);expected=rand;srand(434)
    result=sets.preview(actor,set)
    check(result[:ok],'full loadout preflight accepts available equipment')
    check(snapshot(actor)==before && rand==expected,'preview does not mutate party, actor or RNG')
    check(result[:target][0]==weapon && result[:before].size==8,'preview preserves weapon and calculates all parameter deltas')
    # Count every armor, both carried and equipped, to catch duplication/loss.
    totals=lambda { $data_armors.compact.map { |a| $game_party.item_number(a)+actor.equips.count(a) } }
    inventory=totals.call
    check(sets.apply(actor,set)[:ok],'complete loadout applies through native equip path')
    check(totals.call==inventory && actor.equips[0]==weapon,'all item counts and weapon preserved')
    check(sets.apply(actor,set)[:ok] && totals.call==inventory,'reapplying same loadout is idempotent')
    swapped=BS2Modules.clone(set)
    ring_slots=sets.slots(actor).select { |i| actor.equip_slots[i]==4 }
    swapped[:slots][ring_slots[0]][1]=chosen[4][1].id
    check(sets.apply(actor,swapped)[:ok],'set with distinct ring types applies')
    swapped[:slots][ring_slots[0]],swapped[:slots][ring_slots[1]]=swapped[:slots][ring_slots[1]],swapped[:slots][ring_slots[0]]
    inventory=totals.call
    check(sets.apply(actor,swapped)[:ok] && totals.call==inventory,'ring permutation preserves quantities')
    check(sets.apply(actor,set)[:ok],'original set restores after ring permutation')
    # Native equipment-lock trait must remain authoritative.
    lock=$data_states.compact.find { |s| s.features.any? { |f| f.code==53 && f.data_id==1 } }
    if lock
      actor.add_new_state(lock.id);actor.reset_state_counts(lock.id)
      locked=BS2Modules.clone(set);locked[:slots][1][1]=0
      before=snapshot(actor)
      check(!sets.apply(actor,locked)[:ok] && snapshot(actor)==before,'native locked slot blocks complete loadout')
      actor.remove_state(lock.id)
    else
      # The current database has no state with this trait. Use a native trait
      # fixture, not a different implementation of equip_change_ok?.
      state=RPG::State.new;state.id=$data_states.size
      state.features << RPG::BaseItem::Feature.new(53,1,0)
      $data_states << state;actor.add_new_state(state.id);actor.reset_state_counts(state.id)
      locked=BS2Modules.clone(set);locked[:slots][1][1]=0
      before=snapshot(actor)
      check(!sets.apply(actor,locked)[:ok] && snapshot(actor)==before,'native locked slot blocks complete loadout')
      actor.remove_state(state.id);$data_states.pop
    end
    # Insufficient copies must leave every slot untouched.
    ring=chosen[4][0]
    actor.equip_slots.each_index { |i| actor.change_equip(i,nil) if actor.equip_slots[i]==4 }
    $game_party.lose_item(ring,999)
    before=snapshot(actor)
    check(!sets.apply(actor,set)[:ok] && snapshot(actor)==before,'missing duplicate rings reject entire set without changes')
    $game_party.gain_item(ring,10)
    $game_party.instance_variable_set(:@in_battle,true);before=snapshot(actor)
    check(!sets.apply(actor,set)[:ok] && snapshot(actor)==before,'battle loadout application rejected by model')
    check(!sets.save(actor,2),'battle profile capture refused')
    $game_party.instance_variable_set(:@in_battle,false)
    bad=BS2Modules.clone(set);bad[:slots][1]=[4,ring.id]
    before=snapshot(actor)
    check(!sets.apply(actor,bad)[:ok] && snapshot(actor)==before,'changed slot types rejected atomically')
    bad=BS2Modules.clone(set);bad[:slots][1]=[1,99999]
    check(!sets.apply(actor,bad)[:ok] && snapshot(actor)==before,'unknown item ID rejected without changes')
    parsed=sets.parse("[actor.1.set.1]\nname=Safe\nslot=0,0,1\nslot=1,1,9\nexec=bad\n[unknown]\nslot=2,2,2\n")
    check(parsed[[1,1]][:slots]=={1=>[1,9]},'profile parser rejects weapons and unknown sections')
    # Explicit empty slots are part of the set, not ignored.
    empty=BS2Modules.clone(set);empty[:slots].keys.each { |i| empty[:slots][i][1]=0 }
    check(sets.apply(actor,empty)[:ok] && actor.equips[1..-1].all? { |x| x.nil? },'empty slots unequip and return items')
    check(sets.apply(actor,set)[:ok],'saved set can be restored after clearing slots')
    old=$game_party.item_number(ring)
    $game_party.gain_item(ring,$game_party.max_item_number(ring))
    before=snapshot(actor)
    check(!sets.apply(actor,empty)[:ok] && snapshot(actor)==before,'full inventory cannot discard returned equipment')
    $game_party.lose_item(ring,$game_party.item_number(ring)-old)
    # Inject a genuine failure only during commit; preflight succeeds on clone.
    class Game_Actor
      alias bs2modules_test_change_equip change_equip
      def change_equip(index,item)
        if equal?($bs2modules_commit_fault) && index==2
          raise 'Injected commit failure'
        end
        bs2modules_test_change_equip(index,item)
      end
    end
    $bs2modules_commit_fault=actor;before=snapshot(actor)
    fault_result=sets.apply(actor,empty)
    unless !fault_result[:ok] && snapshot(actor)==before
      log('fault_result='+fault_result.inspect)
      log('actor_vars='+actor.instance_variables.inspect)
      File.open('rollback_before.bin','wb') { |f| f.write(before) }
      File.open('rollback_after.bin','wb') { |f| f.write(snapshot(actor)) }
    end
    check(!fault_result[:ok] && snapshot(actor)==before,'unexpected mid-commit failure rolls back actor and inventory')
    $bs2modules_commit_fault=nil
    SceneManager.instance_variable_set(:@scene,nil)
    scene=BS2Modules::LoadoutsScene.new;SceneManager.instance_variable_set(:@scene,scene);scene.start
    scene.instance_variable_get(:@list).select(0);scene.show_detail
    Graphics.update;capture('loadouts.png')
    scene.actions;scene.request(:save)
    check(scene.instance_variable_get(:@confirm).index==0,'overwrite confirmation defaults to cancel')
    scene.back_list;scene.actions;scene.request(:rename)
    check(scene.instance_variable_get(:@name_edit).name=='Тест защиты','native Russian name editor opens without changing actor name')
    Graphics.update;capture('rename.png')
    scene.cancel_name;scene.terminate
    check(actor.name=='Гримм','profile naming leaves character name intact')
    check(sets.delete(actor,1) && sets.get(actor,1).nil?,'delete persists without touching equipment')
    class << BS2Modules;alias qa_real_write_text write_text;def write_text(*args);false;end;end
    before=BS2Modules.clone(sets.data)
    check(!sets.save(actor,1,'Не записано') && sets.data==before,'write failure preserves previous in-memory profile')
    class << BS2Modules;alias write_text qa_real_write_text;end
  end
  # The engine serializes only its original game objects. New settings live in INI.
  contents=DataManager.make_save_contents
  raw=Marshal.dump(contents)
  check(!raw.include?('BS2Modules'),'saved game format contains no module class or module instance variable')
  File.open('qa_game_content.bin','wb') { |f| f.write(raw) }
  log('result=PASS; checks='+@checks.to_s+'; qol='+defined?(BS2QoL::LOADED).to_s)
rescue Exception => error
  log('result=FAIL; '+error.class.to_s+': '+error.message)
  log(error.backtrace.join("\n"))
end
exit
