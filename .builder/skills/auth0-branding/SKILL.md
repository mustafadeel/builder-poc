---
name: auth0-branding
description: Use when you want to (1) brand an Auth0 tenant's Universal Login to match a website or brand assets (colors, logo, fonts, page layout, text); (2) manually update one or more branding values (logos, colors, fonts, borders, backgrounds, text strings, or the page template) without extraction; (3) rewrite login text to match a voice and tone; (4) reset branding to Auth0 defaults; or (5) check whether a tenant is set up for branding to take effect end-to-end. Does not cover custom prompt partials (custom form fields, client-side validation, progressive profiling) or Advanced Customizations for Universal Login (ACUL); use the `auth0-prompt-partials` and `auth0-acul` skills for those.
license: Apache-2.0
metadata:
  author: Auth0 <support@auth0.com>
---

# Auth0 Branding

Style Auth0 Universal Login to match a brand. Covers the theme (colors, typography, borders, widget layout), tenant-level branding settings (logo, favicon, primary color), page templates (Liquid HTML that wraps the widget), and custom text per screen.

## Capabilities

When this skill is invoked, start by asking the user which of these they want to do:

| # | Capability | What it does |
|---|---|---|
| 1 | **Brand my tenant** | Style Universal Login end-to-end from a website I own, brand assets I have, or manual input. Colors, logo, typography, page layout, and (optionally) login text voice, applied together |
| 2 | **Change specific settings** | Update individual pieces directly: a logo, color, font, corner radius, background, button label, or the page template. No URL extraction or asset parsing needed |
| 3 | **Match my brand voice** | Rewrite Universal Login text to sound like a source I provide: my website, sample copy, or a voice descriptor. Text only; doesn't touch colors or layout |
| 4 | **Rollback to Auth0 defaults** | Pick what to clear: tenant branding settings, the theme, the page template, or custom text on specific prompts |
| 5 | **Check my setup** | Verify that login, signup, password reset, and MFA are actually running Universal Login on my tenant and not Classic. Safe read-only starter |

Pick a capability first, then follow the flow for that capability below. The **Prerequisites** section applies to all capabilities.

## Key Concepts

| Concept | Description |
|---|---|
| Theme | Visual settings (colors, fonts, borders, widget layout, backgrounds) applied to Universal Login. Auth0 currently renders only the default theme; additional themes can be created via the API but are not used by Universal Login |
| Branding Settings | Tenant-level logo, favicon, primary color, and page background color |
| Page Template | Custom HTML using Liquid syntax that wraps the login widget; requires a custom domain |
| Text Customization | Per-prompt, per-screen, per-language text overrides on Universal Login pages |
| Custom Text Variables | Customer-defined keys (prefixed `var-`) in the Custom Text API, referenced from templates and partials as camelCase |
| Custom Domain | Required for page templates; maps your domain to Auth0's login pages |
| Universal Login vs Classic | Tenants can render each flow (login/signup, password reset, MFA) in either experience. Theme, template, and no-code editor only apply to flows running Universal Login |

## Prerequisites

These apply to any capability that writes to the tenant. "Check my setup" is read-only and can be run first to verify these are in place.

### CLI Tenant Context (if using the `auth0` CLI)

The Auth0 CLI is authenticated to **one tenant at a time**. All `auth0 ...` commands run against whichever tenant the CLI is currently logged into:

```bash
auth0 tenants list       # shows all tenants; the active one is marked with →
auth0 tenants use <name> # switch active tenant; prompts for browser login if not already authenticated
```

**Before any write operation in any capability, run `auth0 tenants list`, show the active tenant to the user, and get explicit confirmation to proceed.** If it's the wrong tenant, stop. Tell the user to run `auth0 tenants use <name>` (or `auth0 login` if the target isn't in the list) themselves and re-invoke the skill. Do not try to switch tenants on the user's behalf.

