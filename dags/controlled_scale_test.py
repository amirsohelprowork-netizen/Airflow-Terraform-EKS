"""A bounded KubernetesExecutor scale demonstration.

Set `task_count` when manually triggering the DAG. Keep it below 500 for the
demo; this validates task-Pod scheduling without pretending to benchmark the
customer's production workload.
"""
from datetime import datetime

from airflow.sdk import dag, task


@dag(
    dag_id="controlled_kubernetes_scale_test",
    start_date=datetime(2026, 1, 1),
    schedule=None,
    catchup=False,
    max_active_runs=1,
    tags=["demo", "load-test", "kubernetesexecutor"],
)
def controlled_kubernetes_scale_test():
    @task
    def build_work_items(**context) -> list[int]:
        requested = int(context["dag_run"].conf.get("task_count", 25))
        if requested < 1 or requested > 500:
            raise ValueError("task_count must be between 1 and 500 for this controlled demo")
        return list(range(requested))

    @task
    def simulated_work(item: int) -> None:
        # Replace this bounded operation with a real, idempotent workload only
        # after production capacity testing and downstream rate-limit review.
        print(f"Executing controlled task {item}")

    simulated_work.expand(item=build_work_items())


controlled_kubernetes_scale_test()
