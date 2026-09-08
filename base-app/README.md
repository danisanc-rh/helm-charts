# helm-chart

Chart de aplicación para microservicios. No define plantillas propias: consume el subchart `generic-helm-chart`, que genera **Deployment**, **Service**, **Route** (OpenShift) y **HorizontalPodAutoscaler**.

## Estructura

```text
base-app/
├── Chart.yaml      # Metadatos y declaración de dependencias
├── Chart.lock      # Versión y digest resueltos de cada dependencia
├── values.yaml     # Valores por defecto (anidados bajo generic-helm-chart)
├── charts/         # Subcharts descargados (generado por helm dependency build)
└── README.md
```

Los archivos `values-<env>.yaml` de cada servicio sobreescriben los valores de este chart.

## Dependencias

`Chart.yaml` declara el subchart publicado en GitHub Pages:

```yaml
dependencies:
  - name: generic-helm-chart
    version: 1.0.0
    repository: https://danisanc-rh.github.io/helm-charts/
```

Helm no descarga esa dependencia al hacer `helm install` si el paquete aún no está en `charts/`. Hay que construirla antes.

### `helm dependency build .`

Desde el directorio `base-app/`:

```bash
helm dependency build .
```

**Para qué se usa.** Lee `Chart.yaml` y `Chart.lock`, descarga el subchart `generic-helm-chart` en la versión fijada y lo deja empaquetado en `charts/` (por ejemplo `charts/generic-helm-chart-1.0.0.tgz`). Sin ese paso, `helm template` / `helm install` / `helm upgrade` fallan porque el chart padre no encuentra el subchart.

Diferencia con comandos cercanos:

| Comando | Qué hace |
| --- | --- |
| `helm dependency build .` | Respeta `Chart.lock` y descarga exactamente esas versiones. Úsalo en el día a día y en CI cuando el lock ya existe. |
| `helm dependency update .` | Consulta el repositorio, regenera `Chart.lock` y descarga. Úsalo cuando cambias `name`, `version` o `repository` en `Chart.yaml`. |

Después de un `build` correcto deberías ver algo como:

```text
Saving 1 charts
Downloading generic-helm-chart from repo https://danisanc-rh.github.io/helm-charts/
Deleting outdated charts
```

y el archivo `charts/generic-helm-chart-1.0.0.tgz`.

## Estructura de `values.yaml`

### Por qué todo está dentro de `generic-helm-chart:`

`base-app` es un **chart padre**. No tiene carpeta `templates/`: los manifiestos los genera el **subchart** declarado en `Chart.yaml` con `name: generic-helm-chart`.

Helm aísla los values de cada subchart. La convención es:

```text
values del padre          →  raíz de values.yaml  (este chart no los usa)
values del subchart       →  <nombre-del-subchart>:
```

El nombre de esa clave **tiene que coincidir** con `dependencies[].name` en `Chart.yaml`. Por eso el bloque se llama exactamente `generic-helm-chart` y no `genericHelmChart` ni `chart`.

Dentro de las plantillas del subchart, `.Values.replicaCount` ya **no** mira la raíz del padre: mira lo que el padre puso bajo `generic-helm-chart:`. Helm hace esa traducción al renderizar.

```yaml
# Correcto: llega al Deployment del subchart
generic-helm-chart:
  replicaCount: 2

# Incorrecto: Helm lo trata como value del padre; el subchart sigue con su default
replicaCount: 2
```

Los `values-<env>.yaml` de cada microservicio deben repetir el mismo anidamiento.

---

### Identidad y namespace

**`nameOverride`** (`""`)  
Nombre corto del workload. Si está vacío, se usa el nombre del chart (`helm-chart`). Se trunca a 63 caracteres (límite DNS de Kubernetes).

**`fullnameOverride`** (`""`)  
Nombre real de Deployment, Service, Route y HPA. Si está vacío, se usa `nameOverride` (o el nombre del chart). Es el equivalente de `metadata.name` en un manifiesto.

**`namespace`** (`""`)  
Namespace donde se crean los recursos. Si está vacío, Helm usa el namespace del release (`-n`). Equivale a `metadata.namespace`.

**`labels.app`** (`""`)  
Label `app` de los recursos y del selector de pods. Si está vacío, se deriva de `nameOverride`. Debe coincidir entre Deployment y Service para que el tráfico llegue a los pods. Equivale a `metadata.labels.app`.

---

### Workload (Deployment)

**`replicaCount`** (`1`)  
Número de pods (`spec.replicas`). Si más adelante activas el HPA, Kubernetes deja de respetar este valor como fuente de verdad y escala entre `minReplicas` y `maxReplicas`.

**`revisionHistoryLimit`** (opcional; no está en el archivo por defecto)  
Cuántos ReplicaSets antiguos conserva el Deployment. Si no se declara, Kubernetes usa su default. Equivale a `spec.revisionHistoryLimit`.

**`image.repository`** (`example/app`)  
Imagen sin tag: registro + nombre (`registry.example.com/equipo/servicio`).

