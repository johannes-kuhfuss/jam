# Networking

This document captures network, DNS, ingress, TLS, and load-balancing decisions.

## Lab Load Balancer Addressing

Cilium owns Kubernetes `LoadBalancer` Service IP allocation and L2 advertisement in the lab. kube-vip is only used for the Kubernetes API VIP.

Before bootstrapping GitOps in a new lab, choose:

- one free IP for the Kubernetes API VIP, configured as `api_virtual_ip` in `infra/opentofu/environments/lab/lab.auto.tfvars`
- one free IP or a small free range for Cilium `LoadBalancer` Services, configured in `infra/platform/cilium/l2-lab.yaml`
- one specific IP from that Cilium pool for the public Envoy Gateway, configured in `infra/gitops/platform/gateway/envoy-gateway/config/public-gateway.yaml`

The Envoy Gateway IP must be inside the Cilium `CiliumLoadBalancerIPPool`.

Example for a `192.168.200.0/24` lab network:

```yaml
# infra/platform/cilium/l2-lab.yaml
apiVersion: cilium.io/v2
kind: CiliumLoadBalancerIPPool
metadata:
  name: lab-pool
spec:
  blocks:
    - cidr: 192.168.200.240/28
```

```yaml
# infra/gitops/platform/gateway/envoy-gateway/config/public-gateway.yaml
spec:
  gatewayClassName: envoy
  addresses:
    - type: IPAddress
      value: 192.168.200.240
```

Manual DNS should point the wildcard MAM hostname at the Envoy Gateway IP:

```text
*.mam.jku.internal -> 192.168.200.240
```
