from fastapi import APIRouter
from app.models.request_model import UserRequest
from app.providers.groq_provider import call_groq

router = APIRouter()

APP_ALIASES = {
    "youtube": ["youtube", "you tube", "yt"],
    "whatsapp": ["whatsapp", "whats app"],
    "photos": ["photos", "gallery", "images", "pics"],
    "playstore": ["play store", "playstore"],
    "gpay": ["gpay", "google pay"],
    "settings": ["settings", "setting"],
    "camera": ["camera"],
    "recorder": ["recorder", "voice recorder"],
    "clock": ["clock", "alarm"],
    "chatgpt": ["chatgpt", "chat gpt", "gpt"],
}


def normalize_app_name(query: str):
    query = f" {query} "

    keyword_map = []

    for app, keywords in APP_ALIASES.items():
        for word in keywords:
            keyword_map.append((word, app))

    keyword_map.sort(key=lambda x: len(x[0]), reverse=True)

    for word, app in keyword_map:
        if f" {word} " in query:
            return app

    return None


@router.post("/process")
def process(request: UserRequest):
    query = request.query.lower().strip()

    try:
        # 🔥 YOUTUBE SEARCH FIRST (IMPORTANT ORDER)
        if "youtube" in query and "search" in query:
            search_query = (
                query.replace("search youtube", "")
                .replace("search you tube", "")
                .replace("youtube", "")
                .replace("you tube", "")
                .strip()
            )

            return {
                "type": "command",
                "response": f"Searching YouTube for {search_query}",
                "action": "open_youtube",
                "app": search_query,
            }

        # 🔥 GOOGLE SEARCH
        if query.startswith("search"):
            search_query = query.replace("search", "").strip()

            return {
                "type": "command",
                "response": f"Searching {search_query}",
                "action": "search_google",
                "app": search_query,
            }

        # 🔥 OPEN COMMAND
        if query.startswith("open"):
            app_name = normalize_app_name(query)

            if not app_name:
                app_name = query.replace("open", "").strip()

            # 🎯 SPECIAL CASE
            if app_name == "youtube":
                return {
                    "type": "command",
                    "response": "Opening YouTube",
                    "action": "open_youtube",
                }

            return {
                "type": "command",
                "response": f"Opening {app_name}",
                "action": "open_app",
                "app": app_name,
            }

        # 📞 CALL
        if query.startswith("call"):
            return {
                "type": "command",
                "response": "Opening dialer",
                "action": "call",
            }

        # 💬 SMS
        if "message" in query or "sms" in query:
            return {
                "type": "command",
                "response": "Opening messages",
                "action": "sms",
            }

        # 🤖 FALLBACK AI
        ai_response = call_groq(query)

        return {
            "type": "text",
            "response": ai_response,
        }

    except Exception as e:
        print("ERROR:", e)

        return {
            "type": "text",
            "response": "Something went wrong",
        }