"""yandex-bd.py parse(): organic results only (ads, wizards, Yandex-internal links dropped), redirect unwrapped."""
import importlib.util
import os

HERE = os.path.dirname(os.path.abspath(__file__))
SPEC = importlib.util.spec_from_file_location("yandex_bd_mod", os.path.join(HERE, "..", "scripts", "yandex-bd.py"))
yb = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(yb)


def item(href, title, snippet, extra=""):
    return ('<li class="serp-item"%s><div><a class="Link OrganicTitle-Link" href="%s"><h2 class="OrganicTitle-LinkText">%s</h2></a>'
            '<div><span class="OrganicTextContentSpan">%s</span>\n</div> 12 окт 2026</div></li>') % (extra, href, title, snippet)


PAGE = "<html><ul>" + "".join([
    item("https://vc.ru/a/1", "Первый <b>результат</b>", "Текст первого"),
    item("https://yabs.yandex.ru/count/x", "Реклама", "Реклама тут"),
    item("https://ya.ru/wiz", "Колдунщик", "x", extra=' data-fast-name="entity_search"'),
    item("https://yandex.ru/images/search?text=x", "Картинки", "x"),
    item("https://tr-page.yandex.ru/translate?url=https%3A%2F%2Fexample.com%2Fp", "Перевод", "Через переводчик"),
    item("https://vc.ru/a/1", "Дубль", "Дубль"),
]) + "</ul></html>"


def test_parse_keeps_organic_only():
    docs, items = yb.parse(PAGE)
    assert items == 6
    assert [d["url"] for d in docs] == ["https://vc.ru/a/1", "https://example.com/p"]
    assert docs[0]["title"] == "Первый результат" and docs[0]["domain"] == "vc.ru"
    assert docs[0]["headline"] == "Текст первого" and docs[0]["modtime"] == "12 окт 2026"


def test_parse_empty_page():
    assert yb.parse("<html>captcha</html>") == ([], 0)
