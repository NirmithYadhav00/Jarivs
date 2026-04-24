CACHE = {}

def get_cache(key: str):
    return CACHE.get(key)

def set_cache(key: str, value):
    CACHE[key] = value