For non-interactive or multi-tenant automation, skip the CLI and call the **Management API** directly with an explicit domain + bearer token per call. See `references/examples.md`.

### Universal Login Active for the Flows You Want to Brand

Themes and templates only apply to flows actually running in Universal Login. Tenants can run in hybrid mode where some flows are Classic. Branding in this skill does not affect Classic flows.

All three Classic toggles are **tenant-wide**. There is no per-client override; if a flow is set to Classic, every client in the tenant uses Classic for that flow.

- **Login and signup**: `GET /api/v2/prompts` → `universal_login_experience`. `"classic"` means every client's login and signup runs Classic; `"new"` means Universal Login.
- **Password reset**: `PATCH /api/v2/tenants/settings`; the `change_password` object (`{ enabled, html }`). When `enabled: true`, the tenant renders Classic for password reset.
- **MFA**: same endpoint; the `guardian_mfa_page` object (`{ enabled, html }`). When `enabled: true`, the tenant renders Classic for MFA.

To restore Universal Login for a flow, set the relevant toggle to false. "Check my setup" will flag any toggles in the Classic state.

If a flow is intentionally kept in Classic, "Brand my tenant" can still apply tenant-wide branding settings (logo, favicon, primary color); those show up on Classic pages too. But the theme and page template will not affect that flow.

### Custom Domain (only if working with page templates)

Page templates require a custom domain on the tenant. Branding settings, theme, and text customization do not. If the task involves page templates and no custom domain is configured, use the `auth0-custom-domains` skill to set one up.

## Capability 1: Brand my tenant

End-to-end branding. Fills four slots (primary color, logo URL, font family, page background) from a website URL via Brandfetch, from inline brand values the user supplies, or from a short ask. Shows one proposal, confirms the target tenant, and applies the theme. Layout, voice rewriting, and multi-locale handling are opt-in via `[edit]` on the review, not default.

**See `references/capability-brand.md` for the full flow, the token-extraction logic, and the Apply step.**

## Capability 2: Change specific settings

Manual branding update driven by the user's natural-language intent ("make the primary button orange", "use Inter as the font", "change the signup headline"). The skill resolves the phrase to specific fields, disambiguates when needed, stages changes in memory, then applies as a batch. No URL extraction.

**See `references/capability-manual.md` for the intent-mapping table, per-surface write mechanics, and the Apply/Guardrails sections.**

## Capability 3: Match my brand voice

Rewrite Universal Login text to match a source the user provides: a website, pasted sample copy, or a voice descriptor. The user picks which flows to rewrite via a multiselect; auto-detection is available as a "Detect for me" option. Checks enabled locales and applies merged rewrites via `PUT /prompts/{prompt}/custom-text/{lang}`. Does not touch colors, layout, or logo.

**See `references/capability-voice.md` for the source picker, category checklist, opt-in detection, locale handling, and generate-and-apply flow. See `references/screens.md` for the category → prompts → screens map.**

## Capability 4: Rollback to Auth0 defaults

Clear one or more branding surfaces and restore Auth0's defaults. Reset is per-surface, not all-or-nothing. Destructive; always confirm before writing.

### Ask what to reset

Use two sequential `AskUserQuestion` calls. Do not render a text checklist.

**Call 1 — surfaces to reset** (`multiSelect: true`):
- `question`: "Which pieces should I reset to Auth0 defaults?"
- `header`: "Reset"
- options:

| label | description |
|---|---|
| Tenant branding settings | logo, favicon, primary color, page background |
| Theme | colors, fonts, borders, widget layout, page backgrounds |
| Page template | HTML/Liquid |
| Custom text on prompts | I'll ask which prompts to clear after you confirm |

**Call 2 — backup** (single select):
- `question`: "Save a backup of the selected surfaces before resetting?"
- `header`: "Backup"
- options:

| label | description |
|---|---|
| Yes, save a backup first (Recommended) | I'll write current state to a local JSON file you can restore from manually |
| No, reset without a backup | One-way; Auth0 does not retain prior versions |

