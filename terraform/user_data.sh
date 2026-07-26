#!/bin/bash
set -euo pipefail

# ================================================
# Airflow EC2 Bootstrap Script
# Installs Docker, Docker Compose, and starts Airflow
# Optimized for t2.micro (1GB RAM + 4GB swap)
# ================================================

exec > /var/log/airflow-setup.log 2>&1
echo ">>> Starting Airflow setup at $(date)"

# ---------- Create Swap (critical for t2.micro) ----------
echo ">>> Creating 4GB swap file..."
dd if=/dev/zero of=/swapfile bs=1M count=4096
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile swap swap defaults 0 0' >> /etc/fstab
echo ">>> Swap enabled: $(free -h | grep Swap)"

# ---------- Install Docker ----------
echo ">>> Installing Docker..."
dnf update -y
dnf install -y docker

systemctl enable docker
systemctl start docker

# Add ec2-user to docker group
usermod -aG docker ec2-user

# ---------- Install Docker Compose ----------
echo ">>> Installing Docker Compose..."
DOCKER_COMPOSE_VERSION="v2.29.1"
curl -SL "https://github.com/docker/compose/releases/download/$${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64" \
  -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose

# ---------- Create Airflow directories ----------
echo ">>> Creating Airflow directories..."
AIRFLOW_HOME="/opt/airflow"
mkdir -p $${AIRFLOW_HOME}/{dags,logs,plugins,config}
chown -R 50000:0 $${AIRFLOW_HOME}

# ---------- Create Docker Compose file ----------
# Optimized for low-memory: uses LocalExecutor + SQLite-compatible PostgreSQL
echo ">>> Creating docker-compose.yml..."
cat > $${AIRFLOW_HOME}/docker-compose.yml << 'COMPOSE_EOF'
# ================================================
# Apache Airflow Docker Compose
# Optimized for t2.micro (low memory)
# Uses LocalExecutor for minimal footprint
# ================================================

x-airflow-common: &airflow-common
  image: apache/airflow:${airflow_image_tag}
  environment: &airflow-common-env
    AIRFLOW__CORE__EXECUTOR: LocalExecutor
    AIRFLOW__DATABASE__SQL_ALCHEMY_CONN: postgresql+psycopg2://airflow:airflow@postgres/airflow
    AIRFLOW__CORE__FERNET_KEY: ''
    AIRFLOW__CORE__DAGS_ARE_PAUSED_AT_CREATION: 'true'
    AIRFLOW__CORE__LOAD_EXAMPLES: 'false'
    AIRFLOW__CORE__DEFAULT_TIMEZONE: 'utc'
    AIRFLOW__WEBSERVER__DEFAULT_UI_TIMEZONE: 'utc'
    AIRFLOW__WEBSERVER__DAG_DEFAULT_VIEW: 'graph'
    AIRFLOW__WEBSERVER__WORKERS: '2'
    AIRFLOW__SCHEDULER__MIN_FILE_PROCESS_INTERVAL: '60'
    AIRFLOW__SCHEDULER__DAG_DIR_LIST_INTERVAL: '60'
    AIRFLOW__API__AUTH_BACKENDS: 'airflow.api.auth.backend.basic_auth,airflow.api.auth.backend.session'
    _PIP_ADDITIONAL_REQUIREMENTS: ''
  volumes:
    - ./dags:/opt/airflow/dags
    - ./logs:/opt/airflow/logs
    - ./plugins:/opt/airflow/plugins
  user: "50000:0"
  depends_on: &airflow-common-depends-on
    postgres:
      condition: service_healthy

services:
  # ---------- PostgreSQL (Metadata DB) ----------
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: airflow
      POSTGRES_PASSWORD: airflow
      POSTGRES_DB: airflow
    volumes:
      - postgres-db-volume:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "airflow"]
      interval: 10s
      retries: 5
      start_period: 5s
    restart: always
    deploy:
      resources:
        limits:
          memory: 256M

  # ---------- Airflow Init (runs once) ----------
  airflow-init:
    <<: *airflow-common
    entrypoint: /bin/bash
    command:
      - -c
      - |
        airflow db migrate
        airflow users create \
          --username ${airflow_admin_username} \
          --password ${airflow_admin_password} \
          --firstname Admin \
          --lastname User \
          --role Admin \
          --email admin@example.com || true
        echo "Airflow initialized successfully!"
    environment:
      <<: *airflow-common-env
      _AIRFLOW_DB_MIGRATE: 'true'
      _AIRFLOW_WWW_USER_CREATE: 'true'
    depends_on:
      <<: *airflow-common-depends-on
    restart: "no"

  # ---------- Airflow Webserver ----------
  airflow-webserver:
    <<: *airflow-common
    command: webserver
    ports:
      - "8080:8080"
    healthcheck:
      test: ["CMD", "curl", "--fail", "http://localhost:8080/health"]
      interval: 60s
      timeout: 10s
      retries: 5
      start_period: 60s
    restart: always
    deploy:
      resources:
        limits:
          memory: 512M

  # ---------- Airflow Scheduler ----------
  airflow-scheduler:
    <<: *airflow-common
    command: scheduler
    healthcheck:
      test: ["CMD", "airflow", "jobs", "check", "--job-type", "SchedulerJob", "--hostname", "$${HOSTNAME}"]
      interval: 60s
      timeout: 10s
      retries: 5
      start_period: 60s
    restart: always
    deploy:
      resources:
        limits:
          memory: 512M

volumes:
  postgres-db-volume:

COMPOSE_EOF

# ---------- Copy example DAG ----------
echo ">>> Copying example DAG..."
cat > $${AIRFLOW_HOME}/dags/example_dag.py << 'DAG_EOF'
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator

default_args = {
    "owner": "data-engineering",
    "depends_on_past": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}

def print_hello(**context):
    print(f"Hello from Airflow! Execution date: {context['ds']}")
    return "Hello!"

def process_data(**context):
    import platform, sys
    print(f"Python: {sys.version}")
    print(f"Platform: {platform.platform()}")
    context["ti"].xcom_push(key="status", value="success")

def completion_report(**context):
    status = context["ti"].xcom_pull(task_ids="process_data", key="status")
    print(f"Pipeline completed! Status: {status}")

with DAG(
    dag_id="example_hello_world",
    default_args=default_args,
    description="Hello World DAG to test deployment",
    schedule_interval="@daily",
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=["example", "testing"],
) as dag:
    t1 = PythonOperator(task_id="print_hello", python_callable=print_hello)
    t2 = PythonOperator(task_id="process_data", python_callable=process_data)
    t3 = PythonOperator(task_id="completion_report", python_callable=completion_report)
    t1 >> t2 >> t3
DAG_EOF

chown -R 50000:0 $${AIRFLOW_HOME}/dags/

# ---------- Start Airflow ----------
echo ">>> Starting Airflow with Docker Compose..."
cd $${AIRFLOW_HOME}
docker-compose up -d

echo ">>> Airflow setup complete at $(date)"
echo ">>> Airflow UI will be available at http://<PUBLIC_IP>:8080 in ~3-5 minutes"
echo ">>> Login: ${airflow_admin_username} / ${airflow_admin_password}"
