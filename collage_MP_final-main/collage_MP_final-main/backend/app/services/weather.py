import asyncio
import time
from urllib.parse import urlencode

import httpx

from app.core.config import (
    DEMO_MODE,
    OWM_BASE,
    OPENWEATHER_API_KEY,
    OWM_MISSING,
)
from app.services.demo import DEMO_COMPONENTS, DEMO_HOURLY, DEMO_WEATHER

CACHE = {}


def key_missing():
    return not OPENWEATHER_API_KEY or OPENWEATHER_API_KEY.startswith("YOUR_")


async def owm(path, params):
    if DEMO_MODE or key_missing():
        raise LookupError(OWM_MISSING)
    query = urlencode({**params, "appid": OPENWEATHER_API_KEY})
    async with httpx.AsyncClient(timeout=12) as client:
        response = await client.get(f"{OWM_BASE}{path}?{query}")
        response.raise_for_status()
        return response.json()


async def cached_async(key, ttl, awaitable):
    now = time.time()
    if key in CACHE:
        value, expires = CACHE[key]
        if expires > now:
            return value
    value = await awaitable()
    CACHE[key] = (value, now + ttl)
    return value


def normalize_air_data(current, forecast):
    current_items = current.get("list") or []
    if not current_items:
        raise ValueError("OpenWeatherMap returned no current air-pollution data.")

    current_item = current_items[0]
    hourly = []
    for item in forecast.get("list") or []:
        components = item.get("components") or {}
        if item.get("dt") is None or components.get("pm2_5") is None:
            continue
        hourly.append({"timestamp": int(item["dt"]), **components})

    return {
        "components": current_item.get("components") or {},
        "aqi": (current_item.get("main") or {}).get("aqi", 1),
        "hourly": hourly,
        "mode": "live",
    }


def demo_air_data():
    return {
        "components": DEMO_COMPONENTS,
        "aqi": 1,
        "hourly": DEMO_HOURLY,
        "mode": "demo",
    }


async def air(lat, lon):
    if DEMO_MODE or key_missing():
        return demo_air_data()

    coordinate = {"lat": lat, "lon": lon}
    cache_key = f"air:{round(lat, 2)}:{round(lon, 2)}"
    try:
        current, forecast = await asyncio.gather(
            cached_async(
                f"{cache_key}:current",
                900,
                lambda: owm("/data/2.5/air_pollution", coordinate),
            ),
            cached_async(
                f"{cache_key}:forecast",
                900,
                lambda: owm("/data/2.5/air_pollution/forecast", coordinate),
            ),
        )
        return normalize_air_data(current, forecast)
    except httpx.TransportError:
        return demo_air_data()


async def weather(lat, lon):
    try:
        if DEMO_MODE or key_missing():
            return {**DEMO_WEATHER, "mode": "demo"}
        key = f"weather:{round(lat, 2)}:{round(lon, 2)}"
        data = await cached_async(
            key,
            900,
            lambda: owm(
                "/data/2.5/weather",
                {"lat": lat, "lon": lon, "units": "metric"},
            ),
        )
        return {
            "temperature": data["main"]["temp"],
            "feels_like": data["main"]["feels_like"],
            "humidity": data["main"]["humidity"],
            "wind_speed": data["wind"]["speed"],
            "rain_probability": 0,
            "timezone_offset": data.get("timezone", 0),
            "timezone": data.get("name", ""),
            "description": data["weather"][0]["description"],
            "mode": "live",
        }
    except httpx.TransportError:
        return {**DEMO_WEATHER, "mode": "demo"}
