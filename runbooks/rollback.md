# Rollback Runbook

Production rollback should be controlled and auditable.

## Default Strategy

The baseline rollout strategy is Kubernetes rolling update with readiness probes. A bad pod should not receive traffic until it passes readiness.

## ArgoCD Rollback

1. Open ArgoCD.
2. Select the `voting` application.
3. Review application history.
4. Roll back to the previous healthy revision.
5. Confirm pods become healthy.
6. Record the incident and rollback time.

CLI option:

```powershell
argocd app history voting
argocd app rollback voting <REVISION>
argocd app wait voting --health --sync
```

## Kubernetes Rollback

If ArgoCD is unavailable during a demo:

```powershell
kubectl rollout history deployment/vote -n voting
kubectl rollout undo deployment/vote -n voting
kubectl rollout status deployment/vote -n voting
```

Repeat for `result` or `worker` if needed.

## Optional Canary

Argo Rollouts can be added as an advanced demo. It is not required for the core scope.

The core project documents canary as future maturity unless explicitly enabled.

