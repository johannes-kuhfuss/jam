# Cilium Bootstrap

The lab cluster is created without a Talos-managed CNI and with kube-proxy disabled. Cilium is installed once by `scripts/dev/bootstrap-cilium.sh`, then the files in this directory can be adopted by GitOps for steady-state ownership.

After Talos bootstrap, nodes may remain `NotReady` until Cilium is installed. Run the Cilium bootstrap script immediately after `scripts/dev/provision-lab.sh` completes.

The bootstrap script waits for the Cilium CRDs before applying `l2-lab.yaml`. This avoids discovery errors while the Cilium chart/operator is still registering `CiliumLoadBalancerIPPool` and `CiliumL2AnnouncementPolicy`.

`values.yaml` follows the Talos guidance for Cilium with kube-proxy replacement:

- `kubeProxyReplacement: true`
- `k8sServiceHost: localhost`
- `k8sServicePort: 7445`
- `cni.exclusive: false` so Istio CNI can chain with Cilium for ambient mesh
- Talos-compatible cgroup settings
- no `SYS_MODULE` capability

`l2-lab.yaml` enables Cilium L2 announcements for lab `LoadBalancer` Services. Adjust the IP pool and interface before using it outside the example `192.168.1.0/24` network.

The Envoy Gateway public address should be reserved from this pool through `infra/gitops/platform/gateway/envoy-gateway/config/public-gateway.yaml`. See `docs/architecture/networking.md` for the lab addressing convention.
