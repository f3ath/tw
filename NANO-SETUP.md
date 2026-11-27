# Single-node K3s setup

A small ARM64 Linux host running K3s and a persistent LAN image registry.
Commands marked **node** run over SSH on the server; **workstation** commands
run on the computer used to build and deploy images. Docker Engine is not
required on the node.

Use a stable LAN IP or DHCP reservation. Replace `NODE_IP`, `NODE_HOST`, and
`SSH_USER` below with your own values. Keep Kubernetes API access (TCP 6443)
and registry access (TCP 30500) restricted to a trusted LAN or VPN.

## 1. Check the node

**Node:**

```sh
uname -m
free -h
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS
cat /sys/fs/cgroup/cgroup.controllers
```

Expect `aarch64` and a `memory` cgroup controller. Allow RAM for both the
control plane and workloads; 4 GB or more is a practical starting point.
MicroSD works for initial use; an SSD is preferable for sustained database and
registry writes.

On Raspberry Pi OS, if `memory` is missing, back up and edit the boot command
line:

```sh
sudo cp /boot/firmware/cmdline.txt /boot/firmware/cmdline.txt.bak
sudo nano /boot/firmware/cmdline.txt
```

Append `cgroup_memory=1 cgroup_enable=memory` to the existing single line.
Older installations may use `/boot/cmdline.txt`.

For a simple setup using the kubelet's default swap policy, disable swap:

```sh
sudo swapoff -a
systemctl list-unit-files | grep -E 'swap|dphys|zram'
grep -nE '^[^#].*[[:space:]]swap[[:space:]]' /etc/fstab
```

Make this persistent by commenting out swap entries in `/etc/fstab` and
disabling whichever service provisions swap. If using dphys-swapfile:

```sh
sudo systemctl disable --now dphys-swapfile.service
```

Reboot after boot configuration changes, then verify:

```sh
sudo reboot
```

After reconnecting:

```sh
cat /sys/fs/cgroup/cgroup.controllers
swapon --show
```

The first output should include `memory`; the second should have no entries.
Swap can be enabled later with explicit kubelet configuration.

## 2. Install K3s

**Node:** replace the example variables first. Use a hostname resolvable from
the workstation; the IP is also included in the API certificate.

```sh
NODE_IP=192.168.1.100
NODE_HOST=nano.local

sudo apt update
sudo apt install -y curl ca-certificates
sudo install -d -m 755 /etc/rancher/k3s
sudo tee /etc/rancher/k3s/config.yaml >/dev/null <<EOF_CONFIG
node-name: nano
write-kubeconfig-mode: "0600"
tls-san:
  - "$NODE_HOST"
  - "$NODE_IP"
EOF_CONFIG

curl --proto '=https' --tlsv1.2 -fSL https://get.k3s.io -o "$HOME/install-k3s.sh"
less "$HOME/install-k3s.sh"
sudo env INSTALL_K3S_CHANNEL=stable sh "$HOME/install-k3s.sh"
```

The download does not execute the installer. The final command executes it as
root and installs a service that starts automatically at boot. K3s includes
containerd, networking, DNS, ingress, metrics, and local volume provisioning.

Verify:

```sh
sudo k3s kubectl wait --for=condition=Ready node/nano --timeout=180s
sudo k3s kubectl get nodes -o wide
sudo k3s kubectl get pods -A
sudo k3s kubectl get storageclass
sudo k3s kubectl top nodes
```

Installer Jobs in `Completed` state are normal. For startup failures:

```sh
sudo journalctl -u k3s -n 100 --no-pager
```

If a firewall is enabled, configure the required K3s traffic rather than
opening the host indiscriminately. Do not expose the Flannel VXLAN port
(UDP 8472) publicly.

## 3. Access from a workstation

Install kubectl and Helm on the workstation. Preserve any existing kubeconfig.
The following assumes macOS or Linux and uses a separate config file.

**Workstation:** set the connection details for your node.

```sh
SSH_USER=your-user
NODE_HOST=nano.local
mkdir -p "$HOME/.kube"
ssh -t "$SSH_USER@$NODE_HOST" 'umask 077; sudo cat /etc/rancher/k3s/k3s.yaml > "$HOME/k3s-access.yaml"'
scp "$SSH_USER@$NODE_HOST:k3s-access.yaml" "$HOME/.kube/nano.yaml"
chmod 600 "$HOME/.kube/nano.yaml"
ssh "$SSH_USER@$NODE_HOST" 'rm "$HOME/k3s-access.yaml"'
```

Edit `~/.kube/nano.yaml`:

- Replace the API server address with `https://<node-IP-or-hostname>:6443`,
  using one of the certificate names configured above.
- Rename the cluster, user, and context from `default` to `nano`, including
  the context's `cluster` and `user` references and `current-context`.
- Leave certificate and key data unchanged.

Add this line to the workstation's shell configuration and load it in your
current shell:

```sh
export KUBECONFIG="$HOME/.kube/config:$HOME/.kube/nano.yaml"
kubectl config get-contexts
kubectl --context nano get nodes
kubectl config use-context nano
```

Use `kubectl --context nano ...` or `helm --kube-context nano ...` to explicitly
select the cluster. This kubeconfig contains administrator credentials; keep
it private and refresh the copied credentials when their certificates expire.

## 4. Deploy the registry

**Workstation:** create a single Distribution registry with a persistent volume.
No Docker daemon is required on the node. This registry intentionally uses
plain HTTP without authentication: restrict port 30500 to trusted clients.
Use TLS and authentication before exposing it outside a trusted network.

