# kube-vip

kube-vip is used only for the Kubernetes API VIP. Cilium owns `LoadBalancer` Services through L2 announcements.

The current OpenTofu lab environment injects kube-vip as a Talos inline manifest with `svc_enable=false`. Keep service load balancing disabled here to avoid overlapping ownership with Cilium.

The kube-vip RBAC manifest is referenced as a Talos `extraManifests` URL, so Talos nodes need outbound access to `https://kube-vip.io/manifests/rbac.yaml` during bootstrap. If the lab should be offline-capable, vendor that RBAC manifest into the repo and change the OpenTofu patch to use an inline manifest.
