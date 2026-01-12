from datetime import datetime
import pytz
from app.config import TZ

def get_current_time():
    """Get current datetime in Asia/Jakarta timezone"""
    return datetime.now(TZ)

def to_jakarta_time(dt):
    """Convert datetime to Asia/Jakarta timezone"""
    if dt.tzinfo is None:
        # If naive datetime, localize it
        return TZ.localize(dt)
    else:
        # If aware datetime, convert it
        return dt.astimezone(TZ)

def utc_to_jakarta(dt):
    """Convert UTC datetime to Asia/Jakarta"""
    if dt.tzinfo is None:
        dt = pytz.utc.localize(dt)
    return dt.astimezone(TZ)
