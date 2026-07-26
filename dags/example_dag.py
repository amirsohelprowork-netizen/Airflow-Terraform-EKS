"""
Example DAG: Hello World Pipeline
Demonstrates a simple Airflow DAG for testing EKS deployment.

This DAG:
1. Prints a greeting
2. Performs a simple Python operation
3. Sends a completion message
"""

from datetime import datetime, timedelta

from airflow.sdk import DAG
from airflow.providers.standard.operators.python import PythonOperator


# ---------- Default arguments ----------
default_args = {
    "owner": "data-engineering",
    "depends_on_past": False,
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}


# ---------- Task functions ----------
def print_hello(**context):
    """First task: Print a greeting with execution context."""
    execution_date = context["ds"]
    print(f"👋 Hello from Airflow on EKS! Execution date: {execution_date}")
    print(f"DAG run ID: {context['run_id']}")
    return "Hello from Airflow!"


def process_data(**context):
    """Second task: Simulate data processing."""
    import platform
    import sys

    info = {
        "python_version": sys.version,
        "platform": platform.platform(),
        "dag_id": context["dag"].dag_id,
        "task_id": context["task"].task_id,
        "execution_date": context["ds"],
    }

    for key, value in info.items():
        print(f"  📊 {key}: {value}")

    # Push result to XCom for downstream tasks
    context["ti"].xcom_push(key="processing_status", value="success")
    return info


def completion_report(**context):
    """Third task: Generate a completion report."""
    ti = context["ti"]
    status = ti.xcom_pull(task_ids="process_data", key="processing_status")

    print(f"✅ Pipeline completed!")
    print(f"  Status: {status}")
    print(f"  Finished at: {datetime.utcnow().isoformat()}")


# ---------- DAG Definition ----------
with DAG(
    dag_id="example_hello_world",
    default_args=default_args,
    description="A simple Hello World DAG to test EKS deployment",
    schedule="@daily",
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=["example", "testing", "hello-world"],
    doc_md="""
    ## Example Hello World DAG

    This DAG is used to verify that Airflow on EKS is properly configured and
    the CI/CD pipeline is deploying DAGs correctly.

    ### Tasks
    1. **print_hello** — Prints a greeting with execution context
    2. **process_data** — Simulates data processing and logs system info
    3. **completion_report** — Generates a completion summary
    """,
) as dag:

    task_hello = PythonOperator(
        task_id="print_hello",
        python_callable=print_hello,
    )

    task_process = PythonOperator(
        task_id="process_data",
        python_callable=process_data,
    )

    task_report = PythonOperator(
        task_id="completion_report",
        python_callable=completion_report,
    )

    # Define task dependencies
    task_hello >> task_process >> task_report
