# Gatekeeper Policies

These policies enforce the Kubernetes admission guardrails used by the project.

## Scope & Target Namespaces
- Gatekeeper runtime admission applies to the `voting-staging` and `voting-prod` namespaces.
- System namespaces are excluded.
- Cosign signature verification is handled separately by the Sigstore policy-controller.

## Apply Order
Always apply the templates before constraints:
1. Apply ConstraintTemplates:
   ```bash
   kubectl apply -f policies/gatekeeper/templates
   ```
2. Apply Constraints:
   ```bash
   kubectl apply -f policies/gatekeeper/constraints
   ```

## Safe Rollout Strategy
1. Start with `enforcementAction: dryrun` defined on constraints.
2. Verify constraints behavior via Kubernetes server-side dryrun first.
3. Switch `enforcementAction` to `deny` only after a clean audit and successful server-side dry-run checks.