For custom text, after the user picks the surfaces, list prompts that currently have overrides and ask which to clear (or "all"). Show the locales those overrides cover so the user knows the scope.

Reset is destructive and one-way. Auth0 does not maintain prior versions of themes, templates, or custom text, so the "save to a file" option is the only way to keep a copy of current state before reset.

### Confirm

Show the concrete plan, including the target tenant (per the "CLI Tenant Context" prerequisite):

```
Target tenant: acme-prod  (active in the Auth0 CLI)

I'll reset the following:
  • Theme (current themeId abc123 → deleted; Universal Login will fall back to Auth0's defaults)
  • Custom text on prompts: login, signup-id (locales: en, fr)

Tenant branding settings, page template, and other prompts will be left alone.

Backup: I'll save the current state of the selected surfaces to:
  ~/auth0-branding-backup-<tenant>-<YYYY-MM-DD_HHMMSS>.json
(Override the path or cancel the backup?)

Proceed?
  [y] Yes
  [n] Cancel
```

If the user opted in to save-to-file, ask for a path or accept the default (`~/auth0-branding-backup-<tenant>-<timestamp>.json`). Confirm the path is writable before proceeding. If the user skipped the backup option, omit that block and surface a brief warning that this is one-way.

In production environments, require explicit confirmation before any write.

### Execute (only for surfaces the user selected)

0. **Save backup (if opted in)**: before any writes, fetch the current state of every selected surface and serialize to a single JSON file at the path the user confirmed.
   - Theme: `GET /branding/themes/default` (full theme object)
   - Page template: `GET /branding/templates/universal-login`
   - Custom text: for each selected prompt + locale, `GET /prompts/{prompt}/custom-text/{lang}`
   - Tenant branding: `GET /branding`
   - Write the combined object as pretty-printed JSON with a top-level `tenant`, `timestamp`, and `surfaces` map. Refuse to proceed with reset if the write fails.
1. **Theme**: `DELETE /api/v2/branding/themes/{themeId}`. After delete, `GET /branding/themes/default` returns 404 and Universal Login renders Auth0's built-in defaults.
2. **Page template**: `DELETE /api/v2/branding/templates/universal-login`.
3. **Custom text**: for each selected prompt + locale, `PUT /api/v2/prompts/{prompt}/custom-text/{lang}` with `{}` (empty object) to clear overrides.
4. **Tenant branding settings**: `PATCH /api/v2/branding` with nulls/defaults for only the fields reset (don't clobber anything the user didn't select).

Report what was reset, what was left alone, and (if saved) the full path to the backup file so the user can find it later.

## Capability 5: Check my setup

Read-only diagnosis. Answers "will theme changes actually show up on the flows I care about?"

### Checks (run in parallel)

All Classic toggles are tenant-wide; there is no per-client override.

1. **Universal Login enabled at tenant level**: `GET /api/v2/tenants/settings` → `flags.universal_login === true`.
2. **Login and signup experience**: `GET /api/v2/prompts` → `universal_login_experience`. `"new"` means every client gets Universal Login for login/signup; `"classic"` means every client runs Classic.
3. **Password reset and MFA Classic toggles**: from the tenant settings call, `change_password.enabled` and `guardian_mfa_page.enabled`. Flag if true (that flow is running Classic for the whole tenant).
4. **Custom domain**: `GET /api/v2/custom-domains`. Flag if empty (page templates cannot apply).
5. **Theme present**: `GET /api/v2/branding/themes/default`. Flag if 404 (no theme has been applied yet).
6. **Active flows**: `GET /api/v2/connections`. Determines which login flows actually matter.

### Output format

Structured checklist with pass/fail/warn and a summary of what the theme *will* and *won't* affect:

