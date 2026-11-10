# dbt в контейнере: не зависит от версии Python на компьютере студента.
FROM python:3.12-slim
# git нужен dbt для `dbt debug` и пакетов (`dbt deps`).
RUN apt-get update \
    && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir "dbt-core==1.10.13" "dbt-postgres==1.9.1"
WORKDIR /project
ENTRYPOINT ["dbt"]
