import React from "react";import {createRoot} from "react-dom/client";import {BrowserRouter} from "react-router-dom";
import App from "./App";import {PreferencesProvider} from "./context/PreferencesContext";import "./styles.css";
import {ProfilesProvider} from "./context/ProfilesContext";
createRoot(document.getElementById("root")).render(<BrowserRouter><PreferencesProvider><ProfilesProvider><App/></ProfilesProvider></PreferencesProvider></BrowserRouter>);
