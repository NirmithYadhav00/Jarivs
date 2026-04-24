from command.command_parser import parse_command  # (not used here, but okay if already imported)

def classify_intent(query: str) -> str:
    print("[INTENT INPUT]:", query)

    q = query.lower()

    REAL_TIME_KEYWORDS = [
        "weather", "news", "price", "time", "temperature",
        "today", "now", "latest", "current", "update",
        "score", "live", "stock", "market", "value"
    ]

    CODING_KEYWORDS = [
        "code", "debug", "error", "python", "api",
        "recursion", "function", "bug", "algorithm"
    ]

    COMMAND_KEYWORDS = ["open", "launch", "start"]

    # 🔥 COMMAND
    if any(cmd in q for cmd in COMMAND_KEYWORDS):
        print("[INTENT OUTPUT]: command")
        return "command"

    # 🔥 REAL-TIME
    if any(word in q for word in REAL_TIME_KEYWORDS):
        print("[INTENT OUTPUT]: real_time")
        return "real_time"

    # 🔧 CODING
    if any(word in q for word in CODING_KEYWORDS):
        print("[INTENT OUTPUT]: coding")
        return "coding"

    # 🧠 DEFAULT
    print("[INTENT OUTPUT]: general")
    return "general"
    print("[INTENT INPUT]:", query)

    q = query.lower()
    q_clean = q.replace(" ", "")

    REAL_TIME_KEYWORDS = [
        "weather", "news", "price", "time", "temperature",
        "today", "now", "latest", "current", "update",
        "score", "live", "stock", "market", "value"
    ]

    CODING_KEYWORDS = [
        "code", "debug", "error", "python", "api",
        "recursion", "function", "bug", "algorithm"
    ]

    # 🔥 SIMPLIFIED COMMAND DETECTION
    COMMAND_KEYWORDS = ["open", "launch", "start"]

    # 🔥 COMMAND
    if any(cmd in q for cmd in COMMAND_KEYWORDS):
        print("[INTENT OUTPUT]: command")
        return "command"

    # 🔥 REAL-TIME
    if any(word in q for word in REAL_TIME_KEYWORDS):
        print("[INTENT OUTPUT]: real_time")
        return "real_time"

    # 🔧 CODING
    if any(word in q for word in CODING_KEYWORDS):
        print("[INTENT OUTPUT]: coding")
        return "coding"

    # 🧠 DEFAULT
    print("[INTENT OUTPUT]: general")
    return "general"