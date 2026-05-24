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

## Automated DNS Failover via Script (Production Path)

Use scripts/configure-route53-failover.ps1 to configure Route53 active-passive failover automatically:

```powershell
.\scripts\configure-route53-failover.ps1 `
  -HostedZoneId "Z1234567890ABC" `
  -RecordName "vote.yourdomain.com" `
  -FailureSnsTopicArn "arn:aws:sns:us-east-1:800557027783:devsecops-alerts"
```

The script:
1. Auto-discovers AWS primary LoadBalancer hostname from kubectl get svc.
2. Auto-discovers Azure standby LoadBalancer IP (or pass -SecondaryEndpoint for private/internal LBs).
3. Creates a Route53 Health Check polling /healthz every 10 seconds.
4. Upserts PRIMARY (AWS) and SECONDARY (Azure) CNAME failover records.
5. Optionally wires a CloudWatch alarm to SNS for automated compute failover trigger.

Once configured, DNS failover is **fully automatic** — no manual intervention needed when AWS becomes unhealthy.
