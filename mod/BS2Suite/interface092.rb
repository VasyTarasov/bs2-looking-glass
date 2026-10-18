# encoding: UTF-8
module BS2Suite
  module ShortNotes
    SPECIAL={13=>'Прерывание; уязвимость при успехе',16=>'Сильное прерывание',
      105=>'Прерывание; атака цели↓',106=>'Прерывание; защита цели↓',110=>'Себе: крит +30 п.п.',
      122=>'Себе: точность↑',124=>'Себе: все параметры↑',155=>'Себе: атака +50%',
      308=>'Самоурон; усиление и кровотечение',838=>'Урон выше при малом остатке MP'}.freeze
    def self.enabled?(prefix);Options.get(prefix=='N' ? 'weapon_notes' : 'palette_notes')==1;end
    def self.for_row(row,prefix)
      return '' unless enabled?(prefix) && row[:object]
      return row[:hint].to_s if prefix=='N' && !row[:hint].to_s.empty?
      text=describe(row[:object]);text.size>54 ? text[0,53]+'…' : text
    end
    def self.describe(object)
      return '' unless object
      return SPECIAL[object.id] if object.is_a?(RPG::Skill) && SPECIAL[object.id]
      if object.is_a?(RPG::EquipItem)
        id=WeaponFamilies.root(object.id) if object.is_a?(RPG::Weapon)
        return ArsenalCatalog::NOTES[id].to_s if id && defined?(ArsenalCatalog) && ArsenalCatalog::NOTES[id]
        return object.description.to_s.gsub(/\\[A-Za-z]+\[[^\]]*\]/,'').split(/[\r\n]/).reject { |x| x.empty? }.last.to_s.gsub(/[\[\]]/,'')
      end
      return '' unless object.respond_to?(:effects)
      parts=[]
      object.effects.each do |effect|
        case effect.code
        when 11,12
          label=effect.code==11 ? 'HP' : 'MP';value=[]
          value<<BS2Modules.pct(effect.value1) if effect.value1!=0
          value<<BS2Modules.num(effect.value2) if effect.value2!=0
          parts<<label+' '+value.join(' + ') unless value.empty?
        when 21,22
          state=$data_states[effect.data_id];next unless state && !state.name.to_s.empty?
          chance=effect.value1<1 && effect.code==21 ? ' '+BS2Modules.pct(effect.value1)+' баз.' : ''
          parts<<(effect.code==22 ? 'снять ' : '')+state.name+chance
        when 31,32,33,34
          label=BS2Modules::PARAMS[effect.data_id];next unless label
          parts<<label+({31=>'↑',32=>'↓',33=>' снять усил.',34=>' снять ослаб.'}[effect.code])
        when 44
          parts<<'особый эффект'
        end
      end
      if object.respond_to?(:damage) && object.damage.type!=0
        kind=object.respond_to?(:hit_type) ? ['особый','физ.','маг.'][object.hit_type] : 'урон'
        parts.unshift([3,4].include?(object.damage.type) ? 'лечение' : [5,6].include?(object.damage.type) ? 'поглощение' : kind+' урон')
      end
      side=object.for_user? ? 'Себе: ' : object.for_friend? ? 'Союзникам: ' : object.for_opponent? ? 'Цели: ' : ''
      return side+parts.uniq.take(3).join('; ') unless parts.empty?
      text=object.description.to_s.gsub(/\\[A-Za-z]+\[[^\]]*\]/,'').gsub(/[\r\n]+/,' ').strip
      text.empty? ? 'Особые правила · F7' : text
    end
  end
  if defined?(PaletteWindow)
  class PaletteWindow
    def cycle_group(delta)
      values=@prefix=='N' ? DirectWeapons.groups(@actor) : Semantic.groups(@actor,@prefix)
      numbers=values.map { |g| g[:number] }
      return if numbers.empty?
      index=numbers.index(@group) || (delta>0 ? -1 : 0)
      set_group(numbers[(index+delta)%numbers.size])
    end
    # Horizontal movement has one owner: Palette.update, including Q/E. No cursor double step.
    def cursor_left(wrap=false);end
    def cursor_right(wrap=false);end
    def cursor_pageup;end
    def cursor_pagedown;end
  end
end
end
# New assignments cannot create an invisible second ten inside an existing group.
if BS2Suite.enabled?('semantic_groups')
  module BS2Suite::Semantic
    class << self
      alias bs2092_legacy_mode mode
      def mode(actor)
        value=bs2092_legacy_mode(actor);profile=customs[value]
        profile && profile['entries'].any? { |e| e['prefix']=='N' && (e['page'] || 0)>0 } ? 'progression' : value
      end
      alias bs2092_assign assign
      def assign(actor,prefix,group,digit,object,source=nil,page=0)
        return false unless page==0
        bs2092_assign(actor,prefix,group,digit,object,source,0)
      end
      def migrate_weapon_pages
        changed=false;original=BS2Suite::Store.read('profiles')
        customs.each do |id,profile|
          extra=profile['entries'].select { |e| e['prefix']=='N' && (e['page'] || 0)>0 }
          next if extra.empty?
          candidate=Marshal.load(Marshal.dump(profile));candidate['entries']-=candidate['entries'].select { |e| e['prefix']=='N' && (e['page'] || 0)>0 }
          overflow=false
          extra.group_by { |e| [e['group'],e['page']] }.each do |key,rows|
            free=(1..10).find { |n| !candidate['groups'].has_key?('N'+n.to_s) && !candidate['entries'].any? { |e| e['prefix']=='N' && e['group']==n } }
            unless free;overflow=true;break;end
            behavior=(profile['behaviors'] || {})['N'+key[0].to_s] || (key[0]==1 ? 'now' : 'last')
            (candidate['behaviors'] ||= {})['N'+free.to_s]=behavior
            candidate['groups']['N'+free.to_s]=(profile['groups']['N'+key[0].to_s] || 'Моя группа')+' · продолжение'
            rows.each { |e| e=e.dup;e['group']=free;e['page']=0;candidate['entries']<<e }
          end
          if overflow
            # Preserve the complete profile on disk. Never silently truncate a player's bindings.
            state['active'].each { |actor_id,active| state['active'][actor_id]='progression' if active==id }
            BS2QoL::Hotkeys.notice('Старый профиль N сохранён; для его страниц не хватает свободных групп')
            next
          end
          return unless BS2Suite::Store.write('profiles_before_092',original) if !changed && !original.empty?
          customs[id]=candidate;changed=true
        end
        if changed && !persist
          @customs=nil
          BS2QoL::Hotkeys.notice('Миграция профиля не записана; исходные назначения сохранены')
        end
      end
    end
  end
  BS2Suite::Semantic.migrate_weapon_pages
end
