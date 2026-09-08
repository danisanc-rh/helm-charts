# generic-helm-chart

Chart genérico para desplegar microservicios en **OpenShift / Kubernetes**.

Genera:

| Recurso | Condición |
| --- | --- |
| Deployment | Siempre |
| Service | `service.enabled: true` |
| Route (OpenShift) | `route.enabled: true` |
| HorizontalPodAutoscaler | `autoscaling.enabled: true` |

No genera Ingress. La exposición externa se hace con Route de OpenShift.

---

## Requisitos

- Helm 3
- Cluster Kubernetes u OpenShift
- Para Route: OpenShift (API `route.openshift.io/v1`)
- Para HPA: métricas de CPU/memoria disponibles (Metrics Server) y `resources.requests` definidos en el Deployment

---

## Instalación

```bash
# Instalar con values por defecto (útil para pruebas)
helm install mi-app .

# Instalar con un archivo de values del entorno
helm install mi-app . -f values-prod.yaml

# Instalar en un namespace concreto
helm install mi-app . -n mi-namespace --create-namespace -f values-prod.yaml
```

---

## Nombres de recursos

El nombre de Deployment, Service y Route se calcula así:

1. Si `fullnameOverride` tiene valor, se usa ese (máx. 63 caracteres).
2. Si no, se usa `nameOverride`.
3. Si tampoco, se usa el nombre del chart: `generic-helm-chart`.

El selector de pods es `app: <labels.app>` (o el nombre anterior si `labels.app` está vacío). Service y HPA usan el mismo selector, así que `labels.app` debe coincidir con lo que esperan otros recursos del cluster.

---

## Referencia de `values.yaml`

### Identidad y namespace

| Key | Tipo | Default | Uso |
| --- | --- | --- | --- |
| `nameOverride` | string | `""` | Nombre corto de la app. Se usa si no hay `fullnameOverride`. |
| `fullnameOverride` | string | `""` | Nombre final de Deployment, Service y Route. Equivale a `metadata.name` del manifiesto original. |
| `namespace` | string | `""` | Namespace en el metadata de los recursos. Si está vacío, Helm usa el namespace del release (`-n`). |
| `labels.app` | string | `""` | Label `app` de pods y selector del Service. Si está vacío, se usa el nombre de la app. |

### Deployment

| Key | Tipo | Default | Uso |
| --- | --- | --- | --- |
| `replicaCount` | int | `1` | Número de réplicas. Si el HPA está activo, el cluster puede ignorar este valor y escalar según métricas. |
| `revisionHistoryLimit` | int | *(omitido)* | Cuántos ReplicaSets antiguos conserva el Deployment. Key opcional: solo se renderiza si existe. |
| `image.repository` | string | `example/app` | Imagen sin tag. |
| `image.tag` | string | `latest` | Tag de la imagen. Resultado: `repository:tag`. |
| `image.pullPolicy` | string | `IfNotPresent` | `Always`, `IfNotPresent` o `Never`. |
| `imagePullSecrets` | list | `[]` | Secrets para registries privados. Cada ítem: `{ name: mi-secret }`. |
| `containerPort` | int | `8080` | Puerto que expone el contenedor. Debe coincidir con el que escucha la app. |
| `env` | list | `[]` | Variables de entorno del contenedor (`name` / `value` o `valueFrom`). |
| `envFrom` | list | `[]` | Carga un ConfigMap o Secret completo como variables (`configMapRef` / `secretRef`). |
| `resources` | object | `{}` | `requests` y `limits` de CPU/memoria. Necesario si usas HPA por CPU o memoria. |
| `hostNetwork` | bool | `false` | Si `true`, el pod usa la red del nodo. |
| `dnsPolicy` | string | `ClusterFirst` | Política DNS del pod. Con `hostNetwork: true` suele usarse `ClusterFirstWithHostNet`. |

### Service

| Key | Tipo | Default | Uso |
| --- | --- | --- | --- |
| `service.enabled` | bool | `true` | Crea el Service. |
| `service.type` | string | `ClusterIP` | `ClusterIP`, `NodePort` o `LoadBalancer`. |
| `service.port` | int | `80` | Puerto del Service (el que usan Route y otros clientes del cluster). |
| `service.targetPort` | int | `8080` | Puerto del contenedor al que reenvía el Service. Debe alinearse con `containerPort`. |
| `service.name` | string | `http` | Nombre del puerto. La Route lo usa como `targetPort` si no se indica otro. |

### Route (OpenShift)

