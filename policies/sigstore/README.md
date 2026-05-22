# Sigstore Policy Controller

This directory contains the cluster-side image signature policy for the AWS primary site.

The policy verifies the voting app images in Amazon ECR using Sigstore keyless signatures issued by GitHub Actions through Fulcio.

## Policy

- `clusterimagepolicy-ecr-keyless.yaml`

It matches only the three application repositories:

- `voting-app-vote`
- `voting-app-result`
- `voting-app-worker`

The policy intentionally does not match `redis` or `postgres` demo images because those are public upstream images used only by the local chart fallback. Managed AWS RDS and ElastiCache are used for the primary production-like deployment.

## Enforcement

Policy Controller validates namespaces that opt in with:

```text
policy.sigstore.dev/include=true
```

Use the helper script:

```powershell
.\scripts\apply-sigstore-policy.ps1 -Apply
```

The script:

1. Applies the `ClusterImagePolicy`.
2. Labels the `voting` namespace for policy-controller enforcement.
3. Runs a server-side dry-run deployment using the currently promoted signed image.
4. Removes the namespace label automatically if the admission smoke test fails.

## Demo Notes

- Signed images are produced by the CI pipeline using Cosign keyless signing.
- Unsigned images under the protected ECR repositories should be denied after namespace opt-in.
- The default response to runtime alerts remains alert-first; this policy is admission-time supply-chain enforcement, not runtime quarantine.
