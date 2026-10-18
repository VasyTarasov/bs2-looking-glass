# encoding: UTF-8
module BS2Suite::Sound
  def self.volume(channel,value);(value*BS2Suite::Options.get(channel)/100.0).round;end
  def self.refresh
    [RPG::BGM.last,RPG::BGS.last].each { |track| track.replay if track && !track.name.empty? }
  end
end
module Audio
  class << self
    [:bgm,:bgs,:me,:se].each do |channel|
      original=('bs2suite_'+channel.to_s+'_play').to_sym
      alias_method(original,(channel.to_s+'_play').to_sym)
      define_method((channel.to_s+'_play').to_sym) do |*args|
        values=args.dup;values[1]=BS2Suite::Sound.volume(channel.to_s,values[1] || 100)
        send(original,*values)
      end
    end
  end
end
