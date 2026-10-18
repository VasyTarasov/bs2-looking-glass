# Isolated input QA helper

Only for a separately prepared fixture containing test_prepare_profile.json. Never install this driver into the player game.

From an x86 Visual Studio developer prompt run build.cmd <prepared-fixture>. Its DLL is created in that fixture, not in the repository. Use the hardened run_private_test.ps1. The F12 input test keeps native Input.update and silences only audio; the older no-input prelude does not exercise that path.

The helper substitutes key reads only inside its own process. It does not send system keyboard input. F12 is delivered directly to the bridge handler to test held keys, modifiers, restoration and prevention of recursive QA restarts. MinHook licenses remain in the parent source tree.
