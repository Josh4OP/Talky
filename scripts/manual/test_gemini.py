import os

from dotenv import load_dotenv
from openai import OpenAI

load_dotenv()
client = OpenAI(
    base_url="https://generativelanguage.googleapis.com/v1beta/openai/",
    api_key=os.getenv("GEMINI_API_KEY"),
)
r = client.chat.completions.create(
    model=os.getenv("GEMINI_MODEL"),
    messages=[{"role": "user", "content": 'Responde solo con JSON: {"ok": true}'}],
)
print(r.choices[0].message.content)
