def classify_intent(query: str) -> str:
    print("[INTENT INPUT]:", query)

    q = query.lower().strip()

    # 🔥 COMMAND KEYWORDS (IMPORTANT — EXPANDED)
    COMMAND_KEYWORDS = [
        "open", "launch", "start",
        "call", "dial",
        "message", "sms",
        "whatsapp", "send"
    ]

    # 🔥 REAL-TIME
    REAL_TIME_KEYWORDS = [
        "weather", "news", "price", "time", "temperature",
        "today", "now", "latest", "current", "update",
        "score", "live", "stock", "market", "value"
    ]

    # 🔧 CODING
    CODING_KEYWORDS = [
        "code", "debug", "error", "python", "api",
        "recursion", "function", "bug", "algorithm"
    ]

    # 🔥 PRIORITY 1 → COMMAND (VERY IMPORTANT)
    if any(q.startswith(cmd) for cmd in COMMAND_KEYWORDS):
        print("[INTENT OUTPUT]: command")
        return "command"

    # 🔥 PRIORITY 2 → REAL-TIME
    if any(word in q for word in REAL_TIME_KEYWORDS):
        print("[INTENT OUTPUT]: real_time")
        return "real_time"

    # 🔥 PRIORITY 3 → CODING
    if any(word in q for word in CODING_KEYWORDS):
        print("[INTENT OUTPUT]: coding")
        return "coding"

    # 🧠 DEFAULT
    print("[INTENT OUTPUT]: general")
    return "general"