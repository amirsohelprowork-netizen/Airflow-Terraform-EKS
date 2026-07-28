from datetime import datetime, timedelta
import json

# Airflow 3 SDK imports
try:
    from airflow.sdk import dag, task, chain
    from airflow.providers.standard.operators.empty import EmptyOperator
    from airflow.providers.standard.operators.bash import BashOperator
    from airflow.providers.standard.operators.python import PythonOperator
except ImportError:
    # Fallback compatibility for standard/transitional Airflow 3 installs
    from airflow.decorators import dag, task
    from airflow.operators.empty import EmptyOperator
    from airflow.operators.bash import BashOperator
    from airflow.operators.python import PythonOperator
    from airflow.models.baseoperator import chain


def _legacy_python_callable(ti=None):
    """Callable used for the traditional PythonOperator task."""
    run_id = ti.run_id if ti else "manual_execution"
    print(f"Task 06: PythonOperator executed successfully for run: {run_id}")
    return {"status": "processed", "task_num": 6}


@dag(
    dag_id="airflow3_20_sequential_tasks",
    schedule=None,
    start_date=datetime(2026, 1, 1),
    catchup=False,
    tags=["airflow3", "demo", "sequential"],
    default_args={"owner": "airflow", "retries": 1},
)
def twenty_tasks_pipeline():

    # -------------------------------------------------------------------------
    # TASK DEFINITIONS (20 Distinct Task Types / Decorators)
    # -------------------------------------------------------------------------

    # 1. Standard Python TaskFlow
    @task
    def t01_init_pipeline():
        print("Task 01: Initializing execution state...")
        return {"pipeline_id": "PL-2026-X3", "step": 1}

    # 2. TaskFlow Bash Decorator
    @task.bash
    def t02_check_system():
        return "echo 'Task 02: Python version: $(python --version)'"

    # 3. Empty Operator (Milestone Checkpoint)
    t03_checkpoint_start = EmptyOperator(task_id="t03_checkpoint_start")

    # 4. TaskFlow Short Circuit
    @task.short_circuit
    def t04_verify_prerequisites():
        print("Task 04: Validating system conditions...")
        return True  # Allows execution to continue downstream

    # 5. Classic BashOperator
    t05_classic_bash = BashOperator(
        task_id="t05_classic_bash",
        bash_command="echo 'Task 05: Executed via classic BashOperator'",
    )

    # 6. Classic PythonOperator
    t06_classic_python = PythonOperator(
        task_id="t06_classic_python",
        python_callable=_legacy_python_callable,
    )

    # 7. TaskFlow with Multiple Outputs (Dictionary Expansion into XCom)
    @task(multiple_outputs=True)
    def t07_generate_metadata():
        print("Task 07: Generating task metadata...")
        return {"environment": "production", "batch_size": 500, "region": "us-east-1"}

    # 8. TaskFlow Branching
    @task.branch
    def t08_evaluate_branch():
        print("Task 08: Evaluating dynamic flow path...")
        return "t09_branch_primary"

    # 9. Target Task for Branch
    @task
    def t09_branch_primary():
        print("Task 09: Primary execution branch selected.")
        return "primary_path_complete"

    # 10. Empty Operator (Re-convergence point)
    t10_reconverge = EmptyOperator(task_id="t10_reconverge")

    # 11. JSON Data Processing
    @task
    def t11_process_json(meta_env: str):
        payload = {"source_env": meta_env, "status": "transformed"}
        print(f"Task 11: Encoded payload: {json.dumps(payload)}")
        return payload

    # 12. Directory / File System Check via Bash
    @task.bash
    def t12_fs_audit():
        return "echo 'Task 12: Directory contents count:' $(ls -1 | wc -l)"

    # 13. TaskFlow Custom Sensor
    @task.sensor(poke_interval=2, timeout=10)
    def t13_simulate_sensor():
        print("Task 13: Polling for simulated condition...")
        return True

    # 14. Task with Explicit Retries Configuration
    @task(retries=2, retry_delay=timedelta(seconds=2))
    def t14_resilient_calc():
        print("Task 14: Executing calculation with custom retry policy...")
        return 42 * 100

    # 15. Numerical Data Aggregation
    @task
    def t15_aggregate_metrics(calc_result: int):
        final_val = calc_result + 800
        print(f"Task 15: Computed aggregate value: {final_val}")
        return final_val

    # 16. Bash Timestamp Logging
    t16_timestamp_log = BashOperator(
        task_id="t16_timestamp_log",
        bash_command="echo 'Task 16: Current UTC timestamp:' $(date -u +%Y-%m-%dT%H:%M:%SZ)",
    )

    # 17. Output Data Validation
    @task
    def t17_validate_output(val: int):
        assert val > 0, "Validation failed: value must be positive"
        print(f"Task 17: Validated output value: {val}")
        return "VALIDATED"

    # 18. Cleanup Preparation
    @task
    def t18_prepare_cleanup(status: str):
        print(f"Task 18: Staging system cleanup following state: {status}")
        return "/tmp/airflow_stage_cache"

    # 19. System Cleanup via TaskFlow Bash
    @task.bash
    def t19_execute_cleanup(cache_dir: str):
        return f"echo 'Task 19: Purged cache directory at {cache_dir}'"

    # 20. Empty Operator (Pipeline Completion)
    t20_complete = EmptyOperator(task_id="t20_complete")

    # -------------------------------------------------------------------------
    # TASK INSTANTIATIONS & DEPENDENCY CHAINING
    # -------------------------------------------------------------------------

    # 1-3
    res_t01 = t01_init_pipeline()
    res_t02 = t02_check_system()
    
    # 4-9
    res_t04 = t04_verify_prerequisites()
    res_t07 = t07_generate_metadata()
    res_t08 = t08_evaluate_branch()
    res_t09 = t09_branch_primary()

    # 11-15
    res_t11 = t11_process_json(res_t07["environment"])
    res_t12 = t12_fs_audit()
    res_t13 = t13_simulate_sensor()
    res_t14 = t14_resilient_calc()
    res_t15 = t15_aggregate_metrics(res_t14)

    # 17-19
    res_t17 = t17_validate_output(res_t15)
    res_t18 = t18_prepare_cleanup(res_t17)
    res_t19 = t19_execute_cleanup(res_t18)

    # Strict 1-to-20 Sequential Chain
    chain(
        res_t01,
        res_t02,
        t03_checkpoint_start,
        res_t04,
        t05_classic_bash,
        t06_classic_python,
        res_t07,
        res_t08,
        res_t09,
        t10_reconverge,
        res_t11,
        res_t12,
        res_t13,
        res_t14,
        res_t15,
        t16_timestamp_log,
        res_t17,
        res_t18,
        res_t19,
        t20_complete,
    )


# Instantiate the DAG
twenty_tasks_pipeline()
