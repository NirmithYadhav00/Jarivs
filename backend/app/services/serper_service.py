import os
import requests

from dotenv import load_dotenv

load_dotenv()

SERPER_URL = "https://google.serper.dev/search"


def search_web(query: str):

    payload = {
        "q": query
    }

    headers = {
        "X-API-KEY": os.getenv("SERPER_API_KEY"),
        "Content-Type": "application/json"
    }

    response = requests.post(
        SERPER_URL,
        json=payload,
        headers=headers,
        timeout=10
    )

    return response.json()