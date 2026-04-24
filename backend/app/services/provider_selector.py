def select_provider(intent: str) -> str:
    if intent == "coding":
        return "groq"

    elif intent == "general":
        return "groq"

    elif intent == "real_time":
        return "together"   

    return "groq"