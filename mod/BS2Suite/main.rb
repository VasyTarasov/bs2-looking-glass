# encoding: UTF-8
unless defined?(BS2Suite::LOADED)
  module BS2Suite
    VERSION='0.91-dev'
    ROOT=File.dirname(__FILE__)
    IDS=%w(combat_shortcuts action_queue reference_cards effects loadouts learned_books field_skills saves defeat retry battle_stats controls run_toggle sound debug semantic_groups legacy_shortcuts soul_batch equipped_upgrade steam_bridge hd_display weapon_family_cleanup)
    @enabled=[]
    path=File.join(Dir.pwd,'BS2Suite','modules.ini')
    if File.file?(path) && File.size(path)<8192
      File.open(path,'rb') { |f| f.read }.each_line do |line|
        line=line.dup.force_encoding('UTF-8')
        next unless line.valid_encoding?
        match=/\A([a-z_]+)=1\z/.match(line.strip)
        @enabled << match[1] if match && IDS.include?(match[1])
      end
    end
    @enabled << 'defeat' if @enabled.include?('retry') && !@enabled.include?('defeat')
    def self.enabled?(id);@enabled.include?(id.to_s);end
    def self.load_part(path)
      file=File.join(ROOT,path+'.rb')
      eval(File.open(file,'rb') { |f| f.read }.force_encoding('UTF-8'),TOPLEVEL_BINDING,file,1)
    end
    load_part('modules/common')
    module ::BS2Modules
      VERSION=BS2Suite::VERSION
      def self.enabled?(id);BS2Suite.enabled?(id);end
    end
    load_part('core')
    %w(model bindings windows hotkeys).each { |name| load_part('qol/lib/'+name) }
    load_part('input')
    load_part('weapon_families')
    %w(bindings_v2 hotkeys_v2).each { |name| load_part(name) }
    load_part('qol/lib/favorites') if enabled?('combat_shortcuts') || enabled?('semantic_groups') || enabled?('legacy_shortcuts')
    load_part('qol/lib/commands') if enabled?('combat_shortcuts') || enabled?('semantic_groups') || enabled?('legacy_shortcuts')
    load_part('battle_panels') if enabled?('combat_shortcuts') || enabled?('action_queue') || enabled?('semantic_groups') || enabled?('legacy_shortcuts')
    if enabled?('reference_cards')
      %w(reference_data reference forecast_expression forecast forecast_reference reference_window).each { |name| load_part('qol/lib/'+name) }
    end
    load_part('reference_utilitarian') if enabled?('reference_cards')
    load_part('modules/effects') if enabled?('effects')
    load_part('modules/loadouts') if enabled?('loadouts')
    load_part('modules/integration')
    %w(learned_books field_skills saves sound run_toggle).each { |name| load_part(name) if enabled?(name) }
    load_part('quick_saves') if enabled?('saves')
    load_part('field_auto') if enabled?('field_skills')
    load_part('battle_record') if enabled?('defeat') || enabled?('retry') || enabled?('battle_stats')
    load_part('debug') if enabled?('debug')
    load_part('settings')
    if enabled?('semantic_groups')
      %w(semantic_catalog semantic_model arsenal_catalog direct_weapons semantic_ui semantic_reference).each { |part| load_part(part) }
    end
    load_part('followup')
    if enabled?('steam_bridge') || enabled?('hd_display')
      load_part('steam_bridge')
      BS2Suite::Debug.emit('steam_bridge_boot',{:error=>BS2Suite::SteamBridge.error,:stats=>BS2Suite::SteamBridge.stats}) if enabled?('debug')
    end
    load_part('navigation')
    load_part('interface092')
    load_part('arsenal093') if enabled?('semantic_groups')
    load_part('support093') if enabled?('semantic_groups')
    load_part('notes093') if enabled?('semantic_groups')
    load_part('combat_journal') if enabled?('battle_stats')
    load_part('family_inventory') if enabled?('weapon_family_cleanup')
    if enabled?('hd_display');load_part('hd_display');load_part('hd_context');end
    load_part('support093_hd') if enabled?('semantic_groups') && enabled?('hd_display')
    load_part('armor_families094') if enabled?('weapon_family_cleanup')
    load_part('ux094')
    load_part('reference094') if enabled?('reference_cards')
    load_part('ux095')
    load_part('execution096') if enabled?('semantic_groups')
    load_part('execution097') if enabled?('semantic_groups')
    load_part('reference098') if enabled?('reference_cards') || enabled?('semantic_groups')
    BS2QoL.const_set(:LOADED,true)
    BS2Modules.const_set(:LOADED,true)
    LOADED=true
  end
end
