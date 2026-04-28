---
name: auth0-custom-domains
description: Use when you want to (1) set up a custom authentication domain end-to-end (create in Auth0, write the CNAME into the user's DNS provider, verify ownership); (2) troubleshoot a domain stuck in pending_verification; (3) manage existing domains (set or change the default, update TLS policy, configure client IP header, set the relying party identifier for passkeys, manage per-domain metadata, list); (4) remove a custom domain with DNS cleanup; or (5) check domain health read-only. Detects the DNS provider (Cloudflare, AWS Route 53, Azure DNS, or other registrars) from the domain's NS records and automates record creation where possible, or guides the user through a manual step when not. Covers Multiple Custom Domains (MCD), default-domain selection, certificate type at create time (Auth0-managed vs self-managed), per-domain relying party identifier for passkeys, and the Free-tier credit-card-on-file requirement.
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
---

# Auth0 Custom Domains

Drive Auth0 custom-domain work end-to-end: Auth0 Management API, DNS provider, verification polling, and the configuration that stitches everything together. Detects the user's DNS provider (Cloudflare, Route 53, Azure DNS, or other) and automates record creation when the provider supports it.

## Overview

This skill is **capability-based**, not step-based. It groups the work a user might want to do into five distinct capabilities (setup, troubleshoot, manage, remove, health check), each with its own flow in a dedicated reference file. The main SKILL.md acts as a lobby: it holds the capabilities table, key concepts, prerequisites, and common mistakes that apply across all flows. When a user invokes the skill, pick the matching capability from the table, load its reference file, and follow that flow.

The capability design matches how users actually come to Auth0 custom domain work: "set one up," "mine is broken," "change something," "remove one," or "is my setup still working?" Each intent maps to a distinct flow with its own safety checks and hand-offs.

## Capabilities

When this skill is invoked, start by asking the user which of these they want to do. Route to **Check domain health** first when the user reports a problem without a specific known cause, or when they're unsure which capability they need; it's the safe, read-only starter that will point them to the right follow-up.

| # | Capability | What it does |
|---|---|---|
| 1 | **Set up a custom domain** | End-to-end: create the domain in Auth0, detect the DNS provider, write the CNAME record (automated on Cloudflare / Route 53 / Azure; guided on other providers), verify ownership, and report what to update in the user's apps. Handles first-time setup and adding to MCD. See [references/capability-1-setup.md](references/capability-1-setup.md) |
| 2 | **Troubleshoot verification** | Domain stuck in `pending_verification` or verification failing. Diagnostic ladder: compare DNS to expected, check for proxies / CNAME flattening / conflicting records / propagation / private-zone issues, then retry. See [references/capability-2-troubleshoot.md](references/capability-2-troubleshoot.md) |
| 3 | **Manage existing domains** | Surgical edits on already-configured domains: set or change the default (for MCD), update TLS policy, configure the custom client IP header, set the relying party identifier for passkeys, manage per-domain metadata (up to 10 key-value pairs readable from Actions), list domains and show status. Intent-driven. Certificate type is fixed at create time; PATCH rejects `type` changes. See [references/capability-3-manage.md](references/capability-3-manage.md) |
| 4 | **Remove a custom domain** | Delete a domain safely: warn if it's the default, surface dependent applications, delete in Auth0, clean up the CNAME in DNS. See [references/capability-4-remove.md](references/capability-4-remove.md) |
| 5 | **Check domain health** | Read-only: list all custom domains, check DNS records match expected values, surface default-domain config, flag anything needing attention. Safe starter capability. See [references/capability-5-health.md](references/capability-5-health.md) |

Pick a capability, then follow the flow in its reference file. The **Prerequisites** and **Key Concepts** sections below apply across all capabilities.

## Key Concepts

| Concept | Description |
|---|---|
| CNAME Record | DNS record pointing your custom domain to Auth0's edge (e.g., `{tenant}.edge.tenants.auth0.com`). Must stay in DNS permanently for certificate renewal |
| Auth0-Managed Certificate | Auth0 provisions and auto-renews TLS certs every ~3 months. Default and recommended. Type is fixed at create time and cannot be changed via PATCH |
| Self-Managed Certificate | TLS terminates at a reverse proxy (Cloudflare, CloudFront, Azure Front Door, or GCP LB). Enterprise only; verification uses TXT instead of CNAME. Type is fixed at create time and cannot be changed via PATCH; to change, delete and recreate the domain |
| NS Detection | Looking up the root domain's nameservers to identify the DNS provider and route to the correct automation tier |
| Multiple Custom Domains (MCD) | Enterprise feature; up to 20 domains per tenant for multi-brand or multi-region |
| Default Custom Domain | When MCD is configured, the domain used when a Management API call doesn't send the `auth0-custom-domain` header |
| Relying Party Identifier (RPID) | Per-domain `relying_party_identifier` that decouples the custom domain hostname from the passkey `rpId`. Set at create or via PATCH. Lets you serve auth at `login.example.com` while passkeys bind to `example.com` for cross-surface reuse |
| TLS Policy | `tls_policy` on the domain controls minimum TLS version / cipher posture for Auth0-managed certs. Default `recommended`. Set at create or via PATCH |
| Custom Client IP Header | `custom_client_ip_header` tells Auth0 which request header carries the real client IP when traffic passes through a reverse proxy. Valid values: `true-client-ip`, `cf-connecting-ip`, `x-forwarded-for`, `x-azure-clientip`. Set at create or via PATCH |
| Domain Metadata | Up to 10 custom key-value pairs attached to a custom domain (keys and values ≤ 255 chars). Read from Actions via `event.custom_domain.domain_metadata` for per-domain logic (region, brand, env tagging) |

Full schema and token / `iss` behavior live in [references/advanced.md](references/advanced.md).

## Prerequisites

These apply to any capability that writes to the tenant. **Check domain health** is read-only and can be run first to verify these.

### Auth0 Management API access

All capabilities use the Management API. Either:
- The Auth0 CLI (`auth0 ...`) authenticated to the target tenant (`auth0 tenants use <name>`), or
- A Machine-to-Machine application with the scopes in [references/api.md](references/api.md#management-api-token-scopes).

**Check the active tenant immediately before the first Auth0 CLI command in a capability, not at skill invocation.** Do not check the tenant before the user has chosen a capability. If a capability uses only non-CLI tools (e.g., DNS lookups, Cloudflare MCP, direct Management API calls via curl), skip the tenant check entirely.

When the chosen capability does use the Auth0 CLI, run this before the first CLI command:

```bash
auth0 tenants list
```

Look for the row marked as active (or check the `active` field in the JSON output). Show the active tenant to the user and ask them to confirm it is the intended target. If it's wrong, stop and have the user run:

```bash
auth0 tenants use <tenant-name>
```

Then re-confirm before proceeding. For mutating calls (create, PATCH, delete), require explicit confirmation. For read-only CLI flows, surfacing the tenant name (and naming it in the output report) is enough — still never assume the active tenant is correct based on conversational context alone.

### DNS provider access (for Set up, Troubleshoot, and Remove)

**Set up a custom domain** writes a CNAME. **Remove a custom domain** deletes one. **Troubleshoot verification** may suggest a fix that requires a DNS edit. What the skill needs depends on the provider tier:

- **Tier 1 Cloudflare**: Cloudflare MCP connected. If not, skill prompts the user to run `claude mcp add --transport http cloudflare https://mcp.cloudflare.com/mcp` and authorize in the browser.
- **Tier 2 AWS Route 53**: AWS credentials configured (env vars, shared config, or SSO session). Verified with `aws sts get-caller-identity`.
- **Tier 3 Azure DNS**: Azure CLI signed in. Verified with `az account show`.
- **Tier 4 other**: no programmatic access; user manually adds the record in their provider's dashboard.

**Plan requirements for automation**: None of the three automated tiers require a paid plan on the DNS provider side. Cloudflare DNS record CRUD via the MCP works on the Free plan (Free zones created after Sept 2024 cap at 200 DNS records per zone; Auth0's CNAME counts as one). Route 53 is pay-per-use (~$0.50/hosted zone/month + query costs, not in AWS free tier). Azure DNS is subscription-based with no tier gating; the signed-in identity needs the DNS Zone Contributor role. Full detail per tier in [references/providers.md](references/providers.md).

### Credit card on file (Free-tier tenants)

Custom domains are available on **all plan tiers including Free**. Free tenants need a credit card on file for identity verification (card is not charged). Without one, `POST /custom-domains` returns 403. Fix at **Dashboard → Tenant Settings → Billing** (or the Teams section for Teams-managed tenants).

Surface this as the likely cause on any 403 rather than suggesting a plan upgrade.

## Common Mistakes

| Mistake | Why It's Wrong | What to Do Instead |
|---|---|---|
| Assuming a 403 on create means plan upgrade needed | Free tenants can use custom domains; they just need a credit card on file for identity verification. Card is not charged | Direct the user to **Dashboard → Tenant Settings → Billing** to add a card, then retry |
| Removing the CNAME record after verification | The CNAME must stay permanently. Auth0 re-checks it during certificate renewal; removing it breaks renewal | Keep the CNAME in DNS forever. Document it as protected |
| Using a subdomain when passkeys are planned, without setting `relying_party_identifier` | Passkeys bind to the domain's `rpId`. By default `rpId` equals the custom domain hostname, so passkeys created at `login.example.com` won't reuse on `www.example.com` | Either use the root domain, or set `relying_party_identifier: "example.com"` on the custom domain (at create or via PATCH) to bind passkeys at the eTLD+1 while keeping auth traffic on the subdomain |
| Trying to change certificate type via PATCH | The API rejects `type` on PATCH. Certificate type (`auth0_managed_certificates` vs `self_managed_certs`) is fixed at create time | Plan cert type up front. To change it, delete the domain and recreate with the new `type`. Coordinate the DNS and reverse-proxy cutover carefully to avoid auth downtime |
| Enabling DNS proxy on the CNAME (Cloudflare "orange cloud") | Proxied records prevent Auth0 from verifying ownership and break the Auth0-managed certificate flow | Set the record to DNS-only. Same rule applies to other proxy providers |
| Enabling CNAME flattening on the zone | CNAME flattening rewrites the record Auth0 sees, breaking verification | Disable CNAME flattening for the custom domain record |
| Deleting and recreating the domain when verification is slow | Resets the process; can cause a service interruption for tokens already issued | Wait. If still failing after 4 hours, investigate with `dig` before touching the domain (see **Troubleshoot verification**) |
| Not updating SDK `domain` config after verification | SDKs still point at `tenant.auth0.com`. Tokens have mismatched `iss` claims | Update `domain` / `issuerBaseURL` in every application and SDK config |
| Calling Management API via tenant domain after switching to MCD | With MCD, notification-triggering endpoints need to know which custom domain to use | Send the `auth0-custom-domain: login.example.com` header, or set a default domain (see **Manage existing domains**) |

## Related Skills

- **auth0-branding**: Customize Universal Login appearance (page templates require a verified custom domain)
- **auth0-organizations**: Organization-specific branding for B2B multi-tenancy

## References

- [references/capability-1-setup.md](references/capability-1-setup.md): Set up a custom domain
- [references/capability-2-troubleshoot.md](references/capability-2-troubleshoot.md): Troubleshoot verification
- [references/capability-3-manage.md](references/capability-3-manage.md): Manage existing domains
- [references/capability-4-remove.md](references/capability-4-remove.md): Remove a custom domain
- [references/capability-5-health.md](references/capability-5-health.md): Check domain health
- [references/providers.md](references/providers.md): DNS provider detection, tier-by-tier mechanics, per-registrar cheat sheet
- [references/examples.md](references/examples.md): cURL samples plus end-to-end CI/CD automation and multi-environment patterns
- [references/api.md](references/api.md): Endpoint reference, CLI commands, error codes, scopes
- [references/advanced.md](references/advanced.md): MCD, default-domain, `auth0-custom-domain` header, self-managed certs, token `iss` behavior, verification troubleshooting deep-dive

## External Docs

- [Custom Domains Overview](https://auth0.com/docs/customize/custom-domains)
- [Auth0-Managed Certificates](https://auth0.com/docs/customize/custom-domains/auth0-managed-certificates)
- [Self-Managed Certificates](https://auth0.com/docs/customize/custom-domains/self-managed-certificates)
- [Multiple Custom Domains](https://auth0.com/docs/customize/custom-domains/multiple-custom-domains)
- [Default Custom Domain](https://auth0.com/docs/customize/custom-domains/multiple-custom-domains/default-domain)
- [Configure Features to Use Custom Domains](https://auth0.com/docs/customize/custom-domains/configure-features-to-use-custom-domains)
- [Troubleshoot Custom Domains](https://auth0.com/docs/troubleshoot/integration-extensibility-issues/troubleshoot-custom-domains)
- [Cloudflare MCP Server](https://developers.cloudflare.com/agents/model-context-protocol/mcp-servers-for-cloudflare/)
