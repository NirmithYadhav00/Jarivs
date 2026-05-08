from app.providers.groq_provider import call_groq
from app.providers.github_provider import call_github
from app.services.intent_classifier import classify_intent


def handle_ai(query: str):
    intent = classify_intent(query)

    print("[INTENT]:", intent)

    try:
        # 🔧 CODING → GitHub (DeepSeek/OpenAI)
        if intent == "coding":
            print("[PROVIDER]: github (coding)")
            return call_github(query, intent="coding")

        # 🧠 GENERAL → Groq
        if intent == "general":
            print("[PROVIDER]: groq")
            return call_groq(query)

        # 🌐 REAL-TIME → GitHub (for now)
        if intent == "real_time":
            print("[PROVIDER]: github (real-time)")
            return call_github(query)

        # 🔥 DEFAULT FALLBACK
        print("[PROVIDER]: fallback → github")
        return call_github(query)

    except Exception as e:
        print("[AI ERROR]:", e)

        return {
            "type": "text",
            "responses": [
                {
                    "title": "Error",
                    "content": "AI service failed"
                }
            ]
        }