from math import radians, sin, cos, atan2, sqrt

def haversine_km(lat1, lon1, lat2, lon2):
    r = 6371.0
    p1, p2 = radians(lat1), radians(lat2)
    dp = p2-p1
    dl = radians(lon2-lon1)
    a = sin(dp/2)**2 + cos(p1)*cos(p2)*sin(dl/2)**2
    return r * 2 * atan2(sqrt(a), sqrt(1-a))
