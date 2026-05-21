# DNS / Endpoint Failover Runbook

## Goal

Switch demo traffic from AWS primary to Azure warm standby after the Azure app is healthy.

## Recommended Student Demo Path

For a low-cost demo, use endpoint switching:

1. Verify AWS vote/result endpoints.
2. Run `scripts/dr-failover.ps1`.
3. Verify Azure vote/result endpoints by port-forward or ingress.
4. Present the Azure endpoint as the active endpoint.
5. Record the timestamp when users can vote on Azure.

This satisfies the DR flow without keeping extra DNS services alive during every development cycle.

## Production-Like DNS Path

When Route53 is enabled:

1. Primary record points to AWS ALB ingress.
2. Secondary record points to Azure ingress.
3. Health check monitors AWS `/healthz`.
4. Failover policy sends traffic to Azure when AWS is unhealthy.

Evidence to capture:

- Route53 health check status.
- DNS answer before failover.
- DNS answer after failover.
- First successful vote on Azure.

## Manual DNS Switch

If using a manually managed DNS record:

1. Lower TTL before the demo.
2. Confirm Azure app is healthy.
3. Update `vote` and `result` records to Azure ingress.
4. Wait for TTL.
5. Test from a fresh shell:

```powershell
nslookup vote.example.com
curl -I https://vote.example.com/healthz
```

## Rollback

1. Confirm AWS is healthy.
2. Sync AWS ArgoCD application.
3. Point DNS back to AWS.
4. Scale Azure standby back down.
