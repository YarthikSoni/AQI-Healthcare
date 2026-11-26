# AQI Public Health Monitor

A demo-ready React + FastAPI + Flutter application for personalised AQI risk, exposure tracking and nearby hospitals.

## Backend setup
```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload --port 8000
```

Get a free key at https://home.openweathermap.org/users/sign_up. Paste the value after `OPENWEATHER_API_KEY=` in `backend/.env`. New keys can take up to two hours to activate.

Nearby hospitals use Geoapify Places when `GEOAPIFY_API_KEY` is configured, with OpenStreetMap Overpass as a fallback. Create a Geoapify project at https://myprojects.geoapify.com/ and place its key after `GEOAPIFY_API_KEY=` in `backend/.env`. The Geoapify free plan currently advertises up to 3,000 requests per day; check their pricing page for current limits. Both provider keys are read only by the backend and are never sent to web or mobile clients.

Demo mode is enabled by `DEMO_MODE=true`. It is also automatically used when the key is missing or still the placeholder. Set `DEMO_MODE=false` for live upstream calls. `DATABASE_URL` may use MySQL, for example `mysql+pymysql://user:password@localhost/aqi`; otherwise SQLite is used.

## Web setup
```bash
cd frontend
npm install
npm run dev
```
Open http://localhost:5173. Set `VITE_API_URL` to a custom backend URL if needed.

## Flutter setup
```bash
cd flutter_app
flutter pub get
flutter run
```
The Android emulator default is `http://10.0.2.2:8000/api/v1`. On a real phone, use the laptop LAN IP, for example `http://192.168.1.20:8000/api/v1`, in Settings. Android needs `ACCESS_FINE_LOCATION` and `ACCESS_COARSE_LOCATION`; Android manifest entries are included.

## ML training
Place harmonisable CSV files in `backend/data/raw/` and run:
```bash
cd backend
python train.py
```
The chronological 80/20 split, CPCB recomputation, lag/rolling features, class metrics and persistence baseline are implemented in `train.py`.

## API endpoints
| Method | Endpoint | Purpose |
|---|---|---|
| GET | `/api/v1/health` | Service status |
| POST | `/api/v1/assessment` | Air, weather, risk, symptoms and advice for supplied coordinates/profile; accepts optional `location_name` |
| GET | `/api/v1/air` | Current CPCB and particulate data |
| GET | `/api/v1/weather` | Current weather |
| GET | `/api/v1/location/search?q=` | City search |
| GET | `/api/v1/location/reverse` | Reverse geocode |
| GET | `/api/v1/hospitals/nearby` | Nearby hospitals or pharmacies (`category=hospital|pharmacy`), with Geoapify and Overpass fallback |
| POST/PUT/GET | `/api/v1/profiles` | Risk profiles |
| POST | `/api/v1/exposure/default-schedule` | Suggested schedule |
| POST | `/api/v1/exposure/estimate` | Time-weighted dose |
| GET | `/api/v1/exposure/history/{id}` | Saved dose history |
| GET | `/api/v1/predict/next-day` | Next-day ML prediction |

The web app stores the latest selected city in browser local storage and reuses it on Home and Personal Risk. This preference is per browser; it is not synchronized across devices.

## Tests
```bash
cd backend
pytest -q
cd ../frontend
npm test
```

## Adding a language
Add a locale JSON file under `frontend/src/locales` and a matching language branch in `useI18n`. For Flutter, add `app_<locale>.arb` beside the existing ARB files and update `supportedLocales`. Keep stable backend message keys; clients translate keys while fallback text is always included.

## Data sources and limitations
Data services include OpenWeatherMap, Geoapify Places, OpenStreetMap/Overpass and optional public Kaggle, Mendeley or India Data Portal CSV datasets. Hospital completeness varies with provider coverage and OpenStreetMap contributions. Symptom probabilities use transparent, non-clinically-calibrated heuristic weights. This tool is informational and not medical advice. For a medical emergency in India, call 112 or 108.
