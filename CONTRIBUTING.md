# Contributing

## Versioning

This repo uses **automatic semver tagging** via PR labels. When a PR is merged to `main`, the [auto-tag workflow](.github/workflows/auto-tag.yml) reads the label and creates the next version tag.

| Label | Effect |
|---|---|
| `semver:patch` | Bump patch (e.g. v2.1.3 -> v2.1.4) — bug fixes, docs |
| `semver:minor` | Bump minor (e.g. v2.1.3 -> v2.2.0) — new features, backward-compatible |
| `semver:major` | Bump major (e.g. v2.1.3 -> v3.0.0) — breaking changes |
| `semver:skip` | No release on merge |
| *(no label)* | No release on merge |

Apply **exactly one** `semver:*` label to your PR before merging. Multiple semver labels will cause the workflow to fail.
