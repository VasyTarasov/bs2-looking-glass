# encoding: UTF-8
module BS2Suite::WeaponFamilies
  class << self
    def parents
      return @parents if @parents
      @parents={}
      if defined?(WD_itemsynthesis_ini::W_recipe)
        WD_itemsynthesis_ini::W_recipe.each_with_index do |recipe,id|
          next unless recipe.is_a?(Array) && $data_weapons[id]
          weapons=recipe.select { |r| r.is_a?(Array) && r[0]=='W' }
          next unless weapons.size==1 && weapons[0][2]==1
          parent=weapons[0][1];a=$data_weapons[parent];b=$data_weapons[id]
          @parents[id]=parent if a && parent!=id && a.wtype_id==b.wtype_id
        end
      end
      @parents
    end
    def root(id)
      seen=[]
      while parents[id] && !seen.include?(id)
        seen<<id;id=parents[id]
      end
      id
    end
    def depth(id)
      seen=[]
      while parents[id] && !seen.include?(id)
        seen<<id;id=parents[id]
      end
      seen.size
    end
    def owned(actor)
      ($game_party.weapons+(actor ? actor.equips.select { |x| x.is_a?(RPG::Weapon) } : [])).uniq
    end
    def resolve(id,actor=nil,skill_id=nil)
      choices=owned(actor).select { |w| root(w.id)==root(id) }
      choices.select! { |w| w.features.any? { |f| f.code==43 && f.data_id==skill_id } } if skill_id
      exact=choices.find { |w| w.id==id }
      exact || choices.sort_by { |w| [-depth(w.id),w.id] }.first
    end
    def grants(skill_id)
      $data_weapons.compact.select { |w| w.features.any? { |f| f.code==43 && f.data_id==skill_id } }
    end
  end
end
