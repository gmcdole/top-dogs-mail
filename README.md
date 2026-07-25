# Top Dogs Mail

A branded, Thunderbird-based email client built and maintained by Top Dogs Development (the IT/communications arm of the International Freedom Foundation) for IFF and its subsidiary organizations.

This repository holds the branding pipeline and build configuration used to produce each organization's branded build — it is not a fork of Thunderbird's own source tree. Thunderbird (Mozilla comm-central) is fetched fresh at build time; this repo contains only the patches, configuration, and branding assets layered on top of it.

## Status

Early setup — pilot build in progress for Patriot Radio Club, the first of several IFF subsidiary organizations planned to receive a branded build.

## Structure

- `branding/` — per-organization branding packages (icons, colors, splash assets, configuration). Each subsidiary gets its own subfolder.
- `patches/` — the additive modifications applied to Thunderbird's source to enable per-build branding and any other customizations.
- `build/` — build scripts and CI configuration used to produce a branded installer from upstream Thunderbird source plus this repo's patches and branding.

## License

This project is licensed under the Mozilla Public License 2.0 (MPL-2.0), matching the license of Thunderbird itself. See `LICENSE` for the full text.

## Attribution

Built on [Mozilla Thunderbird](https://www.thunderbird.net/), © Mozilla Foundation and contributors. This project is an independent, unofficial rebrand — it is not affiliated with or endorsed by Mozilla, and does not use the Thunderbird name or logo in any distributed build.
