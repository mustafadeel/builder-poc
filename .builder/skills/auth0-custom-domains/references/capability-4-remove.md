# Remove a Custom Domain

Delete a custom domain from Auth0 and clean up the CNAME record in the user's DNS. Destructive; always confirm before executing and warn about dependent systems.

## Inputs

- The domain name or `custom_domain_id` to remove.
- Tenant context.

## Pre-flight: confirm the active tenant

Delete is irreversible. Before anything else, confirm the Auth0 CLI is pointed at the intended tenant.

```bash
auth0 tenants list
```

Show the active tenant to the user and require explicit confirmation ("about to delete from `acme-prod`; confirm?"). If wrong, stop and have the user run `auth0 tenants use <tenant-name>`, then re-confirm. Deleting from the wrong tenant is not recoverable; the domain and its certificate state are gone.

## Safety checks before deleting

Run these in parallel. Report every flag that comes up; let the user confirm with full awareness.

### 1. Is this the default custom domain?

```bash
auth0 api get "tenants/settings"
```

If `default_custom_domain_id` matches the domain being deleted, warn:

```
login.example.com is the default custom domain for this tenant. Deleting it
means notification-triggering Management API calls will route through
your-tenant.auth0.com until you set a new default via the Manage existing domains flow.
```

The user can proceed anyway, but they should plan to set a new default right after.

### 2. Is this the only custom domain?

```bash
auth0 api get "custom-domains"
```

If the list has only this one domain, warn:

```
This is the only custom domain on the tenant. After deletion, all traffic will
use your-tenant.auth0.com. Apps and SDKs currently pointing at
login.example.com will start failing with iss claim mismatches.
```

### 3. Are applications referencing this domain?

This check is best-effort; there's no single Management API call that surfaces "which apps use this domain." Options:

- `auth0 api get "clients"` and scan `callbacks`, `allowed_logout_urls`, `web_origins`, `allowed_origins` for occurrences of the domain.
- Ask the user directly: "Do you know of any applications still using this domain?"

Surface any hits before deleting.

## Confirm

Show the full impact and ask for explicit yes. Include the current CNAME target value (pulled from `verification.methods[0].record`) so the user can confirm they're deleting the right record:

```text
Ready to delete login.example.com from tenant acme-prod.

Current record:
  CNAME login.example.com → tenant.edge.tenants.auth0.com

This will:
  • Remove the custom domain from Auth0 (irreversible)
  • Invalidate the Auth0-managed certificate
  • Delete the CNAME from DNS (via Route 53 / Cloudflare / etc.; see below)
  • [if default] unset the tenant's default custom domain

Flags:
  • This is the tenant's default custom domain
  • Found 3 clients with callbacks pointing at login.example.com: Web App, Mobile, Legacy

Proceed? [yes / no]
```

## Delete in Auth0

```bash
auth0 api delete "custom-domains/<domainId>"
```

Note the current CNAME target value before deletion; after deletion, the Management API no longer returns it, so if the user wants to recreate later they'd need the new value from a fresh create.

## Clean up the DNS record

**Always attempt automated cleanup first.** Detect the provider from the root domain's NS records and route by tier, same as the Set up a custom domain flow. The skill should do the cleanup for the user, not ask the user to do it manually, whenever the provider tier supports automation and the required credentials are present.

### Automated path (preferred)

- **Tier 1 Cloudflare (via MCP)**: If the Cloudflare MCP is connected, `search("dns records")` then `execute()` a script that calls `cf.dns.records.delete(record_id)` for the CNAME at the target name. No user action needed.
- **Tier 2 Route 53**: If AWS credentials are configured (`aws sts get-caller-identity` succeeds), run `aws route53 change-resource-record-sets` with action `DELETE` (requires the full record set to match). Use `list-resource-record-sets` first to get the exact current value, then poll `get-change` until `INSYNC`. No user action needed.
- **Tier 3 Azure DNS**: If the Azure CLI is signed in (`az account show` succeeds), run `az network dns record-set cname delete --resource-group my-rg --zone-name example.com --name login --yes`. No user action needed.

Full per-tier command examples live in [providers.md](providers.md).

### Manual fallback

Drop to manual guidance only when automation isn't possible — Tier 4 providers (GoDaddy, Namecheap, Hover, etc.), or Tiers 1-3 where the required credentials / MCP aren't available and the user can't authorize them right now. In that case, give clear step-by-step directions:

```text
Couldn't remove the DNS CNAME automatically ({reason: no Cloudflare MCP connection /
no AWS credentials / etc.}). Remove it manually:

1. Go to: {dashboard deep-link for the detected provider}
2. Find the CNAME record:
     Name:  login.example.com
     Value: tenant.edge.tenants.auth0.com
3. Delete it.

Reply 'done' when removed so I can confirm the DNS record is gone, or 'skip' if
you want to leave it in place (harmless but clutters your zone).
```

Use the provider cheat-sheet in [providers.md](providers.md#per-provider-cheat-sheet) for the right deep-link and UI labels. On "done", run `dig +short CNAME login.example.com` to verify the record is gone; warn the user if it still resolves (propagation can take a few minutes).

### Why automate by default

The CNAME is now orphaned: it points at an Auth0 edge hostname that no longer serves the user's domain. Leaving it in place is harmless but clutters the zone and can cause confusion later. Auto-cleanup is the right default; manual is an exception path.

## If the user is keeping the domain but switching tenants

Different flow; don't run this capability. They should:
1. Delete from the original tenant (Auth0 won't let the same domain live on two tenants).
2. Leave the DNS record in place.
3. Create the domain on the new tenant (the Set up a custom domain flow). The CNAME target value will change; they'll need to update the existing DNS record rather than add a new one.

## Post-delete reminder

After successful deletion, tell the user:

```
Deleted login.example.com from Auth0.
DNS CNAME removed via {provider}.

Next steps (outside this skill's scope):
  • Update SDK `domain` / `issuerBaseURL` config back to your-tenant.auth0.com
    in any app that was pointing at login.example.com
  • Update application callback URLs that reference the old custom domain
  • [if was default] set a new default custom domain via the Manage existing domains flow
```
