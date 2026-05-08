import requests
import json
import re
from app.core.config import settings


def call_deepseek(query: str) -> dict:
    url = "https://api.deepseek.com/v1/chat/completions"

    headers = {
        "Authorization": f"Bearer {settings.DEEPSEEK_API_KEY}",
        "Content-Type": "application/json"
    }

    prompt = f"""
You are an AI assistant.

STRICT RULES:
- Respond ONLY in valid JSON

FORMAT:
{{
  "type": "text",
  "responses": [
    {{
      "title": "Answer",
      "content": "..."
    }}
  ]
}}

User Query:
{query}
"""

    payload = {
        "model": "deepseek-chat",
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.3
    }

    try:
        response = requests.post(url, headers=headers, json=payload, timeout=30)
        response.raise_for_status()

        raw = response.json()["choices"][0]["message"]["content"].strip()

        print("[DEEPSEEK RAW]:", raw)

        match = re.search(r'\{.*\}', raw, re.DOTALL)
        cleaned = match.group(0) if match else raw

        try:
            parsed = json.loads(cleaned)

            if "type" not in parsed or "responses" not in parsed:
                raise ValueError

            return parsed

        except:
            return {
                "type": "text",
                "responses": [
                    {
                        "title": "Fallback",
                        "content": raw
                    }
                ]
            }

    except Exception as e:
        print("[DEEPSEEK ERROR]:", e)

        return {
            "type": "text",
            "responses": [
                {
                    "title": "Error",
                    "content": "DeepSeek failed"
                }
            ]
        }