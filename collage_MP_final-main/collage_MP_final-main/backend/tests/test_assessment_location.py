import asyncio

from app.api.v1 import router
from app.schemas.schemas import AssessmentIn, ProfileIn


def test_assessment_returns_the_selected_location(monkeypatch):
    async def fake_air(lat, lon):
        return {"aqi": 20, "components": {}, "hourly": []}

    async def fake_weather(lat, lon):
        return {"temperature": 22}

    monkeypatch.setattr(router, "get_air", fake_air)
    monkeypatch.setattr(router, "get_weather", fake_weather)
    body = AssessmentIn(
        lat=18.5204,
        lon=73.8567,
        location_name="Pune",
        profile=ProfileIn(age=30),
    )

    result = asyncio.run(router.assessment(body))

    assert result["location"] == {
        "name": "Pune",
        "lat": 18.5204,
        "lon": 73.8567,
    }
