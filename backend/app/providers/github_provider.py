import requests
import json
import re
import random
from app.core.config import settings


# 🔥 TOKEN ROTATION
def get_github_token():
    tokens = [
        getattr(settings, "GITHUB_TOKEN_1", None),
        getattr(settings, "GITHUB_TOKEN_2", None),
        getattr(settings, "GITHUB_TOKEN_3", None),
    ]

    tokens = [t for t in tokens if t]

    if not tokens:
        raise ValueError("No GitHub tokens configured")

    return random.choice(tokens)


# 🔥 MODEL LIST (WITH FALLBACK)
def get_models(intent: str = "general"):
    if intent == "coding":
        return ["deepseek-coder", "gpt-4o-mini"]  # try DeepSeek → fallback
    return ["gpt-4o-mini"]


def call_github(query: str, intent: str = "general") -> dict:
    url = "https://models.inference.ai.azure.com/chat/completions"

    token = get_github_token()
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    # 🔥 STRICT JSON PROMPT
    prompt = f"""
You are an AI assistant.

STRICT RULES:
- Respond ONLY in valid JSON
- DO NOT write anything outside JSON

FORMAT:
{{
  "type": "text",
  "responses": [
    {{
      "title": "Answer",
      "content": "your answer here"
    }}
  ]
}}

User Query:
{query}
"""

    models = get_models(intent)

    # 🔥 TRY MODELS ONE BY ONE
    for model in models:
        try:
            payload = {
                "model": model,
                "messages": [{"role": "user", "content": prompt}],
                "temperature": 0.3
            }

            response = requests.post(
                url,
                headers=headers,
                json=payload,
                timeout=30
            )

            response.raise_for_status()

            raw = response.json()["choices"][0]["message"]["content"].strip()

            print(f"[GITHUB RAW - {model}]:", raw)

            # 🔥 CLEAN JSON
            match = re.search(r'\{.*\}', raw, re.DOTALL)
            cleaned = match.group(0) if match else raw

            parsed = json.loads(cleaned)

            if "type" not in parsed or "responses" not in parsed:
                raise ValueError("Invalid structure")

            return parsed

        except Exception as e:
            print(f"[MODEL FAILED - {model}]:", e)

    # 🔥 FINAL FALLBACK
    return {
        "type": "text",
        "responses": [
            {
                "title": "Error",
                "content": "All GitHub models failed"
            }
        ]
    }