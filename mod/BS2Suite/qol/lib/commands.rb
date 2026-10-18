class Window_ActorCommand
  alias bs2q_original_make_command_list make_command_list
  def make_command_list
    bs2q_original_make_command_list
    numbers={:attack=>'1',:skill=>'2',:guard=>'3',:item=>'4',:escape=>'5',:equip_change=>'6'}
    @list.each do |row|
      number=numbers[row[:symbol]]
      actions={:attack=>:attack,:skill=>:skills,:guard=>:guard,:item=>:items,:escape=>:escape,:equip_change=>:equip}
      number=BS2Suite::Keys.token(actions[row[:symbol]]) if actions[row[:symbol]]
      next unless number
      name=row[:name]
      row[:name]=name.is_a?(Array) ? [number+' '+name[0].to_s,name[1]] : number+' '+name.to_s
    end
    set_position if @actor && respond_to?(:set_position)
  end
  alias bs2q_keys_original_handling process_handling
  def process_handling
    return if open? && active && BS2QoL::Hotkeys.handle(self)
    bs2q_keys_original_handling
  end
end

