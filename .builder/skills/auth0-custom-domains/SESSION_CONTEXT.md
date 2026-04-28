# Session Context: auth0-custom-domains skill

**Last session**: 2026-04-24 (Friday)
**Pick up on**: Monday, 2026-04-27

## What this skill does

End-to-end Auth0 custom domain work with four tiers of DNS provider automation. Designed as a capability-based skill (lobby pattern like `auth0-branding`) with 5 capabilities, not a step-based flow.

- **SKILL.md** is a lobby: capabilities table, key concepts, prerequisites, common mistakes.
- Each capability has its own reference file with the full flow.
- DNS provider mechanics (Cloudflare MCP, Route 53, Azure, Tier 4 manual) live in `references/providers.md` and are shared across the Set up, Troubleshoot, and Remove flows.

## Current structure

```
auth0-custom-domains/
  SKILL.md                          ~118 lines (lobby)
  references/
    capability-1-setup.md           ~107 lines
    capability-2-troubleshoot.md    ~130 lines
    capability-3-manage.md          ~185 lines (includes domain_metadata)
    capability-4-remove.md          ~115 lines
    capability-5-health.md          ~108 lines
    providers.md                    ~332 lines (NS patterns, per-tier mechanics, Tier 4 cheat sheet)
    examples.md                     ~149 lines (Auth0 API in curl / node-auth0 / auth0-python)
    api.md                          ~116 lines (endpoint reference, scopes, errors)
    advanced.md                     ~141 lines (MCD, cert types, iss behavior, deep troubleshooting)
    backend.md                      ~137 lines (end-to-end CI/CD script)
```

## Capabilities recap

1. **Set up** a custom domain end-to-end (Auth0 create + DNS CNAME + verify poll)
2. **Troubleshoot verification** with a diagnostic ladder
3. **Manage existing domains** (default, TLS policy, custom client IP header, relying party identifier for passkeys, list, and `domain_metadata` key-value pairs). Cert type is fixed at create; PATCH rejects `type`.
4. **Remove** a domain with DNS cleanup
5. **Check health** read-only (safe starter; routes to other capabilities based on findings)

## What's been done this session

1. Rewrote the existing stub skill as capability-based, following the `auth0-branding` lobby pattern.
2. Applied 4 size-reduction levers: moved capability flows to per-capability files, compressed providers.md's Tier 4 registrars into a cheat-sheet table, trimmed backend.md.
3. Moved skill to `.claude/skills/auth0-custom-domains/` and confirmed harness discovery.
4. Ran the feature-skill-generator validator. Current state: 36 passed, 2 warnings, 1 error. The one error ("missing Step sections") is an expected structural mismatch; the validator was written for step-based skills.
5. Ran 5 parallel sub-agent tests across all capabilities plus an ambiguous-intent prompt.
6. Fixed 10 issues surfaced by those tests (Route 53 DELETE gap, Cloudflare script placeholder callout, TXT branch for self-managed in Cap 2, Enterprise plan pre-check in Cap 3, handoff specificity, lobby wording for ambiguous prompts, etc.).
7. Added Overview section to SKILL.md explaining the capability-based design.
8. Added `domain_metadata` support to the Manage existing domains flow (up to 10 key-value pairs; primary use case is feeding Actions via `event.custom_domain.domain_metadata`).

## Flagged for live verification before first real use

These are in the skill now but marked as "verify on first use" because I couldn't confirm them from the JS-rendered Auth0 Management API reference pages:

1. **`domain_metadata` PATCH merge vs replace semantics**. The skill tells Claude to use GET-merge-PATCH as the safe default. Real behavior might be key-merge (in which case the current pattern is unnecessarily cautious but not wrong).
2. **`domain_metadata` key deletion via `null` value**. Auth0's convention for user/app metadata is setting the value to `null` to remove. The skill uses this pattern but flags it for verification.

