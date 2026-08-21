"""Small helpers shared across the app."""
from decimal import Decimal


def plain(obj):
    """Recursively convert DynamoDB Decimals into plain int/float so the
    result is JSON-serialisable."""
    if isinstance(obj, list):
        return [plain(x) for x in obj]
    if isinstance(obj, dict):
        return {k: plain(v) for k, v in obj.items()}
    if isinstance(obj, Decimal):
        return int(obj) if obj % 1 == 0 else float(obj)
    return obj


class ApiError(Exception):
    """Raised by repositories/routes to return a clean HTTP error."""

    def __init__(self, message, status=400):
        super().__init__(message)
        self.message = message
        self.status = status
