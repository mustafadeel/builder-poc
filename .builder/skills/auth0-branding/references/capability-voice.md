# Capability 3: Match my brand voice

Rewrite Universal Login text to match a source's voice. Does not touch colors, layout, or logo.

## Ask for the source

```
What should the voice match?
  [a] A website URL; I'll sample the copy and classify the voice
  [b] Sample text you paste; I'll classify it
  [c] A voice descriptor you specify (e.g., "casual and direct", "formal and corporate")
```

For [a], run Stage 4 of the "Brand my tenant" pipeline (voice extraction) without the rest. See `capability-brand.md`.

## Pick which screens to rewrite

Universal Login has 80+ screens. Most tenants use under 10. Use `AskUserQuestion` with `multiSelect: true` so the user can click to select flows. Do not render a text checklist.

Call `AskUserQuestion` with:
- `question`: "Which parts of Universal Login do you want to rewrite?"
- `header`: "Flows"
- `multiSelect: true`
- options:

| label | description |
|---|---|
| Login | login, identifier-first entry, identifier challenges |
| Signup | signup, signup-id, signup-password |
| Passwordless | email code/link, SMS OTP, email OTP challenge |
| Password reset | request, reset, confirmation, and reset-time MFA challenges |
| Passkeys | enrollment screens |
| MFA | I'll ask which factors you use after you select this |
| Organizations (B2B) | org picker, org selection, invitation accept |
| Other | consent, logout, device flow, CAPTCHA, brute force, etc. |
| Detect for me | I'll make 4–5 API calls to infer active screens, then show the picker pre-filled |

Expansion rules:

- If the user picks **MFA**, show a sub-picker for factors: OTP (authenticator apps), SMS, push, email, phone, voice, WebAuthn, recovery code. Also include the MFA "landing" screens (`mfa-begin-enroll-options`, `mfa-login-options`, etc.) as a default. Only rewrite sub-screens for factors the user confirms are enabled.
- If the user picks **Other**, show the full list of long-tail screens from `references/screens.md` so they can tick specific ones.
- For each selected category, expand to the set of (prompt, screen) pairs via `references/screens.md`.

**New screens:** `references/screens.md` is a canonical starting point, not an authoritative registry. Auth0 adds screens over time. If the user mentions a screen name the skill doesn't recognize, accept it: probe `GET /api/v2/prompts/{prompt}/custom-text/{lang}` for the prompt they expect it under, or ask the user to confirm the prompt name. The skill should not refuse a rewrite because the screen isn't in the reference map. After a successful rewrite of an unknown screen, offer to add it to `screens.md` so the user doesn't have to re-enter it next time; see "Learn new screens" below.

## Help me figure it out (optional detection)

Only run if the user selected **Detect for me**. Slower (4–5 API calls) and still needs user confirmation for niche flows. The goal is to pre-fill the picker above, not to bypass it.

**What to fetch:**

1. `GET /api/v2/connections` — enabled connections and their `strategy` + `options.authentication_methods`.
2. `GET /api/v2/prompts` — tenant-wide login settings (`universal_login_experience`, `identifier_first`, `webauthn_platform_first_factor`).
3. `GET /api/v2/guardian/factors` — which MFA factors are enabled.
4. `GET /api/v2/organizations` — does the tenant use organizations.

**How to map to the categories above:**

