from pydantic import BaseModel, Field
from typing import List, Optional

class Location(BaseModel):
    lat: float = Field(ge=-90, le=90)
    lon: float = Field(ge=-180, le=180)
    name: Optional[str] = None

class ProfileIn(BaseModel):
    age: int = Field(ge=1, le=120)
    fitness: str = "moderate"
    commute_mode: str = "walk"
    commute_minutes: int = Field(default=0, ge=0)
    outdoor_minutes: int = Field(default=0, ge=0)
    sensitivities: List[str] = []
    has_purifier: bool = False

class AssessmentIn(BaseModel):
    lat: float
    lon: float
    location_name: Optional[str] = Field(default=None, max_length=120)
    profile: ProfileIn

class ExposureEntry(BaseModel):
    microenvironment: str
    activity_level: float = 1.0
    hours: float = Field(gt=0, le=24)

class ExposureEstimateIn(BaseModel):
    profile_id: Optional[int] = None
    pm25: float
    entries: List[ExposureEntry]
