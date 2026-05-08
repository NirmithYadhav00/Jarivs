from collections import defaultdict
from difflib import get_close_matches

from app.core.config import memory_service
from app.core.config import topic_service
from app.providers.groq_provider import call_groq

from app.services.provider_selector import select_provider
from app.utils.cache import get_cache, set_cache
from app.utils.helpers import extract_valid_json, retry_request


APP_CATEGORIES = {
    "youtube": "media",
    "spotify": "media",
    "chrome": "browser",
    "whatsapp": "messaging",
    "instagram": "social"
}


def suggest_alternative(app, installed_apps):
    matches = get_close_matches(app, installed_apps, n=1, cutoff=0.5)
    if matches:
        return matches[0]

    app_category = APP_CATEGORIES.get(app)

    if app_category:
        for installed in installed_apps:
            if APP_CATEGORIES.get(installed) == app_category:
                return installed

    if installed_apps:
        return installed_apps[0]

    return None


# 🔥 CLEAN PROVIDER CALL (ONLY GROQ FOR NOW)
def call_provider(provider_name, prompt):
    def run():
        print(f"[RUNNING] {provider_name}")

        if provider_name == "groq":
            result = call_groq(prompt)
            print(f"[GROQ RAW]: {result}")
            return result

        raise ValueError(f"Unknown provider: {provider_name}")

    try:
        print(f"[CALLING] {provider_name}")
        return retry_request(run)

    except Exception as e:
        print(f"[ERROR] {provider_name}: {e}")

        return '{"responses":[{"title":"Error","content":"AI provider failed"}]}'


def build_prompt_with_memory(memory, current_query, latest_query, current_topic):
    memory_text = ""

    for msg in memory:
        role = msg["role"]
        content = msg["content"]
        memory_text += f"{role.capitalize()}: {content}\n"

    final_prompt = f"""
You are an AI assistant with conversation memory.

IMPORTANT:
- The CURRENT topic is based on the latest user message
- You MUST answer based on the latest topic
- Ignore older topics unless explicitly referenced

CURRENT TOPIC:
{latest_query}

Conversation history:
{memory_text}

Now answer this request:

{current_query}
"""

    return final_prompt.strip()


def execute_tasks(
    tasks,
    user_id: str = "anonymous",
    original_query: str = "",
    installed_apps: list[str] | None = None,
):
    responses = []
    intent_groups = defaultdict(list)
    installed_apps = installed_apps or []
    installed_apps_lower = [app.lower() for app in installed_apps]

    for task in tasks:
        if task["type"] == "command":
            app = task.get("app", "").lower()

            if installed_apps_lower and app not in installed_apps_lower:
                suggestion = suggest_alternative(app, installed_apps_lower)
                responses.append(
                    {
                        "type": "error",
                        "message": f"{app} is not installed",
                        "suggestion": suggestion,
                    }
                )
                continue

            responses.append(
                {
                    "type": "command",
                    "action": task["action"],
                    "app": app,
                    "response": f"Opening {app}",
                }
            )
            continue

        if task["type"] == "ai":
            intent = task.get("intent", "general")
            intent_groups[intent].append(task["query"])

    parsed_responses = []

    for intent, queries in intent_groups.items():
        provider = select_provider(intent)

        structured_prompt = """
You are a backend AI system.

You MUST return ONLY ONE valid JSON object.
NO text before or after JSON.
NO markdown.
NO explanations.

STRICT FORMAT:
{
  "responses": [
    {"title": "string", "content": "string"}
  ]
}

RULES:
- Output MUST be valid JSON
- Use double quotes only
- Do NOT add trailing commas
- Do NOT wrap in ```json
- If multiple queries, combine into one responses array

If you fail to follow format, the system will break.

User queries:
"""

        for query in queries:
            structured_prompt += f"\n- {query}"

        combined_query = " ".join(queries)
        latest_query = queries[-1]
        current_topic = topic_service.get_topic(user_id)
        memory = memory_service.get_relevant_memory(user_id, combined_query, intent)

        enhanced_prompt = build_prompt_with_memory(
            memory,
            structured_prompt,
            latest_query,
            current_topic,
        )

        topic_service.update_topic(user_id, latest_query)

        cache_key = f"{provider}:{enhanced_prompt}"
        cached = get_cache(cache_key)

        if cached:
            raw_response = cached
        else:
            raw_response = call_provider(provider, enhanced_prompt)
            set_cache(cache_key, raw_response)

        raw_response = raw_response.strip()
        parsed = extract_valid_json(raw_response)

        if parsed and "responses" in parsed:
            parsed_responses.extend(parsed["responses"])
            responses.append(
                {
                    "type": "text",
                    "responses": parsed["responses"],
                }
            )
        else:
            responses.append(
                {
                    "type": "text",
                    "responses": [
                        {
                            "title": "Error",
                            "content": "AI response parsing failed",
                        }
                    ],
                }
            )

    if parsed_responses:
        final_text = " ".join(
            item["content"] for item in parsed_responses if item.get("content")
        )

        memory_service.add_interaction(
            user_id=user_id,
            user_message=original_query,
            ai_response=final_text,
            intent=intent,
        )

    return responses