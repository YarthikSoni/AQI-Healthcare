def pm_subindex(concentration, breaks):
    if concentration is None:
        return 0
    c = float(concentration)
    for i, (cl, cu, il, iu) in enumerate(breaks):
        if cl <= c <= cu:
            return round(((iu - il) / (cu - cl)) * (c - cl) + il)
    return breaks[-1][3]

PM25_BREAKS = [(0,30,0,50),(31,60,51,100),(61,90,101,200),(91,120,201,300),(121,250,301,400),(251,500,401,500)]
PM10_BREAKS = [(0,50,0,50),(51,100,51,100),(101,250,101,200),(251,350,201,300),(351,430,301,400),(431,600,401,500)]

def cpcb_aqi(pm25=None, pm10=None):
    pm25_i = pm_subindex(pm25, PM25_BREAKS)
    pm10_i = pm_subindex(pm10, PM10_BREAKS)
    return max(pm25_i, pm10_i)

def cpcb_category(aqi):
    if aqi <= 50: return "Good"
    if aqi <= 100: return "Satisfactory"
    if aqi <= 200: return "Moderate"
    if aqi <= 300: return "Poor"
    if aqi <= 400: return "Very Poor"
    return "Severe"
