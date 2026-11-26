from app.utils.aqi import cpcb_aqi, cpcb_category

def risk_assessment(profile, aqi, weather=None):
    age = profile.get("age", 30)
    fitness = {"low":1.18,"sedentary":1.18,"medium":1.0,"moderate":1.0,"high":0.88}.get(profile.get("fitness","medium"),1.0)
    age_factor = 1.22 if age >= 65 or age <= 12 else 1.08 if age >= 45 else 1.0
    sensitivities = profile.get("sensitivities",[]) or []
    sens_factor = 1.0
    if "respiratory" in sensitivities: sens_factor += 0.18
    if "cardiac" in sensitivities: sens_factor += 0.15
    if "allergy" in sensitivities: sens_factor += 0.08
    commute = profile.get("commute_minutes",0)
    outdoor = profile.get("outdoor_minutes",0)
    exposure_scale = 1 + min(0.35, (commute+outdoor)/300)
    if profile.get("has_purifier"): exposure_scale *= 0.82
    score = round(min(100, (aqi/500)*100*age_factor*sens_factor*fitness*exposure_scale))
    level = "Low" if score < 25 else "Moderate" if score < 50 else "High" if score < 75 else "Very High"
    factors = {"aqi_base":aqi,"age":age_factor,"fitness":fitness,"sensitivities":sens_factor,"exposure":round(exposure_scale,2)}
    return {"score":score,"level":level,"factors":factors}

def symptoms(profile, components, weather=None):
    pm25 = components.get("pm2_5",0)
    pm10 = components.get("pm10",0)
    no2 = components.get("no2",0)
    multiplier = 1.15 if "respiratory" in (profile.get("sensitivities") or []) else 1
    if "cardiac" in (profile.get("sensitivities") or []): multiplier *= 1.12
    vals = {
        "respiratory_irritation": min(95, pm25/15*22*multiplier),
        "throat_cough": min(95, pm25/25*20*multiplier),
        "eye_irritation": min(95, pm10/45*18*1.1),
        "cardiovascular_strain": min(95, (pm25/25*16+no2/25*8)*multiplier),
        "headache_fatigue": min(95, (no2/40*10+components.get("co",0)/1000*8)),
    }
    peak = max(vals, key=vals.get)
    return {"probabilities":{k:round(v,1) for k,v in vals.items()},"peak":peak,"peak_probability":round(vals[peak],1),
            "disclaimer":"Heuristic weights, not clinically calibrated"}

def interventions(profile, hourly):
    pm = [x.get("pm2_5",0) for x in hourly[:24]] or [0]
    worst = max(range(len(pm)), key=pm.__getitem__)
    best = min(range(len(pm)), key=pm.__getitem__)
    def w(i): return ({"key":"intervention.time_window","params":{"start":f"{i:02d}:00","end":f"{min(i+2,24):02d}:00"},"text":f"Avoid exposure around {i:02d}:00-{min(i+2,24):02d}:00"})
    mask = "N95/FFP2" if profile.get("sensitivities") else "Surgical"
    return {"avoid_window":w(worst),"best_window":w(best),"advice":[
      {"key":"intervention.mask","params":{"mask":mask},"text":f"Use a {mask} mask for dense traffic exposure."},
      {"key":"intervention.ventilate","params":{},"text":"Ventilate only during low-PM2.5 windows."},
      {"key":"intervention.exercise","params":{},"text":"Move exercise to the best 2-hour outdoor window."},
    ]}

def exposure_estimate(entries, outdoor_pm25):
    factors={"outdoor":1.0,"open_transit":0.9,"closed_transit":0.6,"indoor":0.35,"filtered_indoor":0.12}
    ventilation={"outdoor":1.2,"open_transit":0.9,"closed_transit":0.7,"indoor":0.5,"filtered_indoor":0.3}
    result=[]; dose=0
    for e in entries:
        env=e["microenvironment"]; hours=float(e["hours"]); activity=float(e.get("activity_level",1))
        exposure=outdoor_pm25*factors.get(env,0.35)*activity
        item_dose=exposure*ventilation.get(env,0.5)*hours
        dose += item_dose
        result.append({**e,"exposure":round(exposure,1),"dose":round(item_dose,2)})
    return {"entries":result,"dose":round(dose,2),"who_guideline_24h":15,"guideline_status":"Above guideline" if dose/24>15 else "Within guideline"}
