import React, {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useState,
} from "react";
import { api } from "../api/client";
import {
  DEFAULT_LOCATION,
  getSavedLocation,
  saveSelectedLocation,
} from "../utils/location";

const PROFILES_KEY = "aqi.profiles.v1";
const ACTIVE_PROFILE_KEY = "aqi.activeProfileId";
const DEFAULT_PROFILE = {
  age: 30,
  fitness: "moderate",
  commute_mode: "walk",
  commute_minutes: 30,
  outdoor_minutes: 60,
  sensitivities: [],
  has_purifier: false,
};

const ProfileContext = createContext(null);

function createId() {
  return (
    globalThis.crypto?.randomUUID?.() ??
    `profile-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`
  );
}

function normalizeCity(city, fallback = DEFAULT_LOCATION) {
  const candidate = city || fallback;
  const lat = Number(candidate.lat);
  const lon = Number(candidate.lon);
  if (
    !Number.isFinite(lat) ||
    lat < -90 ||
    lat > 90 ||
    !Number.isFinite(lon) ||
    lon < -180 ||
    lon > 180
  ) {
    return { ...fallback };
  }
  return { ...candidate, lat, lon };
}

function normalizeProfile(profile = {}, fallbackCity = DEFAULT_LOCATION) {
  return {
    id: String(profile.id ?? createId()),
    name: String(profile.name || "My profile"),
    age: Number(profile.age ?? DEFAULT_PROFILE.age),
    fitness: profile.fitness || DEFAULT_PROFILE.fitness,
    commute_mode: profile.commute_mode || DEFAULT_PROFILE.commute_mode,
    commute_minutes: Number(
      profile.commute_minutes ?? DEFAULT_PROFILE.commute_minutes,
    ),
    outdoor_minutes: Number(
      profile.outdoor_minutes ?? DEFAULT_PROFILE.outdoor_minutes,
    ),
    sensitivities: Array.isArray(profile.sensitivities)
      ? profile.sensitivities
      : [],
    has_purifier: Boolean(profile.has_purifier),
    city: normalizeCity(profile.city, fallbackCity),
  };
}

async function loadProfilesFromStorageOrBackend() {
  const stored = localStorage.getItem(PROFILES_KEY);
  if (stored !== null) {
    let parsed;
    try {
      parsed = JSON.parse(stored);
    } catch {
      throw new Error("Saved profiles could not be read from this browser.");
    }
    if (!Array.isArray(parsed) || parsed.length === 0) {
      throw new Error("Saved profiles are invalid. Please clear the local profiles and retry.");
    }
    const profiles = parsed.map((profile) => normalizeProfile(profile));
    const requestedActiveId = localStorage.getItem(ACTIVE_PROFILE_KEY);
    const activeProfile = profiles.find(
      (profile) => profile.id === requestedActiveId,
    ) || profiles[0];
    localStorage.setItem(PROFILES_KEY, JSON.stringify(profiles));
    localStorage.setItem(ACTIVE_PROFILE_KEY, activeProfile.id);
    return { profiles, activeProfile };
  }

  const legacyProfiles = await api("/profiles");
  const city = getSavedLocation();
  const latestProfile = legacyProfiles[0] || {};
  const profile = normalizeProfile(
    { ...latestProfile, id: createId(), name: "My profile", city },
    city,
  );
  localStorage.setItem(PROFILES_KEY, JSON.stringify([profile]));
  localStorage.setItem(ACTIVE_PROFILE_KEY, profile.id);
  return { profiles: [profile], activeProfile: profile };
}

export function ProfilesProvider({ children }) {
  const [profiles, setProfiles] = useState([]);
  const [activeProfileId, setActiveProfileId] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  const initialize = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const result = await loadProfilesFromStorageOrBackend();
      setProfiles(result.profiles);
      setActiveProfileId(result.activeProfile.id);
      saveSelectedLocation(result.activeProfile.city);
    } catch (loadError) {
      setError(loadError.message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    initialize();
  }, [initialize]);

  const commit = (nextProfiles, nextActiveProfileId) => {
    const activeProfile =
      nextProfiles.find(
        (profile) => profile.id === nextActiveProfileId,
      ) || nextProfiles[0];
    if (!activeProfile) {
      throw new Error("At least one profile must remain selected.");
    }
    localStorage.setItem(PROFILES_KEY, JSON.stringify(nextProfiles));
    localStorage.setItem(ACTIVE_PROFILE_KEY, activeProfile.id);
    saveSelectedLocation(activeProfile.city);
    setProfiles(nextProfiles);
    setActiveProfileId(activeProfile.id);
    setError("");
    return activeProfile;
  };

  const selectProfile = (profileId) => {
    if (!profiles.some((profile) => profile.id === profileId)) {
      throw new Error("The selected profile could not be found.");
    }
    commit(profiles, profileId);
  };

  const addProfile = (name) => {
    const cleanName = name.trim();
    if (!cleanName) {
      throw new Error("Enter a name for the profile.");
    }
    const activeProfile = profiles.find(
      (profile) => profile.id === activeProfileId,
    );
    const profile = normalizeProfile({
      ...DEFAULT_PROFILE,
      id: createId(),
      name: cleanName,
      city: activeProfile?.city || getSavedLocation(),
    });
    commit([...profiles, profile], profile.id);
    return profile;
  };

  const updateProfile = (profileId, changes) => {
    const nextProfiles = profiles.map((profile) =>
      profile.id === profileId
        ? normalizeProfile(
            {
              ...profile,
              ...changes,
              city: changes.city
                ? normalizeCity(changes.city, profile.city)
                : profile.city,
            },
            profile.city,
          )
        : profile,
    );
    if (nextProfiles.every((profile) => profile.id !== profileId)) {
      throw new Error("The profile could not be found.");
    }
    commit(nextProfiles, activeProfileId);
  };

  const deleteProfile = (profileId) => {
    if (profiles.length <= 1) return false;
    const nextProfiles = profiles.filter(
      (profile) => profile.id !== profileId,
    );
    if (nextProfiles.length === profiles.length) {
      throw new Error("The profile could not be found.");
    }
    const nextActiveId =
      activeProfileId === profileId
        ? nextProfiles[0].id
        : activeProfileId;
    commit(nextProfiles, nextActiveId);
    return true;
  };

  const activeProfile = profiles.find(
    (profile) => profile.id === activeProfileId,
  ) || profiles[0] || null;

  return (
    <ProfileContext.Provider
      value={{
        profiles,
        activeProfile,
        activeProfileId,
        loading,
        error,
        retry: initialize,
        selectProfile,
        addProfile,
        updateProfile,
        deleteProfile,
      }}
    >
      {children}
    </ProfileContext.Provider>
  );
}

export function useProfiles() {
  const context = useContext(ProfileContext);
  if (!context) {
    throw new Error("useProfiles must be used inside ProfilesProvider.");
  }
  return context;
}
