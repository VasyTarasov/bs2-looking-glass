"""Version 1 feature selection and preview migration contracts."""
from pathlib import Path
import json,sys,unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from module_selection import MANIFEST,IDS,DEFAULTS,expand,migrate,configuration,parse,for_installation

class ModuleSelectionTests(unittest.TestCase):
 def test_defaults_are_exact(self):self.assertEqual(set(IDS)-set(DEFAULTS),{'legacy_shortcuts','battle_support','debug'})
 def test_bilingual_descriptions_are_complete(self):
  self.assertEqual(len(IDS),20)
  for m in MANIFEST:
   for lang in ['ru','en']:
    self.assertTrue(m['name_'+lang]);self.assertTrue(m['description_'+lang]);self.assertTrue(m['group_'+lang])
 def test_macro_needs_groups_only(self):self.assertEqual(expand(['macros']),['macros','semantic_groups'])
 def test_legacy_does_not_enable_groups(self):self.assertEqual(expand(['legacy_shortcuts']),['legacy_shortcuts'])
 def test_support_does_not_enable_groups(self):self.assertEqual(expand(['battle_support']),['battle_support'])
 def test_legacy_and_groups_coexist(self):self.assertEqual(set(expand(['legacy_shortcuts','semantic_groups'])),{'legacy_shortcuts','semantic_groups'})
 def test_unknown_module_is_refused(self):
  with self.assertRaises(ValueError):expand(['unknown'])
 def test_configuration_roundtrip(self):
  for active in [[],DEFAULTS,IDS,['macros'],['legacy_shortcuts'],['battle_support']]:self.assertEqual(parse(configuration(active).decode()),set(expand(active)))
 def test_old_optional_settings_migrate(self):
  selected=migrate('semantic_groups=1\nloadouts=1\ncontrols=1\nsound=0\neffects=1\ndebug=0\nlegacy_shortcuts=0\n')
  self.assertTrue({'semantic_groups','macros','loadouts','basic_qol','reference_cards','battle_speed','map_highlight'}<=set(selected))
  self.assertFalse({'legacy_shortcuts','battle_support','debug'}&set(selected))
 def test_old_legacy_only_does_not_enable_groups_or_macros(self):
  selected=migrate('legacy_shortcuts=1\nsemantic_groups=0\nloadouts=1\n')
  self.assertIn('legacy_shortcuts',selected);self.assertNotIn('semantic_groups',selected);self.assertNotIn('macros',selected)
 def test_retired_flags_are_not_preserved(self):
  self.assertFalse({'defeat','retry','scaling'}&parse(configuration(migrate('defeat=1\nretry=1\nscaling=1\n')).decode()))
 def test_stable_versions_keep_sparse_choices_during_installer_check(self):
  text='hd_display=1\nbattle_support=1\nbattle_speed=0\nmap_highlight=0\n'
  for version in ['1.0','1.01','1.02','1.03']:
   self.assertEqual(for_installation(text,version,'1.03'),['battle_support','hd_display'])
 def test_preview_check_keeps_the_existing_migration_contract(self):
  text='controls=1\neffects=1\n'
  self.assertEqual(for_installation(text,'0.92-dev','1.03'),migrate(text))

if __name__=='__main__':unittest.main()
