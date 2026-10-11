# Fresh setup contract

PACKAGE_VARIANT = FRESH_EMPTY_MEMORY
TARGET = WINDOWS_CODEX
INHERITED_PERSONAL_MEMORY = NONE
LIVE_TARGET_VALIDATION = UNVERIFIED

1. Read START_HERE.md, PACKAGE_CONTENTS.md and payload/AI_MEMORY_BUNDLE/index.md.
2. Resolve the intended target project from the current user, not from prior memory.
3. Inspect existing AI_MEMORY_BUNDLE and .codex hook configuration. Do not overwrite them.
4. Do not import prior profiles, policies, facts, state, decisions, summaries or host trust.
5. Install using INSTALL.ps1 within the user's authorized scope. No global config edits.
6. Run the installed test suite FIRST, in a separate Windows PowerShell process;
   then run the installed adapter Status in another process.
   When spawning Windows PowerShell 5.1 from PS7, ensure its child-only
   PSModulePath includes the native WindowsPowerShell/v1.0/Modules directory.
   Do not change the global/user environment to repair an inherited module path.
7. Confirm the initial state is EMPTY, no active task, no previous decisions,
   no user policy and no known host facts. PASS means structural validity only.
8. Review and trust hooks using the target client UI/CLI when needed. Trust is not bundled.
9. Verify actual startup/resume and real post-compaction injection separately.
   Never claim them from fixture tests. Keep UNVERIFIED until observed.
10. Stop installation work with a concise result and unresolved items.
    Start recording only current authorized work; do not reconstruct prior memory.

Hook logic is deterministic and does not decide what to remember.
This package cannot erase native product memory or project context.
