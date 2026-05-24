# ===== Stage 1: Build =====
FROM --platform=$BUILDPLATFORM mcr.microsoft.com/dotnet/sdk:8.0 AS build
ARG TARGETARCH
WORKDIR /source
COPY *.csproj .
RUN dotnet restore -a $TARGETARCH
COPY . .
RUN dotnet publish -c release -o /app -a $TARGETARCH --self-contained false --no-restore

# ===== Stage 2: Production image =====
FROM mcr.microsoft.com/dotnet/runtime:8.0-jammy-chiseled
WORKDIR /app
COPY --from=build /app .
USER 10001
HEALTHCHECK --interval=30s --timeout=3s --start-period=20s --retries=3 CMD ["dotnet", "--list-runtimes"]
ENTRYPOINT ["dotnet", "Worker.dll"]
