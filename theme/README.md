# Per-organization themes

Each subsidiary org gets its own subfolder here containing a standard Thunderbird WebExtension theme (a `manifest.json` using the `theme.colors` keys), built from that org's approved palette in the matching `branding/<org-slug>/` package — same config-driven pattern as the rest of this project.

This is a normal WebExtension theme, not a source patch: it doesn't touch comm-central's build system, and (unlike Firefox) Thunderbird does not require extensions to be signed by default (`xpinstall.signatures.required` is `false` out of the box), so these install without needing to go through addons.thunderbird.net.

See `patriotradioclub/manifest.json` for the reference implementation and `NOTES.md` for how a theme like this actually gets installed and made the active/default theme in a shipped build — that part is a real open item, not yet proven end-to-end.
