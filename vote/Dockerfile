# ===== Stage 1: Build dependencies =====
FROM python:3.11-slim AS build
WORKDIR /install
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install/deps -r requirements.txt

# ===== Stage 2: Production image =====
FROM gcr.io/distroless/python3-debian12
WORKDIR /app
COPY --from=build /install/deps /usr/local
COPY . .
ENV PYTHONPATH=/usr/local/lib/python3.11/site-packages
# Distroless sets python3 as the ENTRYPOINT, so we just pass the script path and args
EXPOSE 80
CMD ["/usr/local/bin/gunicorn", "app:app", "-b", "0.0.0.0:80", "--log-file", "-", "--access-logfile", "-", "--workers", "4", "--keep-alive", "0"]
