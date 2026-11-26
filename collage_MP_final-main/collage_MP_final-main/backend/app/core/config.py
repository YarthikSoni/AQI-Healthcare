import os
from pathlib import Path
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[2]
load_dotenv(ROOT / ".env")

OPENWEATHER_API_KEY = os.getenv("OPENWEATHER_API_KEY", "")
GEOAPIFY_API_KEY = os.getenv("GEOAPIFY_API_KEY", "")
DEMO_MODE = os.getenv("DEMO_MODE", "false").lower() == "true"
DATABASE_URL = os.getenv("DATABASE_URL", "")
OWM_BASE = "https://api.openweathermap.org"
OWM_MISSING = "Set OPENWEATHER_API_KEY in backend/.env"

