import React from "react";
import { Navigate, Route, Routes } from "react-router-dom";
import Dashboard from "./pages/Dashboard";
import Hospitals from "./pages/Hospitals";
import Landing from "./pages/Landing";
import Profile from "./pages/Profile";
import Settings from "./pages/Settings";
import Layout from "./components/Layout";

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<Landing />} />
      <Route path="/app" element={<Layout />}>
        <Route index element={<Navigate to="dashboard" replace />} />
        <Route path="dashboard" element={<Dashboard />} />
        <Route path="profile" element={<Profile />} />
        <Route
          path="exposure"
          element={<Navigate to="/app/dashboard" replace />}
        />
        <Route path="hospitals" element={<Hospitals />} />
        <Route path="settings" element={<Settings />} />
      </Route>
    </Routes>
  );
}
