# Application Secrets

Use one directory per application or bounded context.

Example:

```text
infra/gitops/secrets/lab/apps/assets/
infra/gitops/secrets/lab/apps/ingest/
infra/gitops/secrets/lab/apps/search/
```

Each committed Secret manifest in this tree should be SOPS-encrypted.
