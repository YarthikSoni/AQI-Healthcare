import React, { useEffect, useMemo, useRef, useState } from "react";
import { MapContainer, Marker, TileLayer, useMap } from "react-leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";
import useI18n from "../hooks/useI18n";
import { api } from "../api/client";
import { getSavedLocation, saveSelectedLocation } from "../utils/location";

const divIcon = (active = false) =>
  L.divIcon({
    className: "",
    html: `<div class="map-pin ${active ? "active" : ""}"></div>`,
    iconSize: [18, 18],
    iconAnchor: [9, 9],
  });

function Pan({ selected, center }) {
  const map = useMap();
  useEffect(() => {
    if (selected) map.flyTo([selected.lat, selected.lon], 14, { duration: 0.6 });
    else if (center) map.setView(center);
  }, [selected, center, map]);
  return null;
}

export default function Hospitals() {
  const { t, lang } = useI18n();
  const [location, setLocation] = useState(getSavedLocation);
  const center = useMemo(() => [location.lat, location.lon], [location.lat, location.lon]);
  const [radius, setRadius] = useState(5000);
  const [category, setCategory] = useState("hospital");
  const [filter, setFilter] = useState("");
  const [items, setItems] = useState([]);
  const [selected, setSelected] = useState(null);
  const [locating, setLocating] = useState(false);
  const [loading, setLoading] = useState(true);
  const [refresh, setRefresh] = useState(0);
  const [message, setMessage] = useState("");
  const cards = useRef({});

  useEffect(() => {
    let active = true;
    setLoading(true);
    setMessage("");
    setItems([]);
    setSelected(null);
    api(
      `/hospitals/nearby?lat=${location.lat}&lon=${location.lon}&radius_m=${radius}&limit=30&category=${category}`,
    )
      .then((data) => {
        if (!active) return;
        setItems(data.places ?? data.hospitals);
        setSelected(null);
      })
      .catch((error) => {
        if (!active) return;
        setItems([]);
        setMessage(
          error.message === "Failed to fetch"
            ? t("hospitals.loadError")
            : error.message,
        );
      })
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => {
      active = false;
    };
  }, [location.lat, location.lon, radius, category, refresh, lang]);

  const locate = () => {
    setMessage("");
    if (!navigator.geolocation) {
      setMessage(t("hospitals.locationUnsupported"));
      return;
    }

    setLocating(true);
    navigator.geolocation.getCurrentPosition(
      ({ coords }) => {
        const currentLocation = {
          name: t("hospitals.currentLocation"),
          lat: coords.latitude,
          lon: coords.longitude,
        };
        saveSelectedLocation(currentLocation);
        setLocation(currentLocation);
        setSelected(null);
        setRefresh((value) => value + 1);
        setLocating(false);
      },
      (error) => {
        setMessage(
          error.code === error.PERMISSION_DENIED
            ? t("hospitals.locationDenied")
            : t("hospitals.locationUnavailable"),
        );
        setLocating(false);
      },
      { enableHighAccuracy: true, timeout: 15000, maximumAge: 60000 },
    );
  };

  const retrySearch = () => setRefresh((value) => value + 1);

  const visible = useMemo(
    () =>
      items.filter((place) =>
        (place.name || "").toLowerCase().includes(filter.toLowerCase()),
      ),
    [items, filter],
  );

  const pick = (place) => {
    setSelected(place);
    cards.current[place.id]?.scrollIntoView({
      block: "nearest",
      behavior: "smooth",
    });
  };

  return (
    <>
      <div className="page-heading">
        <div>
          <h1>
            {t(
              category === "hospital"
                ? "hospitals.title"
                : "hospitals.pharmaciesTitle",
            )}
          </h1>
          <p className="eyebrow">
            {t("hospitals.nearLocation", { location: location.name })}
          </p>
        </div>
      </div>
      <div
        className="place-categories"
        role="group"
        aria-label={t("hospitals.categoryLabel")}
      >
        <button
          type="button"
          aria-pressed={category === "hospital"}
          onClick={() => {
            setCategory("hospital");
            setFilter("");
          }}
        >
          {t("hospitals.hospitalsOption")}
        </button>
        <button
          type="button"
          aria-pressed={category === "pharmacy"}
          onClick={() => {
            setCategory("pharmacy");
            setFilter("");
          }}
        >
          {t("hospitals.pharmaciesOption")}
        </button>
      </div>
      <div className="hospital-toolbar">
        <button className="button location-button" onClick={locate} disabled={locating}>
          {locating ? t("hospitals.locating") : t("hospitals.useLocation")}
        </button>
        <label>
          {t("hospitals.radius")}
          <select value={radius} onChange={(event) => setRadius(+event.target.value)}>
            <option value="2000">2 km</option>
            <option value="5000">5 km</option>
            <option value="10000">10 km</option>
          </select>
        </label>
        <input
          aria-label={t("hospitals.filter")}
          placeholder={t("hospitals.filter")}
          value={filter}
          onChange={(event) => setFilter(event.target.value)}
        />
      </div>
      {message && (
        <p className="inline-message" role="status">
          {message}{" "}
          <button type="button" className="inline-retry" onClick={retrySearch}>
            {t("common.retry")}
          </button>
        </p>
      )}
      <div className="hospital-layout">
        <aside className="hospital-list" aria-live="polite">
          {loading ? (
            <p className="hospital-empty">{t("common.loading")}…</p>
          ) : visible.length ? (
            visible.map((hospital) => (
              <article
                ref={(element) => {
                  cards.current[hospital.id] = element;
                }}
                className={`hospital-card ${
                  selected?.id === hospital.id ? "selected" : ""
                }`}
                key={hospital.id}
                onClick={() => pick(hospital)}
              >
                <h2>{hospital.name}</h2>
                <b>{hospital.distance_km} km</b>
                {hospital.emergency && <span className="badge">Emergency</span>}
                <p>{hospital.address || "Address not listed"}</p>
                {hospital.phone && <a href={`tel:${hospital.phone}`}>{hospital.phone}</a>}
                <a
                  className="directions"
                  target="_blank"
                  rel="noreferrer"
                  href={hospital.directions_url}
                >
                  {t("hospitals.directions")}
                </a>
              </article>
            ))
          ) : (
            <p className="hospital-empty">
              {t(
                category === "hospital"
                  ? "hospitals.empty"
                  : "hospitals.pharmaciesEmpty",
              )}
            </p>
          )}
        </aside>
        <div className="hospital-map">
          <MapContainer center={center} zoom={13} style={{ height: "100%", width: "100%" }}>
            <TileLayer
              attribution="&copy; OpenStreetMap contributors"
              url={
                document.documentElement.dataset.theme === "dark"
                  ? "https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
                  : "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
              }
            />
            <Marker position={center} icon={divIcon(true)} />
            {visible.map((hospital) => (
              <Marker
                key={hospital.id}
                position={[hospital.lat, hospital.lon]}
                icon={divIcon(selected?.id === hospital.id)}
                eventHandlers={{ click: () => pick(hospital) }}
              />
            ))}
            <Pan selected={selected} center={center} />
          </MapContainer>
        </div>
      </div>
    </>
  );
}
