import React, { useEffect, useId, useState } from "react";
import { api } from "../api/client";
import useI18n from "../hooks/useI18n";
import { locationLabel } from "../utils/location";

export default function CitySearch({
  onSelect,
  className = "",
  labelKey = "profile.cityLabel",
  placeholderKey = "profile.cityPlaceholder",
  hideLabel = false,
  selectedLocation = null,
}) {
  const { t } = useI18n();
  const inputId = useId();
  const [query, setQuery] = useState(
    selectedLocation ? locationLabel(selectedLocation) : "",
  );
  const [matches, setMatches] = useState([]);
  const [searching, setSearching] = useState(false);
  const [message, setMessage] = useState("");

  useEffect(() => {
    setQuery(selectedLocation ? locationLabel(selectedLocation) : "");
  }, [
    selectedLocation?.name,
    selectedLocation?.lat,
    selectedLocation?.lon,
    selectedLocation?.country,
  ]);

  const chooseLocation = async (location) => {
    setSearching(true);
    setMessage("");
    try {
      await onSelect(location);
      setMatches([]);
      setQuery(locationLabel(location));
    } catch {
      setMessage(t("landing.citySaveError"));
    } finally {
      setSearching(false);
    }
  };

  const search = async (event) => {
    event.preventDefault();
    const city = query.trim();
    if (!city) return;

    setSearching(true);
    setMessage("");
    setMatches([]);
    try {
      const results = await api(`/location/search?q=${encodeURIComponent(city)}`);
      if (!results.length) {
        setMessage(t("landing.cityNotFound"));
      } else if (results.length === 1) {
        try {
          await onSelect(results[0]);
          setQuery(locationLabel(results[0]));
        } catch {
          setMessage(t("landing.citySaveError"));
        }
      } else {
        setMatches(results);
      }
    } catch {
      setMessage(t("landing.citySearchError"));
    } finally {
      setSearching(false);
    }
  };

  return (
    <div className={`city-search ${className}`.trim()}>
      <form onSubmit={search}>
        <label className={hideLabel ? "sr-only" : ""} htmlFor={inputId}>
          {t(labelKey)}
        </label>
        <div className="city-search-row">
          <input
            id={inputId}
            type="search"
            value={query}
            placeholder={t(placeholderKey)}
            onChange={(event) => setQuery(event.target.value)}
          />
          <button
            className="button"
            type="submit"
            disabled={searching || !query.trim()}
          >
            {searching ? t("landing.searching") : t("landing.search")}
          </button>
        </div>
      </form>
      {matches.length > 0 && (
        <div className="city-results" aria-label={t("landing.chooseCity")}>
          <span>{t("landing.chooseCity")}</span>
          {matches.map((location, index) => (
            <button
              key={`${location.lat}-${location.lon}-${index}`}
              type="button"
              onClick={() => chooseLocation(location)}
              disabled={searching}
            >
              {locationLabel(location)}
            </button>
          ))}
        </div>
      )}
      {message && (
        <small className="city-message" role="status">
          {message}
        </small>
      )}
    </div>
  );
}
