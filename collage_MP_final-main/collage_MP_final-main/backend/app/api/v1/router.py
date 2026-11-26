from typing import Literal
from fastapi import APIRouter, HTTPException, Query
from app.schemas.schemas import AssessmentIn, ProfileIn, ExposureEstimateIn
from app.core.database import SessionLocal, Base, engine
from app.core.config import (
    DEMO_MODE,
    GEOAPIFY_API_KEY,
    OPENWEATHER_API_KEY,
    OWM_MISSING,
)
from app.models.models import Profile, ExposureLog
from app.services.weather import air, weather
from app.services.logic import risk_assessment, symptoms, interventions, exposure_estimate
from app.services.hospitals import nearby
from app.utils.aqi import cpcb_aqi,cpcb_category
import httpx

router=APIRouter(prefix="/api/v1")
Base.metadata.create_all(bind=engine)

@router.get("/health")
def health():
    return {
        "status": "ok",
        "demo_mode": DEMO_MODE,
        "weather_configured": bool(
            OPENWEATHER_API_KEY and not OPENWEATHER_API_KEY.startswith("YOUR")
        ),
        "geoapify_configured": bool(
            GEOAPIFY_API_KEY and not GEOAPIFY_API_KEY.startswith("YOUR")
        ),
    }

@router.get("/air")
async def get_air(lat:float=Query(...),lon:float=Query(...)):
    try:
        data=await air(lat,lon)
        if "components" not in data:
            components=data["list"][0]["components"] if data else {}
        else: components=data["components"]
        aqi=cpcb_aqi(components.get("pm2_5"),components.get("pm10"))
        return {"lat":lat,"lon":lon,"aqi":aqi,"category":cpcb_category(aqi),"owm_aqi":data.get("aqi",1),
                "components":components,"hourly":data.get("hourly",[]),"mode":data.get("mode","live")}
    except LookupError: raise HTTPException(503,OWM_MISSING)
    except Exception: raise HTTPException(502,"OpenWeatherMap upstream failure")

@router.get("/weather")
async def get_weather(lat:float=Query(...),lon:float=Query(...)):
    try:return await weather(lat,lon)
    except LookupError: raise HTTPException(503,OWM_MISSING)
    except Exception: raise HTTPException(502,"OpenWeatherMap upstream failure")

@router.get("/location/search")
async def location_search(q:str):
    if DEMO_MODE or not OPENWEATHER_API_KEY or OPENWEATHER_API_KEY.startswith("YOUR"):
        return [{"name":q,"lat":28.6139,"lon":77.2090,"country":"IN"}]
    async with httpx.AsyncClient(timeout=12) as c:
        r=await c.get("https://api.openweathermap.org/geo/1.0/direct",params={"q":q,"limit":5,"appid":OPENWEATHER_API_KEY})
        r.raise_for_status();return r.json()

@router.get("/location/reverse")
async def location_reverse(lat:float,lon:float):
    if DEMO_MODE or not OPENWEATHER_API_KEY or OPENWEATHER_API_KEY.startswith("YOUR"):
        return {"name":"New Delhi","lat":lat,"lon":lon,"country":"IN"}
    async with httpx.AsyncClient(timeout=12) as c:
        r=await c.get("https://api.openweathermap.org/geo/1.0/reverse",params={"lat":lat,"lon":lon,"limit":1,"appid":OPENWEATHER_API_KEY})
        r.raise_for_status();data=r.json();return data[0] if data else {"name":"Unknown","lat":lat,"lon":lon}

@router.get("/hospitals/nearby")
async def hospitals_nearby(
    lat: float,
    lon: float,
    radius_m: int = 5000,
    limit: int = 30,
    include_clinics: bool = False,
    category: Literal["hospital", "pharmacy"] | None = None,
):
    selected_category = category or "hospital"
    selected_clinics = include_clinics if category is None else False
    try:
        places = await nearby(
            lat,
            lon,
            radius_m,
            limit,
            selected_clinics,
            selected_category,
        )
        response = {"places": places, "category": selected_category}
        if selected_category == "hospital":
            response["hospitals"] = places
        return response
    except RuntimeError as exc:
        raise HTTPException(502,str(exc)) from exc

@router.post("/assessment")
async def assessment(body:AssessmentIn):
    air_data=await get_air(body.lat,body.lon)
    weather_data=await get_weather(body.lat,body.lon)
    profile=body.profile.model_dump()
    risk=risk_assessment(profile,air_data["aqi"],weather_data)
    sym=symptoms(profile,air_data["components"],weather_data)
    interv=interventions(profile,air_data["hourly"])
    return {
        "location": {
            "name": body.location_name or "Selected location",
            "lat": body.lat,
            "lon": body.lon,
        },
        "air": air_data,
        "weather": weather_data,
        "risk": risk,
        "symptoms": sym,
        "interventions": interv,
    }

@router.post("/profiles")
async def save_profile(body:ProfileIn):
    db=SessionLocal()
    try:
        p=Profile(**body.model_dump())
        db.add(p);db.commit();db.refresh(p);return {"id":p.id,**body.model_dump()}
    finally:db.close()

@router.put("/profiles")
async def update_profile(body:ProfileIn,profile_id:int|None=None):
    db=SessionLocal()
    try:
        query=db.query(Profile)
        p=query.filter(Profile.id==profile_id).first() if profile_id is not None else query.order_by(Profile.id.desc()).first()
        if p is None:
            p=Profile(**body.model_dump())
            db.add(p)
        else:
            for field,value in body.model_dump().items():
                setattr(p,field,value)
        db.commit()
        db.refresh(p)
        return {"id":p.id,**body.model_dump()}
    finally:db.close()

@router.get("/profiles")
async def profiles():
    db=SessionLocal()
    try:return [{"id":p.id,"age":p.age,"fitness":p.fitness,"commute_mode":p.commute_mode,"commute_minutes":p.commute_minutes,
                 "outdoor_minutes":p.outdoor_minutes,"sensitivities":p.sensitivities,"has_purifier":bool(p.has_purifier)}
                for p in db.query(Profile).order_by(Profile.id.desc()).all()]
    finally:db.close()

@router.post("/exposure/default-schedule")
def default_schedule():
    return {"entries":[{"microenvironment":"outdoor","hours":1,"activity_level":1.2},{"microenvironment":"indoor","hours":20,"activity_level":0.7},{"microenvironment":"closed_transit","hours":3,"activity_level":1.0}]}

@router.post("/exposure/estimate")
def exposure(body:ExposureEstimateIn):
    result=exposure_estimate([x.model_dump() for x in body.entries],body.pm25)
    db=SessionLocal()
    try:
        log=ExposureLog(profile_id=body.profile_id,date="today",entries=result["entries"],dose=result["dose"])
        db.add(log);db.commit()
    except Exception:pass
    finally:db.close()
    return result

@router.get("/exposure/history/{id}")
def exposure_history(id:int):
    db=SessionLocal()
    try:return [{"id":x.id,"date":x.date,"entries":x.entries,"dose":x.dose} for x in db.query(ExposureLog).filter(ExposureLog.profile_id==id).all()]
    finally:db.close()

@router.get("/predict/next-day")
def predict_next_day(lat:float,lon:float):
    raise HTTPException(503,"ML model untrained. Run backend/train.py to train models.")
