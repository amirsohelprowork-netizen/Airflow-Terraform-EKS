"""
DAG Validation Script
Validates all DAG files for syntax errors and import issues.
Used in CI/CD before deploying to EKS.

Use --strict in CI (Airflow installed) so import failures fail the build.
Local runs without Airflow still fail on syntax errors and warn on imports.
"""

from __future__ import annotations

import argparse
import importlib.util
import os
import sys


def validate_dag_file(filepath: str, *, strict: bool) -> bool:
    """Validate a single DAG file by compiling and importing it."""
    filename = os.path.basename(filepath)

    try:
        with open(filepath, "r", encoding="utf-8") as f:
            source = f.read()
        compile(source, filepath, "exec")
        print(f"  OK syntax: {filename}")
    except SyntaxError as e:
        print(f"  FAIL syntax in {filename}: {e}")
        return False

    try:
        spec = importlib.util.spec_from_file_location(
            filename.replace(".py", ""), filepath
        )
        if spec and spec.loader:
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            print(f"  OK import: {filename}")
    except Exception as e:
        if strict:
            print(f"  FAIL import in {filename}: {e}")
            return False
        print(f"  WARN import in {filename}: {e}")
        print("     (non-strict mode; CI should pass --strict with Airflow installed)")
        return True

    return True


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Airflow DAG files")
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Fail on import errors (required in CI)",
    )
    args = parser.parse_args()

    dags_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "dags")

    if not os.path.isdir(dags_dir):
        print(f"FAIL: DAGs directory not found: {dags_dir}")
        return 1

    dag_files = [
        os.path.join(dags_dir, f)
        for f in os.listdir(dags_dir)
        if f.endswith(".py") and not f.startswith("__")
    ]

    if not dag_files:
        print("WARN: No DAG files found in dags/")
        return 0

    mode = "strict" if args.strict else "non-strict"
    print(f"\nValidating {len(dag_files)} DAG file(s) ({mode})...\n")

    errors = 0
    for filepath in sorted(dag_files):
        if not validate_dag_file(filepath, strict=args.strict):
            errors += 1

    print("=" * 40)
    if errors:
        print(f"FAIL: {errors} file(s) with errors")
        return 1

    print(f"OK: All {len(dag_files)} DAG file(s) validated")
    return 0


if __name__ == "__main__":
    sys.exit(main())
