# encoding: UTF-8
begin
  File.open('test_result.txt','w') { |f| f.puts 'practical_reference_export_060' }
  DataManager.init;DataManager.setup_new_game
  rows=[]
  [[:skill,$data_skills],[:item,$data_items],[:weapon,$data_weapons],[:armor,$data_armors]].each do |kind,database|
    database.compact.each do |object|
      next if object.name.strip.empty?
      [:ru,:en].each do |language|
        card=BS2QoL::PracticalCard.new(object,nil,language)
        raise 'Invalid card' unless !card.sections.empty? && card.sections.size==card.section_names.size && card.sections.all? { |s| !s.empty? }
        names=[];sections=[]
        card.section_names.each_with_index do |name,i|
          next if ['По целям','Targets'].include?(name)
          lines=card.sections[i].reject { |s| s.start_with?('В сумке:','In inventory:','Ограничения сейчас:','Current restrictions:') }
          next if lines.empty?
          names<<name;sections<<lines
        end
        rows<<[language.to_s,kind.to_s,object.id,card.title,names,sections]
      end
    end
  end
  File.open('practical_reference_export.bin','wb') { |f| Marshal.dump(rows,f) }
  File.open('test_result.txt','a') { |f| f.puts 'result=PASS; checks='+rows.size.to_s+'; native_practical_cards=true' }
rescue Exception=>e
  File.open('test_result.txt','a') { |f| f.puts 'result=FAIL; '+e.class.to_s+': '+e.message;f.puts e.backtrace }
ensure;exit;end
