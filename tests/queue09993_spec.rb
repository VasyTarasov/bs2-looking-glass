# encoding: UTF-8
rgss_main do
  load 'BS2QA_native_capture.rb'
  @checks=0
  def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
  def check(v,s);raise s unless v;@checks+=1;log('PASS '+s);end
  def queue(a,n=3)
    a.instance_variable_set(:@actions,Array.new(n) { Game_Action.new(a) })
    a.instance_variable_set(:@action_input_index,0)
    BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
  end
  def row(kind,id=0,source=0,target=0);{'kind'=>kind,'id'=>id,'source'=>source,'target'=>target};end
  def set(rows);{'name'=>'QA','key'=>1,'rows'=>rows};end
  def tick(scene,n=40)
    scene.instance_variable_get(:@actor_command_window).openness=255
    n.times { Graphics.update;Input.update;scene.instance_variable_get(:@actor_command_window).update;BS2Suite::BattleSupport.tick(scene) }
  end
  def capture_scene(path,source=nil)
    bitmap=source ? source.clone : Graphics.snap_to_bitmap;raw=''.force_encoding('ASCII-8BIT')
    bitmap.height.times do |y|
      raw << "\0"
      bitmap.width.times do |x|
        c=bitmap.get_pixel(x,y);raw << [c.red.to_i,c.green.to_i,c.blue.to_i,c.alpha.to_i].pack('C4')
      end
    end
    chunk=lambda { |tag,data| [data.bytesize].pack('N')+tag+data+[Zlib.crc32(tag+data)].pack('N') }
    png="\x89PNG\r\n\x1a\n".force_encoding('ASCII-8BIT')+chunk.call('IHDR',[bitmap.width,bitmap.height,8,6,0,0,0].pack('NNCCCCC'))+chunk.call('IDAT',Zlib::Deflate.deflate(raw))+chunk.call('IEND','')
    File.open(path,'wb') { |f| f.write(png) };bitmap.dispose
  end
  class Keys09993
    def down;[];end
    def focused?;true;end
  end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'queue/forecast regressions '+BS2Suite::VERSION }
    DataManager.init;DataManager.setup_new_game
    actor=$game_party.leader;actor.change_class(1);actor.change_level(70,false);actor.clear_equipments
    [101,277,391].each { |id| $game_party.gain_item($data_weapons[id],1) }
    actor.change_equip(0,$data_weapons[101]);actor.recover_all
    SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
    troop=RPG::Troop.new;troop.id=79
    enemy=RPG::Enemy.new;enemy.id=5000;enemy.name='QA';enemy.battler_name='';enemy.params=[1000000,100,50,30,50,30,50,50];$data_enemies[5000]=enemy
    member=RPG::Troop::Member.new;member.enemy_id=5000;member.x=300;member.y=180;troop.members=[member];$data_troops[79]=troop
    BattleManager.setup(79,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
    actor.instance_variable_set(:@ap,ATB::MAX_AP);queue(actor)
    scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,scene);scene.start
    BS2QoL::Keyboard.backend=Keys09993.new;BS2QoL::Keyboard.reset
    BS2Suite::Options.set('knowledge_threshold',0)
    support=BS2Suite::BattleSupport;support.instance_variable_set(:@master,false)
    target=$game_troop.members[0];object=$data_skills[actor.attack_skill_id];actor.learn_skill(object.id)
    $game_party.gain_item($data_items[61],30)
    which=File.file?('qa_case.txt') ? File.read('qa_case.txt').strip : 'all'
    if ['all','A1'].include?(which)
      enemy.features << RPG::BaseItem::Feature.new(12,3,0)
      enemy.features << RPG::BaseItem::Feature.new(12,5,0)
      $game_party.gain_item($data_items[105],20)
      support.reset;support.instance_variable_set(:@definitions,[{'actor'=>actor.id,'kind'=>'item','id'=>105}]);support.instance_variable_set(:@master,true)
      queue(actor);scene.start_actor_command_selection
      before=$game_party.item_number($data_items[105]);tick(scene)
      check(before-$game_party.item_number($data_items[105])==1,'A1 failed automatic item spends exactly once')
      3.times do
        actor.actions[0].set_guard;actor.instance_variable_set(:@action_input_index,1)
        BS2Suite::QueueEdit.cancel(scene,actor);tick(scene)
      end
      check(before-$game_party.item_number($data_items[105])==1,'A1 full cancellations preserve failed-attempt history')
      actor.actions[0].set_guard;actor.actions[1].set_guard;actor.instance_variable_set(:@action_input_index,2)
      scene.instance_variable_set(:@bs20999_cancel_time,nil);scene.prior_command;scene.prior_command;tick(scene)
      check(before-$game_party.item_number($data_items[105])==1,'A1 actual single and double Esc do not retry a failed item')
      actor.make_actions;queue(actor);scene.start_actor_command_selection;tick(scene)
      check(before-$game_party.item_number($data_items[105])==1,'A1 action-array regeneration alone is not a new opportunity')
      # Native paid-series completion resets AP. The next ready input is a new period.
      actor.on_action_end;actor.instance_variable_set(:@ap,ATB::MAX_AP);queue(actor);scene.start_actor_command_selection;tick(scene)
      check(before-$game_party.item_number($data_items[105])==2,'A1 real ATB series completion permits one new failed attempt')
      HZM_VXA::QuickSkill.start
      actor.on_action_end
      HZM_VXA::QuickSkill.finish
      actor.instance_variable_set(:@ap,ATB::MAX_AP);queue(actor);scene.start_actor_command_selection;tick(scene)
      check(before-$game_party.item_number($data_items[105])==2,'A1 quick-action context never resets attempt history')
      support.reset;support.instance_variable_set(:@definitions,[{'actor'=>actor.id,'kind'=>'item','id'=>61}]);support.instance_variable_set(:@master,true)
      actor.remove_all_buffs;queue(actor);scene.start_actor_command_selection
      before=$game_party.item_number($data_items[61]);tick(scene)
      log('A1_success_spent='+(before-$game_party.item_number($data_items[61])).to_s+' buff='+actor.instance_variable_get(:@buffs)[2].to_s+' ap='+actor.ap.to_s+' active='+support.active?.to_s+' input='+(actor.input && actor.input.item).inspect)
      check(before-$game_party.item_number($data_items[61])==2 && actor.instance_variable_get(:@buffs)[2]==2,'A1 successful automatic item still reaches two buff levels')
      support.instance_variable_set(:@master,false);actor.remove_all_buffs
    end
    if ['all','A2'].include?(which)
      queue(actor);check(!BS2Suite::Macros.commit(scene,actor,set([row('item',61),row('skill',object.id)]),0),'A2 real macro commits')
      actor.instance_variable_set(:@action_input_index,0)
      live=Marshal.dump([actor.hp,actor.mp,actor.tp,actor.equips,actor.instance_variable_get(:@states),actor.instance_variable_get(:@buffs),$game_party.instance_variable_get(:@items)])
      srand(9321);expected=rand;srand(9321)
      full=BS2Suite::SequenceForecast.new(actor).steps[0]
      step=BS2Suite::ForecastContext.step(object,actor,nil,target,nil,true)
      check(full[:rows].any? && step[:rows]==full[:rows],'A2 selected-action forecast preserves attached preparation')
      check(rand==expected,'A2 forecasts preserve RNG')
      check(live==Marshal.dump([actor.hp,actor.mp,actor.tp,actor.equips,actor.instance_variable_get(:@states),actor.instance_variable_get(:@buffs),$game_party.instance_variable_get(:@items)]),'A2 forecasts preserve live inventory equipment and battler state')
      alternative=BS2Suite::ForecastContext.step(object,actor,nil,target,nil,false)
      check(alternative[:rows][0][:mean]<step[:rows][0][:mean],'A2 explicit alternative never inherits cancelled preparation')
      hd=BS2Suite::QuickDamage.lines(scene,object,actor,nil,target)
      check(hd.join.include?(full[:rows][0][:mean].round.to_s),'A2 HD agrees with complete selected sequence')
      card=BS2QoL::PracticalCard.new(object,actor)
      check(card.forecast09991_steps[0][1][:rows]==full[:rows],'A2 F7 agrees with complete selected sequence')
      log('A2_full_mean='+full[:rows][0][:mean].to_s+' alternative_mean='+alternative[:rows][0][:mean].to_s)
    end
    if ['all','A3'].include?(which)
      queue(actor);rows=[row('guard'),row('skill',object.id)]
      check(!BS2Suite::Macros.commit(scene,actor,set([row('item',61)]+rows),0),'A3 prepared macro commits')
      actor.instance_variable_set(:@action_input_index,1)
      a=BS2Suite::QuickDamage.lines(scene,object,actor,nil,target)
      BS2Suite::QueueEdit.cancel(scene,actor)
      check(!BS2Suite::Macros.commit(scene,actor,set(rows),0),'A3 replacement macro commits')
      actor.instance_variable_set(:@action_input_index,1)
      b=BS2Suite::QuickDamage.lines(scene,object,actor,nil,target)
      fresh=BS2Suite::QuickDamage.calculate(object,actor,nil,[target],target,nil)
      check(b==fresh && b!=a,'A3 removing only preparation invalidates both forecast caches')
      actor.actions[0].instance_variable_set(:@bs2s_macro_before,[row('item',61)])
      c=BS2Suite::QuickDamage.lines(scene,object,actor,nil,target)
      check(c==a,'A3 adding preparation without a revision bump changes the semantic key')
      variants=[[:@bs2s_macro_after,[row('item',61)]],[:@bs2s_macro_after,nil],
        [:@bs2s_macro_source,$data_weapons[277]],[:@bs2s_macro_source,nil],
        [:@bs2s_macro_executor,391],[:@bs2s_macro_executor,nil]]
      variants.each do |field,value|
        actor.actions[0].instance_variable_set(field,value)
        cached=BS2Suite::QuickDamage.lines(scene,object,actor,nil,target)
        direct=BS2Suite::QuickDamage.calculate(object,actor,nil,[target],target,nil)
        check(cached==direct,'A3 semantic cache matches fresh calculation: '+field.to_s+' '+(value ? 'set' : 'removed'))
      end
      $game_troop.members<<Game_Enemy.new(1,5000)
      $game_party.gain_item($data_items[105],10)
      actor.actions[0].instance_variable_set(:@bs2s_macro_before,[row('item',105)])
      [0,1,0].each do |i|
        actor.actions[0].instance_variable_set(:@bs2s_macro_target,i)
        cached=BS2Suite::QuickDamage.lines(scene,object,actor,nil,target)
        direct=BS2Suite::QuickDamage.calculate(object,actor,nil,[target],target,nil)
        check(cached==direct,'A3 changing only attached enemy target matches fresh calculation '+i.to_s)
      end
      $game_troop.members.pop
      actor.actions[0].instance_variable_set(:@bs2s_macro_before,[row('item',61)])
      qd=BS2Suite::QuickDamage
      class << qd
        alias qa09993_calculate calculate
        def calculate(*args);@qa09993_calls=(@qa09993_calls || 0)+1;qa09993_calculate(*args);end
      end
      BS2Suite::Performance.bump
      qd.lines(scene,object,actor,nil,target);calls=qd.instance_variable_get(:@qa09993_calls)
      30.times { qd.lines(scene,object,actor,nil,target) }
      check(qd.instance_variable_get(:@qa09993_calls)==calls,'A3 unchanged frames reuse one result without recalculating')
      class << qd;alias calculate qa09993_calculate;remove_method :qa09993_calculate;end
      log('A3_prepared='+a.join+' bare='+b.join)
    end
    if ['all','B1'].include?(which)
      queue(actor);check(!BS2Suite::Macros.commit(scene,actor,set([row('item',61),row('guard')]),0),'B1 real macro commits')
      action=actor.actions[0];before=$game_party.item_number($data_items[61])
      action.clear;action.set_guard;action.prepare
      check($game_party.item_number($data_items[61])==before,'B1 clear then reuse never executes an old instant item')
      fields=[:@bs2s_macro_before,:@bs2s_macro_after,:@bs2s_macro_source,:@bs2s_macro_executor,:@bs2s_macro_target,:@bs2s_macro_token]
      check(fields.all? { |key| !action.instance_variable_get(key) },'B1 clear releases all macro ownership metadata')
      queue(actor);BS2Suite::Macros.commit(scene,actor,set([row('item',61),row('guard'),row('guard')]),0)
      scene.instance_variable_set(:@bs20999_cancel_time,nil);scene.prior_command
      check(actor.actions.count { |a| a.item }==1,'B3 single Esc still removes only the last paid slot')
      name=BS2QoL::Model.queue(actor)[0][:name]
      check(name.include?($data_items[61].name) && name.include?('до:'),'B3 remaining instant preparation is named in the native queue')
      plan_window=scene.instance_variable_get(:@bs2q_plan)
      plan_window.display(actor,true);Graphics.update
      capture_scene('queue09993.png')
      capture_scene('queue09993-contents.png',plan_window.contents)
      log('B3_native_window='+[plan_window.visible,plan_window.openness,plan_window.opacity,plan_window.contents_opacity,plan_window.contents.width,plan_window.contents.height].inspect)
      display=BS2Suite::HDDisplay;display.apply(display::DEFAULT.merge('width'=>960,'height'=>720))
      90.times { Graphics.update;Input.update;break if display.active? }
      check(display.active?,'B3 actual HD renderer is active for attachment rows')
      hd=display.battle_rows(scene).map { |r| r.split("\t",2)[1] }.join(' ')
      check(hd.include?($data_items[61].name) && hd.include?('Мгновенно до:'),'B3 HD also names remaining instant preparation')
      queue(actor,1);BS2Suite::Macros.commit(scene,actor,set([row('item',61),row('guard')]),0)
      plan_window.display(actor,true)
      check(plan_window.visible,'B3 a single paid slot also exposes attached instant steps')
    end
    if ['all','B2'].include?(which)
      $game_troop.members<<Game_Enemy.new(1,5000)
      gun=$data_skills[17]
      actor.learn_skill(gun.id);actor.recover_all
      actor.instance_variable_set(:@ap,ATB::MAX_AP);queue(actor);scene.start_actor_command_selection
      support.reset;support.instance_variable_set(:@definitions,[{'actor'=>actor.id,'kind'=>'skill','id'=>gun.id}])
      support.new_epoch(actor);plan=support.next_plan(actor)
      check(plan && plan[:object]==gun,'B2 native support planner proposes a paid Gun Break')
      support.propose(scene,plan);original=actor.input
      check(original.item==gun,'B2 visible support suggestion owns a populated input slot')
      macros=BS2Suite::Macros;macros.instance_variable_set(:@data,{[actor.id,1]=>set([row('skill',object.id)])})
      check(macros.open(scene,scene.instance_variable_get(:@actor_command_window)),'B2 open actual C picker over support suggestion')
      picker=scene.instance_variable_get(:@bs2s_macros);macros.fill(scene,picker,actor,1);picker.call_handler(:entry)
      check(scene.instance_variable_get(:@bs2s_macro_targeting),'B2 actual macro picker opens enemy targeting')
      scene.on_enemy_cancel
      check(actor.input.equal?(original) && actor.input.item==gun && support.pending.equal?(plan),'B2 target cancel preserves the previous support suggestion')
      check(!scene.instance_variable_get(:@bs2s_macro_pending) && !scene.instance_variable_get(:@bs2s_macro_targeting),'B2 target cancel discards only the uncommitted macro')
      support.reset
    end
    log('result=PASS; checks='+@checks.to_s)
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure
    BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  end
end
