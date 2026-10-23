"""T08 - JSON Schema estricto para salidas estructuradas de Groq (gpt-oss, qwen).

Contrato: src/infrastructure/external/json_schema.py
  strict_json_schema(model: type[pydantic.BaseModel]) -> dict
Reglas del modo estricto de Groq: todo objeto con `additionalProperties: false`
y TODAS sus propiedades en `required`. Sin referencias $ref sin resolver en la raíz.
"""

from src.domain.entities.analysis import Analisis, Sintesis
from src.infrastructure.external.json_schema import strict_json_schema


def _objects(node):
    if isinstance(node, dict):
        if node.get("type") == "object" or "properties" in node:
            yield node
        for value in node.values():
            yield from _objects(value)
    elif isinstance(node, list):
        for item in node:
            yield from _objects(item)


def test_every_object_is_closed_and_fully_required():
    for model in (Analisis, Sintesis):
        schema = strict_json_schema(model)
        found = list(_objects(schema))
        assert found, "el esquema debe contener objetos"
        for obj in found:
            assert obj.get("additionalProperties") is False
            assert sorted(obj.get("required", [])) == sorted(obj.get("properties", {}))


def test_schema_describes_the_analysis_fields():
    schema = strict_json_schema(Analisis)
    props = schema.get("properties") or schema["$defs"][schema["$ref"].split("/")[-1]]["properties"]
    assert {"organizacion", "claridad", "repeticion", "evidencias"} <= set(props)


def test_original_model_schema_is_not_mutated():
    before = Analisis.model_json_schema()
    strict_json_schema(Analisis)
    assert Analisis.model_json_schema() == before
