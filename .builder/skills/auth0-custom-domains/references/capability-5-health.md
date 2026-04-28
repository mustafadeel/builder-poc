# Check Domain Health

Read-only diagnosis of the tenant's custom domain configuration. No writes. Answers: "is my setup still working?" and "what would block me from doing X?"

This is the safe starter capability. Run it before other capabilities when the user isn't sure what's wrong or just wants a status check.

## Pre-flight: surface the active tenant

Even though this capability is read-only, the data the user sees depends entirely on which tenant the Auth0 CLI is pointed at. Show it explicitly so the report header is unambiguous.

```bash
auth0 tenants list
```

Surface the active tenant to the user and confirm it's the one they want checked. If it's wrong, have them run `auth0 tenants use <tenant-name>`, then proceed. Include the tenant name in the final health report so the output is self-describing.

## Checks (run in parallel)

### 1. List custom domains on the tenant

```bash
auth0 api get "custom-domains"
```

Pull for each: `domain`, `custom_domain_id`, `status`, `type`, `primary`.

### 2. Fetch the tenant default

```bash
auth0 api get "tenants/settings"
```

Read `default_custom_domain_id`. Cross-reference against the domain list from check 1.

### 3. For each domain, compare DNS to expected

For each domain in the list, dig the CNAME and compare to the expected verification record. The expected value is in `verification.methods[0].record` on each domain object.

```bash
dig +short CNAME login.example.com
```

For self-managed domains, the expected record is a TXT, not a CNAME:

```bash
dig +short TXT login.example.com
```

### 4. Check NS resolution from an external resolver

Cross-check the user's local resolver against a public resolver to catch propagation lag:

```bash
dig +short @8.8.8.8 CNAME login.example.com
```

Mismatch between local and external means propagation is in progress; the domain may show `ready` in Auth0 but some clients won't yet see the right record.

### 5. Credit-card-on-file probe (Free tier only)

If the tenant has zero custom domains and the user wants to know whether adding one will work, attempt a create and inspect the error response:

Actually, don't probe speculatively. Instead, check the tenant plan if surfaced in the API response or mention the CC requirement proactively:

```
Note: Free-tier tenants need a credit card on file at
Dashboard → Tenant Settings → Billing to create custom domains. The card is
not charged. If custom domain creation returns 403, this is usually the cause.
```

## Output format

Structured checklist with pass/fail/warn per item. Lean on visual contrast (✓, ✗, ⚠) and keep the output scannable:

```
Tenant: acme-prod

Custom domains (3):

  login.example.com                 ✓ ready
    DNS match                       ✓ CNAME → tenant.edge.tenants.auth0.com
    Certificate type                Auth0-managed
    Default for tenant              ✓ YES

  login-eu.example.com              ✓ ready
    DNS match                       ✓ CNAME → tenant.edge.tenants.auth0.com
    Certificate type                Auth0-managed
    Default for tenant              no

  login-legacy.example.com          ⚠ pending_verification
    DNS match                       ✗ no CNAME found at login-legacy.example.com
    Certificate type                Self-managed
    Default for tenant              no

Tenant settings:
  Default custom domain             ✓ login.example.com

Summary:
  • 2 of 3 domains healthy
  • login-legacy.example.com needs attention → run the Troubleshoot verification flow
```

## Interpreting results

- **Domain `ready` + DNS match ✓**: healthy. Certificate will renew automatically on Auth0-managed.
- **Domain `ready` + DNS match ✗**: the record has been removed or modified after initial verification. Auth0 will start failing certificate renewal in the next cycle (~3 months). Route to the Troubleshoot verification flow to restore the record.
- **Domain `pending_verification` + DNS match ✓**: the record is correct but Auth0 hasn't finished verifying yet, or verification was never triggered. If it's been more than a few minutes, route to the Troubleshoot verification flow.
- **Domain `pending_verification` + DNS match ✗**: the record is missing. Route to the Set up a custom domain flow (from the "write the record" step) to put it back, then verify.
- **Domain `disabled`**: rare and indicates an internal state mismatch. Usually requires support.

## When to recommend other capabilities

Use the health check output to point the user to the next capability:

- DNS mismatch or verification failure → the Troubleshoot verification flow
- No default set and multiple domains → suggest the Manage existing domains flow
- Domains in `pending_verification` past normal window → the Troubleshoot verification flow
- User wants to add another domain or wants to clean up an unused one → the Set up a custom domain flow or the Remove a custom domain flow