```
Tenant: acme-prod (environment: production)

Universal Login at tenant level              ✓
New Universal Login experience               ✓
Current default theme                        ✓ (themeId abc123...)
Custom domain                                ✓ login.acme.com

Tenant-wide flow toggles:
  ✓ Login/signup            universal_login_experience: new  → Universal
  ✓ Password reset          change_password.enabled: false   → Universal
  ✗ MFA                     guardian_mfa_page.enabled: true  → Classic

Active flows (from connections):
  ✓ Username-password database: login + signup + password reset enabled
  ✓ Google social
  — Enterprise: none

Summary:
  Theme will apply to login/signup (tenant set to new) and password reset.
  Theme will NOT apply to MFA (tenant has guardian_mfa_page.enabled: true, so MFA runs Classic for every client).
  Fix (if desired):
    PATCH /tenants/settings --data '{"guardian_mfa_page": {"enabled": false}}'
```

This capability is a safe read-only starter. Run it before "Brand my tenant" when diagnosing "why doesn't my theme show up?"

## Common Mistakes

| Mistake | What to Do Instead |
|---|---|
| Creating additional themes via `POST /branding/themes` (Universal Login only renders the default theme; POSTed themes exist but never apply) | Always update the default theme: `GET /branding/themes/default`, then PATCH by its `themeId` |
| Sending a partial PATCH on a theme (PATCH requires all top-level sections) | GET the theme, apply your changes, then PATCH with the full object |
| Theme or page template changes do not appear on login/reset/MFA (a tenant-wide toggle is forcing that flow into Classic) | Run "Check my setup". Fix the offending tenant toggle: `universal_login_experience: classic` (login/signup), `change_password.enabled: true` (reset), or `guardian_mfa_page.enabled: true` (MFA) |
| Missing `auth0:head` or `auth0:widget` in templates (both are required; the page will not render without them) | Always include both; refuse the PUT otherwise |
| Using PUT for custom text without merging (PUT replaces all text for that prompt/language) | GET current text first, merge, then PUT the full object |

For the extended list (theme field requirements, Brandfetch ToS, homepage-only extraction gaps, CSS class names, CLI tenant context), see `references/api.md`.

## Additional Resources

- `references/capability-brand.md`: "Brand my tenant" flow; extraction pipeline, source priority, Apply step
- `references/capability-manual.md`: "Change specific settings" flow; intent mapping, per-surface write mechanics, Apply/Guardrails
- `references/capability-voice.md`: "Match my brand voice" flow; source picker, category checklist (user-picks-first), opt-in detection, locale handling, generate-and-apply
- `references/screens.md`: category → prompts → screens map for "Match my brand voice" (starting point; Auth0 adds new screens over time)
- `references/api.md`: Management API endpoints, theme/branding schema, CLI commands, error codes
- `references/examples.md`: cURL code samples plus CI/CD deployment and tenant migration patterns
- `references/advanced.md`: Page template creation with Liquid syntax, template variables, text customization details

## Related Skills

- **auth0-custom-domains**: Configure custom domains (required for page templates)
- **auth0-organizations**: Organization-specific branding for B2B multi-tenancy
- **auth0-actions**: Custom logic in login flows via Auth0 Actions
- **auth0-prompt-partials** (future): Custom form fields, client-side validation, progressive profiling
- **auth0-acul** (future): Advanced Customizations for Universal Login

## References

- [Customize Universal Login](https://auth0.com/docs/customize/login-pages/universal-login)
- [Customize Themes](https://auth0.com/docs/customize/login-pages/universal-login/customize-themes)
- [Customize Page Templates](https://auth0.com/docs/customize/login-pages/universal-login/customize-templates)
- [Customize Text Elements](https://auth0.com/docs/customize/login-pages/universal-login/customize-text-elements)
- [Branding API Reference](https://auth0.com/docs/api/management/v2/branding)
- [Brandfetch Brand API](https://docs.brandfetch.com/brand-api/overview)
- [Brandfetch Logo API Guidelines](https://docs.brandfetch.com/logo-api/guidelines)
