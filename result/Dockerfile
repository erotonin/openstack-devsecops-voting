# ===== Stage 1: Build =====
FROM node:20-slim AS build
WORKDIR /app
COPY package*.json ./
RUN npm install --only=production && \
    npm cache clean --force

# ===== Stage 2: Production image =====
# checkov:skip=CKV_DOCKER_7:Distroless nodejs20-debian12 is pinned to a major runtime track for this lab.
FROM gcr.io/distroless/nodejs20-debian12
WORKDIR /app
COPY --from=build /app/node_modules ./node_modules
COPY server.js .
COPY views ./views
USER 10001
EXPOSE 4000
HEALTHCHECK --interval=30s --timeout=3s --start-period=20s --retries=3 CMD ["/nodejs/bin/node", "-e", "fetch('http://127.0.0.1:4000/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"]
CMD ["server.js"]
