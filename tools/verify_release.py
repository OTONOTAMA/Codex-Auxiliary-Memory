"""Verify a built ZIP in a dedicated fixture; never touch live hook configuration."""
import json
import os
import shutil
import subprocess
import tempfile
import tomllib
import zipfile
from pathlib import Path
from build_release import ROOT, DIST, NAME, sha, audit_sources


def verify():
    if os.name != "nt":
        raise RuntimeError("Windows PowerShell live fixture tests require Windows")
    audit_sources()
    ps = Path(os.environ["SystemRoot"]) / "System32/WindowsPowerShell/v1.0/powershell.exe"
    if not ps.is_file():
        raise RuntimeError("Windows PowerShell 5.1 not found")
    env = os.environ.copy()
    env["PSModulePath"] = str(ps.parent / "Modules")

    def run(script, *args, stdin=None, expected=0):
        p = subprocess.run([str(ps), "-NoLogo", "-NoProfile", "-NonInteractive",
                            "-ExecutionPolicy", "Bypass", "-File", str(script), *args],
                           input=stdin, encoding="utf-8", capture_output=True, timeout=90, env=env)
        if p.returncode != expected:
            raise RuntimeError(f"{script.name}: exit {p.returncode}\n{p.stdout}\n{p.stderr}")
        return p.stdout

    path = DIST / (NAME + ".zip")
    expected = (DIST / "SHA256SUMS.txt").read_text(encoding="ascii").split()[0]
    assert sha(path.read_bytes()).lower() == expected
    temp = Path(tempfile.mkdtemp(prefix=".release-test-", dir=ROOT)).resolve()
    try:
        with zipfile.ZipFile(path) as z:
            assert z.testzip() is None
            for name in z.namelist():
                assert (temp / name).resolve().is_relative_to(temp)
            z.extractall(temp)
        package = temp / NAME
        target = temp / "target"
        target.mkdir()
        assert "FILES_INSTALLED" in run(package / "INSTALL.ps1", "-TargetProjectRoot", str(target))
        bundle = target / "AI_MEMORY_BUNDLE"
        adapter = target / ".codex/hooks/ai-memory-adapter.ps1"
        output = run(bundle / "tests/test_adapter_v0.2.ps1")
        assert "RESULT pass=11 fail=0 total=11" in output
        status = json.loads(run(adapter, "-Mode", "Status"))
        assert status["status"] == "PASS" and status["bytes"] <= 4096
        parsed = tomllib.loads((bundle / "manifest.toml").read_text(encoding="utf-8"))
        for rel, expected in parsed["integrity"].items():
            assert sha((bundle / rel).read_bytes()) == expected
        assert "user_config_sha256_observed" not in parsed["host_adapter"]["integrity"]

        def snapshot():
            return {p.relative_to(target).as_posix(): sha(p.read_bytes())
                    for p in target.rglob("*") if p.is_file()}

        before = snapshot()
        for source in ("startup", "resume", "clear", "compact"):
            event = json.dumps({"hook_event_name": "SessionStart", "source": source})
            result = json.loads(run(adapter, "-Mode", "HookSessionStart", stdin=event))
            context = result["hookSpecificOutput"]["additionalContext"]
            assert result["continue"] is True
            assert "AI_MEMORY_BOOTSTRAP_STATUS = PASS" in context
            assert "MEMORY_STATUS = EMPTY" in context
            assert "UNVERIFIED on the target host" in context
            assert len(context.encode("utf-8")) <= 4096
        assert snapshot() == before
        assert "BLOCKED_EXISTING_TARGET" in run(package / "INSTALL.ps1", "-TargetProjectRoot",
                                                str(target), expected=2)
        assert snapshot() == before
        # Guard must reject a nonempty memory slot, restoring original bytes afterward.
        from build_release import BUNDLE
        slot = BUNDLE / "canonical/profile.md"
        original = slot.read_bytes()
        try:
            slot.write_bytes(original + b"\nSynthetic private preference\n")
            try:
                audit_sources()
            except ValueError:
                pass
            else:
                raise AssertionError("Privacy guard accepted modified memory")
        finally:
            slot.write_bytes(original)
        audit_sources()
        return {"status": "PASS", "selftest_pass": 11, "selftest_fail": 0,
                "installed_empty_state": "PASS", "simulated_sources": 4,
                "no_write": "PASS", "no_overwrite": "PASS", "privacy_negative_test": "PASS",
                "real_target_lifecycle": "UNVERIFIED"}
    finally:
        assert temp.parent == ROOT and temp.name.startswith(".release-test-")
        shutil.rmtree(temp)


if __name__ == "__main__":
    print(json.dumps(verify()))
