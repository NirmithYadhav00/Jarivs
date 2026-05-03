from fastapi import APIRouter
from app.models.request_model import UserRequest
from app.providers.groq_provider import call_groq
import re

router = APIRouter()

# 🔥 APP ALIASES
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

# 🔥 SMART APP MATCHING
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

# 🔥 MESSAGE INTELLIGENCE
def extract_message_command(query: str):
    query = query.strip().lower()

    if query.startswith("whatsapp"):
        parts = query.replace("whatsapp", "").strip().split(" ", 1)
        return "whatsapp", parts[0], parts[1] if len(parts) > 1 else ""

    if query.startswith("dm"):
        parts = query.replace("dm", "").strip().split(" ", 1)
        return "instagram", parts[0], parts[1] if len(parts) > 1 else ""

    if query.startswith("message") or query.startswith("sms"):
        parts = query.replace("message", "").replace("sms", "").strip().split(" ", 1)
        return "sms", parts[0], parts[1] if len(parts) > 1 else ""

    return None, None, None


@router.post("/process")
def process(request: UserRequest):
    query = request.query.lower().strip()

    try:
        # 🔥 MESSAGE ROUTING (FIRST PRIORITY)
        platform, contact, message = extract_message_command(query)

        if platform and contact:
            return {
                "type": "command",
                "response": f"Opening {platform} for {contact}",
                "action": "send_message",
                "platform": platform,
                "contact": contact,
                "message": message,
            }

        # 🔥 YOUTUBE SEARCH
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

        # 🔍 GOOGLE SEARCH
        if query.startswith("search"):
            search_query = query.replace("search", "").strip()

            return {
                "type": "command",
                "response": f"Searching {search_query}",
                "action": "search_google",
                "app": search_query,
            }

        # 📞 CALL
        if query.startswith("call"):
            name = query.replace("call", "").strip()

            return {
                "type": "command",
                "response": f"Calling {name}",
                "action": "call",
                "contact": name,
            }

        # 📩 SMS (OLD STYLE)
        if query.startswith("send sms"):
            parts = query.replace("send sms", "").strip().split(" ", 1)

            contact = parts[0] if len(parts) > 0 else ""
            message = parts[1] if len(parts) > 1 else ""

            return {
                "type": "command",
                "response": f"Sending SMS to {contact}",
                "action": "sms",
                "contact": contact,
                "message": message,
            }

        # 🟢 WHATSAPP (OLD STYLE)
        if query.startswith("send whatsapp"):
            parts = query.replace("send whatsapp", "").strip().split(" ", 1)

            contact = parts[0] if len(parts) > 0 else ""
            message = parts[1] if len(parts) > 1 else ""

            return {
                "type": "command",
                "response": f"Opening WhatsApp for {contact}",
                "action": "whatsapp_message",
                "contact": contact,
                "message": message,
            }

        # 🔥 OPEN APP
        if query.startswith("open"):
            app_name = normalize_app_name(query)

            if not app_name:
                app_name = query.replace("open", "").strip()

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