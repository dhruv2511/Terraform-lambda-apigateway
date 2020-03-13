from typing import Optional, Dict

try:
    from pydantic import HttpUrl
except ImportError:
    from typing import AnyStr as HttpUrl

from .data import AttributesModel


class UserModel(AttributesModel):
    username: Optional[str]
    is_service_account: Optional[bool]
    avatar_url: Optional[HttpUrl]
    v2_only: Optional[bool]
    permissions: Optional[Dict[str, bool]]
