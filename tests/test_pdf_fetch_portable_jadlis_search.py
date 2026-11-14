"""pdf-fetch.sh on a machine without pdftotext (Linux without poppler-utils): exit 3 with PDF_TOOL_MISSING
before any download, instead of a misleading «PDF_EMPTY: скан/paywall»."""
import os
import shutil
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "..", "scripts", "pdf-fetch.sh")


def _bin_without_pdftotext(tmp_path):
    """A PATH with the basic tools the script needs and no pdftotext / markitdown."""
    b = tmp_path / "bin"
    b.mkdir()
    for tool in ("bash", "env", "printf", "cut", "mkdir", "shasum", "sha256sum", "curl", "find", "seq", "head",
                 "mktemp", "rm", "rmdir", "mv", "tr", "wc", "grep", "sleep", "awk", "dirname"):
        p = shutil.which(tool)
        if p:
            (b / tool).symlink_to(p)
    return str(b)


def test_missing_pdftotext_fails_loud_before_download(tmp_path):
    env = {"PATH": _bin_without_pdftotext(tmp_path), "HOME": str(tmp_path)}
    r = subprocess.run(["bash", SCRIPT, "http://127.0.0.1:9/nothing.pdf"], capture_output=True, text=True, env=env, timeout=30)
    assert r.returncode == 3
    assert "PDF_TOOL_MISSING" in r.stderr
    assert r.stdout == ""
    assert not (tmp_path / ".cache" / "pdf-fetch").exists()  # failed before touching the cache


def test_md_mode_with_markitdown_passes_the_tool_gate(tmp_path):
    b = _bin_without_pdftotext(tmp_path)
    fake = os.path.join(b, "markitdown")
    with open(fake, "w") as f:
        f.write("#!/bin/sh\nexit 0\n")
    os.chmod(fake, 0o755)
    # No Chrome fallback in the test: a missing binary keeps the run offline and fast.
    env = {"PATH": b, "HOME": str(tmp_path), "PDF_FETCH_LOCK_SEC": "1", "PDF_FETCH_CHROME": "/nonexistent/chrome"}
    r = subprocess.run(["bash", SCRIPT, "http://127.0.0.1:9/nothing.pdf", "--md"], capture_output=True, text=True,
                       env=env, timeout=60)
    assert "PDF_TOOL_MISSING" not in r.stderr  # passes the tool gate, then fails on the unreachable URL
    assert r.returncode == 2
