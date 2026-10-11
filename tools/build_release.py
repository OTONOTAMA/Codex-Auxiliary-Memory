"""Self-contained stdlib release build. package/ is the only payload source."""
import hashlib
import json
import re
import tomllib
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "package"
BUNDLE = PACKAGE / "payload/AI_MEMORY_BUNDLE"
DIST = ROOT / "dist"
NAME = "Codex-Auxiliary-Memory-v0.2.0"
BUNDLE_FILES = (
    "README.md", "index.md", "canonical/policy.md", "canonical/profile.md",
    "canonical/facts.md", "state/current.md", "decisions/decisions.md",
    "candidates/pending.md", "references/README.md", "runtime/HOT_STATE.md",
    "tests/test_adapter_v0.2.ps1",
)
PACKAGE_FILES = (
    "START_HERE.md", "FRESH_CHAT_HANDOFF.md", "PACKAGE_CONTENTS.md", "INSTALL.ps1",
    "PACKAGE_SHA256SUMS.txt", "payload/.codex/hooks/ai-memory-adapter.ps1",
    "payload/AI_MEMORY_BUNDLE/manifest.toml",
) + tuple("payload/AI_MEMORY_BUNDLE/" + rel for rel in BUNDLE_FILES)
EMPTY_SLOTS = ("canonical/policy.md", "canonical/profile.md", "canonical/facts.md",
               "state/current.md", "decisions/decisions.md", "candidates/pending.md",
               "references/README.md")
# Exact empty-template baseline prevents silent inclusion of real records.
EMPTY_HASHES = {
    "canonical/policy.md": "233AF0F435964781CCA39717FF7EA4241207C724EC926150E35500047BA80D70",
    "canonical/profile.md": "86703F9DD6B9CEE525751740017F4D5A5A79B6C2F3904962DBC8DEB80B3E6E24",
    "canonical/facts.md": "A8E05C30D750B9FDCCA874DF0FADBB333CB4C9AD07C8AA8C4B803791E1FD1F39",
    "state/current.md": "B6247A09B41627B98FD2D305FA9C1F9417A69D4D8AAA058A80C78C6813C48E30",
    "decisions/decisions.md": "D312B1904FB8873A6AB258773DCC3D4CB43B7008FB85FED8DAF779720EEF252A",
    "candidates/pending.md": "0B17F0B5DAD50E3508756D8B7077ED260C5AF6A05859D8B836F28A5392AE8ECB",
    "references/README.md": "E1615D7DD736A3640AB4D6654B304C5710B23E075930F09B47E96E6292DEE4BA",
}


def sha(data):
    return hashlib.sha256(data).hexdigest().upper()


def audit_sources():
    actual = {p.relative_to(PACKAGE).as_posix() for p in PACKAGE.rglob("*") if p.is_file()}
    if actual != set(PACKAGE_FILES):
        raise ValueError(f"Unexpected or missing payload: {actual ^ set(PACKAGE_FILES)}")
    for rel in EMPTY_SLOTS:
        data = (BUNDLE / rel).read_bytes()
        if sha(data) != EMPTY_HASHES[rel]:
            raise ValueError(f"Empty memory template changed: {rel}; review before distribution")
    for p in PACKAGE.rglob("*"):
        if not p.is_file():
            continue
        text = p.read_text(encoding="utf-8-sig")
        if re.search(r"(?i)(?:[a-z]:\\Users\\(?!\.\.\.|<|example)[^\\\s`\"]+|"
                     r"sk-[a-zA-Z0-9_-]{20,}|gh[pousr]_[a-zA-Z0-9]{20,}|"
                     r"github_pat_[a-zA-Z0-9_]{20,}|BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY)", text):
            raise ValueError(f"Potential private path/credential: {p.relative_to(PACKAGE)}")
    # This is a guard, not a universal secret detector. Review content before publishing.


def refresh_metadata():
    hot = BUNDLE / "runtime/HOT_STATE.md"
    text = hot.read_text(encoding="utf-8")
    text, count = re.subn(r"(?m)^SOURCE_CURRENT_SHA256 = .+$",
                         "SOURCE_CURRENT_SHA256 = " + sha((BUNDLE / "state/current.md").read_bytes()), text)
    assert count == 1
    hot.write_bytes(text.encode("utf-8"))
    manifest_path = BUNDLE / "manifest.toml"
    text = manifest_path.read_text(encoding="utf-8")
    hashes = '[integrity]\n' + ''.join(f'"{rel}" = "{sha((BUNDLE / rel).read_bytes())}"\n'
                                       for rel in BUNDLE_FILES) + '\n'
    text, count = re.subn(r"\[integrity\]\n.*?(?=\[host_adapter\])", hashes, text, flags=re.S)
    assert count == 1
    text = re.sub(r'(?m)^file_count_excluding_manifest = .*$',
                  f'file_count_excluding_manifest = {len(BUNDLE_FILES)}', text)
    adapter = PACKAGE / "payload/.codex/hooks/ai-memory-adapter.ps1"
    text = re.sub(r'(?m)^script_sha256 = .*$', f'script_sha256 = "{sha(adapter.read_bytes())}"', text)
    manifest_path.write_bytes(text.encode("utf-8"))
    files = sorted(set(PACKAGE_FILES) - {"PACKAGE_SHA256SUMS.txt"})
    (PACKAGE / "PACKAGE_SHA256SUMS.txt").write_bytes(''.join(
        f'{sha((PACKAGE / rel).read_bytes()).lower()}  {rel}\n' for rel in files).encode("utf-8"))


def build():
    audit_sources()
    refresh_metadata()
    parsed = tomllib.loads((BUNDLE / "manifest.toml").read_text(encoding="utf-8"))
    assert parsed["personal_memory_included"] is False
    assert parsed["live_target_validation"] == "UNVERIFIED"
    assert "user_config_sha256_observed" not in parsed["host_adapter"]["integrity"]
    for rel, expected in parsed["integrity"].items():
        assert sha((BUNDLE / rel).read_bytes()) == expected
    assert (BUNDLE / "runtime/HOT_STATE.md").stat().st_size <= 4096
    members = {rel: (PACKAGE / rel).read_bytes() for rel in PACKAGE_FILES}
    for rel in ("README.md", "LICENSE", "CHANGELOG.md", "docs/UNINSTALL.md", "docs/VALIDATION.md"):
        members[rel] = (ROOT / rel).read_bytes()
    assert b"Copyright (c) 2026 OTONOTAMA" in members["LICENSE"]
    DIST.mkdir(exist_ok=True)
    path = DIST / (NAME + ".zip")
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as z:
        for rel, data in sorted(members.items()):
            info = zipfile.ZipInfo(NAME + "/" + rel, (2020, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            z.writestr(info, data)
    with zipfile.ZipFile(path) as z:
        assert z.testzip() is None
        assert len(z.namelist()) == len(members)
        for rel, data in members.items():
            assert z.read(NAME + "/" + rel) == data
    (DIST / "SHA256SUMS.txt").write_bytes(
        f'{sha(path.read_bytes()).lower()}  {path.name}\n'.encode("ascii"))
    return {"status": "PASS", "zip": path.name, "files": len(members),
            "bytes": path.stat().st_size, "sha256": sha(path.read_bytes())}


if __name__ == "__main__":
    print(json.dumps(build()))
