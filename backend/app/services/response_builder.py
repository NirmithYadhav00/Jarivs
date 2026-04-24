def build_response(results):
    command = None
    texts = []
    structured = []

    for res in results:
        if res.get("type") == "command":
            command = res

        elif res.get("type") == "text":
            if "responses" in res:
                structured.extend(res["responses"])
            elif "response" in res:
                texts.append(res["response"])

    if structured:
        if command:
            return {
                "type": "response_with_action",
                "responses": structured,
                "action": command["action"],
                "app": command["app"]
            }

        return {
            "type": "text",
            "responses": structured
        }

    combined_text = "\n\n".join(texts) if texts else None

    if command and combined_text:
        return {
            "type": "response_with_action",
            "response": combined_text,
            "action": command["action"],
            "app": command["app"]
        }

    if command:
        return command

    return {
        "type": "text",
        "response": combined_text
    }