| Key | Tipo | Default | Uso |
| --- | --- | --- | --- |
| `route.enabled` | bool | `true` | Crea la Route. |
| `route.host` | string | `""` | Hostname público. Si está vacío, OpenShift asigna uno. |
| `route.path` | string | `""` | Path de la Route. Vacío = raíz `/`. |
| `route.serviceName` | string | `""` | Service al que apunta. Vacío = el Service de este chart. |
| `route.targetPort` | string | `""` | Puerto del Service (nombre o número). Vacío = `service.name` (`http`). |
| `route.weight` | int | `100` | Peso para split de tráfico (A/B o canary). |
| `route.wildcardPolicy` | string | `None` | `None` o `Subdomain`. |
| `route.annotations` | object | `{}` | Anotaciones de la Route (timeouts, balanceo, etc.). |
| `route.tls.enabled` | bool | `false` | Activa TLS en la Route. |
| `route.tls.termination` | string | `edge` | `edge`, `passthrough` o `reencrypt`. |
| `route.tls.insecureEdgeTerminationPolicy` | string | `Redirect` | Qué hacer con HTTP: `Allow`, `Redirect` o `None`. |
| `route.tls.certificate` | string | *(omitido)* | Certificado PEM. Opcional. |
| `route.tls.key` | string | *(omitido)* | Clave privada PEM. Opcional. |
| `route.tls.caCertificate` | string | *(omitido)* | CA intermedia/root. Opcional. |
| `route.tls.destinationCACertificate` | string | *(omitido)* | CA del backend. Solo aplica con `reencrypt`. |

### Autoscaling (HPA)

| Key | Tipo | Default | Uso |
| --- | --- | --- | --- |
| `autoscaling.enabled` | bool | `false` | Crea el HorizontalPodAutoscaler. |
| `autoscaling.minReplicas` | int | `1` | Mínimo de pods. |
| `autoscaling.maxReplicas` | int | `3` | Máximo de pods. |
| `autoscaling.targetCPUUtilizationPercentage` | int | `70` | Objetivo de CPU (% de `resources.requests.cpu`). Si está vacío, no se añade métrica de CPU. |
| `autoscaling.targetMemoryUtilizationPercentage` | int | *(vacío)* | Objetivo de memoria (% de `resources.requests.memory`). Si está vacío, no se añade métrica de memoria. |

---

## Ejemplo de values

```yaml
fullnameOverride: mi-servicio
namespace: apps
labels:
  app: mi-servicio

replicaCount: 2

image:
  repository: registry.example.com/mi-servicio
  tag: "1.4.2"
  pullPolicy: IfNotPresent

imagePullSecrets:
  - name: registry-credentials

containerPort: 8080

env:
  - name: SPRING_PROFILES_ACTIVE
    value: prod
  - name: JAVA_TOOL_OPTIONS
    value: "-XX:+UseG1GC"

envFrom:
  - configMapRef:
      name: config-tp
  - secretRef:
      name: mi-servicio-secrets

resources:
  requests:
    cpu: 250m
    memory: 512Mi
  limits:
    cpu: "1"
    memory: 1Gi

service:
  enabled: true
  type: ClusterIP
  port: 80
  targetPort: 8080
  name: http

route:
  enabled: true
  host: mi-servicio.apps.cluster.example.com
  tls:
    enabled: true
    termination: edge
    insecureEdgeTerminationPolicy: Redirect

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 6
  targetCPUUtilizationPercentage: 70
```

---

## Comandos populares

### Renderizar y validar (sin tocar el cluster)

```bash
# Ver los manifiestos que generaría Helm
helm template mi-app . -f values-prod.yaml

# Validar el chart (sintaxis y estructura)
helm lint .

# Dry-run contra el cluster (comprueba el API server)
helm install mi-app . -f values-prod.yaml --dry-run --debug

# Diff de un upgrade (requiere el plugin helm-diff)
helm diff upgrade mi-app . -f values-prod.yaml
```

### Instalar, actualizar y desinstalar

```bash
helm install mi-app . -n mi-namespace --create-namespace -f values-prod.yaml

helm upgrade mi-app . -n mi-namespace -f values-prod.yaml

# Instalar si no existe, actualizar si ya existe
helm upgrade --install mi-app . -n mi-namespace -f values-prod.yaml

# Cambiar solo la imagen sin editar el archivo
helm upgrade mi-app . -n mi-namespace -f values-prod.yaml --set image.tag=1.4.3

helm uninstall mi-app -n mi-namespace
```

### Inspeccionar un release

```bash
helm list -n mi-namespace
helm status mi-app -n mi-namespace
helm get values mi-app -n mi-namespace
helm get manifest mi-app -n mi-namespace
helm history mi-app -n mi-namespace
helm rollback mi-app 1 -n mi-namespace
```

### Empaquetar el chart

```bash
helm package .
# Genera generic-helm-chart-1.0.0.tgz
```

---

## Notas

- **Values por entorno.** Este chart está pensado para usarse con `values-<env>.yaml` (por ejemplo `values-dev.yaml`, `values-prod.yaml`) que sobreescriben los defaults.
- **HPA y réplicas.** Con `autoscaling.enabled: true` define `resources.requests`. Sin requests, el HPA no puede calcular utilización y no escala.
- **Route vs Ingress.** El chart no crea Ingress. En OpenShift usa Route. En Kubernetes vanilla desactiva la Route (`route.enabled: false`) y expón el Service con otro mecanismo.
- **`--set` vs `-f`.** `-f` es preferible para objetos y listas (`env`, `resources`, `imagePullSecrets`). `--set` sirve para overrides puntuales (`image.tag`, `replicaCount`).
- **Mapeo desde manifiestos K8s.** Ver comentarios al inicio de `values.yaml` (`metadata.name` → `fullnameOverride`, `Ingress`/`Route` → `route.*`, etc.).
