# encoding: UTF-8
module BS2Suite
  module SoulBatch
    COLORS={9=>[0,20],10=>[1,10],11=>[2,2],12=>[3,2],13=>[6,2],14=>[4,2],15=>[5,2],16=>[7,2]}.freeze
    EVENTS={9=>223,10=>224,11=>225,12=>226,13=>227,14=>228,15=>229,16=>230,17=>221,79=>222}.freeze
    def self.actor
      value=$game_variables[14]
      value.is_a?(Integer) && value>0 ? $game_actors[value] : nil
    end
    def self.valid?(item,event_id)
      item && item.itype_id==1 && item.effects.size==1 && item.effects[0].code==44 && item.effects[0].data_id==event_id
    end
    def self.currency_value(item)
      return nil unless item && item.itype_id==1 && item.consumable && item.damage.none? && item.effects.size==1
      effect=item.effects[0];return nil unless effect.code==44 && ((19..29).include?(effect.data_id) || [216,217].include?(effect.data_id))
      event=$data_common_events[effect.data_id];return nil unless event
      list=event.list.reject { |c| c.code==0 }
      return nil unless list.size==1 && list[0].code==125 && list[0].parameters[0,2]==[0,0]
      n=list[0].parameters[2];n.is_a?(Integer) && n>0 ? n : nil
    end
    def self.plan(mode)
      result=[]
      $game_party.items.each do |item|
        n=$game_party.item_number(item);next unless n>0 && item.itype_id==1
        if mode==:currency
          value=currency_value(item);result<<[item,n,value] if value
        elsif (COLORS.has_key?(item.id) || (mode==:black && [17,79].include?(item.id))) && valid?(item,EVENTS[item.id])
          result<<[item,n,nil]
        end
      end
      result
    end
    def self.apply(mode)
      return false if $game_party.in_battle || $game_message.busy? || $game_map.interpreter.running?
      who=actor;return false unless who && $game_party.members.include?(who)
      rows=plan(mode);return false if rows.empty?
      gain=rows.inject(0) { |sum,r| sum+(r[2] || 0)*r[1] }
      return false if mode==:currency && $game_party.gold+gain>$game_party.max_gold
      inventory=Marshal.load(Marshal.dump($game_party.instance_variable_get(:@items)))
      params=who.instance_variable_get(:@param_plus).dup;sen=$game_variables[38];gold=$game_party.gold
      rows.each do |item,n,value|
        raise 'Inventory changed' unless $game_party.item_number(item)==n
        $game_party.lose_item(item,n)
        if value
          $game_party.gain_gold(value*n)
        elsif COLORS[item.id]
          id,amount=COLORS[item.id];who.add_param(id,amount*n)
        else
          factor=item.id==79 ? 3 : 1
          who.add_param(0,10*factor*n);who.add_param(1,5*factor*n)
          (2..7).each { |id| who.add_param(id,factor*n) }
          $game_variables[38]-=10*factor*n
        end
      end
      true
    rescue StandardError
      $game_party.instance_variable_set(:@items,inventory) if inventory
      who.instance_variable_set(:@param_plus,params) if who && params
      who.refresh if who && params
      $game_variables[38]=sen unless sen.nil?
      $game_party.instance_variable_set(:@gold,gold) unless gold.nil?
      false
    end
  end
  class SoulChoices < Window_Command
    def window_width;Graphics.width-32;end
    def visible_line_number;4;end
    def make_command_list
      add_command('Все обычные цветные души',:colors)
      add_command('Цветные и чёрные души (понизит SEN)',:black)
      add_command('Все денежные души (без ключевых)',:currency)
      add_command('Отмена',:cancel)
    end
  end
  class SoulConfirm < Window_Command
    def initialize(mode)
      @mode=mode;super(16,100);self.z=460;BS2Modules.style(self);select(1)
    end
    def window_width;Graphics.width-32;end
    def visible_line_number;2;end
    def make_command_list
      rows=SoulBatch.plan(@mode);n=rows.inject(0) { |s,r| s+r[1] }
      delta=rows.inject(0) { |s,r| s+([17,79].include?(r[0].id) ? (r[0].id==79 ? 30 : 10)*r[1] : 0) }
      amount=rows.inject(0) { |s,r| s+(r[2] || 0)*r[1] }
      suffix=@mode==:black ? ' · SEN −'+delta.to_s : @mode==:currency ? ' → '+amount.to_s+' душ' : ''
      add_command('Использовать '+n.to_s+' душ'+suffix,:confirm,n>0)
      add_command('Отмена',:cancel)
    end
  end
end
class Window_ItemCategory
  alias bs2080_soul_commands make_command_list
  def make_command_list
    bs2080_soul_commands
    add_command('Съесть души',:bs2_souls) if SceneManager.scene.is_a?(Scene_Item)
  end
end
class Window_ItemCategory
  alias bs2080_category_columns col_max
  def col_max;SceneManager.scene.is_a?(Scene_Item) ? 5 : bs2080_category_columns;end
end
class Scene_Item
  alias bs2080_soul_category create_category_window
  def create_category_window
    bs2080_soul_category
    @category_window.set_handler(:bs2_souls,method(:bs2080_soul_dialog))
  end
  def bs2080_soul_dialog
    @category_window.deactivate;@item_window.deactivate
    @bs2080_soul_menu=BS2Suite::SoulChoices.new(16,72);@bs2080_soul_menu.z=450
    BS2Modules.style(@bs2080_soul_menu)
    [:colors,:black,:currency].each { |mode| @bs2080_soul_menu.set_handler(mode,lambda { bs2080_confirm_souls(mode) }) }
    @bs2080_soul_menu.set_handler(:cancel,method(:bs2080_close_souls))
    @help_window.set_text("Весь запас выбранного вида; чёрные души меняют SEN.\nКлючевые и особые души исключены.")
  end
  def bs2080_confirm_souls(mode)
    @bs2080_soul_menu.deactivate
    @bs2080_soul_confirm=BS2Suite::SoulConfirm.new(mode)
    @bs2080_soul_confirm.set_handler(:cancel,lambda { @bs2080_soul_confirm.dispose;@bs2080_soul_confirm=nil;@bs2080_soul_menu.activate })
    @bs2080_soul_confirm.set_handler(:confirm,lambda {
      okay=BS2Suite::SoulBatch.apply(mode)
      okay ? Sound.play_use_item : Sound.play_buzzer
      bs2080_close_souls
      @help_window.set_text(okay ? 'Души использованы.' : 'Не применено: нет душ, выбранного персонажа или места для валюты.')
    })
  end
  def bs2080_close_souls
    [@bs2080_soul_menu,@bs2080_soul_confirm].compact.each { |w| w.dispose unless w.disposed? }
    @bs2080_soul_menu=nil;@bs2080_soul_confirm=nil
    @category_window.select(0);@item_window.category=:item;@item_window.refresh;@category_window.activate
  end
end
