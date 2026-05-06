# ===== Stage 1: Build =====
FROM node:20-slim AS build
WORKDIR /app
COPY package*.json ./
RUN npm install --only=production && \
    npm cache clean --force

# ===== Stage 2: Production image =====
FROM gcr.io/distroless/nodejs20-debian12
WORKDIR /app
COPY --from=build /app/node_modules ./node_modules
COPY server.js .
COPY views ./views
EXPOSE 80
CMD ["server.js"]
