# encoding: UTF-8
module BS2Suite
  module EquipmentDetails
    def self.view(actor,set)
      copy=Marshal.load(Marshal.dump(actor))
      target=BS2Modules::Loadouts.expected(actor,set)
      copy.instance_variable_get(:@equips).each_with_index { |entry,i| entry.object=target[i] }
      resisted=copy.state_resist_set
      copy.instance_variable_set(:@states,copy.instance_variable_get(:@states).reject { |id| resisted.include?(id) })
      copy
    end
    def self.lines(actor,other=nil)
      after=other || actor
      pair=lambda { |a,b| other && a!=b ? a.to_s+' → '+b.to_s : b.to_s }
      pct=lambda { |v| BS2Modules.pct(v) }
      rows=['Итог с текущими состояниями, уровнем и оружием. Стрелка: сейчас → комплект.',
        'HP '+actor.hp.to_s+' / '+actor.mhp.to_s+' · MP '+actor.mp.to_s+' / '+actor.mmp.to_s]
      (0..7).each { |i| rows<<BS2Modules::PARAMS[i]+': '+pair.call(actor.param(i),after.param(i)) }
      rows<<'';rows<<'Боевые коэффициенты'
      %w(hit eva cri cev mev mrf cnt hrg mrg trg tgr grd rec pha mcr tcr pdr mdr fdr exr).each_with_index do |key,i|
        labels=['Попадание','Уклонение','Крит','Защита от крита','Маг. уклонение','Отражение','Контратака','Реген. HP','Реген. MP','Реген. TP','Вероятность цели','Множитель защиты','Получаемое лечение','Эффект предметов','Расход MP','Получение TP','Физ. урон','Маг. урон','Урон пола','Опыт']
        a=actor.send(key);b=after.send(key)
        neutral=(i<10 ? 0.0 : 1.0)
        next if (a-neutral).abs<0.00001 && (b-neutral).abs<0.00001
        rows<<labels[i]+': '+pair.call(pct.call(a),pct.call(b))
      end
      translator=BS2QoL::ReferenceCard.allocate;translator.instance_variable_set(:@language,:ru)
      rows<<'';rows<<'Сопротивления элементам (получаемый множитель)'
      $data_system.elements.each_with_index do |label,id|
        next if id==0 || label.to_s.empty?
        a=actor.element_rate(id);b=after.element_rate(id)
        next if a==1 && b==1
        rows<<translator.element(id)+': '+pair.call(pct.call(a),pct.call(b))
      end
      rows<<'';rows<<'Состояния (восприимчивость, не готовый шанс)'
      ids=(actor.feature_objects+after.feature_objects).map { |o| o.features.select { |f| [13,14].include?(f.code) }.map { |f| f.data_id } }.flatten.uniq.sort
      ids.each do |id|
        state=$data_states[id];next unless state
        value=lambda { |who| who.state_resist?(id) ? 'иммунитет' : pct.call(who.state_rate(id)) }
        rows<<state.name+': '+pair.call(value.call(actor),value.call(after))
      end
      rows<<'Итоговый шанс наложения также зависит от приёма, попадания, удачи и особых правил.'
      rows
    end
    def self.open(scene,origin,actor,set=nil,title=nil)
      return false unless actor
      other=set && view(actor,set)
      lines=lines(actor,other)
      if set
        available=BS2Modules::Loadouts.preview(actor,set)
        lines+=['','Доступность применения']+(available[:ok] ? ['Комплект доступен.'] : available[:errors])
      end
      object=RPG::Skill.new;object.name=title || (set ? 'Комплект: '+set[:name] : 'Текущая экипировка')
      window=EquipmentDetailsWindow.new(object,actor)
      window.report_lines=lines;window.report_actor=other || actor
      window.rebuild
      origin.deactivate
      scene.instance_variable_set(:@bs2q_reference_window,window)
      scene.instance_variable_set(:@bs2q_reference_origin,origin)
      BS2QoL::Keyboard.consume
      true
    rescue StandardError=>e
      BS2QoL::Hotkeys.notice('Расчёт недоступен: '+e.message);false
    end
  end
  class EquipmentDetailsCard
    attr_reader :sections,:section_names,:language,:title
    def initialize(title,actor,lines)
      @title=title;@language=:ru
      sources=['Условные эффекты и эффекты начала боя перечислены отдельно; итог слева рассчитан на текущее состояние.']
      actor.equips.compact.each do |o|
        detail=BS2QoL::PracticalCard.new(o,actor,:ru)
        sources+=['',o.name]+detail.sections.flatten
      end
      @sections=[lines,sources];@section_names=['Итог / сравнение','Свойства вещей']
    end
    def t(a,b);a;end
  end
  class EquipmentDetailsWindow < Window_BS2QReference
    attr_accessor :report_lines,:report_actor
    def rebuild
      @card=EquipmentDetailsCard.new(@object.name,@report_actor || @actor,@report_lines || EquipmentDetails.lines(@actor))
      @section=[@section,@card.sections.size-1].min;@wrapped={};@offset=0;refresh
    end
  end
end
module BS2QoL::Hotkeys
  class << self
    alias bs2080_equipment_handle handle
    def handle(window)
      scene=SceneManager.scene
      if BS2QoL::Keyboard.first=='F7' && !BS2QoL::Reference.active?(scene)
        if scene.is_a?(Scene_Equip) && !window.is_a?(Window_EquipItem)
          return BS2Suite::EquipmentDetails.open(scene,window,scene.instance_variable_get(:@actor))
        elsif defined?(BS2Modules::LoadoutsScene) && scene.is_a?(BS2Modules::LoadoutsScene) && !scene.instance_variable_get(:@name_input) && !scene.instance_variable_get(:@confirm).active
          return BS2Suite::EquipmentDetails.open(scene,window,scene.instance_variable_get(:@actor),scene.set)
        end
      end
      bs2080_equipment_handle(window)
    end
  end
end
