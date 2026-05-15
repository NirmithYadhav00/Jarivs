from app.services.serper_service import search_web
from app.providers.groq_provider import call_groq


def realtime_response(query: str):

    search_results = search_web(query)

    prompt = f"""
    You are Lucky AI.

    Use this realtime web information to answer naturally.

    Keep responses:
    - short
    - conversational
    - voice-friendly

    Web Data:
    {search_results}

    User Query:
    {query}
    """

    return call_groq(prompt)