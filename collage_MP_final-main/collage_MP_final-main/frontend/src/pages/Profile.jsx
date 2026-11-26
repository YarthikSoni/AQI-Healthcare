import React, { useEffect, useState } from "react";
import { useProfiles } from "../context/ProfilesContext";

export default function Profile() {
  const {
    profiles,
    activeProfile,
    activeProfileId,
    loading,
    error: profileError,
    retry,
    selectProfile,
    addProfile,
    updateProfile,
    deleteProfile,
  } = useProfiles();
  const [form, setForm] = useState(null);
  const [newProfileName, setNewProfileName] = useState("");
  const [saved, setSaved] = useState("");
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!activeProfile) {
      setForm(null);
      return;
    }
    setForm({
      ...activeProfile,
      city: { ...activeProfile.city },
      sensitivities: [...activeProfile.sensitivities],
    });
    setSaved("");
  }, [activeProfile]);

  const setField = (field, value) =>
    setForm((current) => ({ ...current, [field]: value }));

  const confirmDiscard = () =>
    !form ||
    JSON.stringify(form) === JSON.stringify(activeProfile) ||
    window.confirm("Discard your unsaved profile changes?");

  const toggleSensitivity = (sensitivity) =>
    setForm((current) => ({
      ...current,
      sensitivities: current.sensitivities.includes(sensitivity)
        ? current.sensitivities.filter((item) => item !== sensitivity)
        : [...current.sensitivities, sensitivity],
    }));

  const submit = (event) => {
    event.preventDefault();
    if (!activeProfile || !form) return;
    setSaving(true);
    setSaved("");
    try {
      updateProfile(activeProfile.id, form);
      setSaved("Profile saved on this browser");
    } catch (error) {
      setSaved(error.message);
    } finally {
      setSaving(false);
    }
  };

  const createProfile = (event) => {
    event.preventDefault();
    if (!confirmDiscard()) return;
    setSaved("");
    try {
      addProfile(newProfileName);
      setNewProfileName("");
    } catch (error) {
      setSaved(error.message);
    }
  };

  const removeProfile = () => {
    if (!activeProfile) return;
    if (!window.confirm(`Delete ${activeProfile.name}? This cannot be undone.`)) {
      return;
    }
    try {
      const removed = deleteProfile(activeProfile.id);
      setSaved(
        removed ? "Profile deleted" : "At least one profile must remain.",
      );
    } catch (error) {
      setSaved(error.message);
    }
  };

  if (loading) return <p>Loading profiles…</p>;

  if (profileError) {
    return (
      <section className="profile-page">
        <div className="notice" role="alert">
          <div>
            <h2>Could not load local profiles</h2>
            <p>{profileError}</p>
          </div>
          <button className="button" type="button" onClick={retry}>
            Retry
          </button>
        </div>
      </section>
    );
  }

  return (
    <section className="profile-page">
      <div className="page-heading">
        <div>
          <p className="eyebrow">Personalize your assessment</p>
          <h1>Profiles</h1>
        </div>
      </div>
      <div className="profile-picker" role="group" aria-label="Select a profile">
        {profiles.map((profile) => (
          <button
            className="profile-picker-card"
            type="button"
            key={profile.id}
            aria-pressed={profile.id === activeProfileId}
            onClick={() => {
              if (!confirmDiscard()) return;
              try {
                selectProfile(profile.id);
              } catch (error) {
                setSaved(error.message);
              }
            }}
          >
            <span className="profile-avatar" aria-hidden="true">
              {profile.name.trim().charAt(0).toUpperCase()}
            </span>
            <strong>{profile.name}</strong>
          </button>
        ))}
        <form className="profile-add-form" onSubmit={createProfile}>
          <input
            aria-label="New profile name"
            maxLength={40}
            placeholder="New profile name"
            value={newProfileName}
            onChange={(event) => setNewProfileName(event.target.value)}
          />
          <button
            className="button"
            type="submit"
            disabled={!newProfileName.trim()}
          >
            Add profile
          </button>
        </form>
      </div>
      {form && activeProfile && (
        <form className="panel profile-form" onSubmit={submit}>
          <section className="profile-section">
            <div className="profile-section-heading">
              <span>01</span>
              <div>
                <h2>Profile</h2>
                <p>This profile is stored locally in this browser.</p>
              </div>
            </div>
            <div className="profile-fields">
              <label>
                Profile name
                <input
                  type="text"
                  maxLength={40}
                  required
                  value={form.name}
                  onChange={(event) => setField("name", event.target.value)}
                />
              </label>
            </div>
          </section>

          <section className="profile-section">
            <div className="profile-section-heading">
              <span>02</span>
              <div>
                <h2>About you</h2>
                <p>Age and fitness help tailor your personal risk estimate.</p>
              </div>
            </div>
            <div className="profile-fields">
              <label>
                Age
                <input
                  type="number"
                  min="1"
                  max="120"
                  required
                  value={form.age}
                  onChange={(event) => setField("age", +event.target.value)}
                />
              </label>
              <label>
                Fitness level
                <select
                  value={form.fitness}
                  onChange={(event) => setField("fitness", event.target.value)}
                >
                  <option value="low">Low</option>
                  <option value="moderate">Moderate</option>
                  <option value="high">High</option>
                </select>
              </label>
            </div>
          </section>

          <section className="profile-section">
            <div className="profile-section-heading">
              <span>03</span>
              <div>
                <h2>Daily exposure</h2>
                <p>Describe your usual commute and time spent outdoors.</p>
              </div>
            </div>
            <div className="profile-fields profile-exposure-fields">
              <label>
                Commute mode
                <select
                  value={form.commute_mode}
                  onChange={(event) =>
                    setField("commute_mode", event.target.value)
                  }
                >
                  <option value="walk">Walk</option>
                  <option value="cycle">Cycle</option>
                  <option value="two-wheeler">Two-wheeler</option>
                  <option value="auto">Auto</option>
                  <option value="bus">Bus</option>
                  <option value="metro">Metro</option>
                  <option value="car with AC">Car with AC</option>
                  <option value="car with windows open">
                    Car with windows open
                  </option>
                  <option value="WFH">Work from home</option>
                </select>
              </label>
              <label>
                Commute (minutes per day)
                <input
                  type="number"
                  min="0"
                  required
                  value={form.commute_minutes}
                  onChange={(event) =>
                    setField("commute_minutes", +event.target.value)
                  }
                />
              </label>
              <label>
                Outdoor time (minutes per day)
                <input
                  type="number"
                  min="0"
                  required
                  value={form.outdoor_minutes}
                  onChange={(event) =>
                    setField("outdoor_minutes", +event.target.value)
                  }
                />
              </label>
            </div>
          </section>

          <section className="profile-section">
            <div className="profile-section-heading">
              <span>04</span>
              <div>
                <h2>Health considerations</h2>
                <p>Select any sensitivities that should affect your risk score.</p>
              </div>
            </div>
            <fieldset className="sensitivity-fieldset">
              <legend>Sensitivities</legend>
              <div className="sensitivity-options">
                {["respiratory", "cardiac", "allergy"].map((sensitivity) => (
                  <label className="sensitivity-option" key={sensitivity}>
                    <input
                      type="checkbox"
                      checked={form.sensitivities.includes(sensitivity)}
                      onChange={() => toggleSensitivity(sensitivity)}
                    />
                    <span>{sensitivity}</span>
                  </label>
                ))}
              </div>
            </fieldset>
            <label className="purifier-option">
              <input
                type="checkbox"
                checked={form.has_purifier}
                onChange={(event) =>
                  setField("has_purifier", event.target.checked)
                }
              />
              <span>I use an air purifier at home</span>
            </label>
          </section>

          <div className="profile-actions">
            <div>
              <p role="status">{saved}</p>
              <button
                type="button"
                className="inline-retry"
                onClick={removeProfile}
                disabled={profiles.length <= 1}
              >
                Delete this profile
              </button>
            </div>
            <button className="button" type="submit" disabled={saving}>
              {saving ? "Saving…" : "Save profile"}
            </button>
          </div>
        </form>
      )}
    </section>
  );
}
