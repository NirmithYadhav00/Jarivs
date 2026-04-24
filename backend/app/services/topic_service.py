from collections import defaultdict


class TopicService:
    def __init__(self):
        # user_id -> current topic
        self.user_topics = defaultdict(str)

    def get_topic(self, user_id: str) -> str:
        return self.user_topics.get(user_id, "")

    def update_topic(self, user_id: str, query: str):
        if not query:
            return

        # 🔥 Basic heuristic (we improve later)
        self.user_topics[user_id] = query.strip()

    def clear_topic(self, user_id: str):
        if user_id in self.user_topics:
            del self.user_topics[user_id]