"""yt-transcript.py: pick_track takes the `-orig` track of the video's audio language, not the first one."""
import importlib.util
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "yt-transcript.py"
spec = importlib.util.spec_from_file_location("yt_transcript_under_test", SCRIPT)
yt = importlib.util.module_from_spec(spec)
spec.loader.exec_module(yt)

# Shape of `yt-dlp -J Ajqub1jgsVM` on 2026-10-11: English video (language en-US), no manual subs,
# 21 `-orig` keys in automatic_captions (one per auto-dubbed audio track), the first one `ar-orig`.
DUB_ORIG = ["ar", "bn", "de-DE", "en", "es", "fr", "hi", "id", "it", "ja", "ko", "ml", "nl", "pl",
            "pt", "ru", "ta", "te", "th", "tr", "uk"]
TRANSLATIONS = ["ab", "af", "ar", "de", "en", "es", "fr", "pl", "ru", "uk", "zh-Hans"]


def info(language="en-US", origs=DUB_ORIG, translations=TRANSLATIONS, subtitles=None):
    auto = {k + "-orig": [{}] for k in origs}
    auto.update({k: [{}] for k in translations})
    return {"language": language, "subtitles": subtitles or {}, "automatic_captions": auto}


def test_dubbed_video_takes_audio_language_orig():
    assert yt.pick_track(info(), ["en", "ru", "pl"]) == ("en-orig", True)


def test_requested_lang_does_not_pull_a_dub():
    # --lang ru must not return ru-orig (a dubbed track) when the audio is English
    assert yt.pick_track(info(), ["ru"]) == ("en-orig", True)


def test_regional_orig_matches_base_language():
    assert yt.pick_track(info(language="de", origs=["ar", "de-DE", "en"]), ["en"]) == ("de-DE-orig", True)


def test_exact_regional_orig_wins():
    assert yt.pick_track(info(language="pt-BR", origs=["pt", "pt-BR"]), ["en"]) == ("pt-BR-orig", True)


def test_unknown_language_single_orig_is_the_original():
    assert yt.pick_track(info(language=None, origs=["ja"]), ["en", "ru"]) == ("ja-orig", True)


def test_unknown_language_many_origs_uses_requested_lang():
    assert yt.pick_track(info(language=None), ["ru", "en"]) == ("ru-orig", True)


def test_no_matching_orig_falls_to_requested_translation_not_foreign_orig():
    # audio language has no -orig track: take the requested-language translation, never `ar-orig`
    got = yt.pick_track(info(language="sv", origs=["ar", "bn"]), ["en"])
    assert got == ("en", True)


def test_manual_subtitles_still_win():
    assert yt.pick_track(info(subtitles={"en": [{}], "ar": [{}]}), ["en"]) == ("en", False)


def test_no_captions():
    assert yt.pick_track({"language": "en"}, ["en"]) == (None, None)


def test_missing_plugin_is_skipped_silently(monkeypatch, capsys):
    monkeypatch.setattr(yt, "PLUGIN_PY", "/nonexistent/python3")
    assert yt.try_plugin("Ajqub1jgsVM") == (None, None)
    out = capsys.readouterr()
    assert out.out == "" and out.err == ""