- **Login**: always pre-check. Everyone hits login screens. For `auth0` (database) connections, check `options.authentication_methods.password.enabled`. Social strategies (`google-oauth2`, `facebook`, `apple`, etc.) and enterprise strategies (`samlp`, `oidc`, `waad`, `okta`, etc.) also land on the login screen via social/enterprise buttons. If `/prompts.identifier_first === true`, prefer the split `login-id` + `login-password` screens over the combined `login`.
- **Signup**: pre-check if `options.authentication_methods.password.signup_behavior !== "disallow"` and `options.disable_signup !== true` on at least one `auth0` connection.
- **Passwordless**: pre-check if any `email` or `sms` strategy connection is enabled, OR if an `auth0` (database) connection has passwordless entries in `options.authentication_methods`. Auth0 is rolling out passwordless on database connections, so read the `authentication_methods` object directly (don't hardcode expected field names); the skill should pick up email-OTP and SMS-OTP variants as they appear.
- **Password reset**: pre-check if `options.authentication_methods.password.enabled === true` on any database connection and password reset isn't explicitly disabled.
- **Passkeys**: pre-check if `options.authentication_methods.passkey.enabled === true` on any database connection.
- **MFA**: pre-check if `GET /guardian/factors` shows any factor with `enabled: true`. Within MFA, only pre-check the sub-factors that are actually enabled (typical: OTP, push, SMS, email; less common: phone, voice, WebAuthn roaming, recovery code). If `/prompts.webauthn_platform_first_factor === true`, the legacy WebAuthn biometrics flow is active — include those `mfa-webauthn-*` screens.
- **Organizations**: pre-check if `GET /organizations` returns any rows.
- **Other**: leave unchecked by default. Ask the user directly if they use consent, device flow, logout customization, or any other screens from the long-tail list.

Present the category picker with pre-checks applied. The user confirms or adjusts before proceeding.

## Check enabled locales before rewriting

Text is per-language. English is enabled by default; Auth0 supports ~80 languages and every key has a default translation in each. When you rewrite voice in one language, the others stay on Auth0 defaults, which can read as a voice mismatch.

1. `GET /api/v2/tenants/settings`; read `enabled_locales`.
2. If more than one locale is enabled, ask:

   > "Your tenant has English, French, and Spanish enabled. I'll generate rewrites in English first. Do you want me to also generate matching rewrites in French and Spanish?"

   Options:
   - [all] Rewrite in every enabled locale
   - [en-only] English only; leave other locales on Auth0 defaults
   - [pick] Pick which locales to rewrite

3. For non-English locales, the voice profile still applies but must be adapted in that language. If you (or the user) aren't confident in a locale, flag it. A clean default is usually better than a clumsy rewrite.

## Generate and apply

**Constraint:** `GET /api/v2/prompts/{prompt}/custom-text/{lang}` returns only keys the tenant has explicitly customized, not Auth0's defaults. Most tenants have no custom text yet, so this is the norm rather than an edge case. The skill sources English defaults from Auth0's docs page and auto-translates the voice-matched English into every other enabled locale.

### Step 1: Establish the English baseline for each (prompt, screen)

The baseline needs the full set of keys for the screen in the tenant's current form. Auth0 docs defaults plus any tenant overrides, merged, gives that. Try in order:

- **Auth0 docs page + tenant overrides** (normal path):
  1. Fetch https://auth0.com/docs/customize/login-pages/universal-login/customize-text-elements#prompt-values and extract the English defaults for the prompt from its accordion list.
  2. `GET /prompts/{prompt}/custom-text/en` to fetch any tenant overrides for the screen.
  3. Merge: docs defaults as the base, tenant overrides on top. Tenant-customized keys win; uncustomized keys keep Auth0's defaults. Don't stop at the tenant response alone — it may only cover a subset of the screen's keys (e.g., the customer customized the title but not the description or error messages), so the merged view is the full baseline.
- **User paste** (fallback): if the docs page doesn't cover the screen or the fetched copy looks clearly stale, ask the user to open the Auth0 Dashboard → **Branding → Universal Login → Customize Text**, select the relevant prompt and screen, switch to the **Raw JSON** tab for that screen's text-and-translations, and paste the exact JSON here. That's the authoritative baseline. Do not accept screenshots or text copied from the live login page; those are error-prone.
- **Skip**: if none of the above work, skip the screen and tell the user which screens were skipped.

### Step 2: Generate the English rewrite

Produce voice-matched English copy for every key in the baseline. Show side-by-side with the baseline; the user approves, edits inline, or skips. The user can also correct a baseline that looked off (by pasting current text) at any point.

### Step 3: Translate into every other selected locale

For each non-English locale the user selected:

- **Tenant override**: if `GET /prompts/{prompt}/custom-text/<locale>` returns keys for this screen, use those as the baseline and rewrite in-voice in that language.
- **Otherwise**: translate the approved English voice-matched rewrite into the locale. Preserve the voice intent from the English rewrite rather than falling back to Auth0's neutral default for that language.

Show each locale's proposed text so the user can spot-check and edit any translation that looks off. Don't require the user to paste non-English source copy; translation from the voice-matched English is the default path.

### Step 4: Apply

Before writing, show the target tenant name and the prompt/locale pairs about to be updated, and get explicit confirmation (per the "CLI Tenant Context" prerequisite in SKILL.md).

Batch by prompt: one `PUT /api/v2/prompts/{prompt}/custom-text/{lang}` per prompt-locale pair, with approved new keys merged across all screens under that prompt and any existing overrides preserved.

Never PUT without merging; PUT replaces the full object for that prompt/lang. The custom-text API is per-prompt, not per-screen, so screens under the same prompt share one PUT call.

## Learn new screens

If the run included a screen that was not in `references/screens.md` (because Auth0 shipped a new one, or the user named a screen the reference didn't cover) AND the PUT succeeded, offer to persist it so the user doesn't have to re-enter it next time:

```
I rewrote `<screen-name>` under the `<prompt-name>` prompt. It wasn't in my
reference list. Add it to screens.md so I'll remember it next time?

  [y] Yes, add it under <inferred-category>
  [c] Yes, but put it under a different category (I'll pick)
  [n] Skip; don't save
```

Infer the default category from the prompt name where possible:
- `mfa-*` → **MFA**
- `reset-password*` → **Password reset**
- `login-passwordless*`, `*-otp-challenge` → **Passwordless**
- `organizations`, `invitation` → **Organizations (B2B)**
- `passkey*` → **Passkeys**
- `login*`, `*identifier-challenge`, `*identifier-enrollment` → **Login**
- `signup*` → **Signup**
- anything else → **Other**

If the user accepts, append a new row to the matching category's table in `references/screens.md` with the `(prompt, screen)` pair. Only persist after a successful PUT so a failed or canceled rewrite doesn't pollute the reference. If multiple new screens came up in the same run, batch the confirmations into one question listing all of them.

The reference map grows with real usage this way; users only name a new screen once.