**How to verify** (15 minutes against a test tenant):
- Create a custom domain with two metadata keys.
- PATCH with just one key set. Does the other survive?
- PATCH with a value of `null`. Is the key removed?

Update the skill based on findings. If `null`-deletion works, remove the "verify on first use" note. If not, document the actual deletion mechanic.

## Known issues and things I'd watch

- **Validator error** "missing Step sections" is structural and expected for a capability-based skill. If you want it to pass clean, either teach the validator about capability skills or ignore that error.
- **SKILL.md size is 118 lines** (very under branding's ~900). There's room to add more lobby-level content if testing shows routing fails often.
- **Cap 3 at ~185 lines** is the biggest capability file. Watch for further bloat as more management operations are added; if it crosses ~220, consider splitting (e.g., `capability-3a-settings.md` for cert/default and `capability-3b-metadata.md` for metadata).

## Memory written this session

- `memory/reference_custom_domains_plan_gating.md`: custom domains are available on all plan tiers; Free tier requires a credit card on file for identity verification (not charged). A 403 on create usually means missing card, not plan upgrade needed. Surface this correctly in any future Auth0 work.

## Suggested next steps for Monday

In rough priority order:

1. **Run the two live-verification tests** above to confirm `domain_metadata` PATCH semantics. Update the skill wording accordingly.
2. **Real-world test run**. Invoke the skill against an actual test tenant for the Set up a custom domain flow (setup) and the Check domain health flow (health). The capability-level testing we did was dry-run; the real question is whether end-to-end execution works cleanly. Candidate test domain: something on a Cloudflare-hosted zone since Tier 1 has the most automation.
3. **Consider adding a Step 4: Configure features to use the custom domain** flesh-out. Currently it's brief with a link to Auth0's docs. Test feedback may reveal users consistently asking "OK it's verified, now what?" — at which point pulling SDK-update + callback-URL + passkey-rpId guidance inline is justified.
4. **Consider the Cap 3 split** if metadata ops get used heavily.
5. **Submit to the auth0/agent-skills repo** if the skill feels solid after testing. PR path is via the repo's contribution flow; branding and other skills live there.

## Test prompts that worked in this session

Use these as regression prompts:

- "Set up login.example.com as a custom domain on my Auth0 tenant. My DNS is at Cloudflare." → Cap 1
- "My custom domain login.acme.com has been stuck in pending_verification for over an hour." → Cap 2
- "I have three custom domains on this tenant. Make login-eu.example.com the default, and set the relying party identifier on login.example.com to example.com." → Cap 3 (multi-intent)
- "Tag login.example.com with region=us-east and brand=acme so Actions can read it." → Cap 3 (metadata)
- "Remove login-legacy.example.com from my Auth0 tenant. DNS is at Route 53." → Cap 4
- "Check the health of my Auth0 custom domains." → Cap 5
- "Something's wrong with my Auth0 custom domain, can you look at it?" → Cap 5 (ambiguous; lobby routes to health check as safe starter)

## Files NOT to touch without thought

- `references/providers.md` is shared by Caps 1, 2, 4. Changes to the Cloudflare script pattern or Route 53 command shape propagate everywhere. Update carefully.
- `SKILL.md` is always loaded into context. Keep additions here lean.

## Context for "why is this designed this way"

- **Capability pattern over step pattern**: Users come to this skill with distinct intents ("set up", "mine is broken", "change something", "remove", "status check"). A step-based skill (Step 1 → Step 2 → Step 3) forces a single flow on all of them. Capability pattern routes each intent to its own flow.
- **Lobby SKILL.md**: Keeps always-loaded context tight (~118 lines vs. branding's ~900). Tradeoff: users pay one extra file read when Claude loads a capability file. For distinct-intent work, the tradeoff wins.
- **providers.md as shared DNS playbook**: All DNS mechanics (Cloudflare `execute()` pattern, Route 53 UPSERT/DELETE, Azure CLI, per-registrar Tier 4) live in one file. Capabilities reference it, no duplication.
