#!/usr/bin/env python3
"""Validate every contracts/*.example.json fixture against its contracts/*.json
JSON Schema (Draft 2020-12).

Usage: python3 contracts/validate.py   (requires Python >= 3.11 and `jsonschema`)

If an example file contains a JSON array, every element is validated against
the schema; otherwise the whole document is validated.
"""

import json
import sys
from pathlib import Path

if sys.version_info < (3, 11):
    sys.exit("contracts/validate.py needs Python >= 3.11 (try: python3.11 contracts/validate.py)")

try:
    import jsonschema
    from referencing import Registry, Resource
    from referencing.jsonschema import DRAFT202012
except ImportError:
    sys.exit("missing dependency: pip install jsonschema")

HERE = Path(__file__).resolve().parent


def main() -> int:
    schemas = {}
    for path in sorted(HERE.glob("*.json")):
        if path.name.endswith(".example.json"):
            continue
        schemas[path.stem] = json.loads(path.read_text(encoding="utf-8"))

    registry = Registry()
    for schema in schemas.values():
        sid = schema.get("$id")
        if sid:
            registry = registry.with_resource(
                sid, Resource.from_contents(schema, default_specification=DRAFT202012)
            )

    failures = 0
    checked = 0
    for name in sorted(schemas):
        schema = schemas[name]
        example_path = HERE / f"{name}.example.json"
        if not example_path.exists():
            print(f"FAIL {name}: missing {example_path.name}")
            failures += 1
            continue
        validator = jsonschema.validators.validator_for(schema)(schema, registry=registry)
        example = json.loads(example_path.read_text(encoding="utf-8"))
        items = example if isinstance(example, list) else [example]
        for i, item in enumerate(items):
            checked += 1
            label = f"{name}.example.json[{i}]" if isinstance(example, list) else f"{name}.example.json"
            errors = sorted(validator.iter_errors(item), key=lambda e: list(e.absolute_path))
            if errors:
                failures += 1
                for err in errors:
                    loc = "/".join(str(p) for p in err.absolute_path) or "<root>"
                    print(f"FAIL {label} at {loc}: {err.message}")
            else:
                print(f"ok   {label}")

    print(f"\n{checked - failures}/{checked} example messages valid; {len(schemas)} contracts checked.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
