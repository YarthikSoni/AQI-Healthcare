import logging
import time

import httpx

from app.core.config import GEOAPIFY_API_KEY
from app.utils.haversine import haversine_km

GEOAPIFY_URL = "https://api.geoapify.com/v2/places"
OVERPASS_MIRRORS = [
    "https://overpass.private.coffee/api/interpreter",
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
]
CACHE = {}
logger = logging.getLogger(__name__)


def parse_tags(tags):
    address = ", ".join(
        filter(
            None,
            [
                tags.get("addr:housenumber"),
                tags.get("addr:street"),
                tags.get("addr:city"),
                tags.get("addr:postcode"),
            ],
        )
    )
    return address or tags.get("addr:full", "")


def hospital_record(
    *,
    record_id,
    name,
    lat,
    lon,
    origin_lat,
    origin_lon,
    address="",
    phone=None,
    website=None,
    opening_hours=None,
    emergency=False,
    speciality=None,
    category="hospital",
):
    distance = haversine_km(origin_lat, origin_lon, lat, lon)
    return {
        "id": record_id,
        "name": name or f"Unnamed {category}",
        "category": category,
        "lat": lat,
        "lon": lon,
        "distance_km": round(distance, 2),
        "address": address,
        "phone": phone,
        "website": website,
        "opening_hours": opening_hours,
        "emergency": str(emergency).lower() == "yes" or emergency is True,
        "speciality": speciality,
        "directions_url": f"https://www.google.com/maps/dir/?api=1&destination={lat},{lon}",
    }


def parse_overpass(data, lat, lon, limit, category="hospital"):
    results = []
    for element in data.get("elements", []):
        tags = element.get("tags", {}) or {}
        center = element.get("center") or {}
        element_lat = element.get("lat", center.get("lat"))
        element_lon = element.get("lon", center.get("lon"))
        if element_lat is None or element_lon is None:
            continue
        results.append(
            hospital_record(
                record_id=element["id"],
                name=tags.get("name"),
                lat=float(element_lat),
                lon=float(element_lon),
                origin_lat=lat,
                origin_lon=lon,
                address=parse_tags(tags),
                phone=tags.get("phone") or tags.get("contact:phone"),
                website=tags.get("website") or tags.get("contact:website"),
                opening_hours=tags.get("opening_hours"),
                emergency=tags.get("emergency", ""),
                speciality=tags.get("healthcare:speciality"),
                category=category,
            )
        )
    return sorted(results, key=lambda item: item["distance_km"])[:limit]


def parse_geoapify(data, lat, lon, radius_m, limit, category="hospital"):
    results = []
    for index, feature in enumerate(data.get("features", [])):
        properties = feature.get("properties", {}) or {}
        geometry = feature.get("geometry", {}) or {}
        coordinates = geometry.get("coordinates") or []
        feature_lat = properties.get("lat")
        feature_lon = properties.get("lon")
        if feature_lat is None and len(coordinates) >= 2:
            feature_lon, feature_lat = coordinates[:2]
        if feature_lat is None or feature_lon is None:
            continue

        feature_lat = float(feature_lat)
        feature_lon = float(feature_lon)
        distance = haversine_km(lat, lon, feature_lat, feature_lon)
        if distance > radius_m / 1000:
            continue

        datasource = properties.get("datasource") or {}
        raw = datasource.get("raw") or {}
        tags = raw.get("tags") or raw
        contact = properties.get("contact") or {}
        categories = properties.get("categories") or []
        speciality = tags.get("healthcare:speciality")
        if not speciality:
            speciality = next(
                (
                    category.removeprefix("healthcare.clinic_or_praxis.")
                    for category in categories
                    if category.startswith("healthcare.clinic_or_praxis.")
                ),
                None,
            )
        address = properties.get("formatted") or ", ".join(
            filter(
                None,
                [properties.get("address_line1"), properties.get("address_line2")],
            )
        )
        results.append(
            hospital_record(
                record_id=properties.get("place_id") or raw.get("id") or f"geoapify-{index}",
                name=properties.get("name") or tags.get("name"),
                lat=feature_lat,
                lon=feature_lon,
                origin_lat=lat,
                origin_lon=lon,
                address=address,
                phone=properties.get("phone")
                or contact.get("phone")
                or tags.get("phone")
                or tags.get("contact:phone"),
                website=properties.get("website")
                or contact.get("website")
                or tags.get("website")
                or tags.get("contact:website"),
                opening_hours=properties.get("opening_hours")
                or tags.get("opening_hours"),
                emergency=properties.get("emergency") or tags.get("emergency", ""),
                speciality=speciality,
                category=category,
            )
        )
    return sorted(results, key=lambda item: item["distance_km"])[:limit]


