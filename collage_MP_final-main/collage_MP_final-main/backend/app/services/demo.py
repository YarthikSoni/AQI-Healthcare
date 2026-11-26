DEMO_WEATHER = {"temperature":27.8,"feels_like":31.2,"humidity":64,"wind_speed":2.1,"rain_probability":0.15,"timezone_offset":19800,"timezone":"Asia/Kolkata","description":"haze"}
DEMO_COMPONENTS = {"pm2_5":91.2,"pm10":168.4,"no2":42.1,"so2":18.4,"o3":51.2,"co":784,"nh3":8.2}
DEMO_HOURLY = [{"timestamp":1735689600+i*3600,"pm2_5":round(max(28,58+i*2 if i<8 else 92-(i-8)*2),1),"pm10":round(120+i*2,1),"no2":38+i,"o3":44} for i in range(24)]
