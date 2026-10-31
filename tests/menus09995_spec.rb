# encoding: UTF-8
# Integration regressions from the 0.9994 audit. Real native windows/input/costs.
rgss_main do
  load 'BS2QA_native_capture.rb'
  @checks=0
  def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
  def check(v,s);raise s unless v;@checks+=1;log('PASS '+s);end
  class MenuKeys09995
    attr_accessor :keys
    def initialize;@keys=[];end
    def down;@keys;end
    def focused?;true;end
  end
  def frame(keys=[]);@raw.keys=keys;@scene.update_basic;end
  def tap(keys);frame;frame(keys);end
  def queue
    BS2Suite::Palette.close(@scene,false) if BS2Suite::Palette.current(@scene)
    @scene.bs2s_hide_selection;@scene.bs2s_forget_menu
    @actor.instance_variable_set(:@actions,Array.new(4) { Game_Action.new(@actor) })
    @actor.instance_variable_set(:@action_input_index,0);@actor.instance_variable_set(:@ap,ATB::MAX_AP)
    BattleManager.instance_variable_set(:@actor_index,0);BattleManager.instance_variable_set(:@phase,:input)
    @scene.start_actor_command_selection
  end
  def row(prefix,group,digit,kind,id,source=0)
    {'prefix'=>prefix,'group'=>group,'digit'=>digit,'kind'=>kind,'id'=>id,'source'=>source}
  end
  def profile(entries)
    BS2Suite::Semantic.customs['u9995']={'name'=>'QA menu integration','groups'=>{},'entries'=>entries,'behaviors'=>{'N1'=>'now'}}
    BS2Suite::Semantic.state['active'][@actor.id.to_s]='u9995'
  end
  def open_menu(prefix,group=1,index=0)
    BS2Suite::Palette.open(@scene,@scene.instance_variable_get(:@actor_command_window),@actor,prefix)
    w=BS2Suite::Palette.current(@scene);w.set_group(group);w.select(index);w
  end
  def native_item(item)
    @scene.instance_variable_get(:@actor_command_window).deactivate;@scene.command_item
    w=@scene.instance_variable_get(:@item_window);w.openness=255;w.select(w.instance_variable_get(:@data).index(item));w
  end
  def stock(item,n);$game_party.gain_item(item,n-$game_party.item_number(item));end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'Audit fixes '+BS2Suite::VERSION }
    DataManager.init;DataManager.setup_new_game
    SceneManager.instance_variable_set(:@background_bitmap,Bitmap.new(640,480))
    @actor=$game_party.leader;@actor.change_class(1);@actor.change_level(70,false);@actor.clear_equipments
    $game_party.gain_item($data_weapons[101],1);@actor.change_equip(0,$data_weapons[101]);@actor.recover_all
    troop=RPG::Troop.new;troop.id=79
    enemy=RPG::Enemy.new;enemy.id=5000;enemy.name='QA';enemy.battler_name='';enemy.params=[1000000,100,50,30,50,30,50,50];$data_enemies[5000]=enemy
    member=RPG::Troop::Member.new;member.enemy_id=5000;member.x=300;member.y=180;troop.members=[member];$data_troops[79]=troop
    BattleManager.setup(79,true,false);$game_party.on_battle_start;BattleManager.make_battlers_ap
    @raw=MenuKeys09995.new;BS2QoL::Keyboard.backend=@raw;BS2QoL::Keyboard.reset
    @scene=Scene_Battle.new;SceneManager.instance_variable_set(:@scene,@scene);@scene.start;queue
    support=BS2Suite::BattleSupport;support.instance_variable_set(:@master,false)
    if defined?(BS2Suite::HDDisplay)
      hd=BS2Suite::HDDisplay;hd.apply(hd::DEFAULT.merge('width'=>1280,'height'=>720))
      20.times { frame };check(hd.active?,'new integration suite uses the real HD compositor')
    end
    magic=RPG::Skill.new;magic.id=5005;magic.name='QA paid magic';magic.scope=1;magic.stype_id=1;magic.hit_type=2;magic.mp_cost=5;magic.damage.type=1;magic.damage.formula='a.mat*2';magic.damage.variance=0
    other_magic=Marshal.load(Marshal.dump(magic));other_magic.id=5006;other_magic.name='QA second magic'
    [magic,other_magic].each { |s| $data_skills[s.id]=s;@actor.learn_skill(s.id) }
    item=$data_items[61];other=$data_items[56]
    # A1: favorite/filter refresh must never arm the next consumable.
    stock(item,1);stock(other,5);BS2QoL::Preferences.lists[:item]=[other.id]
    queue;w=native_item(item);tap([13])
    check(w.item==item && !w.current_item_enabled?,'last native item remains selected and disabled')
    before=$game_party.item_number(other);tap([65])
    check(w.item==item && !w.current_item_enabled?,'A retains the depleted selection while adding its favorite')
    check(BS2QoL::Preferences.favorite?(:item,item.id),'depleted item can be added to favorites')
    tap([13]);check($game_party.item_number(other)==before,'Enter after favorite refresh cannot spend another consumable')
    tap([65]);check(w.item==item && !BS2QoL::Preferences.favorite?(:item,item.id),'removing favorite also retains the depleted selection')
    tap([83]);check(w.bs2q_only && w.item==item && !w.current_item_enabled?,'favorites filtering keeps the disabled selection safe')
    tap([13]);check($game_party.item_number(other)==before,'filtered depleted selection never arms another item')
    tap([83]);stock(item,1);w.refresh
    check(w.item==item && w.current_item_enabled?,'reacquiring a depleted item re-enables the real row')
    tap([13]);@scene.on_item_cancel;native_item(other)
    check(!w.instance_variable_get(:@data).include?(item),'fresh native menu does not inherit the temporary zero row')
    @scene.on_item_cancel
    # A2: marker scope and stable digits across group/prefix/root transitions.
    profile([row('B',1,1,'item',61),row('B',2,1,'item',56),row('M',1,1,'skill',magic.id),row('N',1,1,'weapon',101)])
    stock(item,1);queue;open_menu('B');tap([13]);w=BS2Suite::Palette.current(@scene)
    check(w.item==item && !w.current_item_enabled?,'palette retains its original depleted item')
    tap([69]);w=BS2Suite::Palette.current(@scene)
    check(w.group==2 && w.entries.map { |r| [r[:id],r[:digit]] }==[[56,1]],'E changes B group without injecting the old item or moving digits')
    tap([77]);tap([49]);w=BS2Suite::Palette.current(@scene)
    check(w.prefix=='M' && w.entries.map { |r| [r[:id],r[:digit]] }==[[magic.id,1]],'M keeps its own entries and original numeric addresses')
    tap([78]);tap([49]);w=BS2Suite::Palette.current(@scene)
    check(w.prefix=='N' && w.entries.map { |r| r[:id] }==[101],'N cannot inherit an exhausted B item')
    tap([66]);tap([49]);w=BS2Suite::Palette.current(@scene)
    check(w.prefix=='B' && w.group==1 && w.item==item && !w.current_item_enabled?,'returning to the original group retains its scoped disabled marker')
    tap([27]);open_menu('B');check(BS2Suite::Palette.current(@scene).entries.empty?,'explicit exit retires the palette marker')
    # A6 and the additional digit-choice regression.
    profile([row('M',1,1,'skill',magic.id),row('M',1,2,'skill',magic.id)]);queue;open_menu('M',1,1);tap([13]);w=BS2Suite::Palette.current(@scene)
    check(w.index==1 && w.entry[:digit]==2,'duplicate skill returns to the exact second custom slot')
    check(@actor.actions[0].item==magic,'duplicate-slot restoration does not change the selected action')
    profile([row('M',1,1,'skill',magic.id),row('M',1,2,'skill',other_magic.id)]);queue;open_menu('M',1,0);tap([50]);w=BS2Suite::Palette.current(@scene)
    check(@actor.actions[0].item==other_magic && w.item==other_magic && w.index==1,'digit two remembers the chosen row rather than the previously hovered row')
    # A4: failed choices preserve the controller for both Enter and digits.
    profile([row('M',1,1,'skill',magic.id)]);queue;@actor.mp=0;w=open_menu('M');tap([13])
    check(BS2Suite::Palette.current(@scene)==w && w.item==magic,'Enter on insufficient MP retains the same palette')
    check(@actor.actions.all? { |a| !a.item },'failed Enter cannot create a paid slot')
    tap([49]);check(BS2Suite::Palette.current(@scene)==w && w.index==0,'unavailable numeric selection also retains group and cursor')
    check(@actor.actions.all? { |a| !a.item },'failed numeric choice cannot create a paid slot')
    @actor.recover_all;magic.note='<クールタイム:3>';magic.instance_variable_set(:@cool_time,nil);@actor.cool_time[magic.id]=3;w.refresh;tap([13])
    check(BS2Suite::Palette.current(@scene)==w && @actor.actions.all? { |a| !a.item },'cooldown refusal retains the menu without scheduling a command')
    @actor.cool_time.clear;@actor.skill_seal<<magic.id;w.refresh;tap([49])
    check(BS2Suite::Palette.current(@scene)==w && @actor.actions.all? { |a| !a.item },'sealed technique refusal retains the menu')
    @actor.skill_seal.clear;magic.note='';magic.instance_variable_set(:@cool_time,nil);@actor.recover_all
    # A3: maintenance runs only at completed native input boundaries.
    profile([row('M',1,1,'skill',magic.id)]);queue;@actor.clear_buffs;stock(item,10)
    support.reset;support.instance_variable_set(:@definitions,[{'actor'=>@actor.id,'kind'=>'item','id'=>item.id}]);support.instance_variable_set(:@master,true)
    open_menu('M');before=$game_party.item_number(item);tap([13]);w=BS2Suite::Palette.current(@scene)
    check($game_party.item_number(item)==before-2 && @actor.instance_variable_get(:@buffs)[2]==2,'completed M choice services due automatic items before restoring the menu')
    check(w && w.item==magic && @actor.actions[0].item==magic && @actor.instance_variable_get(:@action_input_index)==1,'automatic upkeep preserves the queued action and originating menu')
    check(!support.busy? && support.active?,'nested native quick actions finish without disabling or reentering support')
    before=$game_party.item_number(item);@actor.clear_buffs
    30.times { frame;support.tick(@scene) }
    check($game_party.item_number(item)==before,'idle palette frames never trigger hidden maintenance')
    tap([118]);30.times { frame;support.tick(@scene) }
    check($game_party.item_number(item)==before && BS2QoL::Reference.active?(@scene),'F7 inspection also keeps maintenance paused')
    tap([27]);$game_troop.members<<Game_Enemy.new(1,5000);tap([13])
    check(@scene.instance_variable_get(:@enemy_window).active,'multiple enemies keep the native target controller')
    tap([27]);check($game_party.item_number(item)==before && BS2Suite::Palette.current(@scene),'target cancellation returns without performing automatic upkeep')
    tap([13]);tap([49]);w=BS2Suite::Palette.current(@scene)
    check($game_party.item_number(item)==before-2 && w && w.item==magic,'target confirmation services upkeep at the next valid boundary')
    check(@actor.actions[0].item==magic && @actor.actions[1].item==magic,'support never replaces earlier or newly confirmed paid commands')
    $game_troop.members.pop;support.instance_variable_set(:@master,false)
    queue;@actor.clear_buffs;stock(item,6);stock(other,5)
    support.reset;support.instance_variable_set(:@definitions,[{'actor'=>@actor.id,'kind'=>'item','id'=>item.id}]);support.instance_variable_set(:@master,true)
    before=$game_party.item_number(item);manual=$game_party.item_number(other);w=native_item(other);tap([13])
    check($game_party.item_number(item)==before-2 && $game_party.item_number(other)==manual-1,'native instant-item completion also performs bounded automatic upkeep')
    check(w.active && w.item==other && @actor.actions.all? { |a| !a.item },'native support boundary keeps the same ordinary item list and free slot')
    support.instance_variable_set(:@master,false)
    log('result=PASS; checks='+@checks.to_s)
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure
    BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  end
end
