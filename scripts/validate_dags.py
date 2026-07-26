"""
DAG Validation Script
Validates all DAG files for syntax errors and import issues.
Used in CI/CD pipeline before deploying to EKS.
"""

import importlib.util
import os
import sys


def validate_dag_file(filepath: str) -> bool:
    """Validate a single DAG file by attempting to compile and import it."""
    filename = os.path.basename(filepath)

    # Step 1: Check Python syntax
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            source = f.read()
        compile(source, filepath, "exec")
        print(f"  ✅ Syntax OK: {filename}")
    except SyntaxError as e:
        print(f"  ❌ Syntax Error in {filename}: {e}")
        return False

    # Step 2: Try to import the module
    try:
        spec = importlib.util.spec_from_file_location(
            filename.replace(".py", ""), filepath
        )
        if spec and spec.loader:
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
            print(f"  ✅ Import OK: {filename}")
    except Exception as e:
        print(f"  ⚠️  Import Warning in {filename}: {e}")
        print(f"     (This may be OK if the DAG uses runtime-only dependencies)")
        # Don't fail on import errors — some deps may only exist in MWAA
        return True

    return True


def main() -> int:
    """Validate all DAG files in the dags/ directory."""
    dags_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "dags")

    if not os.path.isdir(dags_dir):
        print(f"❌ DAGs directory not found: {dags_dir}")
        return 1

    dag_files = [
        os.path.join(dags_dir, f)
        for f in os.listdir(dags_dir)
        if f.endswith(".py") and not f.startswith("__")
    ]

    if not dag_files:
        print("⚠️  No DAG files found in dags/ directory")
        return 0

    print(f"\n🔍 Validating {len(dag_files)} DAG file(s)...\n")

    errors = 0
    for filepath in sorted(dag_files):
        if not validate_dag_file(filepath):
            errors += 1

    print(f"\n{'='*40}")
    if errors:
        print(f"❌ Validation FAILED: {errors} file(s) with errors")
        return 1
    else:
        print(f"✅ All {len(dag_files)} DAG file(s) validated successfully!")
        return 0


if __name__ == "__main__":
    sys.exit(main())
