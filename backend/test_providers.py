from app.providers.groq_provider import call_groq
from app.providers.github_provider import call_github


def test_groq():
    print("\n--- TESTING GROQ ---")
    res = call_groq("What is recursion?")
    print(res)


def test_github():
    print("\n--- TESTING GITHUB ---")

    print("\n[GENERAL]")
    print(call_github("Explain recursion simply"))

    print("\n[CODING]")
    print(call_github("Write recursion in Python", intent="coding"))


if __name__ == "__main__":
    test_groq()
    test_github()