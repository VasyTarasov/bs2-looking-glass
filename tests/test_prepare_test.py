"""Public QA launcher suite routing; all fixtures remain source-only."""
from pathlib import Path
import sys, unittest
sys.dont_write_bytecode=True
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from prepare_test import suite_file

class PrepareSuiteTests(unittest.TestCase):
    def test_live_regression_is_routable(self):
        self.assertEqual(suite_file('live09996').name,'live09996_spec.rb')
    def test_polish_suites_are_routable(self):
        for name in ['v1_modules','v1_basic','v1_reference','v1_visual','forecast_zero099994','hud_mechanics099994','catalog_ui','catalog_v1','forecast_percent','forecast_presentation','cleanse09999','auto_items09998','polish_content','polish_support','polish_gunbreak','polish_inventory','polish_economy','polish_system','module_boot']:
            self.assertTrue(suite_file(name).is_file())
    def test_legacy_aliases(self):
        self.assertEqual(suite_file('smoke').name,'keys_spec.rb')
    def test_unknown_and_traversal_are_rejected(self):
        for name in ['retry','not_a_real_suite','../main','C:/example']:
            with self.assertRaises(ValueError):suite_file(name)

if __name__=='__main__':unittest.main()
