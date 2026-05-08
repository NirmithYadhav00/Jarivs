def build_response(results):
    command = None
    structured = []

    for res in results:
        if not isinstance(res, dict):
            continue

        # 🔥 COMMAND DETECTION
        if res.get("type") == "command":
            command = res

        # 🔥 TEXT HANDLING
        elif res.get("type") == "text":
            if "responses" in res:
                structured.extend(res["responses"])

            elif "response" in res:
                structured.append({
                    "title": "Answer",
                    "content": res["response"]
                })

    # =========================
    # 🔥 CASE 1: COMMAND + AI
    # =========================
    if command and structured:
        response = {
            "type": "response_with_action",
            "action": command.get("action"),
            "responses": structured
        }

        # 🔥 optional fields (safe attach)
        optional_fields = ["app", "platform", "contact", "message", "query"]

        for field in optional_fields:
            if field in command and command[field] is not None:
                response[field] = command[field]

        return response

    # =========================
    # 🔥 CASE 2: ONLY AI
    # =========================
    if structured:
        return {
            "type": "text",
            "responses": structured
        }

    # =========================
    # 🔥 CASE 3: ONLY COMMAND
    # =========================
    if command:
        return command

    # =========================
    # 🔥 FALLBACK
    # =========================
    return {
        "type": "text",
        "responses": [
            {
                "title": "Answer",
                "content": "No response generated"
            }
        ]
    }