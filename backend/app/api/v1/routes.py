from fastapi import APIRouter
import time

from app.models.request_model import UserRequest
from app.models.response_model import ResponseModel
from app.providers.groq_provider import call_groq

from app.services.execution_engine import execute_tasks
from app.services.intent_classifier import classify_intent
from app.services.task_planner import plan_tasks
from command.command_parser import parse_command

router = APIRouter()


# 🔥 FAST PATH (USE THIS NOW)
@router.post("/process")
def process(request: UserRequest):
    query = request.query.lower().strip()

    try:
        # 🔥 detect ANY open command
        if query.startswith("open "):
            app_name = query.replace("open ", "").strip()

            return {
                "type": "command",
                "response": f"Opening {app_name}",
                "action": "open_app",
                "app": app_name
            }

        # 🤖 normal AI
        ai_response = call_groq(query)

        return {
            "type": "text",
            "response": ai_response
        }

    except Exception as e:
        print("ERROR:", e)
        return {
            "type": "text",
            "response": "Something went wrong"
        }

    query = request.query.lower().strip()

    try:
        # 🎯 STRICT command detection
        if query.startswith("open "):
            app_name = query.replace("open ", "").strip()

            if "youtube" in app_name:
                return {
                    "type": "command",
                    "response": "Opening YouTube",
                    "action": "open_youtube"
                }

            if "whatsapp" in app_name:
                return {
                    "type": "command",
                    "response": "Opening WhatsApp",
                    "action": "open_whatsapp"
                }

        # 🤖 NORMAL AI FLOW
        ai_response = call_groq(query)

        return {
            "type": "text",
            "response": ai_response
        }

    except Exception as e:
        print("ERROR:", e)
        return {
            "type": "text",
            "response": "Something went wrong"
        }

    query = request.query.lower()

    try:
        # 🔥 SIMPLE COMMAND DETECTION
        if "open youtube" in query:
            return {
                "type": "command",
                "response": "Opening YouTube",
                "action": "open_youtube"
            }

        # NORMAL AI
        ai_response = call_groq(query)

        return {
            "type": "text",
            "response": ai_response
        }

    except Exception as e:
        print("ERROR:", e)
        return {
            "type": "text",
            "response": "Something went wrong"
        }

    start_time = time.time()

    if "call" in query:
        name = query.replace("call", "").strip()
        return {
            "type": "command",
            "action": "call",
            "contact": name
        }

    if "message" in query or "sms" in query:
        name = query.replace("message", "").strip()
        return {
            "type": "command",
            "action": "message",
            "contact": name
        }

    try:
        user_text = request.query.strip()

        if not user_text:
            return ResponseModel(
                response="I didn't catch that."
            )

        ai_response = call_groq(user_text)

        latency = round(time.time() - start_time, 2)
        print(f"[FAST PATH] {latency}s | {user_text}")

        return ResponseModel(
            type="text",
            response=ai_response
        )

    except Exception as e:
        print(f"[ERROR] {str(e)}")

        return ResponseModel(
            response="Something went wrong."
        )


# 🧠 ADVANCED PATH (KEEP FOR LATER)
@router.post("/chat")
def chat(request: UserRequest):
    user_id = request.user_id
    query = request.query

    installed_apps = request.installed_apps or []

    # Step 1: classify
    intent = classify_intent(query)

    # Step 2: command intelligence
    if intent == "command":
        parsed_command = parse_command(query)

        if parsed_command:
            tasks = plan_tasks(parsed_command, intent="command")
        else:
            return {
                "status": "error",
                "message": "Command not understood",
            }
    else:
        tasks = plan_tasks(query, intent)

    # Step 3: execute
    results = execute_tasks(
        tasks,
        user_id=user_id,
        original_query=query,
        installed_apps=installed_apps,
    )

    return results