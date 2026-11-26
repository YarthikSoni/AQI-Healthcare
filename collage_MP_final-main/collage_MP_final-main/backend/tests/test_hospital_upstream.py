import asyncio

import httpx
import pytest

from app.services import hospitals


def test_hospital_upstream_failure_is_not_reported_as_empty_results(monkeypatch):
    class UnavailableClient:
        def __init__(self, *args, **kwargs):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *args):
            return False

        async def post(self, *args, **kwargs):
            raise httpx.ConnectError("offline")

    hospitals.CACHE.clear()
    monkeypatch.setattr(hospitals, "GEOAPIFY_API_KEY", "")
    monkeypatch.setattr(hospitals, "OVERPASS_MIRRORS", ["mirror-a", "mirror-b"])
    monkeypatch.setattr(hospitals.httpx, "AsyncClient", UnavailableClient)

    with pytest.raises(RuntimeError, match="OpenStreetMap hospital search failed"):
        asyncio.run(hospitals.nearby(28.6, 77.2, 5000, 30, False))


def test_geoapify_nearby_uses_backend_key_and_parses_feature(monkeypatch):
    class Response:
        def raise_for_status(self):
            pass

        def json(self):
            return {
                "features": [
                    {
                        "type": "Feature",
                        "geometry": {
                            "type": "Point",
                            "coordinates": [77.201, 28.601],
                        },
                        "properties": {
                            "place_id": "geo-place-1",
                            "name": "City Hospital",
                            "lat": 28.601,
                            "lon": 77.201,
                            "formatted": "1 Main Road, New Delhi",
                            "phone": "+911234567890",
                            "categories": ["healthcare.hospital"],
                        },
                    }
                ]
            }

    class Client:
        def __init__(self, *args, **kwargs):
            self.headers = kwargs["headers"]

        async def __aenter__(self):
            return self

        async def __aexit__(self, *args):
            return False

        async def get(self, url, params):
            assert url == hospitals.GEOAPIFY_URL
            assert params["categories"] == (
                "healthcare.hospital,healthcare.clinic_or_praxis"
            )
            assert params["filter"] == "circle:77.2,28.6,5000"
            assert "apiKey" not in params
            assert self.headers["x-api-key"] == "test-key"
            return Response()

    hospitals.CACHE.clear()
    monkeypatch.setattr(hospitals, "GEOAPIFY_API_KEY", "test-key")
    monkeypatch.setattr(hospitals.httpx, "AsyncClient", Client)

    results = asyncio.run(hospitals.nearby(28.6, 77.2, 5000, 30, True))
    assert results[0]["id"] == "geo-place-1"
    assert results[0]["name"] == "City Hospital"
    assert results[0]["phone"] == "+911234567890"


def test_geoapify_separates_hospital_and_pharmacy_searches(monkeypatch):
    requested_categories = []

    class Response:
        def __init__(self, category):
            self.category = category

        def raise_for_status(self):
            pass

        def json(self):
            is_pharmacy = self.category == "healthcare.pharmacy"
            name = "Corner Pharmacy" if is_pharmacy else "Central Hospital"
            return {
                "features": [
                    {
                        "type": "Feature",
                        "geometry": {
                            "type": "Point",
                            "coordinates": [77.201, 28.601],
                        },
                        "properties": {
                            "place_id": name,
                            "name": name,
                            "lat": 28.601,
                            "lon": 77.201,
                            "categories": [self.category],
                        },
                    }
                ]
            }

    class Client:
        def __init__(self, *args, **kwargs):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *args):
            return False

        async def get(self, url, params):
            requested_categories.append(params["categories"])
            return Response(params["categories"])

    hospitals.CACHE.clear()
    monkeypatch.setattr(hospitals, "GEOAPIFY_API_KEY", "test-key")
    monkeypatch.setattr(hospitals.httpx, "AsyncClient", Client)

    pharmacies = asyncio.run(
        hospitals.nearby(28.6, 77.2, 5000, 30, False, "pharmacy")
    )
    health_facilities = asyncio.run(
        hospitals.nearby(28.6, 77.2, 5000, 30, False, "hospital")
    )

    assert requested_categories == [
        "healthcare.pharmacy",
        "healthcare.hospital",
    ]
    assert pharmacies[0]["name"] == "Corner Pharmacy"
    assert pharmacies[0]["category"] == "pharmacy"
    assert health_facilities[0]["name"] == "Central Hospital"
    assert health_facilities[0]["category"] == "hospital"


def test_overpass_pharmacy_search_uses_pharmacy_amenity(monkeypatch):
    queries = []

    class Response:
        def raise_for_status(self):
            pass

        def json(self):
            return {
                "elements": [
                    {
                        "id": 123,
                        "lat": 28.601,
                        "lon": 77.201,
                        "tags": {
                            "amenity": "pharmacy",
                            "name": "Neighborhood Pharmacy",
                        },
                    }
                ]
            }

    class Client:
        def __init__(self, *args, **kwargs):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *args):
            return False

        async def post(self, url, data):
            queries.append(data["data"])
            return Response()

    monkeypatch.setattr(hospitals, "OVERPASS_MIRRORS", ["mirror"])
    monkeypatch.setattr(hospitals.httpx, "AsyncClient", Client)

    pharmacies = asyncio.run(
        hospitals.overpass_nearby(28.6, 77.2, 5000, 30, False, "pharmacy")
    )

    assert 'nwr["amenity"="pharmacy"]' in queries[0]
    assert 'nwr["amenity"="hospital"]' not in queries[0]
    assert pharmacies[0]["name"] == "Neighborhood Pharmacy"
    assert pharmacies[0]["category"] == "pharmacy"
