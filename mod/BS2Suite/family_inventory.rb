# encoding: UTF-8
module BS2Suite
  module FamilyInventory
    class << self
      def paused?;@busy || @suspended.to_i>0;end
      def suspend
        @suspended=@suspended.to_i+1
        yield
      ensure
        @suspended-=1
      end
      def ancestor?(old_id,new_id)
        return false if old_id==new_id
        seen=[];id=new_id
        while WeaponFamilies.parents[id] && !seen.include?(id)
          seen<<id;id=WeaponFamilies.parents[id]
          return true if id==old_id
        end
        false
      end
      def normalize
        entered=false
        return if paused? || !$game_party || !$data_weapons
        if $game_party.in_battle;@pending=true;return;end
        @busy=true;entered=true;removed=0
        inventory=Marshal.load(Marshal.dump($game_party.instance_variable_get(:@weapons)))
        armor_inventory=Marshal.load(Marshal.dump($game_party.instance_variable_get(:@armors)))
        backups=$game_party.members.map { |a| [a,Marshal.load(Marshal.dump(a))] }
        # Only linear ancestors are obsolete. Alternative recipe branches remain distinct.
        $game_party.members.each do |actor|
          actor.equips.each_with_index do |old,slot|
            next unless old.is_a?(RPG::Weapon) && actor.equip_change_ok?(slot)
            best=$game_party.weapons.select { |w| ancestor?(old.id,w.id) && actor.equippable?(w) }.max_by { |w| WeaponFamilies.depth(w.id) }
            actor.change_equip(slot,best) if best
          end
        end
        equipped=$game_party.members.map { |a| a.equips.select { |w| w.is_a?(RPG::Weapon) } }.flatten
        owned=($game_party.weapons+equipped).uniq
        $game_party.weapons.each do |old|
          next unless owned.any? { |best| ancestor?(old.id,best.id) }
          count=$game_party.instance_variable_get(:@weapons)[old.id].to_i
          next if count<=0
          $game_party.lose_item(old,count);removed+=count
        end
        if defined?(BS2Suite::ArmorFamilies094)
          equipped_armor=$game_party.members.map { |a| a.equips.select { |e| e.is_a?(RPG::Armor) } }.flatten
          armor_owned=($game_party.armors+equipped_armor).uniq
          $game_party.armors.each do |old|
            next unless armor_owned.any? { |best| BS2Suite::ArmorFamilies094.ancestor?(old.id,best.id) }
            count=$game_party.item_number(old);$game_party.lose_item(old,count);removed+=count
          end
        end
        # The inventory contains at most one spare copy of an equipment entry.
        # Equipped copies are retained, including identical rings and ally gear.
        ($game_party.weapons+$game_party.armors).each do |item|
          excess=$game_party.item_number(item)-1
          if excess>0;$game_party.lose_item(item,excess);removed+=excess;end
        end
        favorites=BS2QoL::Preferences.ids(:weapon)
        updated=favorites.map do |id|
          next id if equipped.any? { |weapon| weapon.id==id }
          best=owned.select { |weapon| ancestor?(id,weapon.id) }.max_by { |weapon| WeaponFamilies.depth(weapon.id) }
          best ? best.id : id
        end.uniq
        if updated!=favorites
          BS2QoL::Preferences.lists[:weapon]=updated
          BS2QoL::Preferences.persist
        end
        @pending=false;@last_error=nil
        BS2QoL::Hotkeys.notice('Убраны дубли / младшие версии снаряжения: '+removed.to_s) if removed>0
        removed
      rescue StandardError=>e
        $game_party.instance_variable_set(:@weapons,inventory) if inventory
        $game_party.instance_variable_set(:@armors,armor_inventory) if armor_inventory
        backups.to_a.each do |actor,copy|
          actor.instance_variables.each { |key| actor.remove_instance_variable(key) unless copy.instance_variable_defined?(key) }
          seen={}
          copy.instance_variables.each { |key| actor.instance_variable_set(key,reconnect(copy.instance_variable_get(key),copy,actor,seen)) }
        end
        # Retry on the next inventory operation/load, never on every graphics frame.
        @pending=false
        message='Объединение оружия отложено: '+e.message
        BS2QoL::Hotkeys.notice(message) unless message==@last_error
        @last_error=message
        false
      ensure
        @busy=false if entered
      end
      def reconnect(value,copy,actor,seen)
        return actor if value.equal?(copy)
        return value if seen[value.object_id]
        seen[value.object_id]=true
        if value.is_a?(Array)
          value.map! { |v| reconnect(v,copy,actor,seen) }
        elsif value.is_a?(Hash)
          pairs=value.map { |k,v| [reconnect(k,copy,actor,seen),reconnect(v,copy,actor,seen)] }
          value.clear;pairs.each { |k,v| value[k]=v }
        elsif !value.is_a?(Module)
          value.instance_variables.each { |k| value.instance_variable_set(k,reconnect(value.instance_variable_get(k),copy,actor,seen)) }
        end
        value
      end
      def pending?;@pending;end
      def request;@pending=true;end
    end
  end
end
class Game_Party
  alias bs2091_family_gain gain_item
  def gain_item(item,amount,include_equip=false)
    result=bs2091_family_gain(item,amount,include_equip)
    # gain_item is also called halfway through trade_item_with_party and refresh.
    # Defer to a completed UI/event boundary instead of changing a half-finished trade.
    BS2Suite::FamilyInventory.request if item.is_a?(RPG::EquipItem) && amount>0
    result
  end
end
class Scene_ItemSynthesis
  alias bs2091_family_craft do_syntetic
  def do_syntetic(number)
    result=BS2Suite::FamilyInventory.suspend { bs2091_family_craft(number) }
    BS2Suite::FamilyInventory.normalize unless result==false
    result
  end
end
module DataManager
  class << self
    alias bs2091_family_extract extract_save_contents
    def extract_save_contents(contents)
      bs2091_family_extract(contents)
      BS2Suite::FamilyInventory.normalize
    end
  end
end
class Scene_Map
  alias bs2091_family_map_start start
  def start
    bs2091_family_map_start
    BS2Suite::FamilyInventory.normalize
  end
end
class Scene_Base
  alias bs2091_family_update update_basic
  def update_basic
    bs2091_family_update
    BS2Suite::FamilyInventory.normalize if BS2Suite::FamilyInventory.pending? && !$game_party.in_battle
  end
end
class Scene_MenuBase
  alias bs2091_family_menu start
  def start
    BS2Suite::FamilyInventory.normalize if BS2Suite::FamilyInventory.pending?
    bs2091_family_menu
  end
end
