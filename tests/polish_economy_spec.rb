# encoding: UTF-8
# Compare batch use with the game's actual common-event interpreter.
rgss_main do
  @checks=0;@failures=[]
  def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
  def check(v,s);@checks+=1;@failures<<s unless v;log((v ? 'PASS ' : 'FAIL ')+s);end
  class EconomyOracle < Game_Interpreter
    attr_accessor :quantity
    def command_101
      @index+=1 while next_event_code==401
      true
    end
    def command_102;@branch[@indent]=0;true;end
    def command_103;$game_variables[@params[0]]=@quantity;true;end
  end
  def setup(item,n,selected=2)
    DataManager.init;DataManager.setup_new_game
    $game_party.remove_actor(1);$game_party.add_actor(2)
    actor=$game_party.leader;actor.change_class(1);actor.change_level(70,false);actor.clear_equipments;actor.recover_all
    $game_variables[14]=selected;$game_variables[38]=80
    $game_party.gain_item(item,n);actor
  end
  def result(actor,item)
    [actor.instance_variable_get(:@param_plus).dup,actor.hp,actor.mp,$game_party.gold,$game_variables[38],$game_party.item_number(item)]
  end
  def native_use(actor,item,n,currency=false)
    (currency ? n : 1).times do
      actor.use_item(item);$game_temp.clear_common_event
      item.effects.select { |e| e.code==44 }.each do |e|
        interpreter=EconomyOracle.new;interpreter.quantity=n
        interpreter.setup($data_common_events[e.data_id].list)
        frames=0
        while interpreter.running?
          interpreter.update;frames+=1;raise 'native event did not finish' if frames>1000
        end
      end
    end
  end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'Soul common-event oracle and upgrade rollback' }
    DataManager.init;DataManager.setup_new_game
    ids=[9,10,11,12,13,14,15,16,17,79]
    ids.each do |id|
      item=$data_items[id];actor=setup(item,2)
      native_use(actor,item,2)
      expected=result(actor,item);display=(101..108).map { |i| $game_variables[i] }
      check(expected[-1]==0,'native colored-soul event consumes the chosen two items '+id.to_s) if (9..16).include?(id)
      actor=setup(item,2)
      mode=[17,79].include?(id) ? :black : :colors
      check(BS2Suite::SoulBatch.apply(mode),'batch applies native soul '+id.to_s)
      check(result(actor,item)==expected,'native stats, resources, SEN and stock match '+id.to_s)
      if (9..16).include?(id)
        check((101..108).map { |i| $game_variables[i] }==display,'native displayed-stat cache matches '+id.to_s)
      end
    end
    item=$data_items.compact.find { |i| BS2Suite::SoulBatch.currency_value(i) }
    actor=setup(item,2,0);native_use(actor,item,2,true);expected=result(actor,item)
    actor=setup(item,2,0)
    check(BS2Suite::SoulBatch.apply(:currency),'currency batch does not require a stat-soul recipient')
    check(result(actor,item)==expected,'currency batch matches native item use without selected actor')
    actor=setup(item,2,0);$game_party.gain_gold($game_party.max_gold)
    before=result(actor,item)
    check(!BS2Suite::SoulBatch.apply(:currency) && result(actor,item)==before,'currency overflow preserves souls and stock')
    # Fail after the native synthesis path has already granted an output.
    DataManager.init;DataManager.setup_new_game
    actor=$game_party.leader;actor.change_class(1);actor.change_level(70,false);actor.clear_equipments
    family=BS2Suite::FamilyInventory
    pair=BS2Suite::WeaponFamilies.parents.find { |child,parent| actor.equippable?($data_weapons[parent]) && actor.equippable?($data_weapons[child]) }
    output=$data_weapons[pair[0]];old=$data_weapons[pair[1]]
    $game_party.gain_item(old,1);actor.change_equip(0,old)
    recipe=WD_itemsynthesis_ini::W_recipe[output.id]
    recipe[1,recipe.size].each do |kind,id,n|
      data={'I'=>$data_items,'W'=>$data_weapons,'A'=>$data_armors}[kind]
      next if kind=='W' && id==old.id
      $game_party.gain_item(data[id],n)
    end
    $game_party.gain_gold(recipe[0]);family.instance_variable_set(:@pending,false)
    before=Marshal.dump([actor,$game_party.instance_variable_get(:@items),$game_party.instance_variable_get(:@weapons),$game_party.instance_variable_get(:@armors),$game_party.gold])
    scene=Scene_ItemSynthesis.allocate;scene.instance_variable_set(:@item,output)
    list=Object.new
    def list.recipe(output);WD_itemsynthesis_ini::W_recipe[output.id];end
    scene.instance_variable_set(:@list_window,list)
    def scene.bs2080_syntetic(number)
      $game_party.gain_item(@item,number)
      raise IOError,'injected failure after output grant'
    end
    check(scene.do_syntetic(1)==false,'failed upgrade is rejected')
    after=Marshal.dump([actor,$game_party.instance_variable_get(:@items),$game_party.instance_variable_get(:@weapons),$game_party.instance_variable_get(:@armors),$game_party.gold])
    check(before==after,'failed upgrade restores actor, materials, gold and output')
    check(!family.pending?,'failed upgrade restores pending cleanup state')
    log('result='+(@failures.empty? ? 'PASS' : 'FAIL')+'; checks='+@checks.to_s+'; failures='+@failures.size.to_s)
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure
    BS2Suite::SteamBridge.stop if defined?(BS2Suite::SteamBridge)
  end
end
