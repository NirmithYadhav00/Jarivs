import httpx
from app.core.config import settings


class TogetherProvider:

    def __init__(self):
        self.api_key = settings.TOGETHER_API_KEY
        self.url = "https://api.together.xyz/v1/chat/completions"

    def generate(self, prompt: str) -> dict:
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }

        payload = {
            "model": "mistralai/Mixtral-8x7B-Instruct-v0.1",
            "messages": [
                {
                    "role": "system",
                    "content": "Return ONLY valid JSON. No extra text."
                },
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            "temperature": 0.3
        }

        response = httpx.post(self.url, headers=headers, json=payload, timeout=30.0)
        response.raise_for_status()

        return response.json()
