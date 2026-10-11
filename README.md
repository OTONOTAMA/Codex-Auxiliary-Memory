# Codex Auxiliary Memory

A small, file-based supplementary memory package for **Codex on Windows**.
It starts with **empty memory**: no author's profile, policy, host facts,
conversation history, work state, decisions, credentials or trust settings.

## Download and install

Download **Codex-Auxiliary-Memory-v0.2.0.zip** from
[GitHub Releases](https://github.com/OTONOTAMA/Codex-Auxiliary-Memory/releases/latest).
GitHub's automatic **Source code (zip)** is the development source, not the
ready-to-install package.

Extract the installation ZIP and ask a new Codex chat:

> Read FRESH_CHAT_HANDOFF.md and set this up for this project. Start with empty
> memory; do not import previous memory. Inspect existing hooks before installing.

See `START_HERE.md` for manual installation. Run the included tests before
adapter Status, then verify actual session injection on your target.
Project and hook trust must be reviewed in the target client when requested;
the package does not copy trust or change global configuration.

## What it does

- Keeps small files for adopted policies, preferences, verified facts,
  current work, material decisions and unverified candidates.
- Validates a short derived `HOT_STATE.md` against the current-state hash.
- Uses a project-local SessionStart hook to reload that saved note at supported
  startup, resume, clear and post-compaction boundaries.
- Has no transcript processing, network dependency, per-turn model call,
  database or background service.

The adapter's normal HOT_STATE target is 4,096 UTF-8 bytes; larger notes are
not injected as successful memory. Hooks validate and reload saved notes;
**they do not automatically record or summarize every conversation**.
AI must maintain relevant memory within the current user's authorized scope.
Use “bootstrap supplementary memory” or “update supplementary memory” with Codex.

## Boundaries and compatibility

- This is supplementary memory, not complete recall or a guarantee against forgetting.
- Stored notes and summaries cannot authorize work or override current instructions.
- Empty package memory does not clear Codex/ChatGPT native memory, personalization
  or project instructions.
- Targets Windows PowerShell 5.1 and a Codex client supporting the documented
  project-local hooks. Other platforms are not qualified by this release.
- Local fixture tests do not prove hook trust, actual startup delivery or actual
  post-compaction reinjection. Verify those separately in each target environment.
- Existing bundle/hook files are not overwritten. Inspect and merge separately.
- Never put credentials, secrets or full transcripts in memory.

Hook reference: [official documentation](https://learn.chatgpt.com/docs/hooks).
For safe removal see `docs/UNINSTALL.md`. Removal does not delete your memory.

## Source and maintenance

`package/` is the distribution source of truth. Do not maintain another hand-edited
ZIP. Python **3.11 or newer**, standard library only, is needed to build/test the
release; it is not required for normal PowerShell adapter operation.

```text
python tools/build_release.py
python tools/verify_release.py
```

The build regenerates hashes, audits empty memory and release contents, and
creates the installation ZIP plus SHA256SUMS.txt under `dist/`.
Verification installs only into a dedicated disposable fixture, runs the adapter
tests and simulated lifecycle events, checks no-write/no-overwrite behavior,
and removes only that fixture. It does not register or trust real hooks.
An inherited PowerShell 7 module path is corrected only for child test processes.

## License

MIT — Copyright (c) 2026 OTONOTAMA. Use, modification, redistribution and commercial
use are permitted under the license. Retain the copyright and license notice.
Provided without warranty. This is an independent project, not an OpenAI product.

---

# Codex Auxiliary Memory — 日本語

**Windows版Codex向け**の、小さなファイルベースの補助記憶パッケージです。
**記憶が空の状態**から始めます。作者のプロフィール・ポリシー・PC情報・会話履歴・
作業状態・決定履歴・資格情報・信頼設定は含みません。

## ダウンロード・導入

[GitHub Releases](https://github.com/OTONOTAMA/Codex-Auxiliary-Memory/releases/latest)から
**Codex-Auxiliary-Memory-v0.2.0.zip**をダウンロードしてください。
GitHub標準の **Source code (zip)** は開発用ソースであり、導入用ZIPではありません。

導入用ZIPを展開し、新しいCodexチャットへ次のように依頼します。

> FRESH_CHAT_HANDOFF.mdを読んで、このプロジェクトにセットアップして。
> 記憶は空から開始し、以前の記憶は取り込まないで。既存Hookは導入前に確認して。

手動導入は`START_HERE.md`を参照してください。同梱テストを先に実行し、その後に
アダプターのStatus、導入先の実セッションへの注入を確認します。
導入先でプロジェクトやHookの信頼確認が求められた場合は内容を確認してください。
信頼登録のコピーやグローバル設定の変更は行いません。

## できること

- 採用したポリシー・好み・確認済み事実・現在作業・重要な決定・未確認候補を小さなファイルで保持。
- 短い派生メモ`HOT_STATE.md`を現在状態のハッシュと照合。
- プロジェクト内のSessionStart Hookで、対応する起動・再開・clear・圧縮後に保存済みメモを読み戻す。
- 会話全文の処理・通信依存・毎ターンのモデル呼出し・DB・常駐サービスは不要。

HOT_STATEの通常目標はUTF-8で4,096バイトです。超過したメモを正常な記憶として
注入しません。Hookは保存済みメモを確認して読み戻すものであり、
**会話をすべて自動記録・要約する機能ではありません**。
AIが現在のユーザーの許可範囲内で必要な記録を維持します。
「補助記憶ブートして」「補助記憶に反映して」と依頼できます。

## 対応範囲・注意

- 完全な記憶や、忘れないことを保証する仕組みではありません。
- 保存メモ・要約は作業許可にならず、現在の指示を上書きしません。
- 空のパッケージでも、Codex/ChatGPT自身のMemory・個人設定・プロジェクト指示は消えません。
- Windows PowerShell 5.1と、記載のプロジェクトHookに対応したCodexクライアントが対象。
  他OSは本版の検証対象外です。
- 隔離試験だけでは信頼登録・実起動時の注入・実圧縮後の再注入を証明できません。
  導入先ごとに別途確認してください。
- 既存のバンドルやHookは上書きしません。統合は別途確認します。
- 資格情報・秘密情報・会話全文は保存しないでください。

Hookの参照：[公式ドキュメント](https://learn.chatgpt.com/docs/hooks)。
取り外し手順は`docs/UNINSTALL.md`を参照。取り外しても記憶は削除しません。

## ソース・保守

配布内容の正本は`package/`です。ZIPを別途手修正して二重管理しません。
作成・検証にはPython **3.11以上**の標準ライブラリのみを使用します。
通常のPowerShellアダプター運用にPythonは不要です。

```text
python tools/build_release.py
python tools/verify_release.py
```

作成処理はハッシュを再生成し、初期記憶が空であることと配布内容を検査して、
`dist/`に導入用ZIPとSHA256SUMS.txtを生成します。
検証は専用の一時fixture内だけで導入・テスト・模擬ライフサイクル確認・
無変更時の書込み禁止・既存対象の上書き禁止を確認し、fixtureだけを削除します。
実Hookの登録や信頼登録は行いません。
PowerShell 7由来のモジュールパスは試験の子プロセス内だけで補正します。

## ライセンス

MIT — Copyright (c) 2026 OTONOTAMA。
利用・改変・再配布・商用利用が可能です。著作権表示とライセンス文を保持してください。
無保証です。OpenAI公式製品ではなく、独立したプロジェクトです。
