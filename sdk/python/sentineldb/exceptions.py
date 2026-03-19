class SentinelDBError(Exception):
    pass

class ConnectionError(SentinelDBError):
    def __init__(self, url: str, cause: Exception):
        super().__init__(f"Cannot connect to SentinelDB at {url}: {cause}")
        self.url = url
        self.cause = cause

class KeyNotFoundError(SentinelDBError):
    def __init__(self, key: str):
        super().__init__(f"Key not found: {key}")
        self.key = key

class GuardViolationError(SentinelDBError):
    def __init__(self, key: str, reason: str, alternatives: list):
        super().__init__(f"Guard violation for key '{key}': {reason}")
        self.key = key
        self.reason = reason
        self.alternatives = alternatives
