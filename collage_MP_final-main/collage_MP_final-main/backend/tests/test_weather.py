import asyncio

from app.services import weather


def test_air_combines_current_conditions_with_hourly_forecast(monkeypatch):
    current = {
        "list": [
            {
                "main": {"aqi": 3},
                "components": {"pm2_5": 42.0, "pm10": 70.0},
            }
        ]
    }
    forecast = {
        "list": [
            {"dt": 1_800_000_000, "components": {"pm2_5": 45.0, "pm10": 72.0}},
            {"dt": 1_800_003_600, "components": {"pm2_5": 49.0, "pm10": 75.0}},
        ]
    }
    requested_paths = []

    async def fake_owm(path, params):
        requested_paths.append(path)
        if path == "/data/2.5/air_pollution":
            return current
        if path == "/data/2.5/air_pollution/forecast":
            return forecast
        raise AssertionError(f"Unexpected OpenWeatherMap path: {path}")

    weather.CACHE.clear()
    monkeypatch.setattr(weather, "DEMO_MODE", False)
    monkeypatch.setattr(weather, "OPENWEATHER_API_KEY", "test-key")
    monkeypatch.setattr(weather, "owm", fake_owm)

    result = asyncio.run(weather.air(28.6, 77.2))

    assert set(requested_paths) == {
        "/data/2.5/air_pollution",
        "/data/2.5/air_pollution/forecast",
    }
    assert result["aqi"] == 3
    assert result["components"]["pm2_5"] == 42.0
    assert [point["pm2_5"] for point in result["hourly"]] == [45.0, 49.0]
    assert result["mode"] == "live"
