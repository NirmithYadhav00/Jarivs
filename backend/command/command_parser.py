from command.app_resolver import resolve_app

OPEN_VERBS = ["open", "launch", "start"]


def parse_command(user_input: str) -> dict | None:
    text = user_input.lower()

    if any(verb in text for verb in OPEN_VERBS):
        app = resolve_app(user_input)

        if app:
            return {
                "type": "command",
                "action": "open_app",
                "app": app
            }

    return None