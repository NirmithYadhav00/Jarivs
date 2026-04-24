from pydantic import BaseModel
from typing import Optional


class StructuredResponseItem(BaseModel):
    title: Optional[str] = None
    content: str

class ResponseModel(BaseModel):
    type: str
    response: Optional[str] = None
    responses: Optional[list[StructuredResponseItem]] = None
    action: Optional[str] = None
    app: Optional[str] = None
