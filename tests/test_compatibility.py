import sys,unittest,zlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from compatibility import fingerprint,script_rows
from install import dump

class CompatibilityTests(unittest.TestCase):
    def item(self):return {'@name':b'Herb','@description':b'Old text','@price':10,'@effects':[],'@note':b'comment\n<tag: 5>'}
    def test_translation_and_free_notes_do_not_change_mechanics(self):
        a=self.item();b=dict(a,**{'@name':'Hierba'.encode(),'@description':b'New text','@note':b'new comment\n<tag:5>'})
        self.assertEqual(fingerprint(a,'item'),fingerprint(b,'item'))
    def test_changed_price_and_tag_are_not_presented_as_old_facts(self):
        a=self.item()
        for changed in [dict(a,**{'@price':20}),dict(a,**{'@note':b'<tag:6>'})]:self.assertNotEqual(fingerprint(a,'item'),fingerprint(changed,'item'))
    def rows(self):
        code=b'\n'.join(b'class '+n+b';end' for n in [b'Game_Action',b'Game_Battler',b'Game_Actor',b'Game_Party',b'Scene_Battle',b'Window_Base'])
        return [[i,b'Name',zlib.compress(code if i==0 else b'# comment',1)] for i in range(49)]+[[49,b'Main',zlib.compress(b'rgss_main {}',1)]]
    def test_script_ids_names_and_compression_are_not_build_identifiers(self):
        a=self.rows();b=[[i+1000,b'Localized title' if n!=b'Main' else n,zlib.compress(zlib.decompress(c),9)] for i,n,c in a]
        self.assertEqual(script_rows(b'\x04\x08'+dump(a))[1],script_rows(b'\x04\x08'+dump(b))[1])
    def test_missing_game_class_and_displaymod_have_specific_refusals(self):
        rows=self.rows();rows[0][2]=zlib.compress(b'class OtherGame;end')
        with self.assertRaisesRegex(ValueError,'Required BLACK SOULS'):script_rows(b'\x04\x08'+dump(rows))
        rows=self.rows();rows[1][1]=b'DisplayMod'
        with self.assertRaisesRegex(ValueError,'DisplayMod'):script_rows(b'\x04\x08'+dump(rows))
    def test_trailing_compressed_payload_is_invalid(self):
        rows=self.rows();rows[0][2]+=b'corrupt trailing data'
        with self.assertRaises(ValueError):script_rows(b'\x04\x08'+dump(rows))

if __name__=='__main__':unittest.main()
