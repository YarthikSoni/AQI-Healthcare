from sqlalchemy import Column, Integer, Float, String, DateTime, JSON
from sqlalchemy.sql import func
from app.core.database import Base

class Profile(Base):
    __tablename__ = "profiles"
    id = Column(Integer, primary_key=True)
    age = Column(Integer)
    fitness = Column(String(32))
    commute_mode = Column(String(64))
    commute_minutes = Column(Integer)
    outdoor_minutes = Column(Integer)
    sensitivities = Column(JSON)
    has_purifier = Column(Integer)
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

class ExposureLog(Base):
    __tablename__ = "exposure_logs"
    id = Column(Integer, primary_key=True)
    profile_id = Column(Integer)
    date = Column(String(32))
    entries = Column(JSON)
    dose = Column(Float)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
