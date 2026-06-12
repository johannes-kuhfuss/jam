# Application Secrets

Use one directory per application or bounded context.

Example:

```text
infra/kubernetes/secrets/lab/apps/assets/
infra/kubernetes/secrets/lab/apps/ingest/
infra/kubernetes/secrets/lab/apps/search/
```

Each committed Secret manifest in this tree should be SOPS-encrypted.
