# Battle completion regression checks — 1.04

The reported symptom was repeated battle rewards followed by the game closing without an error. The same symptom was reproduced on 1.03 in RGSS301 with the original `SceneManager.run` / `Scene_Battle.update` loop and the real instant skill 932, without holding Ctrl or injecting an exception.

After victory, the semantic-menu QuickSkill handler continued into `next_command`. This restarted the turn phase after `battle_end`; the original end-of-frame victory check then ran again. The second `SceneManager.return` exhausted the scene stack and ended the main loop. The fix unwinds the obsolete action/input handler and does not restore actions from a completed battle.

The regression suite covers:

- A lethal instant item and the real instant skill, with no Ctrl, the checkbox enabled without Ctrl, ordinary Ctrl and instant Ctrl.
- Instant-only sequences and instant steps before/after a queued action. Subsequent steps must not spend items after the battle ends.
- An injected optional priority-bookkeeping failure. This is a separate defensive test, not a claim that this failure occurred in the user's game.
- Native common-event battle abort, preservation of a new battle generation's queue, nonlethal instant actions and propagation of unexpected execution errors.
- HD/classic switching, disabled sidebar, rejected sidebar text, and hiding the old plan/footer during battle fade-out.
- A 40-battle accelerated run through the original main loop, checking return to the previous scene, one reward per battle, cleanup scope, GDI/USER objects and private memory.
- Adaptive-priority ordering, persistence and exactly one statistics record after actual native victory.

The native fixtures exclude personal saves and disable audio playback and Steam integration. They use the real Windows executable and RGSS301, rather than a replacement Ruby interpreter. These tests do not constitute a complete playthrough, a Steam-overlay test or proof that every reported exit has this cause. The reporter's exact save and two named encounters were not reproduced directly.

Relevant public suites: `battle_exit`, `battle_exit_loop`, `battle_exit_edges`, and `priority_finish` in `tools/prepare_test.py`. The helper file is copied into the isolated test directory automatically. Fixtures need the usual native game assets; none are distributed with the source.

An older broad `iteration0991` suite stopped in its scripted reference-card modal-input driver on both unchanged 1.03 and this candidate. It is not counted as a passing suite. Focused priority tests replace that suite for assessing the battle-end ordering change.
