# ===== Stage 1: Build dependencies =====
FROM python:3.14-slim AS build
WORKDIR /install
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install/deps -r requirements.txt

# ===== Stage 2: Production image (Hardened Slim) =====
FROM python:3.14-slim
RUN apt-get update && apt-get upgrade -y && \
    rm -rf /var/lib/apt/lists/* && \
    # Remove package managers & shells to reduce attack surface
    rm -rf /usr/local/lib/python3.11/ensurepip && \
    rm -f /usr/local/bin/pip* && \
    adduser --disabled-password --no-create-home --uid 10001 appuser
WORKDIR /app
COPY --from=build /install/deps /usr/local
COPY . .
USER 10001
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --start-period=20s --retries=3 CMD ["python", "-c", "import sys, urllib.request; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8080/healthz', timeout=2).status == 200 else 1)"]
CMD ["gunicorn", "app:app", "-b", "0.0.0.0:8080", "--log-file", "-", "--access-logfile", "-", "--workers", "4", "--keep-alive", "0"]
