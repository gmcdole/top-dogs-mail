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
