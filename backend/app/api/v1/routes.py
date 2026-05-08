from fastapi import APIRouter
from app.models.request_model import UserRequest
from app.services.ai_service import handle_ai
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
        contact = parts[0] if len(parts) > 0 else ""
        message = parts[1] if len(parts) > 1 else ""
        return "whatsapp", contact, message

    if query.startswith("dm"):
        parts = query.replace("dm", "").strip().split(" ", 1)
        contact = parts[0] if len(parts) > 0 else ""
        message = parts[1] if len(parts) > 1 else ""
        return "instagram", contact, message

    if query.startswith("message") or query.startswith("sms"):
        parts = query.replace("message", "").replace("sms", "").strip().split(" ", 1)
        contact = parts[0] if len(parts) > 0 else ""
        message = parts[1] if len(parts) > 1 else ""
        return "sms", contact, message

    return None, None, None


# 🔥 MULTI-TASK SPLITTER
def split_tasks(query: str):
    if " and " in query:
        return [q.strip() for q in query.split(" and ")]
    return [query]


@router.post("/process")
def process(request: UserRequest):

    query = re.sub(r"\s+", " ", request.query.lower()).strip()
    tasks = split_tasks(query)

    try:
        print("[QUERY]:", query)
        responses = []

        for task in tasks:
            print("[TASK]:", task)

            # =========================
            # 🔥 COMMAND LAYER
            # =========================

            # 📩 MESSAGE
            platform, contact, message = extract_message_command(task)
            if platform and contact:
                responses.append({
                    "type": "command",
                    "response": f"Opening {platform} for {contact}",
                    "action": "send_message",
                    "platform": platform,
                    "contact": contact,
                    "message": message,
                })
                continue

            # ▶️ YOUTUBE SEARCH
            if "youtube" in task and "search" in task:
                search_query = (
                    task.replace("search youtube", "")
                    .replace("search you tube", "")
                    .replace("youtube", "")
                    .replace("you tube", "")
                    .strip()
                )

                responses.append({
                    "type": "command",
                    "response": f"Searching YouTube for {search_query}",
                    "action": "open_youtube",
                    "query": search_query,
                })
                continue

            # 🔍 GOOGLE SEARCH
            if task.startswith("search"):
                search_query = task.replace("search", "").strip()

                responses.append({
                    "type": "command",
                    "response": f"Searching {search_query}",
                    "action": "search_google",
                    "query": search_query,
                })
                continue

            # 📞 CALL
            if task.startswith("call"):
                name = task.replace("call", "").strip()

                responses.append({
                    "type": "command",
                    "response": f"Calling {name}",
                    "action": "call",
                    "contact": name,
                })
                continue

            # 📩 SMS
            if task.startswith("send sms"):
                parts = task.replace("send sms", "").strip().split(" ", 1)
                contact = parts[0] if len(parts) > 0 else ""
                message = parts[1] if len(parts) > 1 else ""

                responses.append({
                    "type": "command",
                    "response": f"Sending SMS to {contact}",
                    "action": "sms",
                    "contact": contact,
                    "message": message,
                })
                continue

            # 🟢 WHATSAPP
            if task.startswith("send whatsapp"):
                parts = task.replace("send whatsapp", "").strip().split(" ", 1)
                contact = parts[0] if len(parts) > 0 else ""
                message = parts[1] if len(parts) > 1 else ""

                responses.append({
                    "type": "command",
                    "response": f"Opening WhatsApp for {contact}",
                    "action": "whatsapp_message",
                    "contact": contact,
                    "message": message,
                })
                continue

            # 📱 OPEN APP
            if task.startswith("open"):
                app_name = normalize_app_name(task)

                if not app_name:
                    app_name = task.replace("open", "").strip()

                if app_name == "youtube":
                    responses.append({
                        "type": "command",
                        "response": "Opening YouTube",
                        "action": "open_youtube",
                    })
                else:
                    responses.append({
                        "type": "command",
                        "response": f"Opening {app_name}",
                        "action": "open_app",
                        "app": app_name,
                    })
                continue

            # =========================
            # 🤖 AI LAYER
            # =========================
            ai_response = handle_ai(task)
            responses.append(ai_response)

        return responses

    except Exception as e:
        print("[ERROR]:", e)

        return {
            "type": "text",
            "responses": [
                {"title": "Error", "content": "Something went wrong"}
            ],
        }