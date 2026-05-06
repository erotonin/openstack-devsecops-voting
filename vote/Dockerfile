# ===== Stage 1: Build dependencies =====
FROM python:3.11-slim AS build
WORKDIR /install
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install/deps -r requirements.txt

# ===== Stage 2: Production image (Hardened Slim) =====
FROM python:3.11-slim
RUN apt-get update && apt-get upgrade -y && \
    rm -rf /var/lib/apt/lists/* && \
    # Remove package managers & shells to reduce attack surface
    rm -rf /usr/local/lib/python3.11/ensurepip && \
    rm -f /usr/local/bin/pip* && \
    adduser --disabled-password --no-create-home appuser
WORKDIR /app
COPY --from=build /install/deps /usr/local
COPY . .
USER appuser
EXPOSE 8080
CMD ["gunicorn", "app:app", "-b", "0.0.0.0:8080", "--log-file", "-", "--access-logfile", "-", "--workers", "4", "--keep-alive", "0"]
