#!/usr/bin/env bash
# Regression harness for the auth0-custom-domains skill.
#
# Runs each regression prompt through `claude -p` in a fresh session, captures
# the response to tests/logs/<slug>.log, and prints a summary you can eyeball.
#
# This is a routing test, not an end-to-end test. The prompts will usually
# stop at the first real-action step because no live credentials / tenants
# are wired in; what we're checking is that Claude picks the right capability
# and walks the correct flow. For true E2E, run the prompts interactively
# against a real tenant and real DNS zone (see README.md in this directory).

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/tests/logs"
mkdir -p "$LOG_DIR"

# Name => expected capability marker (rough string match in the response)
declare -a PROMPTS=(
  "cap5-health|Check the health of my Auth0 custom domains.|Check domain health"
  "cap1-setup-cloudflare|Set up login.example.com as a custom domain on my Auth0 tenant. My DNS is at Cloudflare.|Set up a custom domain"
  "cap2-troubleshoot|My custom domain login.acme.com has been stuck in pending_verification for over an hour.|Troubleshoot verification"
  "cap3-manage-multi|I have three custom domains on this tenant. Make login-eu.example.com the default, and set the relying party identifier on login.example.com to example.com.|Manage existing domains"
  "cap3-metadata|Tag login.example.com with region=us-east and brand=acme so Actions can read it.|domain_metadata"
  "cap4-remove-route53|Remove login-legacy.example.com from my Auth0 tenant. DNS is at Route 53.|Remove a custom domain"
  "ambiguous|Something's wrong with my Auth0 custom domain, can you look at it?|Check domain health"
)

pass=0
fail=0
declare -a failures=()

printf '%-30s %-10s %s\n' "PROMPT" "RESULT" "LOG"
printf '%s\n' "------------------------------ ---------- ----------------------------------------"

for entry in "${PROMPTS[@]}"; do
  IFS='|' read -r slug prompt marker <<< "$entry"
  log="$LOG_DIR/$slug.log"

  # Run in non-interactive mode, fresh session, no streaming.
  claude -p "$prompt" > "$log" 2>&1 || true

  if grep -qiF "$marker" "$log"; then
    printf '%-30s %-10s %s\n' "$slug" "PASS" "$log"
    pass=$((pass + 1))
  else
    printf '%-30s %-10s %s\n' "$slug" "REVIEW" "$log"
    failures+=("$slug (expected: $marker)")
    fail=$((fail + 1))
  fi
done

echo
echo "Summary: $pass passed, $fail need review."
if [ $fail -gt 0 ]; then
  echo
  echo "Needs review:"
  for f in "${failures[@]}"; do
    echo "  - $f"
  done
  echo
  echo "Open the logs above; a REVIEW doesn't always mean the skill misrouted."
  echo "Claude may have chosen different phrasing. Read the log to decide."
fi
