# encoding: UTF-8
module BS2Suite::HDDisplay
  class << self
    alias bs2093_palette_rows palette_rows
    def palette_rows(window)
      rows=bs2093_palette_rows(window)
      key=BS2Suite::Keys.token(:Z)
      hint=window.prefix=='N' ? key+' — выделенное оружие последним' : key+' — авто выбранного предмета / Gun Break'
      rows<<row('D',hint) if window.group && !window.assignment && window.transition.empty? && (window.prefix=='N' || (window.prefix=='B' && BS2Suite::SupportState.eligible?(window.item)) || (window.prefix=='V' && BS2Suite::SupportState.gunbreak?(window.item)))
      rows
    end
    alias bs2093_battle_rows battle_rows
    def battle_rows(scene)
      rows=bs2093_battle_rows(scene)
      support=BS2Suite::SupportState
      rows<<row('H',support.label) if support.active?
      rows
    end
  end
end
