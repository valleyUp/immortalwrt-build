# ImmortalWrt build for MangoPi M28C

This repository builds an ImmortalWrt firmware for Widora MangoPi M28C on a public GitHub-hosted runner. It stores the package seed and the QModem feed line. Each run clones the latest `master` of [immortalwrt/immortalwrt](https://github.com/immortalwrt/immortalwrt) and does not commit changes back to that tree.

## Run a build

1. Open Actions and choose **Build MangoPi M28C**.
2. Leave the upstream ref empty to build the latest `master`.
3. Turn on **Publish a GitHub Release** when the images should be kept. Artifacts are kept for 3 days either way.

A tag named `v*` also builds and publishes a release. The release notes record the ImmortalWrt commit and `feeds.buildinfo` from that run.

## Files

- `configs/mangopi-m28c.config` is the package seed from `scripts/diffconfig.sh`.
- `configs/feeds.extra` adds QModem's `main` branch. The other feeds stay on the branches shipped by upstream.
- `.github/build.sh` writes an untracked `feeds.conf`, runs `make defconfig`, and builds.

To change the package set, regenerate the seed in an ImmortalWrt tree with `./scripts/diffconfig.sh` and replace `configs/mangopi-m28c.config`.

## Signing

Without repository secrets, each clean runner generates a new apk key. To keep the key used by an already flashed device, add these Actions secrets from the existing key files:

- `APK_PRIVATE_KEY`: contents of `private-key.pem`
- `APK_PUBLIC_KEY`: contents of `public-key.pem`

Keep the line breaks from the PEM files.
