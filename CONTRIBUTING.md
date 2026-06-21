# Contributing

Contributions should keep this repository useful as public Rabbit R1
documentation and integration scaffolding without redistributing private or
proprietary material.

## Before Opening A Pull Request

- Read `README.md`, `docs/RABOBSTER_REBUILD_GUIDE.md`, `SECURITY.md`, and
  `docs/assets/ASSET_PROVENANCE.md`.
- Do not add APKs, ROM packages, generated flash images, extracted proprietary
  blobs, private dumps, account data, signing keys, device identity files, or
  credentials.
- Keep third-party assets and brand marks out of the repo unless their
  permission and license are documented at the time they are added.
- Prefer documentation and reproducible scripts over binary artifacts.
- Run the relevant syntax or dry-run checks for any script you edit.

## Pull Request Checklist

- The change is scoped to public documentation, integration code, scripts, or
  repo-local assets that can be redistributed.
- No generated Android build output or signing material is included.
- Any new asset includes source, creator, license, and allowed-use notes.
- Any script that can mutate a host, source tree, or device has a clear warning,
  prompt, dry-run behavior, or documented reason.
