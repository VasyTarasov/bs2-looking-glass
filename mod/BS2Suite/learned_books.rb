# encoding: UTF-8
module BS2Suite::Books
  def self.skills(item)
    return [] unless item.is_a?(RPG::Item)
    item.effects.select { |e| e.code==43 && $data_skills[e.data_id] }.map { |e| $data_skills[e.data_id] }.uniq
  end
  def self.status(item,actor)
    ids=skills(item);return nil if ids.empty? || !actor
    count=ids.count { |s| actor.skill_learn?(s) }
    count==ids.size ? :learned : count>0 ? :partial : :new
  end
  def self.description(item,actor)
    list=skills(item);return '' if list.empty? || !actor
    actor.name+': '+list.map { |s| (actor.skill_learn?(s) ? '✓ ' : '○ ')+s.name }.join(', ')
  end
end
class Window_Base
  alias bs2suite_book_name draw_item_name
  def draw_item_name(item,x,y,enabled=true,width=172)
    actor=instance_variable_get(:@actor)
    actor=$game_party.menu_actor unless actor.is_a?(Game_Actor)
    status=BS2Suite::Books.status(item,actor)
    return bs2suite_book_name(item,x,y,enabled,width) unless status
    bs2suite_book_name(item,x+30,y,enabled,width-30)
    change_color(status==:learned ? text_color(3) : system_color,enabled)
    draw_text(x,y,30,line_height,status==:learned ? '✓' : status==:partial ? '½' : '○')
  end
end
class Window_Help
  alias bs2suite_book_help set_item
  def set_item(item)
    bs2suite_book_help(item)
    info=BS2Suite::Books.description(item,$game_party.menu_actor)
    set_text(info+"\n"+@text.to_s) unless info.empty?
  end
end
