#include ../../include/release-prefs.js

// app.update.url.manual: URL user can browse to manually if for some reason
// all update installation attempts fail.
// app.update.url.details: a default value for the "More information about this
// update" link supplied in the "An update is available" page of the update
// wizard.
//
// Placeholder URLs on topdogs.dev (path-based convention) -- these pages
// don't exist yet since the self-hosted update server is a later phase of
// this project. Safe as placeholders for now: nothing in the build process
// requires them to resolve, only to be present as preference values.

pref("app.update.url.manual", "https://topdogs.dev/mail/patriotradioclub/update");
pref("app.update.url.details", "https://topdogs.dev/mail/patriotradioclub/update/notes");

// Default toolbar/window theme for this org (approved 2026-08-23 — see
// theme/patriotradioclub/manifest.json for the actual theme, built from
// branding/patriot-radio-club/palette-and-assets.md).
//
// This pref alone does NOT install or activate the theme — it only tells
// Thunderbird which theme ID to use as active *if* that theme is already
// installed in the profile. Getting the theme itself installed is a
// separate, not-yet-proven step — see theme/patriotradioclub/NOTES.md for
// the two candidate mechanisms (policies.json force-install at packaging
// time, or the account-setup install script dropping the .xpi into the
// profile directly) and which is actually verified vs. still planned.
pref("extensions.activeThemeID", "patriotradioclub-theme@topdogs.dev");
