const STORAGE_KEY = "aqi.selectedLocation";

export const DEFAULT_LOCATION = {
  name: "New Delhi",
  lat: 28.6139,
  lon: 77.209,
  country: "IN",
};

export function locationLabel(location) {
  return [location.name, location.state, location.country]
    .filter(Boolean)
    .join(", ");
}

export function getSavedLocation() {
  const raw = localStorage.getItem(STORAGE_KEY);
  if (!raw) return DEFAULT_LOCATION;

  try {
    const location = JSON.parse(raw);
    const lat = Number(location.lat);
    const lon = Number(location.lon);
    if (Number.isFinite(lat) && lat >= -90 && lat <= 90 &&
        Number.isFinite(lon) && lon >= -180 && lon <= 180) {
      return { ...location, lat, lon };
    }
  } catch (error) {
    console.warn("Could not read the saved location.", error);
  }

  localStorage.removeItem(STORAGE_KEY);
  return DEFAULT_LOCATION;
}

export function saveSelectedLocation(location) {
  localStorage.setItem(
    STORAGE_KEY,
    JSON.stringify({
      name: location.name || "Selected location",
      lat: Number(location.lat),
      lon: Number(location.lon),
      country: location.country,
      state: location.state,
    }),
  );
}
