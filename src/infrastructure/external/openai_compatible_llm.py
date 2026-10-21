from openai import BadRequestError, OpenAI

from src.domain.interfaces.ports import LLMProvider


class OpenAICompatibleLLM(LLMProvider):
    def __init__(self, name: str, base_url: str, api_key: str, model: str,
                 timeout: float = 90, max_retries: int = 4):
        self.name = name
        self.model = model
        self.client = OpenAI(base_url=base_url, api_key=api_key,
                             timeout=timeout, max_retries=max_retries)

    def complete_json(self, system: str, user: str) -> str:
        kwargs = dict(
            model=self.model,
            messages=[{"role": "system", "content": system},
                      {"role": "user", "content": user}],
            temperature=0.3,
        )
        try:
            r = self.client.chat.completions.create(
                **kwargs, response_format={"type": "json_object"})
        except BadRequestError:
            r = self.client.chat.completions.create(**kwargs)

        content = r.choices[0].message.content
        if not content:
            raise ValueError(f"{self.name} devolvió una respuesta vacía")
        return content