**`image.tag`** (`latest`)  
Tag o digest de la imagen. Junto con `repository` forma `repository:tag`.

**`image.pullPolicy`** (`IfNotPresent`)  
Cuándo kubelet baja la imagen: `IfNotPresent`, `Always` o `Never`. Equivale a `imagePullPolicy`.

**`imagePullSecrets`** (`[]`)  
Lista de secrets con credenciales del registro privado. Equivale a `spec.template.spec.imagePullSecrets`. Ejemplo:

```yaml
imagePullSecrets:
  - name: registry-credentials
```

**`containerPort`** (`8080`)  
Puerto que abre el contenedor. Debe alinearse con `service.targetPort`. Equivale a `container.ports[].containerPort`.

**`env`** (`[]`)  
Variables de entorno del contenedor (`name` + `value` o `valueFrom`). Equivale a `container.env`.

**`envFrom`** (`[]`)  
Inyecta todas las claves de un ConfigMap o Secret. Equivale a `container.envFrom`.

**`resources`** (`{}`)  
`requests` y `limits` de CPU y memoria. Vacío = sin cuota explícita. Equivale a `container.resources`.

**`hostNetwork`** (`false`)  
Si es `true`, el pod usa la red del nodo (mismo IP/puertos). Equivale a `spec.template.spec.hostNetwork`.

**`dnsPolicy`** (`ClusterFirst`)  
Cómo resuelve DNS el pod. Con `hostNetwork: true` suele usarse `ClusterFirstWithHostNet`. Equivale a `spec.template.spec.dnsPolicy`.

---

### Service

Solo se renderiza si `service.enabled` es `true`.

**`service.enabled`** (`true`)  
Crea o omite el Service.

**`service.type`** (`ClusterIP`)  
Tipo de Service: `ClusterIP` (interno), `NodePort` o `LoadBalancer`.

**`service.port`** (`80`)  
Puerto en el que el Service escucha dentro del cluster.

**`service.targetPort`** (`8080`)  
Puerto del contenedor al que se reenvía el tráfico. Debe coincidir con `containerPort`.

**`service.name`** (`http`)  
Nombre del puerto del Service. La Route usa este nombre como `targetPort` si `route.targetPort` está vacío.

---

### Route (OpenShift)

Solo se renderiza si `route.enabled` es `true`. Este chart **no** genera Ingress; un Ingress de Kubernetes se mapea a esta Route.

**`route.enabled`** (`true`)  
Crea o omite la Route.

**`route.host`** (`""`)  
Hostname público (`mi-app.apps.cluster.example.com`). Vacío = OpenShift asigna uno.

**`route.path`** (`""`)  
Path HTTP. Vacío = raíz (`/`).

**`route.serviceName`** (`""`)  
Service al que apunta la Route. Vacío = el Service que genera este chart (`fullnameOverride` / `nameOverride`).

**`route.targetPort`** (`""`)  
Puerto del Service. Vacío = `service.name` (`http`).

**`route.weight`** (`100`)  
Peso del backend (0–100). Sirve para canary entre varias Routes al mismo host.

**`route.wildcardPolicy`** (`None`)  
Si el host admite wildcard (`*.apps.example.com`). `None` = host exacto.

**`route.annotations`** (`{}`)  
Anotaciones extra de OpenShift (timeouts, balanceo, etc.).

**`route.tls.enabled`** (`false`)  
Activa el bloque `spec.tls` de la Route.

**`route.tls.termination`** (`edge`)  
Dónde termina TLS: `edge` (el router descifra), `passthrough` (llega al pod) o `reencrypt`.

**`route.tls.insecureEdgeTerminationPolicy`** (`Redirect`)  
Qué hacer con HTTP en el puerto inseguro: `Redirect`, `Allow` o `None`. Solo aplica con terminación `edge` o `reencrypt`.

---

### Autoscaling (HPA)

Solo se renderiza si `autoscaling.enabled` es `true`.

**`autoscaling.enabled`** (`false`)  
Crea o omite el HorizontalPodAutoscaler.

**`autoscaling.minReplicas`** (`1`)  
Mínimo de pods que el HPA puede dejar.

**`autoscaling.maxReplicas`** (`3`)  
Máximo de pods que el HPA puede crear.

**`autoscaling.targetCPUUtilizationPercentage`** (`70`)  
Umbral de CPU promedio. Si se deja vacío, no se añade métrica de CPU.

**`autoscaling.targetMemoryUtilizationPercentage`** (vacío)  
Umbral de memoria promedio. Vacío a propósito: no se añade métrica de memoria hasta que se defina un número.

## Uso

Desde `base-app/`:

```bash
# 1. Descargar el subchart (obligatorio la primera vez y en CI)
helm dependency build .

# 2. Renderizar manifiestos sin instalar
helm template mi-app . -f values.yaml

# 3. Instalar o actualizar
helm upgrade --install mi-app . -f values.yaml -n <namespace>
```

Para un entorno concreto, pasa el values del servicio:

```bash
helm upgrade --install mi-app . -f values-prod.yaml -n <namespace>
```
