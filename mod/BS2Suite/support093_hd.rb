# encoding: UTF-8
module BS2Suite::HDDisplay
  class << self
    alias bs2093_palette_rows palette_rows
    def palette_rows(window)
      rows=bs2093_palette_rows(window)
      key=BS2Suite::Keys.token(:Z)
      hint=window.prefix=='N' ? key+' — выделенное оружие последним' : key+' — авто выбранного предмета / Gun Break'
      rows<<row('D',hint) if window.group && !window.assignment && window.transition.empty? && (window.prefix=='N' || (window.prefix=='B' && BS2Suite::BattleSupport.eligible?(window.item)) || (window.prefix=='V' && BS2Suite::BattleSupport.gunbreak?(window.item)))
      rows
    end
    alias bs2093_battle_rows battle_rows
    def battle_rows(scene)
      rows=bs2093_battle_rows(scene)
      support=BS2Suite::BattleSupport
      rows<<row('H',support.label)
      if support.active? && support.hero && BS2Suite::Options.get('experimental_support')==1
        units=$game_troop.alive_members.reject { |e| e.hidden? }
        text=units.take(4).map { |target| target.name+': '+support.reserve(target,:buff).to_s }.join(' · ')
        rows+=wrap_lines(['Запас обновления по наблюдениям: '+text]).map { |line| row('D',line) } unless text.empty?
      end
      rows
    end
  end
end
