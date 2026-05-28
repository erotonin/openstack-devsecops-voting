#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -lt 2 ]]; then
  echo "Usage: $0 <image-digest-ref> <certificate-identity-regexp> [certificate-oidc-issuer]" >&2
  exit 2
fi

image_ref="$1"
identity_regexp="$2"
issuer="${3:-https://token.actions.githubusercontent.com}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

verify_json="$tmpdir/cosign-verify.json"
signatures_json="$tmpdir/cosign-signatures.json"
cert_pem="$tmpdir/signing-cert.pem"
cert_text="$tmpdir/signing-cert.txt"

cosign verify \
  --certificate-oidc-issuer "$issuer" \
  --certificate-identity-regexp "$identity_regexp" \
  --output json \
  "$image_ref" | tee "$verify_json"

jq -e 'length > 0' "$verify_json" >/dev/null

jq -r '[.[] | .cert // .Cert // .certificate // .Certificate // empty][0] // empty' "$verify_json" > "$cert_pem"

if ! grep -q "BEGIN CERTIFICATE" "$cert_pem"; then
  cosign download signature "$image_ref" > "$signatures_json"
  jq -r '[.[] | .cert // .Cert // .certificate // .Certificate // empty][0] // empty' "$signatures_json" > "$cert_pem"
fi

if ! grep -q "BEGIN CERTIFICATE" "$cert_pem"; then
  echo "Could not extract the keyless signing certificate from cosign signature metadata." >&2
  echo "The identity verification passed, but the crypto policy check requires the X.509 certificate." >&2
  exit 1
fi

openssl x509 -in "$cert_pem" -noout -text > "$cert_text"

signature_algorithm="$(awk -F': ' '/Signature Algorithm:/ {print $2; exit}' "$cert_text" | tr '[:upper:]' '[:lower:]')"
public_key_algorithm="$(awk -F': ' '/Public Key Algorithm:/ {print $2; exit}' "$cert_text" | tr '[:upper:]' '[:lower:]')"
public_key_bits="$(awk -F'[()]' '/Public-Key:/ {gsub(/[^0-9]/, "", $2); print $2; exit}' "$cert_text")"

if [[ -z "$signature_algorithm" || -z "$public_key_algorithm" ]]; then
  echo "Could not read certificate signature/public-key algorithms." >&2
  exit 1
fi

case "$signature_algorithm" in
  *md5*|*sha1*)
    echo "Rejected weak certificate signature algorithm: $signature_algorithm" >&2
    exit 1
    ;;
  *sha256*|*sha384*|*sha512*|*ed25519*)
    ;;
  *)
    echo "Rejected unapproved certificate signature algorithm: $signature_algorithm" >&2
    exit 1
    ;;
esac

case "$public_key_algorithm" in
  *id-ecpublickey*|*ed25519*)
    if [[ -n "$public_key_bits" && "$public_key_bits" -lt 256 ]]; then
      echo "Rejected weak EC/EdDSA public key size: ${public_key_bits} bits" >&2
      exit 1
    fi
    ;;
  *rsaencryption*)
    if [[ -z "$public_key_bits" || "$public_key_bits" -lt 3072 ]]; then
      echo "Rejected weak RSA public key size: ${public_key_bits:-unknown} bits" >&2
      exit 1
    fi
    ;;
  *)
    echo "Rejected unapproved public key algorithm: $public_key_algorithm" >&2
    exit 1
    ;;
esac

{
  echo "### Cosign signature crypto policy"
  echo ""
  echo "- Image: \`$image_ref\`"
  echo "- OIDC issuer: \`$issuer\`"
  echo "- Identity regexp: \`$identity_regexp\`"
  echo "- Certificate signature algorithm: \`$signature_algorithm\`"
  echo "- Certificate public key algorithm: \`$public_key_algorithm\`"
  echo "- Public key size: \`${public_key_bits:-n/a}\` bits"
  echo "- Policy result: passed"
} >> "${GITHUB_STEP_SUMMARY:-/dev/null}"

echo "Cosign signature crypto policy passed for $image_ref"
