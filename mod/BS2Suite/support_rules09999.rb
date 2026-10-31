# encoding: UTF-8
# Native wine use and intentional madness tracking; no reserve/limit settings.
class Game_Battler
  alias bs209999_automation_use use_item
  def use_item(item)
    result=bs209999_automation_use(item)
    BS2Suite::BattleSupport.note_use(self,item)
    result
  end
  alias bs209999_madness_apply item_apply
  def item_apply(user,item)
    result=bs209999_madness_apply(user,item)
    if actor? && user.actor? && item.for_friend? && @result.added_states.include?(28)
      @bs2s_intentional_madness=true
    end
    result
  end
  alias bs209999_madness_erase erase_state
  def erase_state(id)
    @bs2s_intentional_madness=false if id==28
    bs209999_madness_erase(id)
  end
  alias bs209999_madness_clear clear_states
  def clear_states
    @bs2s_intentional_madness=false
    bs209999_madness_clear
  end
end
