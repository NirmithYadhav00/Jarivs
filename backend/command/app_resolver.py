import re

APP_MAP = {
    "youtube": ["youtube", "yt", "yt app", "youtube app"],
    "whatsapp": ["whatsapp", "whats app", "wa", "watsapp", "whatsap"],
    "chrome": ["chrome", "browser", "google chrome", "my browser"],
    "instagram": ["instagram", "insta", "ig"]
}


def normalize(text: str) -> str:
    text = text.lower()
    text = re.sub(r'[^a-z0-9\s]', '', text)
    return text.strip()


def resolve_app(user_input: str) -> str | None:
    text = normalize(user_input)

    # 1. synonym match
    for app, keywords in APP_MAP.items():
        for keyword in keywords:
            if keyword in text:
                return app

    # 2. fallback: extract after verb
    tokens = text.split()
    for i, token in enumerate(tokens):
        if token in ["open", "launch", "start"]:
            if i + 1 < len(tokens):
                return tokens[i + 1]

    # 3. fallback: last word
    if tokens:
        return tokens[-1]

    return None