# firefox-addons

Signed builds and update manifests for crampenn's self-distributed (unlisted) Firefox add-ons.

- `updates/<slug>.json` — Firefox update manifest; each add-on's `update_url` points at its raw file
- Releases — signed `.xpi` files, tagged `<slug>-v<version>`
- `.github/workflows/release-addon.yml` — reusable workflow that signs an add-on and publishes it here

## Adding an add-on

1. In the add-on repo, add `.github/workflows/release.yml`:

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

2. Set the `AMO_JWT_ISSUER`, `AMO_JWT_SECRET` and `RELEASES_TOKEN` secrets in the add-on repo.
3. Set `browser_specific_settings.gecko.update_url` in its `manifest.json` to
   `https://raw.githubusercontent.com/crampenn/firefox-addons/main/updates/<slug>.json`.

A release happens on push to main whenever the manifest version has no `<slug>-v<version>` release yet.
