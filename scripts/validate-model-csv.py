#!/usr/bin/env python3
"""Validate aeroplane_model.csv against a supplied source JSON file."""

import csv
import json
import sys
from pathlib import Path


source_path = Path(sys.argv[1])
csv_path = Path(sys.argv[2]) if len(sys.argv) > 2 else Path("data/aeroplane_model.csv")

with source_path.open(encoding="utf-8") as source:
    expected = json.load(source)

actual: dict[str, dict[str, dict[str, int | str]]] = {}
with csv_path.open(newline="", encoding="utf-8") as converted:
    for row in csv.DictReader(converted):
        actual.setdefault(row["manufacturer"], {})[row["model"]] = {
            "max_seats": int(row["max_seats"]),
            "max_weight": int(row["max_weight"]),
            "max_distance": int(row["max_distance"]),
            "engine_type": row["engine_type"],
        }

if actual != expected:
    raise SystemExit("conversion differs from source JSON")

attribute_count = sum(len(attributes) for models in actual.values() for attributes in models.values())
print(f"fidelity exact: {len(actual)} manufacturers, {sum(map(len, actual.values()))} models, {attribute_count} attributes")
