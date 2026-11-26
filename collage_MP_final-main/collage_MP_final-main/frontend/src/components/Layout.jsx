import React from "react";
import { NavLink, Outlet } from "react-router-dom";
import { usePreferences } from "../context/PreferencesContext";
import useI18n from "../hooks/useI18n";
import ThemeToggle from "./ThemeToggle";

export default function Layout() {
  const { lang, setLang } = usePreferences();
  const { t } = useI18n();
  return (
    <>
      <header className="app-header">
        <NavLink className="brand" to="/">
          AQI Monitor
        </NavLink>
        <nav>
          <NavLink to="/" end>
            {t("nav.home")}
          </NavLink>
          <NavLink to="/app/dashboard">{t("dashboard.risk")}</NavLink>
          <NavLink to="/app/profile">Profile</NavLink>
          <NavLink to="/app/hospitals">{t("hospitals.title")}</NavLink>
        </nav>
        <div className="toggles">
          <ThemeToggle />
          <button onClick={() => setLang(lang === "en" ? "hi" : "en")}>
            {lang === "en" ? "EN" : "हिन्दी"}
          </button>
        </div>
      </header>
      <main className="app-shell">
        <Outlet />
      </main>
    </>
  );
}
