# TW ingress

Shared HTTP routing, installed independently of the server. Requires an
existing ingress controller and server Service. By default it also configures
K3s's bundled Traefik to expose HTTP on node port 8080. Routes `/api/v0` (Prefix) and
`/auth/google/callback` (Exact) without path rewriting. Leaves `/` available
for a future web app route on the same hostname and entry point.

## Install

From the repository root, using the same cluster and namespace as the server:

```sh
helm upgrade --install edge ./helm/ingress -n tw \
  --set serverService=api --wait --timeout 5m
```

`serverService` is the server's Helm release name by default. The backend
Service must be in the same namespace and have a port named `http`.

For local configuration, keep a values file outside the repository:

```yaml
host: server.example.com
serverService: api
```

```sh
helm upgrade --install edge ./helm/ingress -n tw \
  -f /path/to/ingress-values.yaml --wait --timeout 5m
```

Alternatively, the root Makefile reads the context, namespace, release name,
and local values-file path from the Git-ignored `.env`:

```dotenv
KUBE_CONTEXT=your-context
KUBE_NAMESPACE=tw
INGRESS_RELEASE=edge
INGRESS_VALUES_FILE=$(HOME)/.config/tw/ingress-values.yaml
```

```sh
make deploy-ingress
```

The values file must exist and supply `serverService` when the server release
is not named `api`. Use an absolute path or a path relative to the make working
directory. This target deploys routing and the Traefik port configuration; it
does not install the server or the ingress controller.

With `host: ""` (the default), requests match any hostname, including access
by IP. Otherwise DNS and the HTTP Host header must match the configured host.
`className` defaults to `traefik`; `annotations` selects its `web` entry point.
Set `traefik.webPort` to change the external HTTP port. On clusters without
K3s, set `traefik.enabled: false` and configure the controller separately. See
[exposing HTTP on port 8080](../../NANO-SETUP.md#expose-http-on-port-8080).
Set the server chart's `baseUri` to the resulting external API URL.

For verification (401 means the request reached the authenticated API):

```sh
kubectl -n tw get ingress edge
curl -i http://server.example.com:8080/api/v0/vehicles
```

## Moving from the server chart

If ingress was previously enabled in the server release, remove its old
`ingress` values and run `make deploy-server` first. Helm removes the previous
Ingress. Then install this chart with a different release name such as `edge`.
There will be a brief routing interruption between those steps. This chart
does not adopt the old release's Ingress automatically.

## K3s Traefik configuration

The chart creates `HelmChartConfig/traefik` in `kube-system`, independently of
the release namespace. The deploying user needs permission to manage that
resource. Only one release should own it. Changing `traefik.webPort` affects
all routes on the controller's `web` entry point, replacing the default public
port 80. The administrative entry point remains unexposed.

K3s reconciles the Traefik release asynchronously. After `make deploy-ingress`,
allow time for that reconciliation and verify:

```sh
kubectl -n kube-system get service traefik
```

Helm's `--wait` does not wait for the nested Traefik reconciliation. Port 8080
must be available on the node. Uninstalling this chart removes its Traefik
configuration; verify the resulting controller configuration afterward.

If you already created the same HelmChartConfig manually, Helm will reject it
unless it is adopted. Inspect it first; this chart manages only the HTTP port
and replaces `valuesContent`. Preserve any other required settings separately,
or set `traefik.enabled: false` and keep managing the configuration yourself.
To adopt a manually created resource containing only the port setting, with
release `edge` in namespace `tw`:

```sh
kubectl -n kube-system label helmchartconfig traefik \
  app.kubernetes.io/managed-by=Helm --overwrite
kubectl -n kube-system annotate helmchartconfig traefik \
  meta.helm.sh/release-name=edge meta.helm.sh/release-namespace=tw --overwrite
make deploy-ingress
```

Use your configured Kubernetes context and actual Helm release name/namespace.
Do not adopt a resource owned by another Helm release.
