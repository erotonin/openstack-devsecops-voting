# Gatekeeper Policies

These policies enforce the Kubernetes admission guardrails used by the project.

Apply order:

```powershell
kubectl apply -f policies/gatekeeper/templates
kubectl apply -f policies/gatekeeper/constraints
```

Scope:

- The constraints target the `voting` namespace.
- System namespaces are intentionally excluded.
- Cosign signature verification is handled separately by Sigstore policy-controller.
