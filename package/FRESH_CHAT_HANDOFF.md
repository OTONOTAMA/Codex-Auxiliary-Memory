# Fresh setup contract

PACKAGE_VARIANT = FRESH_EMPTY_MEMORY
TARGET = WINDOWS_CODEX
INHERITED_PERSONAL_MEMORY = NONE
LIVE_TARGET_VALIDATION = UNVERIFIED

## Scope preflight / 導入スコープの事前確認

- Standard = PROJECT. Resolve one intended local project root from current user intent;
  if unambiguous, proceed autonomously within setup authorization, without repeated questions.
- Code/Hook installation scope is not data ownership. All chats using this installation
  share AI_MEMORY_BUNDLE, including state/current.md; do not adopt another chat's task/GO.
  Keep chat-specific progress in separately owned DEV_STATE. Use one coordinated local
  memory writer; multi-writer or cloud-sync concurrency is not guaranteed.
- Multiple users/PCs do not automatically share local files. Review local access before
  storing personal information. No credentials, private logs or full transcripts.
- Inspect project/user/plugin Hooks and existing config/trust before changing anything.
  Preserve unrelated handlers; stop on conflicts and plan a minimal authorized merge.
  Do not copy trust, mix memories, migrate progress or run the installer again over existing data.
- Inspect Git tracked files and configure suitable local exclusions for live memory,
  private configs and progress/evidence before they are created. Do not stage private data;
  ignore rules do not untrack it. Existing tracked private data needs an explicit remediation plan.
- GLOBAL is unsupported by the shipped installer. Do not pass the user Codex home as
  TargetProjectRoot. For nonstandard scope, assess feasibility, affected chats, data sharing,
  duplicate handlers and test/rollback plan; confirm user intent and authorization first.
- Verify the ZIP checksum and PACKAGE_SHA256SUMS.txt before installation. Validation is
  integrity evidence, not authorization or a guarantee of all environments.

- 標準はPROJECT。現在の意図から対象のローカルrootを確定し、明確な標準導入なら再質問せず進める。
- 機能配置とデータ所有は別。state/current.mdも含む記憶は同じ設置先のチャット間で共有される。
  別チャットのタスクやGOを採用せず、固有進捗は個別DEV_STATEへ。記憶の書込み担当は単一に調整する。
- 複数PC・複数人で自動同期しない。個人情報の閲覧範囲を確認し、秘密・私的ログ・会話全文を入れない。
- user/project/pluginのHookと既存設定・信頼を確認し、無関係なものを保持。競合は最小の統合案で扱い、
  信頼コピー・記憶混合・進捗移行・既存対象への再インストールをしない。
- 実記憶・固有設定・進捗/証拠の作成前にGit追跡対象と適切なローカル除外を確認する。
  ignoreは既存追跡を解除しない。既存の個人情報は無断削除せず対処を確認する。
- GLOBALは同梱機能ではない。ユーザーのCodexホームをTargetProjectRootにしない。
  非標準構成は対応可否・影響・共有範囲・重複・検証/復元を検討し、意図と承認を確認してから扱う。
- 導入前にZIP checksumとPACKAGE_SHA256SUMS.txtを照合する。整合性検証は実行許可ではない。

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
