"""websearch.py: Brave dates normalise to YYYY-MM-DD whatever shape `age` comes in, and text rendering never crashes."""
import importlib.util
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "websearch.py"
spec = importlib.util.spec_from_file_location("websearch_under_test", SCRIPT)
ws = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ws)

URL = "https://www.informacion.es/vega-baja/2025/01/07/torrevieja.html"
# Shape seen in a live llm/context response on 2026-10-07: `age` is a list of four renderings, or [].
AGE_LIST = ["Wednesday, January 08, 2025", "2025-01-08", "636 days ago", "2025-01-08T13:37:18Z"]


def ctx(age):
    g = {"url": URL, "title": "Torrevieja", "snippets": ["padrón"]}
    return ws.norm_brave_ctx(g, {URL: {"title": "Torrevieja", "age": age}})


def test_ctx_age_list_gives_iso_date():
    assert ctx(AGE_LIST)["date"] == "2025-01-08"


def test_ctx_age_empty_list_gives_empty_date():
    assert ctx([])["date"] == ""


def test_ctx_age_string_still_works():
    assert ctx("2025-01-08T13:37:18Z")["date"] == "2025-01-08"


def test_ctx_missing_source_gives_empty_date():
    assert ws.norm_brave_ctx({"url": URL, "snippets": []}, None)["date"] == ""


def test_web_age_list_gives_iso_date():
    r = ws.norm_brave_web({"url": URL, "title": "t", "description": "d", "page_age": AGE_LIST})
    assert r["date"] == "2025-01-08"


def test_web_page_age_string_still_works():
    r = ws.norm_brave_web({"url": URL, "title": "t", "description": "d", "page_age": "2025-01-08T13:37:18"})
    assert r["date"] == "2025-01-08"


def test_render_results_with_ctx_list_age_does_not_crash():
    lines = ws.render_results([ctx(AGE_LIST), ctx([])])
    assert "2025-01-08" in lines[0]
    assert all(isinstance(line, str) for line in lines)
