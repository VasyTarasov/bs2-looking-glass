# encoding: UTF-8
module BS2Suite
  module EquippedUpgrade
    class << self
      attr_reader :count_target,:error
      def parent(output)
        return nil unless output.is_a?(RPG::Weapon)
        recipe=WD_itemsynthesis_ini::W_recipe[output.id]
        return nil unless recipe
        weapons=recipe[1,recipe.size].select { |r| r[0]=='W' }
        return nil unless weapons.size==1 && weapons[0][2]==1
        id=weapons[0][1]
        return nil unless WeaponFamilies.parents[output.id]==id
        $data_weapons[id]
      end
      def slots(old,output)
        return [] if $game_party.in_battle
        rows=[]
        $game_party.members.each do |a|
          a.equips.each_with_index { |e,i| rows<<[a,i] if e==old && a.equip_change_ok?(i) && a.equippable?(output) }
        end
        rows
      end
      def with_count(output)
        previous=@count_target;@count_target=output
        yield
      ensure
        @count_target=previous
      end
      def target(recipe)
        return nil unless recipe
        id=WD_itemsynthesis_ini::W_recipe.index(recipe)
        id && $data_weapons[id]
      end
      def reconnect(value,backup,actor,seen)
        return actor if value.equal?(backup)
        return value if seen[value.object_id]
        seen[value.object_id]=true
        if value.is_a?(Array)
          value.map! { |v| reconnect(v,backup,actor,seen) }
        elsif value.is_a?(Hash)
          pairs=value.map { |k,v| [reconnect(k,backup,actor,seen),reconnect(v,backup,actor,seen)] }
          value.clear;pairs.each { |k,v| value[k]=v }
        elsif !value.is_a?(Module)
          value.instance_variables.each { |k| value.instance_variable_set(k,reconnect(value.instance_variable_get(k),backup,actor,seen)) }
        end
        value
      end
      def craft(scene,number)
        @error=nil;output=scene.instance_variable_get(:@item);old=parent(output)
        return yield unless old
        raise 'Неверное количество' unless number.is_a?(Integer) && number>0
        recipe=scene.instance_variable_get(:@list_window).recipe(output)
        needed=number-$game_party.item_number(old)
        chosen=needed>0 ? slots(old,output).take(needed) : []
        raise 'Экипированное оружие недоступно' if chosen.size<[needed,0].max
        backups=chosen.map { |a,i| [a,Marshal.load(Marshal.dump(a))] }
        inventory={};[:@items,:@weapons,:@armors].each { |k| inventory[k]=Marshal.load(Marshal.dump($game_party.instance_variable_get(k))) }
        gold=$game_party.gold
        expected={}
        chosen.each do |a,i|
          expected[a] ||= a.equips.dup;expected[a][i]=output
          a.instance_variable_get(:@equips)[i].object=nil
          $game_party.gain_item(old,1)
        end
        # Revalidate all recipe materials before native code grants any result.
        recipe[1,recipe.size].each do |kind,id,n|
          obj={'I'=>$data_items,'W'=>$data_weapons,'A'=>$data_armors}[kind][id]
          raise 'Недостаточно материалов' unless obj && $game_party.item_number(obj)>=[n*number,1].max
        end
        raise 'Недостаточно душ' if $game_party.gold<recipe[0]*number
        yield
        chosen.each do |a,i|
          raise 'Не получено улучшенное оружие' unless $game_party.item_number(output)>0
          $game_party.lose_item(output,1)
          a.instance_variable_get(:@equips)[i].object=output
        end
        expected.each do |a,equips|
          a.refresh
          raise 'Улучшение затронуло другие слоты' unless a.equips==equips
        end
        true
      rescue StandardError=>e
        inventory.each { |k,v| $game_party.instance_variable_set(k,v) } if inventory
        $game_party.instance_variable_set(:@gold,gold) unless gold.nil?
        backups.to_a.each do |a,copy|
          a.instance_variables.each { |k| a.remove_instance_variable(k) unless copy.instance_variable_defined?(k) }
          seen={}
          copy.instance_variables.each { |k| a.instance_variable_set(k,reconnect(copy.instance_variable_get(k),copy,a,seen)) }
        end
        @error=e.message;BS2QoL::Hotkeys.notice('Улучшение отменено: '+e.message)
        false
      end
    end
  end
end
class Game_Party
  alias bs2080_real_count item_number
  def item_number(item)
    n=bs2080_real_count(item)
    target=BS2Suite::EquippedUpgrade.count_target
    if target && item==BS2Suite::EquippedUpgrade.parent(target)
      n+=BS2Suite::EquippedUpgrade.slots(item,target).size
    end
    n
  end
end
class Window_ItemSynthesisList
  alias bs2080_materials have_mat?
  def have_mat?(recipe)
    BS2Suite::EquippedUpgrade.with_count(BS2Suite::EquippedUpgrade.target(recipe)) { bs2080_materials(recipe) }
  end
end
class Scene_ItemSynthesis
  alias bs2080_max_buy max_buy
  def max_buy
    BS2Suite::EquippedUpgrade.with_count(@item) { bs2080_max_buy }
  end
  alias bs2080_syntetic do_syntetic
  def do_syntetic(number)
    BS2Suite::EquippedUpgrade.craft(self,number) { bs2080_syntetic(number) }
  end
end

class Window_ItemSynthesisMaterial
  alias bs2080_material_display draw_material_info
  def draw_material_info(x,y)
    BS2Suite::EquippedUpgrade.with_count(BS2Suite::EquippedUpgrade.target(@recipe)) { bs2080_material_display(x,y) }
  end
end
