import os
from pathlib import Path

from dotenv import dotenv_values

from app.services.memory_service import MemoryService

from app.services.topic_service import TopicService

memory_service = MemoryService(max_messages=10)

topic_service = TopicService()
class BaseSettings:
    class Config:
        env_file = ".env"

    def __init__(self, **kwargs):
        env_file = getattr(self.Config, "env_file", ".env")
        env_path = Path(__file__).resolve().parents[2] / env_file
        env_values = dotenv_values(env_path)

        annotations = getattr(self.__class__, "__annotations__", {})
        for field_name in annotations:
            value = kwargs.get(field_name)
            if value is None:
                value = os.getenv(field_name)
            if value is None:
                value = env_values.get(field_name)
            setattr(self, field_name, value)


class Settings(BaseSettings):
    GROQ_API_KEY: str
    TOGETHER_API_KEY: str
    HUGGINGFACE_API_KEY: str
    class Config:
        env_file = ".env"


settings = Settings()

GROQ_API_KEY = settings.GROQ_API_KEY
TOGETHER_API_KEY = settings.TOGETHER_API_KEY
