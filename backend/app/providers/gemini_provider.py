from google import genai
from dotenv import load_dotenv

import os
import traceback

load_dotenv()

client = genai.Client(
    api_key=os.getenv("GEMINI_API_KEY")
)

SYSTEM_PROMPT = """
You are Lucky AI.

Keep responses short and conversational.
"""


def call_gemini(query: str):

    try:

        print("[GEMINI]: Request started")

        response = client.models.generate_content(
            model="gemini-2.0-flash",
            contents=f"{SYSTEM_PROMPT}\nUser: {query}"
        )

        print("[GEMINI RESPONSE]:", response)

        text = response.text

        print("[GEMINI TEXT]:", text)

        return {
            "type": "text",
            "responses": [
                {
                    "title": "Lucky",
                    "content": text
                }
            ]
        }

    except Exception:

        print(traceback.format_exc())

        return {
            "type": "text",
            "responses": [
                {
                    "title": "Gemini Error",
                    "content": "Gemini failed"
                }
            ]
        }