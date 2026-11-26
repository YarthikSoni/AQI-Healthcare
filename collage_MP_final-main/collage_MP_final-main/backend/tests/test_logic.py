from app.utils.aqi import cpcb_aqi,cpcb_category
from app.utils.haversine import haversine_km
from app.services.logic import risk_assessment,symptoms,interventions,exposure_estimate
from app.services.hospitals import parse_overpass

def test_aqi():
    assert cpcb_aqi(40,80)==80
    assert cpcb_category(50)== "Good"

def test_risk():
    r=risk_assessment({"age":70,"fitness":"low","commute_minutes":60,"outdoor_minutes":30,"sensitivities":["respiratory"],"has_purifier":False},200)
    assert r["score"]>50 and r["level"] in {"High","Very High"}

def test_symptoms():
    s=symptoms({"sensitivities":["respiratory"]},{"pm2_5":100,"pm10":150,"no2":50,"co":1000},{})
    assert 0<=s["peak_probability"]<=95

def test_interventions():
    x=interventions({},[{"pm2_5":v} for v in [10,90,20]])
    assert "avoid_window" in x and "key" in x["avoid_window"]

def test_exposure():
    x=exposure_estimate([{"microenvironment":"outdoor","hours":2,"activity_level":1}],80)
    assert x["dose"]>0

def test_haversine():
    d=haversine_km(28.6139,77.2090,28.6139,77.2090)
    assert d==0

def test_hospital_parse():
    data={"elements":[{"id":1,"lat":28.61,"lon":77.20,"tags":{"name":"City Hospital","addr:street":"Main Road","phone":"+91123","emergency":"yes"}}]}
    x=parse_overpass(data,28.6139,77.2090,30)
    assert x[0]["name"]=="City Hospital" and x[0]["emergency"]
