# encoding: UTF-8
# Test-only input agent and observers. Native Graphics.update and calculations remain intact.
module BS2QA
  @checks = 0
  @events = []
  @uses = []
  @outcomes = []
  @random_events = []
  @frame_start = Graphics.frame_count
  @idle = 0
  @intent = 0
  @target_cancelled = false
  @weapon_done = false
  @case_name = nil
  class << self
    attr_reader :events, :uses, :checks, :outcomes, :case_name, :random_events, :raw_keys
    attr_accessor :result, :plan, :actor, :start_frame, :visual_rng
    def visual_random; @visual_random ||= Random.new(90210); end
    def log(text)
      File.open('test_result.txt','a') { |file| file.puts text }
    end
    def json(value)
      case value
      when Hash; '{'+value.map { |k,v| json(k.to_s)+':'+json(v) }.join(',')+'}'
      when Array; '['+value.map { |v| json(v) }.join(',')+']'
      when String,Symbol
        '"'+value.to_s.gsub(/[\\"\n\r\t]/) { |c| {'\\'=>'\\\\','"'=>'\\"',"\n"=>'\\n',"\r"=>'\\r',"\t"=>'\\t'}[c] }+'"'
      when NilClass; 'null'
      when TrueClass; 'true'
      when FalseClass; 'false'
      else; value.to_s
      end
    end
    def check(value,label)
      raise 'QA assertion: '+label unless value
      @checks += 1
      log('PASS '+label)
    end
    def options
      @options ||= Hash[File.open('qa_options.txt','rb') { |f| f.read }.split(/\r?\n/).map { |l| l.split('=',2) }]
    end
    def mod?; options['variant']=='mod'; end
    def id(battler)
      battler.actor? ? 'actor:'+battler.id.to_s : 'enemy:'+battler.index.to_s
    end
    def state
      {:party=>$game_party.members.map { |a| [a.id,a.hp,a.mp,a.tp,a.states.map { |s| s.id }.sort,a.equips.map { |e| e && e.id },a.exp] },
       :items=>$game_party.items.map { |i| [i.id,$game_party.item_number(i)] }.sort,
       :gold=>$game_party.gold,
       :enemy=>$game_troop.members.map { |e| [e.enemy_id,e.hp,e.mp,e.states.map { |s| s.id }.sort] }}
    end
    def active(scene,name)
      window=scene.instance_variable_get(name)
      window && !window.disposed? && window.active && window.open? ? window : nil
    end
    def move_to(window,index)
      raise 'Requested row missing' unless index
      return :C if window.index==index
      columns=window.col_max
      return :DOWN if window.index/columns < index/columns
      return :UP if window.index/columns > index/columns
      window.index%columns < index%columns ? :RIGHT : :LEFT
    end
    def command(window,symbol,ext=nil)
      list=window.instance_variable_get(:@list)
      index=list.index { |row| row[:symbol]==symbol && (ext.nil? || row[:ext]==ext) }
      raise 'Command absent '+symbol.to_s unless index
      move_to(window,index)
    end
    def choose_object(window,id)
      data=window.instance_variable_get(:@data) || []
      index=data.index { |o| o && o.id==id }
      raise 'Object absent in list: '+id.to_s unless index
      if window.index==index && !window.current_item_enabled?
        raise 'Driver requested unavailable '+id.to_s+' in '+window.class.to_s+' hp/mp/tp='+[@actor.hp,@actor.mp,@actor.tp].inspect+' states='+@actor.states.map { |s| s.id }.inspect
      end
      move_to(window,index)
    end
    def advance
      @intent += 1
      @target_cancelled=false
      @intent_started_uses=@uses.size
    end
    def update_intent
      action=@plan[@intent]
      if action && action[:kind]!=:weapon && @uses.size>@intent_started_uses
        ids=action[:id]==350 ? [350,351,352] : [action[:id]]
        used=@uses[@intent_started_uses..-1].any? { |e| e[:user]==id(@actor) && e[:kind]==action[:kind].to_s && ids.include?(e[:id]) }
        advance if used
      end
    end
    def raw(chord)
      @raw_keys=[]
      @raw_keys << 0x10 if chord[0,1]=='S'
      @raw_keys << 0x11 if chord[0,1]=='C'
      @raw_keys << chord[-1,1].to_i+0x30
      nil
    end
    def clear_raw; @raw_keys=[]; end
    def key(scene)
      frame=Graphics.frame_count
      raise 'Frame budget exceeded '+@case_name.to_s if @start_frame && frame-@start_frame>10000
      if frame%300==0
        names=scene ? scene.instance_variables.select { |name| v=scene.instance_variable_get(name); v.is_a?(Window_Selectable) && v.active }.map { |name| v=scene.instance_variable_get(name); [name,v.index,v.openness] } : []
        log('progress case='+@case_name.to_s+' scene='+scene.class.to_s+' intent='+@intent.to_s+' uses='+@uses.size.to_s+' windows='+names.inspect)
      end
      return (frame.even? ? :C : nil) if $game_message && ($game_message.busy? || $game_message.visible)
      return nil unless scene
      return nil if frame.odd?
      update_intent
      action=@plan[@intent] || {:kind=>:skill,:id=>14}
      if scene.is_a?(Scene_Equip)
        if @actor.equips[0] && @actor.equips[0].id==action[:id]
          @weapon_done=true
          return :B
        end
        w=active(scene,:@item_window)
        return choose_object(w,action[:id]) if w
        w=active(scene,:@slot_window)
        return move_to(w,0) if w
        w=active(scene,:@command_window)
        return command(w,:equip) if w
        return nil
      end
      return nil unless scene.is_a?(Scene_Battle)
      if action[:kind]==:weapon && @actor.equips[0] && @actor.equips[0].id==action[:id]
        @weapon_done=true
        if active(scene,:@bs2q_hub)
          return :B
        elsif active(scene,:@actor_command_window)
          advance
          action=@plan[@intent] || {:kind=>:skill,:id=>14}
        end
      end
      [:@actor_window,:@enemy_window].each do |name|
        w=active(scene,name)
        next unless w
        if action[:cancel] && !@target_cancelled
          @target_cancelled=true
          @events << {:navigation=>'target_cancel',:stock=>$game_party.item_number($data_items[1]),:hp=>@actor.hp}
          return :B
        end
        return :C
      end
      w=active(scene,:@bs2q_weapon)
      return choose_object(w,action[:id]) if w
      w=active(scene,:@skill_window)
      return choose_object(w,action[:id]) if w
      w=active(scene,:@item_window)
      return choose_object(w,action[:id]) if w
      w=active(scene,:@bs2q_hub)
      return command(w,action[:kind]) if w
      w=active(scene,:@actor_command_window)
      if w
        return command(w,:guard) if action[:kind]==:guard && !mod?
        return command(w,:escape) if action[:kind]==:escape && !mod?
        if mod?
          return raw('3') if action[:kind]==:guard
          return raw('5') if action[:kind]==:escape
          return raw('S2') if action[:kind]==:weapon
          # Direct flask deliberately skips the single-ally picker. Exercise
          # cancellation through an unpaid magic target before the first flask.
          return raw('C2') if action[:kind]==:item && action[:cancel] && !@target_cancelled
          return raw('C1') if action[:kind]==:item
          return raw({14=>'C2',18=>'C3',350=>'C4'}[action[:id]])
        end
        return command(w,:equip_change) if action[:kind]==:weapon
        return command(w,:item) if action[:kind]==:item
        return command(w,:skill,$data_skills[action[:id]].stype_id)
      end
      w=active(scene,:@party_command_window)
      return command(w,:fight) if w
      nil
    end
    def begin_case(name,index)
      @case_name=name;@events=[];@uses=[];@random_events=[];@intent=0;@intent_started_uses=0;@target_cancelled=false;@weapon_done=false
      @result=nil;@start_frame=Graphics.frame_count
      DataManager.setup_new_game
      @start_frame=Graphics.frame_count
      $game_switches[TMBMIST::SW_NOUSE]=true if options['isolate_visual_rng']=='true'
      @actor=$game_party.members[0]
      @actor.change_class(1)
      @actor.change_level(name=='defeat' || name=='allowed_defeat' ? 1 : 70,false)
      @actor.name='QA'
      @actor.clear_equipments
      [101,112,384].each { |i| $game_party.gain_item($data_weapons[i],1) }
      @actor.change_equip(0,$data_weapons[101])
      [14,18,31,181,350].each { |i| @actor.learn_skill(i) }
      @actor.recover_all
      @actor.hp=[@actor.mhp/3,1].max
      $game_party.gain_item($data_items[1],6)
      if mod?
        BS2QoL::Preferences.instance_variable_set(:@lists,{:weapon=>[112,101,384],:item=>[1],:skill=>[14,18,350,181]})
        BS2QoL::Bindings.instance_variable_set(:@data,{
          'weapons'=>{'S1'=>[:weapon,101],'S2'=>[:weapon,112]},
          'items'=>{'S1'=>[:item,1]},
          'quick'=>{'C1'=>[:item,1],'C2'=>[:skill,14],'C3'=>[:skill,18],'C4'=>[:skill,350]}})
      end
      @plan=[{:kind=>:weapon,:id=>112},{:kind=>:item,:id=>1,:cancel=>true},
             {:kind=>:item,:id=>1},{:kind=>:skill,:id=>18},{:kind=>:skill,:id=>14}]
      # Two actual enemies keep the cancellation fixture meaningful now that
      # a sole enemy is confirmed automatically by the requested UI behavior.
      troop=['victory','actions'].include?(name) ? 79 : 3
      can_lose=false
      if name=='defeat' || name=='allowed_defeat'
        @actor.hp=1;@actor.clear_equipments;@plan=[{:kind=>:guard,:id=>2}]*30
        can_lose=name=='allowed_defeat'
      elsif name=='escape'
        @plan=[{:kind=>:escape,:id=>0}]
      elsif name=='stages'
        @actor.change_level(30,false)
        @actor.change_equip(0,$data_weapons[384])
        @actor.recover_all
        @plan=[{:kind=>:skill,:id=>350}]*6
        troop=5
      elsif name=='magic'
        @actor.change_level(25,false);@actor.recover_all
        @plan=[{:kind=>:skill,:id=>14}]*15
      elsif name=='actions'
        @actor.change_equip(0,$data_weapons[112])
        @plan=@plan[1..-1]
      end
      srand(options['seed'].to_i+index)
      @random_events=[]
      BattleManager.setup(troop,true,can_lose)
      BattleManager.instance_variable_set(:@preemptive,true) if name=='escape'
      BattleManager.save_bgm_and_bgs
      BattleManager.event_proc=Proc.new { |n| @result=n }
      SceneManager.instance_variable_set(:@stack,[Scene_BS2QATerminal.new])
      SceneManager.instance_variable_set(:@scene,Scene_Battle.new)
      log('case_start='+name+'; class='+@actor.class_id.to_s+'; hp='+@actor.hp.to_s)
    end
    def run_case(name,index)
      begin_case(name,index)
      while SceneManager.scene
        current=SceneManager.scene
        break if current.is_a?(Scene_BS2QATerminal)
        if current.is_a?(Scene_Gameover)
          # Exercise its complete startup/transition, then stop before returning to title.
          current.start
          current.post_start
          3.times { current.update }
          current.terminate
          break
        end
        current.main
      end
      expected=(name=='defeat' || name=='allowed_defeat') ? 2 : (name=='escape' ? 1 : 0)
      check(@result==expected,name+' reaches expected battle outcome')
      check(!$game_party.in_battle,name+' clears in-battle flag')
      check(@actor.hp==1,'allowed defeat revives to one HP') if name=='allowed_defeat'
      if name=='victory'
        check(@weapon_done,'weapon change completed through user-facing flow')
        check(@events.any? { |e| e[:navigation]=='target_cancel' },'target cancel occurred in full frame loop')
        check(@uses.count { |e| e[:user]==id(@actor) && e[:kind]=='item' && e[:id]==1 }==2,'two quick items consumed exactly twice')
      end
      if name=='stages'
        check(@uses.select { |e| e[:user]==id(@actor) }.map { |e| e[:id] }.uniq.size>=2,'stage replacement exercised across inputs')
      end
      summary={:case=>name,:result=>@result,:state=>state,:uses=>@uses,:effects=>@events,
               :rng_tail=>5.times.map { rand(1000000) },:frames=>Graphics.frame_count-@start_frame,:random_calls=>@random_events}
      @outcomes << summary
      write_results
      log('case_done='+name+'; frames='+summary[:frames].to_s+'; uses='+@uses.size.to_s)
    end
    def regressions
      @plan=nil;@case_name=nil
      Input.instance_variable_set(:@qa_key,nil)
      DataManager.setup_new_game
      @actor=$game_party.members[0]
      @actor.change_class(1)
      @actor.change_level(25,false)
      @actor.recover_all
      # Only QA-prefixed saves in the isolated copy; never personal SaveNN files.
      class << DataManager
        alias bs2qa_original_make_filename make_filename unless method_defined?(:bs2qa_original_make_filename)
        def make_filename(index); 'BS2QA_Save'+index.to_s+'.rvdata2'; end
      end
      if !mod? && File.file?('BS2QA_Save0.rvdata2')
        check(DataManager.load_game(0),'unmodified engine loads mod-session save')
        $game_system.on_after_load
        @actor=$game_party.members[0]
        check(@actor.hp==123 && $game_variables[777]=='QA-save','cross-process save retains known state without mod classes')
      end
      @actor.hp=123
      $game_variables[777]='QA-save'
      $game_party.gain_item($data_items[1],4)
      expected=Marshal.dump(state)
      world=[$game_variables[777],$game_map.map_id,$game_player.x,$game_player.y]
      check(DataManager.save_game(0),'native save writes isolated QA fixture')
      @actor.hp=1;$game_variables[777]='changed';$game_party.lose_item($data_items[1],3)
      check(DataManager.load_game(0),'native load restores QA fixture')
      $game_system.on_after_load
      @actor=$game_party.members[0]
      check(Marshal.dump(state)==expected,'save/load roundtrip restores actor and inventory')
      check(world==[$game_variables[777],$game_map.map_id,$game_player.x,$game_player.y],'save/load restores variable and map position')
      raw=File.open('BS2QA_Save0.rvdata2','rb') { |f| f.read }
      check(!raw.include?('BS2QoL'),'save contains no custom mod class names')
      if mod?
        preferences=BS2QoL::Preferences
        limit=preferences.parse('weapon='+(1..100).to_a.join(','))
        check(limit[:weapon].size==64,'favorite file bounded to 64 positions')
        preferences.instance_variable_set(:@lists,{:weapon=>[],:item=>[],:skill=>[]})
        preferences.persist
        original=File.open(preferences.path,'rb') { |f| f.read }
        class << preferences
          alias bs2qa_real_path path
          def path; File.join(Dir.pwd,'QA_missing_parent','missing_child','preferences.ini'); end
        end
        preferences.toggle(:weapon,101)
        check(preferences.error==:write_failed,'preference write failure is visible without crash')
        check(preferences.ids(:weapon)==[101],'write failure retains preferences in memory')
        class << preferences
          alias path bs2qa_real_path
        end
        check(File.open(preferences.path,'rb') { |f| f.read }==original,'write failure preserves last good file')
        check(preferences.persist && preferences.error.nil?,'preference persistence recovers')
        # Full upgrade inventory exercises long single-column collection bitmaps.
        $data_weapons.compact.each { |w| $game_party.gain_item(w,1) unless w.name.empty? }
        preferences.instance_variable_set(:@lists,{:weapon=>[384,101],:item=>[1],:skill=>[105]})
        before=ObjectSpace.each_object(Window).count { |w| !w.disposed? }
        12.times do |iteration|
          menu=Scene_BS2QFavorites.new
          SceneManager.instance_variable_set(:@scene,menu)
          menu.start
          menu.post_start
          menu.instance_variable_get(:@tabs).process_ok
          window=menu.instance_variable_get(:@collection)
          if iteration==0
            class << Audio
              attr_accessor :bs2qa_se_events
              alias bs2qa_muted_se_play se_play
              def se_play(*args)
                (@bs2qa_se_events ||= []) << args
                bs2qa_muted_se_play(*args)
              end
            end
            Audio.bs2qa_se_events=[]
            window.process_ok
            check(Audio.bs2qa_se_events.size==1,'one confirmation produces one menu sound')
            data=window.instance_variable_get(:@data)
            favorites=data.take(64).map { |object| object.id }
            preferences.instance_variable_set(:@lists,{:weapon=>favorites,:item=>[1],:skill=>[105]})
            window.refresh;window.select(64)
            check(!window.current_item_enabled?,'full favorite list disables another addition')
            Audio.bs2qa_se_events=[]
            window.process_ok
            check(preferences.ids(:weapon)==favorites && Audio.bs2qa_se_events.size==1,
              'rejected addition keeps 64 favorites and plays one sound')
            window.select(0)
            check(window.current_item_enabled?,'full favorite list still allows removal')
            Audio.bs2qa_se_events=[]
            window.process_ok
            check(preferences.ids(:weapon).size==63 && Audio.bs2qa_se_events.size==1,
              'removing from full favorite list succeeds with one sound')
          end
          check(window.item_max>=300,'large inventory opens '+iteration.to_s) if iteration==0
          window.select(window.item_max-1)
          window.cursor_pageup
          window.cursor_pagedown
          check(window.index<window.item_max && window.index>=0,'scroll selection remains valid '+iteration.to_s) if iteration==0
          menu.terminate
        end
        GC.start
        after=ObjectSpace.each_object(Window).count { |w| !w.disposed? }
        check(after==before,'repeated menu opening leaves no live native windows')
        @actor.clear_equipments
        @actor.change_equip(0,$data_weapons[101])
        @actor.forget_skill(105);@actor.tp=100;@actor.recover_all
        BattleManager.setup(3,true,false);$game_party.on_battle_start
        @actor.instance_variable_set(:@ap,ATB::MAX_AP)
        BattleManager.instance_variable_set(:@actor_index,0)
        help=Window_Help.new;view=Viewport.new(0,360,640,120)
        skills=Window_BattleSkill.new(help,view)
        skills.actor=@actor;skills.bs2q_only=true;skills.refresh
        check(@actor.skills.include?($data_skills[105]),'weapon grants temporary skill')
        @actor.change_equip(0,$data_weapons[112]);skills.refresh
        check(skills.instance_variable_get(:@data).include?($data_skills[105]),'lost weapon skill remains in favorites')
        check(!skills.enable?($data_skills[105]),'lost weapon skill is disabled after equipment change')
        skills.dispose;help.dispose;view.dispose
        $game_party.on_battle_end
      end
      @outcomes << {:case=>'regressions',:variant=>options['variant'],:checks=>@checks}
      write_results
    end
    def write_results
      File.open('system_result.json','wb') do |file|
        file.write(json({:variant=>options['variant'],:native_graphics=>true,:seed=>options['seed'].to_i,
          :visual_rng_isolated=>options['isolate_visual_rng']=='true',
          :visual_rng_strategy=>options['isolate_visual_rng']=='true' ? 'no_mist_and_separate_sprite_generator' : 'native',
          :checks=>@checks,:outcomes=>@outcomes}))
      end
    end
  end
end

module Kernel
  alias bs2qa_observed_rand rand
  def rand(*args)
    return BS2QA.visual_random.rand(*args) if BS2QA.visual_rng
    value=bs2qa_observed_rand(*args)
    BS2QA.random_events << [:rand,args,value,caller[0]] if BS2QA.case_name
    value
  end
end

# Scene_Equip destroys/recreates the battle sprites. Their native mirror,
# breath and aura phase initialization all draw from Kernel.rand. During the
# controlled experiment only, give this visual constructor a separate RNG.
# Normal system runs and the installable mod use the untouched global RNG.
class Sprite_Battler
  alias bs2qa_visual_initialize initialize
  def initialize(*args)
    previous=BS2QA.visual_rng
    BS2QA.visual_rng=true if BS2QA.options['isolate_visual_rng']=='true'
    bs2qa_visual_initialize(*args)
  ensure
    BS2QA.visual_rng=previous
  end
end
class Array
  alias bs2qa_observed_sample sample
  def sample(*args)
    value=bs2qa_observed_sample(*args)
    BS2QA.random_events << [:sample,size,args,caller[0]] if BS2QA.case_name
    value
  end
end

class Scene_BS2QATerminal < Scene_Base; end

class BS2QA_RawBackend
  def focused?; true; end
  def down; BS2QA.raw_keys || []; end
end

module Input
  class << self
    def update
      now=Graphics.frame_count
      if @qa_sample_frame==now
        @qa_key=nil
      else
        @qa_sample_frame=now
        BS2QA.clear_raw
        @qa_key=BS2QA.plan ? BS2QA.key(SceneManager.scene) : nil
      end
      BS2QoL::Keyboard.update if BS2QA.mod?
    end
    def trigger?(key); @qa_key==key; end
    def repeat?(key); @qa_key==key; end
    def press?(key); @qa_key==key || (key==:CTRL && !!BS2QA.options['battle_ctrl']); end
  end
end

class Game_Battler
  alias bs2qa_observed_use_item use_item
  def use_item(item)
    before=[hp,mp,tp]
    result=bs2qa_observed_use_item(item)
    BS2QA.uses << {:user=>BS2QA.id(self),:kind=>item.is_a?(RPG::Skill) ? 'skill' : 'item',:id=>item.id,
      :before=>before,:after=>[hp,mp,tp]} if BS2QA.case_name
    result
  end
  alias bs2qa_observed_item_apply item_apply
  def item_apply(user,item)
    before=[hp,mp,tp]
    result=bs2qa_observed_item_apply(user,item)
    BS2QA.events << {:target=>BS2QA.id(self),:user=>BS2QA.id(user),:id=>item.id,:before=>before,
      :after=>[hp,mp,tp],:states=>states.map { |s| s.id }.sort,:missed=>@result.missed,
      :evaded=>@result.evaded,:critical=>@result.critical} if BS2QA.case_name
    result
  end
end

begin
  File.open('test_result.txt','w') { |f| f.puts 'system_suite; native_graphics=true; ruby='+RUBY_VERSION }
  BS2QoL::Keyboard.backend=BS2QA_RawBackend.new if BS2QA.mod?
  DataManager.init
  BS2Suite::Options.set('instant_battle_ctrl',BS2QA.options['battle_ctrl']=='instant' ? 1 : 0) if BS2QA.mod? && BS2QA.options['battle_ctrl']
  BS2Suite::Debug.start if defined?(BS2Suite::Debug)
  SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(Graphics.width,Graphics.height))
  BS2QA.options['cases'].split(',').each_with_index do |name,index|
    name=='regressions' ? BS2QA.regressions : BS2QA.run_case(name,index)
  end
  BS2QA.log('result=PASS; checks='+BS2QA.checks.to_s+'; scenarios='+BS2QA.outcomes.size.to_s)
rescue Exception => error
  BS2QA.log('result=FAIL; '+error.class.to_s+': '+error.message+"\n"+error.backtrace.join("\n"))
end
BS2Suite::Debug.close if defined?(BS2Suite::Debug)
exit
