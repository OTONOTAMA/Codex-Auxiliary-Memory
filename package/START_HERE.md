# Codex Auxiliary Memory v0.2.1

記憶をゼロから使い始める、Windows版Codex向けのセットアップパッケージです。
元ユーザーのプロフィール・ポリシー・環境情報・会話内容・作業状態・決定履歴は含みません。
初期メモは空です。導入先の現在の指示・事実だけを記録してください。

## 最短手順

標準はPROJECT内への導入です。同じ設置先のチャットはAI_MEMORY_BUNDLE全体を共有します。
共有記憶は別チャットの作業再開やGOの根拠ではなく、個別の進捗はDEV_STATEで分離します。
複数PC/複数人での自動共有・GLOBAL導入は提供しません。記憶更新は単一ローカル担当で調整します。
AIはFRESH_CHAT_HANDOFF.mdの事前確認を実施し、Git追跡/公開への個人情報混入と既存設定の変更を防ぎます。

Standard scope is PROJECT; chats using it share the whole memory bundle, not
private task state or execution authority. DEV_STATE keeps per-chat progress separate.
No automatic multi-PC/user sharing or GLOBAL installer is provided. Coordinate a
single local memory writer. Codex must follow the scope/Git-safety preflight in
FRESH_CHAT_HANDOFF.md; a clear standard setup needs no extra scope questionnaire.

1. 新しいCodexチャットへこのZIPを渡します。
2. 「FRESH_CHAT_HANDOFF.mdを読んで、この環境にセットアップして。以前の記憶は引き継がないで」と依頼します。
3. 対象プロジェクトと既存設定を確認してから設置します。
4. 対象環境でプロジェクトとHookの信頼確認が求められた場合は内容を確認して許可します。
5. 同梱テスト、Status、新しいセッションでの注入を確認します。

このZIPだけで導入許可・既存ファイルの上書き許可・タスク実行許可が成立するわけではありません。
元チャットの記憶は空ですが、CodexやChatGPT自身のMemory・個人設定・プロジェクト指示を消す機能ではありません。

## 手動導入

ZIPを展開し、そのフォルダで実行します。対象フォルダは先に作成してください。

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\INSTALL.ps1 -TargetProjectRoot "C:\path\to\project"
```

既存のAI_MEMORY_BUNDLE、hooks.json、同名アダプターがあれば上書きせず停止します。
既存Hookとの統合は別途確認してください。グローバル設定や信頼登録はコピーしません。

PowerShell 7やCodex内蔵シェルからWindows PowerShell 5.1を子プロセスとして
呼ぶと、親のPSModulePathによってGet-FileHashなど標準コマンドが見えなくなる
場合があります。その場合は独立したWindows PowerShell 5.1から実行するか、
子プロセスだけのPSModulePathをWindows PowerShell標準Modulesへ設定してください。
ユーザー全体の環境変数を変更する必要はありません。

次をこの順に実行します。

```powershell
powershell.exe -NoLogo -NoProfile -NonInteractive -File "C:\path\to\project\AI_MEMORY_BUNDLE\tests\test_adapter_v0.2.ps1"
powershell.exe -NoLogo -NoProfile -NonInteractive -File "C:\path\to\project\.codex\hooks\ai-memory-adapter.ps1" -Mode Status
```

StatusのPASSは空の初期メモの構造・ハッシュが正常という意味です。
実セッションへの注入や実圧縮後の再注入が検証済みという意味ではありません。
導入先でそれぞれ確認するまでUNVERIFIEDとして扱います。

## 普段の使い方

- 「補助記憶ブートして」：必要な記録だけ読む。
- 「補助記憶に反映して」：現在の重要な事実・状態を保存する。
- 自動Hookは保存済みの短いメモを再投入するだけで、会話を自動で記録・要約しません。

本版はMITライセンスです。LICENSEを参照してください。
Hookの信頼とSessionStart仕様の参照： https://learn.chatgpt.com/docs/hooks
