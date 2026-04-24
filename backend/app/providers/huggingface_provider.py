import httpx
from app.core.config import settings


class HuggingFaceProvider:

    def __init__(self):
        self.api_key = settings.HUGGINGFACE_API_KEY
        self.url = "https://api-inference.huggingface.co/models/HuggingFaceH4/zephyr-7b-beta"
    def generate(self, prompt: str) -> str:
        headers = {
            "Authorization": f"Bearer {self.api_key}"
        }

        payload = {
            "inputs": prompt,
            "parameters": {
                "temperature": 0.3,
                "max_new_tokens": 500
            }
        }

        response = httpx.post(self.url, headers=headers, json=payload, timeout=30.0)
        response.raise_for_status()

        data = response.json()

        # HF returns different structure
        if isinstance(data, list):
            return data[0].get("generated_text", "")

        return str(data)
