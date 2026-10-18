# encoding: UTF-8
module BS2Suite::ArmorFamilies094
  GROUPS=[["Кольцо Жизни",[79, 159, 160, 161]],["Кольцо Стойкости",[80, 162, 163, 164]],["Кольцо Дурного Глаза",[81, 181, 182, 183]],["Кольцо Стальной Защиты",[82, 187, 188, 189]],["Волшебное Кольцо с Камнем",[86, 190, 191, 192]],["Кольцо Грани",[91, 199, 200, 201]],["Кольцо с Шершнем",[93, 196, 197, 198]],["Кольцо Стены",[94, 202, 203, 204]],["Кольцо Богини",[95, 184, 185, 186]],["Мокрый",[96, 171, 172, 173]],["Мягкий",[97, 174, 175, 176]],["Кольцо Бога Ветра",[98, 205, 206, 207]],["Кольцо Колдовства",[99, 208, 209, 210]],["Пустое Кольцо",[108, 177, 178, 179]],["Кольцо Лондиниума",[118, 211, 212, 213]],["Кольцо Снайпера",[120, 193, 194, 195]],["Кольцо Греха",[149, 223, 224, 225]]].freeze
  def self.parents
    return @parents if @parents
    @parents={}
    GROUPS.each do |name,ids|
      base=$data_armors[ids[0]]
      next unless base && ids.each_with_index.all? { |id,n| a=$data_armors[id];a && a.etype_id==base.etype_id && a.atype_id==base.atype_id && a.name==name+(n==0 ? '' : '+'+n.to_s) }
      ids.each_cons(2) { |a,b| @parents[b]=a }
    end
    @parents
  end
  def self.ancestor?(a,b)
    seen=[]
    while parents[b] && !seen.include?(b)
      seen<<b;b=parents[b];return true if a==b
    end
    false
  end
  def self.depth(id)
    n=0;seen=[]
    while parents[id] && !seen.include?(id);seen<<id;id=parents[id];n+=1;end
    n
  end
end
if defined?(BS2Modules::Loadouts)
module BS2Modules::Loadouts
  class << self
    alias bs2094_armor_item item
    def item(id)
      original=bs2094_armor_item(id);return original unless original
      owned=($game_party.armors+$game_party.members.map { |a| a.equips.select { |e| e.is_a?(RPG::Armor) } }.flatten).uniq
      return original if owned.include?(original)
      choices=owned.select { |a| BS2Suite::ArmorFamilies094.ancestor?(id,a.id) }
      choices.max_by { |a| BS2Suite::ArmorFamilies094.depth(a.id) } || original
    end
  end
end
end
