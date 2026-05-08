from app.core.config import GROQ_API_KEY
import json


def call_groq(query: str) -> dict:
    try:
        from groq import Groq
    except ImportError as exc:
        raise RuntimeError(
            "The 'groq' package is not installed in the active Python environment."
        ) from exc

    client = Groq(api_key=GROQ_API_KEY)

    # 🔥 STRICT PROMPT
    prompt = f"""
You are an AI assistant.

STRICT RULES:
- Respond ONLY in valid JSON
- DO NOT write anything outside JSON
- DO NOT use markdown

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

    response = client.chat.completions.create(
        model="llama-3.1-8b-instant",
        messages=[
            {"role": "user", "content": prompt}
        ],
        temperature=0.3,
    )

    raw_text = response.choices[0].message.content

    # 🔥 SAFE JSON PARSE
    try:
        parsed = json.loads(raw_text)
        return parsed
    except Exception:
        return {
            "type": "text",
            "responses": [
                {
                    "title": "Fallback",
                    "content": raw_text
                }
            ]
        }