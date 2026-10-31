"""Run only the pack's public helpers under an isolated interpreter."""
from pathlib import Path
import runpy,sys
TOOLS=Path(__file__).resolve().parent
if len(sys.argv)<2 or sys.argv[1] not in {'install','update','collect_debug'}:raise SystemExit('Choose install, update or collect_debug')
tool=sys.argv.pop(1);sys.argv[0]=str(TOOLS/(tool+'.py'))
sys.path.insert(0,str(TOOLS))
runpy.run_path(sys.argv[0],run_name='__main__')
