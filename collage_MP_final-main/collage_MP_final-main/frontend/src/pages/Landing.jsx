import React, { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import useI18n from "../hooks/useI18n";
import { usePreferences } from "../context/PreferencesContext";
import { api } from "../api/client";
import { useProfiles } from "../context/ProfilesContext";
import CitySearch from "../components/CitySearch";
import ThemeToggle from "../components/ThemeToggle";

export default function Landing() {
  const { t } = useI18n();
  const { lang, setLang } = usePreferences();
  const { activeProfile, updateProfile, error: profileError } = useProfiles();
  const [aqi, setAqi] = useState(null);
  const [message, setMessage] = useState("");

  useEffect(() => {
    if (!activeProfile) return undefined;
    let active = true;
    const location = activeProfile.city;
    setAqi(null);
    setMessage("");
    api(
      `/air?lat=${encodeURIComponent(location.lat)}&lon=${encodeURIComponent(location.lon)}`,
    )
      .then((data) => {
        if (active) setAqi(data);
      })
      .catch(() => {
        if (active) setMessage(t("landing.aqiUnavailable"));
      });
    return () => {
      active = false;
    };
  }, [
    activeProfile?.id,
    activeProfile?.city?.lat,
    activeProfile?.city?.lon,
    lang,
  ]);

  const selectCity = async (city) => {
    if (!activeProfile) {
      throw new Error("No active profile is available.");
    }
    updateProfile(activeProfile.id, { city });
  };

  return (
    <>
      <header className="landing-header">
        <a className="brand" href="#top">
          AQI Monitor
        </a>
        <nav>
          <a href="#features">{t("nav.features")}</a>
          <a href="#how">{t("nav.how")}</a>
        </nav>
        <div className="toggles">
          <ThemeToggle />
          <button onClick={() => setLang(lang === "en" ? "hi" : "en")}>
            {lang === "en" ? "EN" : "हिन्दी"}
          </button>
        </div>
        <Link className="button" to="/app/dashboard">
          {t("nav.open")}
        </Link>
      </header>
      <main id="top">
        <section className="hero">
          <div>
            <p className="eyebrow">Personal air health intelligence</p>
            <h1>{t("hero.title")}</h1>
            <p>{t("hero.subtitle")}</p>
            <Link className="button" to="/app/dashboard">
              {t("hero.cta")}
            </Link>
          </div>
          <aside className="aqi-card">
            <span>{t("snapshot.title")}</span>
            <strong>{aqi?.aqi ?? "—"}</strong>
            <b>{aqi?.category || t("common.loading")}</b>
            {!activeProfile && profileError ? (
              <span className="snapshot-city">{profileError}</span>
            ) : null}
            {aqi?.mode === "demo" && (
              <small className="demo-note">{t("landing.demoData")}</small>
            )}
            {activeProfile && (
              <CitySearch
                key={activeProfile.id}
                labelKey="profile.cityLabel"
                selectedLocation={activeProfile.city}
                onSelect={selectCity}
              />
            )}
            {message && (
              <small className="city-message" role="status">
                {message}
              </small>
            )}
          </aside>
        </section>
        <section id="features" className="section">
          <h2>{t("features.title")}</h2>
          <div className="feature-grid">
            {[
              "Personal risk",
              "Hourly symptoms",
              "Micro-interventions",
              "Weather-aware forecasts",
              "Nearby hospitals",
            ].map((feature) => (
              <article key={feature}>
                <h3>{feature}</h3>
                <p>Clear, local guidance for the air around you.</p>
              </article>
            ))}
          </div>
        </section>
        <section id="how" className="section">
          <h2>How it works</h2>
          <div className="steps">
            <b>1. Share your profile</b>
            <b>2. Check your location</b>
            <b>3. Follow calm, timed advice</b>
          </div>
        </section>
      </main>
      <footer className="landing-footer">
        <section id="methods" className="footer-section">
          <h2>Data and methods</h2>
          <p>
            OpenWeatherMap, OpenStreetMap, harmonised public datasets and
            transparent heuristic ML-assisted signals.
          </p>
        </section>
        <section id="faq" className="footer-section">
          <h2>FAQ</h2>
          <details>
            <summary>Is this medical advice?</summary>
            <p>{t("disclaimer")}</p>
          </details>
        </section>
        <p className="footer-disclaimer">{t("disclaimer")}</p>
      </footer>
    </>
  );
}
