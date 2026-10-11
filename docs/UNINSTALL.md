# Conservative removal

1. Pause work using this bundle. Back up `AI_MEMORY_BUNDLE/` and the current
   project hook configuration. Preserve any memory you want to keep.
2. Inspect the target project's `.codex/hooks.json` and other hook sources.
3. If that file contains only this package's SessionStart entry and has not
   acquired other settings, move it to a backup location outside `.codex/`.
   If it contains other hooks, remove ONLY the handler invoking
   `.codex/hooks/ai-memory-adapter.ps1`. Preserve unrelated groups and handlers;
   validate the resulting JSON. Do not delete the whole file blindly.
4. Restart/resume the target client and check that this adapter is no longer
   invoked. Review changed hooks when the client requests it.
5. The adapter script may be moved to the backup only after no hook references
   it. Leave other scripts and global settings untouched.
6. **Leave `AI_MEMORY_BUNDLE/` intact.** Its profile/facts/state/decisions may
   contain new user memory. Deleting them requires a separate explicit choice.

No automatic uninstaller is supplied: a later merged hook configuration must
not be removed based on the package's original assumptions.
