import requests
from datetime import date
from typing import List, Dict, Set
import logging
from functools import lru_cache

logger = logging.getLogger(__name__)

class HolidayService:
    """Service for fetching and caching Indonesian public holidays"""
    
    API_URL = "https://api-harilibur.vercel.app/api"
    
    @staticmethod
    @lru_cache(maxsize=10)
    def fetch_holidays(year: int) -> Set[date]:
        """
        Fetch holidays for a specific year from API
        Returns a set of dates for quick lookup
        Cached to avoid repeated API calls
        """
        try:
            logger.info(f"Fetching holidays for year {year} from API")
            response = requests.get(f"{HolidayService.API_URL}?year={year}", timeout=10)
            
            if response.status_code == 200:
                data = response.json()
                holidays = set()
                
                # Parse response - could be array or object
                if isinstance(data, list):
                    for item in data:
                        try:
                            holiday_date_str = item['holiday_date']
                            # Normalize date format (handle single-digit days/months)
                            parts = holiday_date_str.split('-')
                            if len(parts) == 3:
                                year_part, month_part, day_part = parts
                                normalized = f"{year_part}-{month_part.zfill(2)}-{day_part.zfill(2)}"
                                holiday_date = date.fromisoformat(normalized)
                                holidays.add(holiday_date)
                        except (KeyError, ValueError) as e:
                            logger.warning(f"Error parsing holiday: {e}")
                elif isinstance(data, dict):
                    # If response is object, iterate through values
                    for value in data.values():
                        if isinstance(value, list):
                            for item in value:
                                try:
                                    holiday_date_str = item['holiday_date']
                                    # Normalize date format (handle single-digit days/months)
                                    parts = holiday_date_str.split('-')
                                    if len(parts) == 3:
                                        year_part, month_part, day_part = parts
                                        normalized = f"{year_part}-{month_part.zfill(2)}-{day_part.zfill(2)}"
                                        holiday_date = date.fromisoformat(normalized)
                                        holidays.add(holiday_date)
                                except (KeyError, ValueError) as e:
                                    logger.warning(f"Error parsing holiday: {e}")
                
                logger.info(f"Successfully fetched {len(holidays)} holidays for year {year}")
                return holidays
            else:
                logger.error(f"Failed to fetch holidays: HTTP {response.status_code}")
                return set()
                
        except requests.exceptions.RequestException as e:
            logger.error(f"Error fetching holidays from API: {e}")
            return set()
        except Exception as e:
            logger.error(f"Unexpected error fetching holidays: {e}")
            return set()
    
    @staticmethod
    def is_holiday(check_date: date) -> bool:
        """Check if a specific date is a public holiday"""
        holidays = HolidayService.fetch_holidays(check_date.year)
        return check_date in holidays
    
    @staticmethod
    def is_weekend(check_date: date) -> bool:
        """Check if a date is weekend (Saturday or Sunday)"""
        return check_date.weekday() >= 5  # 5=Saturday, 6=Sunday
    
    @staticmethod
    def is_non_working_day(check_date: date) -> bool:
        """Check if a date is non-working day (weekend or holiday)"""
        return HolidayService.is_weekend(check_date) or HolidayService.is_holiday(check_date)
    
    @staticmethod
    def get_holidays_for_range(start_date: date, end_date: date) -> List[date]:
        """Get all holidays within a date range"""
        if start_date > end_date:
            return []
        
        # Get unique years in the range
        years = set()
        current = start_date
        while current <= end_date:
            years.add(current.year)
            current = date(current.year + 1, 1, 1) if current.month == 12 else date(current.year, current.month + 1, 1)
        
        # Fetch holidays for all years
        all_holidays = set()
        for year in years:
            all_holidays.update(HolidayService.fetch_holidays(year))
        
        # Filter holidays within range
        holidays_in_range = [h for h in all_holidays if start_date <= h <= end_date]
        return sorted(holidays_in_range)
