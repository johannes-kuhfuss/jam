# Lab GitOps Entry Point

Flux reconciles this directory into the lab cluster after `scripts/dev/bootstrap-gitops.sh` installs the controller.

Keep this path cluster-specific. Shared platform and application resources should be referenced from this directory through Kustomize resources.
