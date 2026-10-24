"""JSON Schema estricto (modo strict de Groq) a partir de un modelo pydantic."""

import copy

from pydantic import BaseModel

_DEFS_PREFIX = "#/$defs/"


def _resolve_refs(node, defs: dict):
    if isinstance(node, list):
        return [_resolve_refs(item, defs) for item in node]
    if not isinstance(node, dict):
        return node
    if "$ref" in node:
        target = copy.deepcopy(defs[node["$ref"].removeprefix(_DEFS_PREFIX)])
        siblings = {k: v for k, v in node.items() if k != "$ref"}
        return _resolve_refs({**target, **siblings}, defs)
    return {key: _resolve_refs(value, defs) for key, value in node.items()}


def _close_objects(node) -> None:
    if isinstance(node, list):
        for item in node:
            _close_objects(item)
        return
    if not isinstance(node, dict):
        return
    if node.get("type") == "object" or "properties" in node:
        node["additionalProperties"] = False
        node["required"] = list(node.get("properties", {}))
    for value in node.values():
        _close_objects(value)


def strict_json_schema(model: type[BaseModel]) -> dict:
    schema = copy.deepcopy(model.model_json_schema())
    defs = schema.pop("$defs", {})
    resolved = _resolve_refs(schema, defs)
    _close_objects(resolved)
    return resolved
