from app.providers.groq_provider import call_groq
from app.providers.github_provider import call_github

from app.services.intent_classifier import classify_intent
from app.services.realtime_service import realtime_response


def handle_ai(query: str):

    intent = classify_intent(query)

    print("[INTENT]:", intent)

    try:

        # 🔧 Coding Tasks
        if intent == "coding":

            print("[PROVIDER]: github (coding)")

            return call_github(query, intent="coding")

        # 🌐 Realtime Queries
        elif intent == "real_time":

            print("[PROVIDER]: realtime pipeline")

            return realtime_response(query)

        # 🧠 General Assistant
        elif intent == "general":

            print("[PROVIDER]: groq")

            return call_groq(query)

        # 🔥 Fallback
        print("[PROVIDER]: fallback → groq")

        return call_groq(query)

    except Exception:

        import traceback

        print(traceback.format_exc())

        return {
            "type": "text",
            "responses": [
                {
                    "title": "Error",
                    "content": "AI service failed"
                }
            ]
        }