async def geoapify_nearby(
    lat, lon, radius_m, limit, include_clinics, category="hospital"
):
    categories = (
        ["healthcare.pharmacy"]
        if category == "pharmacy"
        else ["healthcare.hospital"]
    )
    if category == "hospital" and include_clinics:
        categories.append("healthcare.clinic_or_praxis")
    params = {
        "categories": ",".join(categories),
        "filter": f"circle:{lon},{lat},{radius_m}",
        "bias": f"proximity:{lon},{lat}",
        "limit": min(max(limit, 1), 500),
        "lang": "en",
    }
    headers = {
        "x-api-key": GEOAPIFY_API_KEY,
        "User-Agent": "AQI-Public-Health-Monitor/1.0 (educational demo)",
    }
    try:
        async with httpx.AsyncClient(
            timeout=httpx.Timeout(12, connect=5), headers=headers
        ) as client:
            response = await client.get(GEOAPIFY_URL, params=params)
            response.raise_for_status()
            return parse_geoapify(
                response.json(), lat, lon, radius_m, limit, category
            )
    except (httpx.HTTPError, ValueError) as exc:
        raise RuntimeError(f"Geoapify {category} search failed.") from exc


async def overpass_nearby(
    lat, lon, radius_m, limit, include_clinics, category="hospital"
):
    amenity = "pharmacy" if category == "pharmacy" else "hospital"
    query = (
        f'[out:json][timeout:10];(nwr["amenity"="{amenity}"]'
        f"(around:{radius_m},{lat},{lon});"
    )
    if category == "hospital" and include_clinics:
        query += (
            f'nwr["amenity"="clinic"](around:{radius_m},{lat},{lon});'
        )
    query += ");out center;"
    last_error = None

    async with httpx.AsyncClient(
        timeout=httpx.Timeout(12, connect=5),
        headers={"User-Agent": "AQI-Public-Health-Monitor/1.0 (educational demo)"},
    ) as client:
        for url in OVERPASS_MIRRORS:
            try:
                response = await client.post(url, data={"data": query})
                response.raise_for_status()
                return parse_overpass(
                    response.json(), lat, lon, limit, category
                )
            except (httpx.HTTPError, ValueError) as exc:
                logger.warning("Overpass mirror %s failed: %s", url, exc)
                last_error = exc
    raise RuntimeError(f"OpenStreetMap {category} search failed.") from last_error


async def nearby(
    lat, lon, radius_m, limit, include_clinics, category="hospital"
):
    key = (
        f"{round(lat, 3)}:{round(lon, 3)}:{radius_m}:{limit}:"
        f"{category}:{include_clinics}:{bool(GEOAPIFY_API_KEY)}"
    )
    now = time.time()
    if key in CACHE and CACHE[key][1] > now:
        return CACHE[key][0]

    geoapify_error = None
    if GEOAPIFY_API_KEY:
        try:
            results = await geoapify_nearby(
                lat, lon, radius_m, limit, include_clinics, category
            )
            CACHE[key] = (results, now + 3600)
            return results
        except RuntimeError as exc:
            geoapify_error = exc
            logger.warning("Geoapify %s provider failed; trying Overpass.", category)

    try:
        results = await overpass_nearby(
            lat, lon, radius_m, limit, include_clinics, category
        )
    except RuntimeError as exc:
        if geoapify_error:
            raise RuntimeError(
                f"{category.title()} search is temporarily unavailable from Geoapify and OpenStreetMap."
            ) from exc
        raise

    CACHE[key] = (results, now + 3600)
    return results
