from typing import List, Optional

from pydantic import BaseModel, Field


class UserRequest(BaseModel):
    user_id: str
    query: str
    installed_apps: Optional[List[str]] = Field(default_factory=list)
