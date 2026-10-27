---
name: firefox-addon
description: Rules for crampenn's Firefox add-ons (repos whose manifest.json has browser_specific_settings.gecko). Use whenever changing a Firefox add-on — every change needs a manifest version bump — and when setting up a new add-on to auto-release through crampenn/firefox-addons.
---

# Firefox add-ons

## Version bumps

Bump `version` in `manifest.json` once per push: AMO won't sign, and Firefox won't update to, a version it has already seen.

- Compare against the pushed version (`git show @{upstream}:manifest.json`). If the local version is already higher, it's been bumped for this batch of changes; don't bump again.
- Always a minor bump, features and fixes alike: `1.8` → `1.9`, `1.9` → `1.10`. No patch versions.
- A version that still has a patch part drops it on the next bump: `1.8.2` → `1.9`.
- Changes only to dotfiles/dirs (`.github/`, `.claude/`) aren't packaged and need no bump.

A Stop hook in this plugin blocks finishing a turn when packaged files changed without a bump.

## Auto-release

Add-ons are signed as **unlisted** on AMO and published to the public repo `crampenn/firefox-addons` (local clone usually `~/Development/firefox-addons`). Pushing to `main` with a new version releases it; installed copies update themselves through `update_url`.

How it fits together:
- Each add-on repo (usually private) has a small `release.yml` that calls the reusable workflow `crampenn/firefox-addons/.github/workflows/release-addon.yml@main`.
- That workflow signs with `web-ext sign --channel unlisted`, creates release `<slug>-v<version>` in `firefox-addons` with `<slug>-<version>.xpi`, and commits `updates/<slug>.json`.
- It skips (with a warning) when `<slug>-v<version>` already exists, i.e. the version wasn't bumped.

### Setting up a new add-on

1. Pick the slug: the add-on repo's name, e.g. `lazy-girl-romance`.
2. Add `.github/workflows/release.yml` to the add-on repo:

   ```yaml
   name: Release

   on:
     push:
       branches: [main]

   jobs:
     release:
       uses: crampenn/firefox-addons/.github/workflows/release-addon.yml@main
       with:
         slug: <slug>
       secrets: inherit
   ```

3. In `manifest.json` → `browser_specific_settings.gecko`, make sure `id` is set and add:

   ```json
   "update_url": "https://raw.githubusercontent.com/crampenn/firefox-addons/main/updates/<slug>.json"
   ```

4. The user sets the repo's secrets — give them these commands (each prompts for the value; never ask for or handle the values yourself):

   ```sh
   gh secret set AMO_JWT_ISSUER --repo crampenn/<repo>
   gh secret set AMO_JWT_SECRET --repo crampenn/<repo>
   gh secret set RELEASES_TOKEN --repo crampenn/<repo>
   ```

   All add-ons share the same values: AMO API credentials from https://addons.mozilla.org/developers/addon/api/key/ and the fine-grained token (resource owner `crampenn`, Contents read/write on `firefox-addons` only), so the token itself needs no change per add-on.

5. Bump the version, then the user pushes to `main`. After the first release, they install the `.xpi` from the `firefox-addons` release on each machine once; later releases auto-update.

### Testing locally

The user tests with a temporary add-on (`about:debugging` → Load Temporary Add-on). It replaces the installed copy until it's removed or Firefox restarts; then about:addons → gear → Check for Updates pulls the latest release.
