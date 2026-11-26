import React, { useEffect, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import {
  Line,
  LineChart,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";

import { api } from "../api/client";
import CitySearch from "../components/CitySearch";
import useI18n from "../hooks/useI18n";
import { useProfiles } from "../context/ProfilesContext";
import { locationLabel } from "../utils/location";

function formatLocalHour(timestamp, timezoneOffset) {
  const hour = new Date(
    (Number(timestamp) + timezoneOffset) * 1000,
  ).getUTCHours();
  return `${String(hour).padStart(2, "0")}:00`;
}

function assessmentProfile(profile) {
  return {
    age: profile.age,
    fitness: profile.fitness,
    commute_mode: profile.commute_mode,
    commute_minutes: profile.commute_minutes,
    outdoor_minutes: profile.outdoor_minutes,
    sensitivities: profile.sensitivities,
    has_purifier: profile.has_purifier,
  };
}

export default function Dashboard() {
  const { t } = useI18n();
  const {
    activeProfile,
    profiles,
    activeProfileId,
    loading: profilesLoading,
    error: profilesError,
    retry: retryProfiles,
    selectProfile,
    addProfile,
    updateProfile,
  } = useProfiles();
  const navigate = useNavigate();
  const [data, setData] = useState(null);
  const [error, setError] = useState("");
  const [profileActionError, setProfileActionError] = useState("");

  useEffect(() => {
    if (!activeProfile) return undefined;
    let active = true;
    setData(null);
    setError("");
    api("/assessment", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        lat: activeProfile.city.lat,
        lon: activeProfile.city.lon,
        location_name: activeProfile.city.name,
        profile: assessmentProfile(activeProfile),
      }),
    })
      .then((assessment) => {
        if (active) setData(assessment);
      })
      .catch((requestError) => {
        if (active) setError(requestError.message);
      });
    return () => {
      active = false;
    };
  }, [activeProfile]);

  const selectCity = async (city) => {
    if (!activeProfile) {
      throw new Error("No active profile is available.");
    }
    updateProfile(activeProfile.id, { city });
  };

  const createProfile = () => {
    let name = "New profile";
    let suffix = 2;
    while (profiles.some((profile) => profile.name === name)) {
      name = `New profile ${suffix}`;
      suffix += 1;
    }
    try {
      addProfile(name);
      setProfileActionError("");
      navigate("/app/profile");
    } catch (actionError) {
      setProfileActionError(actionError.message);
    }
  };

  const hourly = Array.isArray(data?.air?.hourly)
    ? data.air.hourly.slice(0, 24)
    : [];
  const timezoneOffset = data?.weather.timezone_offset || 0;
  const shortcut = data
    ? data.risk.level === "High" || data.risk.level === "Very High"
    : false;

  return (
    <>
      <div className="page-heading">
        <div className="risk-location">
          <h1>Health dashboard</h1>
          {activeProfile && profiles.length > 0 && (
            <div className="active-profile-controls">
              <label className="sr-only" htmlFor="active-profile">
                Switch profile
              </label>
              <select
                id="active-profile"
                aria-label="Switch profile"
                value={activeProfileId}
                onChange={(event) => {
                  try {
                    selectProfile(event.target.value);
                    setProfileActionError("");
                  } catch (actionError) {
                    setProfileActionError(actionError.message);
                  }
                }}
              >
                {profiles.map((profile) => (
                  <option key={profile.id} value={profile.id}>
                    {profile.name}
                  </option>
                ))}
              </select>
              <button
                className="button profile-add-button"
                type="button"
                onClick={createProfile}
              >
                <span aria-hidden="true">+</span> Add profile
              </button>
            </div>
          )}
          {profileActionError && (
            <p className="inline-message" role="alert">
              {profileActionError}
            </p>
          )}
          {activeProfile && (
            <>
              <CitySearch
                key={activeProfile.id}
                className="risk-city-search"
                labelKey="profile.cityLabel"
                selectedLocation={activeProfile.city}
                onSelect={selectCity}
              />
            </>
          )}
        </div>
        {data && <span className="status">{data.air.category}</span>}
      </div>
      {profilesLoading ? (
        <p>{t("common.loading")}…</p>
      ) : profilesError ? (
        <div className="notice" role="alert">
          <p>{profilesError}</p>
          <button className="button" type="button" onClick={retryProfiles}>
            Retry
          </button>
        </div>
      ) : error ? (
        <div className="notice">
          <h2>{t("setup")}</h2>
          <p>{error}</p>
        </div>
      ) : !data ? (
        <p>{t("common.loading")}…</p>
      ) : (
        <>
          {data.air.mode === "demo" && (
            <p className="demo-note">{t("landing.demoData")}</p>
          )}
          <div className="metrics">
            <article>
              <span>AQI</span>
              <strong>{data.air.aqi}</strong>
            </article>
            <article>
              <span>{t("dashboard.risk")}</span>
              <strong>{data.risk.score}</strong>
              <small>{data.risk.level}</small>
            </article>
            <article>
              <span>Temperature</span>
              <strong>{data.weather.temperature}°C</strong>
            </article>
            <article>
              <span>Humidity</span>
              <strong>{data.weather.humidity}%</strong>
            </article>
          </div>
          {shortcut && (
            <div className="notice">
              <strong>{t("dashboard.hospitals")}</strong>
              <Link className="button" to="/app/hospitals">
                {t("hospitals.title")}
              </Link>
            </div>
          )}
          <div className="grid-two">
            <article className="panel">
              <h2>Hourly PM2.5</h2>
              {hourly.length ? (
                <div className="chart">
                  <ResponsiveContainer width="100%" height={260}>
                    <LineChart data={hourly}>
                      <XAxis
                        dataKey="timestamp"
                        tickFormatter={(value) =>
                          formatLocalHour(value, timezoneOffset)
                        }
                      />
                      <YAxis />
                      <Tooltip
                        labelFormatter={(value) =>
                          formatLocalHour(value, timezoneOffset)
                        }
                      />
                      <Line
                        type="monotone"
                        dataKey="pm2_5"
                        name="PM2.5"
                        stroke="#4f6f82"
                        strokeWidth={2}
                        dot={false}
                      />
                    </LineChart>
                  </ResponsiveContainer>
                </div>
              ) : (
                <p>{t("dashboard.hourlyUnavailable")}</p>
              )}
            </article>
            <article className="panel">
              <h2>Timed advice</h2>
              {data.interventions.advice.map((item, index) => (
                <p key={index}>{t(item.key, item.params) || item.text}</p>
              ))}
            </article>
          </div>
          <p className="emergency">
            <a href="tel:112">112</a> / <a href="tel:108">108</a> —{" "}
            {t("emergency.note")}
          </p>
        </>
      )}
    </>
  );
}
