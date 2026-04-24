from app.core.config import GROQ_API_KEY


def call_groq(query: str) -> str:
    try:
        from groq import Groq
    except ImportError as exc:
        raise RuntimeError(
            "The 'groq' package is not installed in the active Python environment."
        ) from exc

    client = Groq(api_key=GROQ_API_KEY)
    response = client.chat.completions.create(
        model="llama-3.1-8b-instant",
        messages=[
            {"role": "user", "content": query}
        ]
    )

    return response.choices[0].message.content
