from collections import defaultdict
from typing import Dict, List


class MemoryService:
    def __init__(self, max_messages: int = 10):
        # 🔥 user_id → intent → messages
        self.memory_store: Dict[str, Dict[str, List[Dict[str, str]]]] = defaultdict(
            lambda: {
                "coding": [],
                "general": []
            }
        )
        self.max_messages = max_messages

    # ✅ GET MEMORY BY INTENT
    def get_memory(self, user_id: str, intent: str) -> List[Dict[str, str]]:
        return self.memory_store[user_id].get(intent, [])

    # ✅ ADD INTERACTION WITH INTENT
    def add_interaction(self, user_id: str, user_message: str, ai_response: str, intent: str):
        if not user_id:
            return

        memory_bucket = self.memory_store[user_id].get(intent, [])

        memory_bucket.append({
            "role": "user",
            "content": user_message
        })

        memory_bucket.append({
            "role": "assistant",
            "content": ai_response
        })

        # trim
        self.memory_store[user_id][intent] = memory_bucket[-self.max_messages:]

    # ✅ CLEAR MEMORY
    def clear_memory(self, user_id: str):
        if user_id in self.memory_store:
            del self.memory_store[user_id]

    # ✅ SMART MEMORY (WITH INTENT)
    def get_relevant_memory(self, user_id: str, current_query: str, intent: str, limit: int = 5):
        memory = self.memory_store[user_id].get(intent, [])

        if not memory:
            return []

        keywords = set(current_query.lower().split())

        # 🔥 Always include last interaction
        last_interaction = memory[-2:] if len(memory) >= 2 else memory

        relevant = []

        for msg in memory[:-2]:
            content = msg["content"].lower()

            if any(word in content for word in keywords):
                relevant.append(msg)

        relevant = relevant[-limit:]

        final_memory = last_interaction + relevant

        # remove duplicates
        seen = set()
        unique_memory = []

        for msg in final_memory:
            key = (msg["role"], msg["content"])
            if key not in seen:
                seen.add(key)
                unique_memory.append(msg)

        return unique_memory