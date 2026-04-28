# Set Up a Custom Domain

End-to-end provisioning: create the domain in Auth0, write the CNAME into the user's DNS provider, verify ownership, and report what to update in their apps. Handles both the first custom domain on a tenant and adding another one to a tenant with MCD already enabled.

## Gather inputs

Ask for or confirm:

- **Custom domain value** (e.g., `login.example.com`).
- **Certificate type**. Default to `auth0_managed_certificates`. Only choose `self_managed_certs` if the user explicitly asks for self-managed (Enterprise only). **Pick carefully: `type` is fixed at create time and the API rejects changes to it via PATCH.** Changing cert type later requires delete + recreate.
- **Passkey / RPID plan**. If the user plans to use passkeys, confirm what `rpId` they want bound. Two paths:
  - Root-domain custom domain (`example.com`): passkeys bind to the root automatically.
  - Subdomain custom domain (`login.example.com`): set `relying_party_identifier: "example.com"` so passkeys bind to the eTLD+1 and remain usable across subdomains and native apps. This field is also PATCHable later.
- **Reverse proxy (if any)**. If the tenant sits behind Cloudflare, CloudFront, Azure Front Door, or another proxy that forwards real client IP in a non-standard header, plan to set `custom_client_ip_header` so rate limiting, anomaly detection, and logs see the real IP. Valid values: `true-client-ip`, `cf-connecting-ip`, `x-forwarded-for`, `x-azure-clientip`.
- **TLS policy**. Default is `recommended`. Only override if there's a specific compliance reason.
- **Tenant context**. **Required pre-flight: confirm the active tenant before the create call.** Run `auth0 tenants list`, surface the active tenant to the user, and get explicit confirmation. If it's wrong, stop and have the user run `auth0 tenants use <name>`, then re-confirm. Creating in the wrong tenant is annoying to undo.

## Create the domain in Auth0

Minimal create (Auth0-managed certs, defaults everywhere):

```bash
auth0 api post "custom-domains" --data '{
  "domain": "login.example.com",
  "type": "auth0_managed_certificates"
}'
```