```sh
kubectl --context nano apply -f - <<'EOF_REGISTRY'
apiVersion: v1
kind: Namespace
metadata:
  name: registry
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: registry-data
  namespace: registry
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: registry
  namespace: registry
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: registry
  template:
    metadata:
      labels:
        app: registry
    spec:
      containers:
        - name: registry
          image: registry:3
          env:
            - name: OTEL_TRACES_EXPORTER
              value: none
            - name: REGISTRY_LOG_LEVEL
              value: info
          ports:
            - containerPort: 5000
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              memory: 256Mi
          readinessProbe:
            httpGet:
              path: /v2/
              port: 5000
          volumeMounts:
            - name: data
              mountPath: /var/lib/registry
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: registry-data
---
apiVersion: v1
kind: Service
metadata:
  name: registry
  namespace: registry
spec:
  type: NodePort
  selector:
    app: registry
  ports:
    - port: 5000
      targetPort: 5000
      nodePort: 30500
EOF_REGISTRY
kubectl --context nano -n registry rollout status deployment/registry --timeout=180s
```

The default StorageClass provisions storage on the node. With local-path,
the requested size is not a disk quota: monitor free disk space. Deleting the
PVC may delete all stored images. Persistence is not a backup.

## 5. Allow HTTP pulls on K3s

**Node:** use the same stable IP that you will put in image tags. Merge this
entry into the file if it already contains registry configuration.

```sh
sudo nano /etc/rancher/k3s/registries.yaml
```

Contents (replace the example IP):

```yaml
mirrors:
  "192.168.1.100:30500":
    endpoint:
      - "http://192.168.1.100:30500"
```

Restart K3s to load the configuration:

```sh
sudo systemctl restart k3s
sudo k3s kubectl wait --for=condition=Ready node/nano --timeout=180s
```

Apply the registry configuration on every node that will pull these images.

## 6. Allow HTTP pushes from Docker

On Docker Desktop, open **Settings > Docker Engine** and merge this property
into the existing JSON, replacing the IP:

```json
{
  "insecure-registries": ["192.168.1.100:30500"]
}
```

Apply and restart Docker Desktop. For Linux Docker Engine, merge the same
property into `/etc/docker/daemon.json` and restart Docker.

These instructions use Docker's default builder. A separately configured
BuildKit builder has its own registry configuration.

## 7. Build, push, and verify

**Workstation:** from the repository root, set the registry address and use a
new tag for each build.

```sh
REGISTRY=192.168.1.100:30500
TAG=dev-1

curl -f "http://$REGISTRY/v2/"
docker build --platform linux/arm64 -f server/Dockerfile \
  -t "$REGISTRY/tw-server:$TAG" .
docker push "$REGISTRY/tw-server:$TAG"
```

The registry endpoint should return `{}`. For a pull check using the node's
configured container runtime, run on the **node**:

```sh
sudo k3s crictl pull 192.168.1.100:30500/tw-server:dev-1
```

A server Deployment should reference the fully qualified image with a unique
tag:

```yaml
image: 192.168.1.100:30500/tw-server:dev-1
imagePullPolicy: IfNotPresent
```

The registry stores images; it does not automatically deploy new builds.
Update the server release's image tag to roll out a new build.

For PostgreSQL installation, follow the
[chart README](server/helm/postgres/README.md). Finish its Helm installation
before deploying the API, since the tenant role is created by a Helm hook.

## Expose HTTP on port 8080

The repository-level [ingress chart](helm/ingress/README.md) creates both the
application Ingress and K3s's Traefik HelmChartConfig. Its default
`traefik.webPort: 8080` exposes the existing `web` entry point on node port 8080.
Configure `INGRESS_VALUES_FILE` in the root `.env` (an empty YAML mapping `{}`
uses the chart defaults), then run:

```sh
make deploy-ingress
```

If `HelmChartConfig/traefik` already exists from a manual setup, follow the
chart README's adoption instructions before deploying. Do not replace unrelated
Traefik settings. On other Kubernetes distributions, set `traefik.enabled: false`.

This changes the public HTTP port from 80 to 8080 for all routes using `web`.
It does not expose Traefik's administrative entry point or change the API
container port. Keep port 8080 free of other host services. K3s's Helm controller
applies the change automatically; allow time for reconciliation, then check:

```sh
kubectl --context nano -n kube-system get service traefik
kubectl --context nano -n kube-system get pods
```

The Service should advertise port 8080. Install the ingress release in the
server Service's namespace.
Set the server's `baseUri` to its external URL and run `make deploy-server`.
Verify using the configured hostname
(or IP when the ingress host is empty):

```sh
curl -i http://server.example.com:8080/api/v0/vehicles
```

An unauthenticated request should reach the server and return 401. A 404 from
Traefik indicates no route matched; check the hostname, entry point, and Ingress:

```sh
kubectl --context nano -n tw get ingress
kubectl --context nano -n tw describe ingress edge
```

[Traefik customization in K3s](https://docs.k3s.io/networking/networking-services)
uses HelmChartConfig rather than editing the managed Traefik HelmChart.
The `ports.web.exposedPort` setting is documented in the
[Traefik chart values](https://github.com/traefik/traefik-helm-chart/blob/master/traefik/VALUES.md).

## References

- [K3s requirements](https://docs.k3s.io/installation/requirements)
- [K3s installation](https://docs.k3s.io/quick-start)
- [K3s cluster access](https://docs.k3s.io/cluster-access)
- [K3s private registries](https://docs.k3s.io/installation/private-registry)
- [Distribution registry deployment](https://distribution.github.io/distribution/about/deploying/)
- [Docker insecure registries](https://docs.docker.com/reference/cli/dockerd/#insecure-registries)
