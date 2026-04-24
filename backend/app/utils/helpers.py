import json
import re
import time


def extract_valid_json(text: str):
    """
    Extracts the first valid JSON object from LLM output.
    """

    # 🔹 Try direct parse
    try:
        return json.loads(text)
    except:
        pass

    # 🔹 Try to extract largest JSON block
    match = re.search(r"\{[\s\S]*\}", text)

    if match:
        try:
            return json.loads(match.group())
        except:
            pass


def retry_request(func, retries=2, delay=1):
    for attempt in range(retries + 1):
        try:
            return func()
        except Exception:
            if attempt == retries:
                raise
            time.sleep(delay)

    return None
