import math
from typing import Tuple
from app.config import LOKASI_ABSENSI

class LocationService:
    @staticmethod
    def calculate_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """Hitung jarak antara dua koordinat (Haversine formula) dalam km"""
        R = 6371  # Radius bumi dalam km
        
        lat1_rad = math.radians(lat1)
        lat2_rad = math.radians(lat2)
        delta_lat = math.radians(lat2 - lat1)
        delta_lon = math.radians(lon2 - lon1)
        
        a = math.sin(delta_lat / 2) ** 2 + \
            math.cos(lat1_rad) * math.cos(lat2_rad) * \
            math.sin(delta_lon / 2) ** 2
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        
        return R * c
    
    @staticmethod
    def validate_location(latitude: float, longitude: float) -> Tuple[bool, str]:
        """Validasi apakah koordinat berada dalam radius lokasi yang valid"""
        for location_name, location_data in LOKASI_ABSENSI.items():
            distance = LocationService.calculate_distance(
                latitude, 
                longitude,
                location_data['lat'],
                location_data['lon']
            )
            
            if distance <= location_data['radius']:
                return True, location_name
        
        return False, ""
    
    @staticmethod
    def get_nearest_location(latitude: float, longitude: float) -> dict:
        """Dapatkan lokasi terdekat dari koordinat yang diberikan"""
        nearest = None
        min_distance = float('inf')
        
        for location_name, location_data in LOKASI_ABSENSI.items():
            distance = LocationService.calculate_distance(
                latitude,
                longitude,
                location_data['lat'],
                location_data['lon']
            )
            
            if distance < min_distance:
                min_distance = distance
                nearest = {
                    'name': location_name,
                    'distance': round(distance, 2),
                    **location_data
                }
        
        return nearest
    
    @staticmethod
    def get_all_locations() -> dict:
        """Dapatkan semua lokasi absensi yang tersedia"""
        return LOKASI_ABSENSI
