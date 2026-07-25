# Build pipeline — status and notes

## Current approach

GitHub Actions, public-repo runner (4 CPU / 16GB RAM), triggered manually (`workflow_dispatch`) for now while we get a build working. Will move to scheduled/automatic once proven.

Steps in `.github/workflows/build.yml`:
1. Check out this repo.
2. Free up runner disk space (strip preinstalled Android SDK/.NET/Haskell etc. that we don't need) to get from the default ~14-22GB free up to 40GB+, since Thunderbird's build needs 30-40GB.
3. Install build prerequisites (git, python3, build tools).
4. Bootstrap the actual Thunderbird source using Mozilla's `mach bootstrap` / `bootstrap.py` tooling, targeting the `comm/mail` (Thunderbird) project rather than plain Firefox.
5. Write a `mozconfig` with `ac_add_options --enable-project=comm/mail`.
6. Run `./mach build`.

## Known unknowns going in (first attempt, expect iteration)

- Exact non-interactive flags for `bootstrap.py` in a CI context aren't confirmed from docs alone — Mozilla's bootstrap tooling assumes an interactive human by default. First workflow run is a real test of this, not a guaranteed-correct first try.
- Build time is unknown for our case — official docs say a fast Linux box can do it in under 15 minutes, slower setups take hours. GitHub's free runner should be reasonably fast (4 CPU/16GB) but this hasn't been proven yet for comm-central specifically.
- Branding patch (from `patches/`) is not yet applied in this first workflow — first goal is proving we can get a plain, unbranded Thunderbird build to compile successfully via CI at all. Branding gets layered in once the base build works.

## Next steps once this first run completes (success or failure)

- If it fails: read the actual error from the Actions log and fix the specific step that broke, rather than guessing further.
- If it succeeds: this proves the pipeline mechanics work. Next is writing and applying the actual branding patch (`patches/`) plus the Patriot Radio Club branding package we already built (`branding/patriot-radio-club/`).
