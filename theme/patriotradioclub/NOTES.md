# Making this the shipped default theme — status: planned, not yet proven

**Verified (2026-08-23), not guessed:**
- Thunderbird's `theme.colors` WebExtension API and the exact property names used in `patriotradioclub/manifest.json` are current per the official Thunderbird WebExtension API docs (`theme.html`) and the `thunderbird/developer-docs` theme guide.
- Thunderbird ships with `xpinstall.signatures.required` set to `false` by default (confirmed via Mozilla Bugzilla #1549562) — unlike Firefox, an unsigned, self-built `.xpi` will install without fighting signature verification.
- Thunderbird supports the same enterprise `policies.json` mechanism as Firefox (`Extensions` / `ExtensionSettings`, with a `force_installed` install mode) — confirmed via `thunderbird.github.io/policy-templates`. This is the officially documented way to pre-install and lock an extension without any source-level build changes.

**Not yet verified — this is the actual next step, not a solved problem:**
Two candidate mechanisms for getting this theme active out of the box in a fresh Top Dogs Mail install, neither tested yet against a real build:

1. **`distribution/policies.json` baked into the packaged build**, using `ExtensionSettings` to force-install this theme's `.xpi` and (separately) set it active. This is the "proper," documented mechanism and should be preferred if it proves to work cleanly in our packaging step.
2. **Fallback: the account-setup/install script drops the `.xpi` directly into the new profile's `extensions/` folder** (named by the theme's `browser_specific_settings.gecko.id`, i.e. `patriotradioclub-theme@topdogs.dev.xpi`) and sets `extensions.activeThemeID` in that profile's `prefs.js`. This reuses the same install-script mechanism already planned for account setup (see `Top-Dogs-Mail-Project-Reference.md`, "Script credential handling"), so it doesn't require solving the packaging-level policy question first — useful as a proof-of-concept path if option 1 turns out to need more packaging work than expected.

The default pref `extensions.activeThemeID` has been added to `branding/mozilla-branding/patriotradioclub/pref/thunderbird-branding.js` as a low-risk, config-only addition consistent with that file's existing pattern — but note that pref alone does nothing until the theme is actually installed into the profile by one of the two mechanisms above. Whichever path is used should be decided and tested once there's an actual packaged build to test it against (Windows CI build + packaging work, tracked in the main project reference doc).
