# DAGs are baked into a versioned, immutable image. CI tags every deployment
# with the Git commit SHA so rollback is a Helm image-tag change.
FROM apache/airflow:3.0.6

USER root
RUN apt-get update && apt-get install -y --no-install-recommends curl && rm -rf /var/lib/apt/lists/*

USER airflow
COPY --chown=airflow:0 requirements/requirements.txt /requirements.txt
RUN if [ -s /requirements.txt ]; then pip install --no-cache-dir -r /requirements.txt; fi
COPY --chown=airflow:0 dags/ /opt/airflow/dags/
