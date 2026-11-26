from pathlib import Path
import pandas as pd, numpy as np, joblib, json
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, f1_score, mean_absolute_error, mean_squared_error, r2_score
from xgboost import XGBRegressor
from app.utils.aqi import cpcb_aqi,cpcb_category

RAW=Path(__file__).parent/"data"/"raw"
OUT=Path(__file__).parent/"ml_artifacts";OUT.mkdir(parents=True,exist_ok=True)

def load_data():
    frames=[]
    for path in RAW.glob("*.csv"):
        df=pd.read_csv(path)
        df.columns=[c.lower().strip().replace(" ","_") for c in df.columns]
        datecol=next((c for c in df.columns if "date" in c or "time" in c),None)
        pm25=next((c for c in df.columns if "pm2" in c),None)
        pm10=next((c for c in df.columns if "pm10" in c),None)
        if datecol and (pm25 or pm10):
            def parse(v):
                try:return pd.to_datetime(v,dayfirst=True)
                except:return pd.NaT
            d=pd.DataFrame({"date":df[datecol].map(parse),"pm25":pd.to_numeric(df[pm25] if pm25 else 0,errors="coerce"),
                            "pm10":pd.to_numeric(df[pm10] if pm10 else 0,errors="coerce")})
            frames.append(d)
    if not frames:return pd.DataFrame(columns=["date","pm25","pm10"])
    data=pd.concat(frames).dropna(subset=["date"]).set_index("date").resample("D").mean().reset_index()
    data["aqi"]=data.apply(lambda r:cpcb_aqi(r.pm25,r.pm10),axis=1)
    return data

def features(data):
    data=data.sort_values("date").copy()
    data["pm25_lag1"]=data.pm25.shift(1);data["pm10_lag1"]=data.pm10.shift(1)
    data["pm25_roll7"]=data.pm25.shift(1).rolling(7).mean();data["pm10_roll7"]=data.pm10.shift(1).rolling(7).mean()
    data["target_aqi"]=data.aqi.shift(-1)
    data["target_class"]=data.target_aqi.map(cpcb_category)
    return data.dropna()

if __name__=="__main__":
    df=features(load_data())
    cols=["pm25","pm10","pm25_lag1","pm10_lag1","pm25_roll7","pm10_roll7"]
    if len(df)<20:
        print("Not enough rows in backend/data/raw. Add CSV datasets and rerun.")
        raise SystemExit(0)
    split=int(len(df)*.8);train,test=df.iloc[:split],df.iloc[split:]
    clf=RandomForestClassifier(n_estimators=200,random_state=42,class_weight="balanced")
    clf.fit(train[cols],train.target_class)
    pred=clf.predict(test[cols])
    reg=XGBRegressor(n_estimators=300,max_depth=5,random_state=42)
    reg.fit(train[cols],train.target_aqi)
    aq_pred=reg.predict(test[cols])
    persistence=test.aqi
    metrics={"accuracy":accuracy_score(test.target_class,pred),"macro_f1":f1_score(test.target_class,pred,average="macro"),
             "mae":mean_absolute_error(test.target_aqi,aq_pred),"rmse":mean_squared_error(test.target_aqi,aq_pred)**.5,
             "r2":r2_score(test.target_aqi,aq_pred),"persistence_mae":mean_absolute_error(test.target_aqi,persistence),
             "persistence_rmse":mean_squared_error(test.target_aqi,persistence)**.5}
    joblib.dump(clf,OUT/"hazard_rf.joblib");joblib.dump(reg,OUT/"aqi_xgb.joblib")
    (OUT/"metrics.json").write_text(json.dumps(metrics,indent=2))
    print(json.dumps(metrics,indent=2))
