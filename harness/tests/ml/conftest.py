"""Pruebas de ML aplazadas: el clasificador acústico (T10, T11) queda fuera del MVP (decisión D-11).

Las pruebas no se borran ni se modifican; solo se excluyen de la recolección mientras dure el aplazamiento.
Para retomar el clasificador, vacía esta lista y pasa T10 y T11 a `todo` (ver harness/context/12-decisions.md).
"""

collect_ignore = [
    "test_dataset.py",
    "test_features.py",
    "test_event_model.py",
    "test_postprocess.py",
    "test_event_classifier.py",
]
