import os
from pathlib import Path
from dotenv import dotenv_values

from app.services.memory_service import MemoryService
from app.services.topic_service import TopicService

# 🔥 SERVICES
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
    DEEPSEEK_API_KEY: str
    GITHUB_TOKEN_1: str
    GITHUB_TOKEN_2: str
    GITHUB_TOKEN_3: str

    class Config:
        env_file = ".env"


# 🔥 INIT SETTINGS
settings = Settings()

# 🔥 EXPORT VARIABLES
GROQ_API_KEY = settings.GROQ_API_KEY
DEEPSEEK_API_KEY = settings.DEEPSEEK_API_KEY
GITHUB_TOKEN_1 = settings.GITHUB_TOKEN_1
GITHUB_TOKEN_2 = settings.GITHUB_TOKEN_2
GITHUB_TOKEN_3 = settings.GITHUB_TOKEN_3