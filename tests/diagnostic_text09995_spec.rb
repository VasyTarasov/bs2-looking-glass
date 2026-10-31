# encoding: UTF-8
rgss_main do
  @checks=0
  def log(s);File.open('test_result.txt','a') { |f| f.puts s };end
  def check(v,s);raise s unless v;@checks+=1;log('PASS '+s);end
  begin
    File.open('test_result.txt','w') { |f| f.puts 'Diagnostic text recovery '+BS2Suite::VERSION }
    debug=BS2Suite::Debug;debug.start
    samples=["\xff\x00".force_encoding('UTF-8'),"a\xc3".force_encoding('UTF-8'),"\x00\xd8".force_encoding('UTF-16LE'),"Привет\n\"\\\t",'Привет'.encode('Windows-1251')]
    samples.each_with_index do |text,i|
      json=debug.json({:text=>text})
      check(json.encoding.name=='UTF-8' && json.valid_encoding?,'text case '+i.to_s+' serializes into valid UTF-8')
      check(debug.emit('text_recovery_'+i.to_s,{:text=>text}),'text case '+i.to_s+' is written without stopping recording')
    end
    cyclic=[];cyclic<<cyclic
    check(debug.json(cyclic).bytesize<1000,'cyclic diagnostic values remain bounded')
    check(debug.json([0.0/0.0,1.0/0.0,-1.0/0.0])=='[null,null,null]','nonfinite numbers remain valid JSON nulls')
    check(debug.emit('after_bad_text',{:ok=>true}) && debug.recording? && !debug.error,'a subsequent normal event remains recordable')
    log('result=PASS; checks='+@checks.to_s)
  rescue Exception=>e
    log('result=FAIL; '+e.class.to_s+': '+e.message);log(e.backtrace.join("\n"))
  ensure
    BS2Suite::Debug.close if defined?(BS2Suite::Debug)
  end
end
