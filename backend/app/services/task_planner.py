import re

from app.services.intent_classifier import classify_intent
from command.command_parser import parse_command

CONNECTORS = ["and", "then", "also", ","]


def split_query(query: str):
    pattern = r"\b(?:" + "|".join(CONNECTORS) + r")\b"
    parts = re.split(pattern, query, flags=re.IGNORECASE)
    return [part.strip() for part in parts if part.strip()]


def clean_query(part: str):
    fillers = ["please", "can you", "tell me", "show me"]
    part_lower = part.lower()

    for filler in fillers:
        part_lower = part_lower.replace(filler, "")

    return part_lower.strip()


def plan_tasks(query: str | dict, intent: str):

    # 🔥 STRUCTURED COMMAND (from routes)
    if intent == "command" and isinstance(query, dict):
        return [
            {
                "type": "command",
                "action": query["action"],
                "app": query["app"],
            }
        ]

    if not isinstance(query, str):
        return []

    tasks = []
    parts = split_query(query)

    for part in parts:
        part = part.strip()

        # 🔥 CENTRAL COMMAND PARSER
        command = parse_command(part)
        if command:
            tasks.append(command)
            continue

        # 🔧 CLEAN + CLASSIFY
        cleaned = clean_query(part)
        part_intent = classify_intent(cleaned)

        tasks.append(
            {
                "type": "ai",
                "query": cleaned,
                "intent": part_intent,
            }
        )

    return tasks