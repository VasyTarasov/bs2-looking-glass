# encoding: UTF-8
rgss_main do
  begin
    File.open('test_result.txt','w') { |f| f.puts 'bounded interaction catalogue '+BS2Suite::VERSION }
    DataManager.init;DataManager.setup_new_game
    class HighlightEventView
      attr_reader :id
      def initialize(id,page);@id=id;@page=page;end
      def transparent;false;end
      def opacity;255;end
      def character_name;@page.graphic.character_name;end
      def tile_id;@page.graphic.tile_id;end
    end
    counts=Hash.new(0);pages=0;maps=0
    world=Marshal.dump([$game_variables,$game_switches,$game_self_switches,$game_party,$game_actors]);srand(992);expected=rand;srand(992)
    Dir.glob('Data/Map[0-9]*.rvdata2').each do |file|
      map=load_data(file);maps+=1
      map.events.each do |id,event|
        event.pages.each do |page|
          next unless [0,1,2].include?(page.trigger)
          pages+=1;yes,why=BS2Suite::InteractionHighlight.classify(HighlightEventView.new(id,page));counts[why]+=1
          raise 'Analyzer error on catalogue page' if why==:analysis_error
        end
      end
      GC.start if maps%30==0
    end
    raise 'Insufficient corpus' unless maps>=400 && pages>=20000
    raise 'Read-only violation' unless world==Marshal.dump([$game_variables,$game_switches,$game_self_switches,$game_party,$game_actors]) && rand==expected
    File.open('highlight_counts.txt','w') { |f| f.puts 'maps='+maps.to_s;f.puts 'pages='+pages.to_s;counts.each { |key,value| f.puts key.to_s+'='+value.to_s } }
    File.open('test_result.txt','a') { |f| f.puts 'PASS all '+pages.to_s+' interactive event pages classify without interpreter/script execution or world/RNG changes';f.puts 'result=PASS; checks=2' }
  rescue Exception=>e
    File.open('test_result.txt','a') { |f| f.puts 'result=FAIL; '+e.class.to_s+': '+e.message;f.puts e.backtrace.join("\n") }
  end
end
