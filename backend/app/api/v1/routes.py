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


# 🔥 NEW: MESSAGE INTELLIGENCE
def extract_message_command(query: str):
    patterns = [
        r"message (.+?) (.+)",
        r"send message to (.+?) (.+)",
        r"tell (.+?) (.+)",
        r"sms (.+?) (.+)"
    ]

    for pattern in patterns:
        match = re.match(pattern, query)
        if match:
            contact = match.group(1).strip()
            message = match.group(2).strip()
            return contact, message

    return None, None


@router.post("/process")
def process(request: UserRequest):
    query = request.query.lower().strip()

    try:
        # 🔥 MESSAGE INTELLIGENCE (ADDED FIRST)
        contact, message = extract_message_command(query)

        if contact and message:
            return {
                "type": "command",
                "response": f"Sending message to {contact}",
                "action": "sms",
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

        # 📞 CALL BY NAME
        if query.startswith("call"):
            name = query.replace("call", "").strip()

            return {
                "type": "command",
                "response": f"Calling {name}",
                "action": "call",
                "contact": name,
            }

        # 📩 SMS (OLD STYLE STILL WORKS)
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

        # 🟢 WHATSAPP MESSAGE
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