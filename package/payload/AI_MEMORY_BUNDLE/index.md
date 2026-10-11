# Memory operation index

INITIAL_MEMORY = EMPTY
CURRENT_USER_INSTRUCTIONS_AND_MACHINE_EVIDENCE_OUTRANK_STORED_MEMORY
STORED_MEMORY_IS_NOT_EXECUTION_AUTHORIZATION
HOT_STATE_IS_DERIVED_NON_CANONICAL

## Read

Standard memory scope is PROJECT. All chats using this bundle share its files,
including state/current.md. Treat another chat's work as reference, not your own
active task or authorization. Keep session-specific progress in owned DEV_STATE.
共有記憶とチャット固有進捗を区別し、別チャットの作業やGOを自分のものとして採用しない。
Coordinate one local writer; concurrent memory edits are not transactionally isolated.
Keep live memory and personal data out of Git/public uploads; files do not auto-sync across PCs/users.

Read manifest.toml and this index. Resolve only the canonical sources needed
for the current task. Use state/current.md to continue work only if it contains
an actual recorded task. Empty slots do not justify inferring a prior identity,
preference, policy, machine configuration, decision or authorization.
Candidates and references are supporting information, not canonical authority.
Higher-priority host instructions always apply.

## Write

Within currently authorized work, record material changes only:

- canonical/policy.md: current explicitly adopted policies.
- canonical/profile.md: current explicit user preferences.
- canonical/facts.md: facts with source and verification scope.
- state/current.md: current objective, state, next action and unresolved items.
- decisions/decisions.md: material decisions and their current basis.
- candidates/pending.md: unverified candidates; do not silently promote them.

Do not store secrets or full transcripts. Do not save or resurrect GO as task authority.
Do not reconstruct missing facts from earlier conversations or model memory.
No semantic change means no checkpoint write is needed.

After changing state/current.md, generate a short derived HOT_STATE.candidate.md
inside runtime/, using FORMAT_VERSION=1, AUTHORITY=DERIVED_NON_CANONICAL,
BUNDLE_ID=AI_SUPPLEMENTARY_MEMORY_BUNDLE, SOURCE_CURRENT=state/current.md and
the actual SHA256 of current.md. Target <=4096 UTF-8 bytes.
Invoke the installed adapter with -Mode CommitHotState and check its result.
Do not hand-edit the published HOT_STATE while committing a candidate.
Refresh manifest [integrity] hashes for changed files and maintain its file count.
Candidate content is AI semantic work; hash checks alone do not certify its meaning.

## Bootstrap

SessionStart startup/resume/clear/compact injects saved HOT_STATE after validation.
Hooks do not update memory, process transcripts or use the network.
On STALE/UNVERIFIED/BLOCKED, read required canonical sources manually;
do not turn missing information into claimed success.

## Natural commands

「補助記憶ブートして」: read necessary memory and report current state.
「補助記憶に反映して」 / 「チェックポイント作成」: save material current state,
refresh derived HOT_STATE and verify, if the task context is unambiguous.
