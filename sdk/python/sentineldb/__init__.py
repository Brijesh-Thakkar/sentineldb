from .client import SentinelDB
from .models import Version, ProposalResult, Alternative, Guard, HealthStatus
from .exceptions import (
    SentinelDBError, ConnectionError, KeyNotFoundError, GuardViolationError
)

__version__ = "0.1.0"
__all__ = [
    "SentinelDB",
    "Version", "ProposalResult", "Alternative", "Guard", "HealthStatus",
    "SentinelDBError", "ConnectionError", "KeyNotFoundError", "GuardViolationError"
]
