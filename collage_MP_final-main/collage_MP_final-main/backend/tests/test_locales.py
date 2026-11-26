import json
from pathlib import Path

def test_locale_keys():
    root=Path(__file__).parents[2]/"frontend"/"src"/"locales"
    en=json.loads((root/"en.json").read_text())
    hi=json.loads((root/"hi.json").read_text())
    assert set(en)==set(hi)
