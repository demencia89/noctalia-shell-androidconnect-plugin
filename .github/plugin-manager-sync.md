# Plugin Manager Sync

This repository includes a GitHub Actions workflow at `.github/workflows/sync-plugin-manager.yml`.

When you publish a GitHub release, it syncs this repository into:

- repository: `demencia89/noctalia-plugins`
- branch: `add-androidconnect-plugin`
- path: `androidconnect/`

That branch is intended to stay aligned with the plugin-manager submission, so pushes to it update the existing pull request automatically if one is already open.

Required repository secret:

- `NOCTALIA_PLUGINS_SYNC_TOKEN`

Recommended token shape:

- Fine-grained personal access token
- Repository access limited to `demencia89/noctalia-plugins`
- Repository permissions:
  - `Contents: Read and write`

The workflow runs on published releases and can also be triggered manually with `workflow_dispatch`.
