#!/usr/bin/env bash
set -euo pipefail

# Ensure we're in the Terraform directory
if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform not found in PATH" >&2
  exit 1
fi

# Simple, no-deps approach (uses -raw so no jq required)
bucket_name="$(terraform output -raw bucket_name 2>/dev/null || true)"
distribution_id="$(terraform output -raw distribution_id 2>/dev/null || true)"
distribution_domain_name="$(terraform output -raw distribution_domain_name 2>/dev/null || true)"
log_bucket_name="$(terraform output -raw log_bucket_name 2>/dev/null || true)"

echo "bucket_name=${bucket_name}"
echo "distribution_id=${distribution_id}"
echo "distribution_domain_name=${distribution_domain_name}"
echo "log_bucket_name=${log_bucket_name}"

# Optionally export for use in the current shell (call as `source ./grab_names.sh`)
export TF_BUCKET_NAME="${bucket_name}"
export TF_CF_DISTRIBUTION_ID="${distribution_id}"
export TF_CF_DOMAIN="${distribution_domain_name}"
export TF_LOG_BUCKET_NAME="${log_bucket_name}"
