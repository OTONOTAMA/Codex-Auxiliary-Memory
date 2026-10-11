# v0.2.0 validation scope

Verified in an isolated Windows installation fixture:

- Package allowlist, exact empty-memory baselines and private-path/key pattern scan.
- Regenerated manifest and package hashes; ZIP readback/CRC and byte agreement.
- Installer creates only the dedicated target; existing target rejected without writes.
- Included adapter selftests: 11 PASS, 0 FAIL.
- Empty initial state Status: PASS.
- Simulated startup/resume/clear/compact: valid bounded empty context, no file changes.
- A synthetic nonempty profile is rejected by the release privacy guard.

These are deterministic/fixture results, not target-client lifecycle acceptance.
Actual hook review/trust, startup/resume delivery and actual post-compaction
delivery remain UNVERIFIED for a new target until observed there.
The pattern scan is not a universal secret detector; source review is still required.

No private user memory or live host trust is included as validation evidence.
