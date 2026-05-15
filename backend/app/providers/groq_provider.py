from app.core.config import GROQ_API_KEY
from groq import Groq
import json


def call_groq(query: str) -> dict:

    try:

        client = Groq(
            api_key=GROQ_API_KEY
        )

        response = client.chat.completions.create(

            model="llama-3.1-8b-instant",

            messages=[

                {
                    "role": "system",
                    "content": """
You are Lucky AI, a fast voice assistant.

STRICT RULES:
- Reply naturally
- Keep answers short
- Maximum 1 short sentence
- Sound conversational
- Return ONLY valid JSON
- No markdown
- No extra explanation
"""
                },

                {
                    "role": "user",
                    "content": f"""
Return response ONLY in this JSON format:

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
                }
            ],

            temperature=0.2,

            max_tokens=60,
        )

        raw_text = response.choices[0].message.content

        print("[GROQ RAW]:", raw_text)

        # ✅ SAFE JSON PARSE
        try:

            parsed = json.loads(raw_text)

            return parsed

        except Exception:

            return {
                "type": "text",
                "responses": [
                    {
                        "title": "Answer",
                        "content": raw_text
                    }
                ]
            }

    except Exception as e:

        print("[GROQ ERROR]:", e)

        return {
            "type": "text",
            "responses": [
                {
                    "title": "Error",
                    "content": "Groq AI failed"
                }
            ]
        }