Full-featured create with optional fields (omit any that don't apply):

```bash
auth0 api post "custom-domains" --data '{
  "domain": "login.example.com",
  "type": "auth0_managed_certificates",
  "verification_method": "txt",
  "tls_policy": "recommended",
  "custom_client_ip_header": "cf-connecting-ip",
  "relying_party_identifier": "example.com",
  "domain_metadata": {
    "region": "us-east",
    "brand": "acme"
  }
}'
```

Notes on the optional fields:
- `verification_method`: default is derived from `type` (CNAME for Auth0-managed, TXT for self-managed). Only set it if explicitly overriding.
- `tls_policy`: default `recommended`; no reason to set unless compliance requires.
- `custom_client_ip_header`: one of `true-client-ip`, `cf-connecting-ip`, `x-forwarded-for`, `x-azure-clientip`. Match the header the proxy in front of Auth0 emits.
- `relying_party_identifier`: set when the custom domain is a subdomain but passkeys should bind to the parent domain.
- `domain_metadata`: up to 10 key-value pairs (keys and values ≤ 255 chars); surfaces in Actions.

The response contains `custom_domain_id`, `status: "pending_verification"`, and `verification.methods[0].record`: the CNAME value to put in DNS. Save these.

**If the API returns 403**: the tenant is a Free tenant without a credit card on file. Direct the user to **Dashboard → Tenant Settings → Billing** (or the Teams section for Teams-managed tenants) to add a card, then retry. The card is not charged. This is the correct diagnosis on Free tier; do not suggest a plan upgrade.

**If the API returns 409**: the domain already exists on this or another tenant. `auth0 api get "custom-domains"` to list existing. If it's already on this tenant and just needs verification, skip to the verify step below with the existing `custom_domain_id`.

See [examples.md](examples.md) for curl, node-auth0, and auth0-python code patterns.

## Detect the DNS provider and route to a tier

```bash
dig +short NS example.com
```

Match the NS pattern against the table in [providers.md](providers.md#ns-pattern-to-provider-mapping) to select a tier:

- **Tier 1 Cloudflare**: full automation via Cloudflare MCP
- **Tier 2 AWS Route 53**: assisted via AWS CLI
- **Tier 3 Azure DNS**: assisted via Azure CLI
- **Tier 4 other**: guided manual record entry

The per-tier mechanics (MCP pre-flight, CLI commands, record format, fallbacks) live in [providers.md](providers.md). Follow the tier section that matches, then return here for the verify step.

## Check for an existing record at the target name

Before writing, check what's already there:

```bash
dig +short CNAME login.example.com
```

Three outcomes:
1. **No record**: proceed with the write.
2. **Record matches the expected value**: skip the write, go straight to verify.
3. **Record exists with a different value**: confirm with the user before overwriting. Show both values. On Tier 2 (Route 53) the `UPSERT` action will overwrite silently, so the confirmation has to happen in the skill, not the CLI.

## Write the CNAME record

Execute the tier-specific flow from [providers.md](providers.md). For Tiers 2 and 3, wait for the provider to report propagation complete (Route 53: `INSYNC`; Azure: proceed after ~30s) before triggering Auth0 verification. For Tier 4, wait for the user to reply "done."

## Trigger Auth0 verification

```bash
auth0 api post "custom-domains/<domainId>/verify"
```

## Poll until ready

Poll `GET /api/v2/custom-domains/<domainId>` with backoff: 5s, 10s, 20s, 30s, 60s, 60s... up to ~10 minutes total. Stop when `status` becomes `ready`.

If the polling window expires with status still `pending_verification`: route to the **Troubleshoot verification** flow rather than retrying blindly.

## Report next steps

On success, tell the user what they need to update in their applications:

```
Custom domain login.example.com is verified and ready.

Next steps (outside this skill's scope):
  • SDK config: change the `domain` / `issuerBaseURL` value to login.example.com
    in every application SDK
  • Application callback URLs: update any URLs that reference the old tenant
    domain
  • Passkey rpId: if using passkeys, confirm rpId matches the eTLD+1 of the
    custom domain
  • SAML / WS-Fed metadata URLs: regenerate and redistribute

Full guide: https://auth0.com/docs/customize/custom-domains/configure-features-to-use-custom-domains
```

If the tenant now has multiple custom domains for the first time, mention that they may want to set a default via the Manage existing domains flow.

## MCD: adding a domain to a tenant that already has one

The flow above is identical whether this is the tenant's first custom domain or the Nth. A few things to mention when MCD is in play:

- The new domain gets its own `custom_domain_id`, CNAME verification record, and certificate lifecycle.
- Consider setting a default custom domain after adding the second domain (the Manage existing domains flow). Without a default, notification-triggering Management API calls route through the tenant domain unless the caller sends the `auth0-custom-domain` header. See [advanced.md](advanced.md#the-auth0-custom-domain-header).
- MCD is Enterprise-only with a base of 20 domains per tenant. If the user is on a non-Enterprise plan, creating a second domain returns a 403 with a different error than the Free-tier CC case; surface the full error body so the user knows which limit they hit.

## Edge cases to handle during setup

- **Private hosted zone (Route 53)**: if `list-hosted-zones-by-name` returns a private zone, fall back to Tier 4; Auth0 verification needs a public zone.
- **Apex vs subdomain**: the CNAME always goes into the zone of the root domain, at the subdomain name. If the user asked for a custom domain at the apex (e.g., `example.com` itself), DNS doesn't permit a real CNAME at the apex; suggest a subdomain instead or use ALIAS/ANAME records where supported.
- **Shared parent zone with delegation**: if the apex is delegated to a different provider than the subdomain, check the NS records for the subdomain specifically, not just the root.
