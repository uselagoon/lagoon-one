# Installation inside k8s

### Lagoon Core

Requirements:

* Ingress Controller installed in k8s cluster
* Cert Manager \(if TLS expected\)
* Storage
  * RWO storage as default Storage Class
* Lagoon Charts Helm Repo 

```text
helm repo add lagoon https://uselagoon.github.io/lagoon-charts/
```

example values.yaml

```text
elasticsearchHost: https://none.com
harborURL: "https://none.com"
harborAdminPassword: none
kibanaURL: https://none.com
logsDBAdminPassword: none
s3FilesAccessKeyID: none
s3FilesBucket: none
s3FilesHost: none
s3FilesSecretAccessKey: none
s3BAASAccessKeyID: none
s3BAASSecretAccessKey: none
imageTag: v2.0.0-alpha.9
registry: none.com

api:
  ingress:
    enabled: true
    annotations:
      kubernetes.io/tls-acme: "true"
    hosts:
    - host: api.lagoon.example.com
      paths:
      - /
    tls:
      - secretName: api-tls
        hosts:
          - api.lagoon.example.com

keycloak:
  ingress:
    enabled: true
    annotations:
      kubernetes.io/tls-acme: "true"
    hosts:
    - host: keycloak.lagoon.example.com
      paths:
      - /
    tls:
      - secretName: keycloak-tls
        hosts:
          - keycloak.lagoon.example.com

webhookHandler:
  ingress:
    enabled: true
    annotations:
      kubernetes.io/tls-acme: "true"
    hosts:
    - host: webhookhandler.lagoon.example.com
      paths:
      - /
    tls:
      - secretName: webhookhandler-tls
        hosts:
          - webhookhandler.lagoon.example.com

ui:
  ingress:
    enabled: true
    annotations:
      kubernetes.io/tls-acme: "true"
    hosts:
    - host: ui.lagoon.example.com
      paths:
      - /
    tls:
      - secretName: ui-tls
        hosts:
          - ui.lagoon.example.com

backupHandler:
  ingress:
    enabled: true
    annotations:
      kubernetes.io/tls-acme: "true"
    hosts:
    - host: backuphandler.lagoon.example.com
      paths:
      - /
    tls:
      - secretName: backuphandler-tls
        hosts:
          - backuphandler.lagoon.example.com

drushAlias:
  ingress:
    enabled: true
    annotations:
      kubernetes.io/tls-acme: "true"
    hosts:
    - host: drushalias.lagoon.example.com
      paths:
      - /
    tls:
      - secretName: drushalias-tls
        hosts:
          - drushalias.lagoon.example.com

ssh:
  service:
    type: LoadBalancer
    port: 22


broker:
  ingress:
    enabled: true
    annotations:
      kubernetes.io/tls-acme: "true"
    hosts:
    - host: broker.lagoon.example.com
      paths:
      - /
    tls:
      - secretName: broker-tls
        hosts:
          - broker.lagoon.example.com

webhookHandler:
  ingress:
    enabled: true
    annotations:
      kubernetes.io/tls-acme: "true"
    hosts:
    - host: webhookhandler.lagoon.example.com
      paths:
      - /
    tls:
      - secretName: webhookhandler-tls
        hosts:
          - webhookhandler.lagoon.example.com

```

```text
helm upgrade --install --create-namespace --namespace lagoon-core --values values.yaml lagoon-core lagoon/lagoon-core
```

visit ui

username: lagoonadmin

password: use lagoon-core-keycloak secret 











### Lagoon Remote

Requirements



example values.yaml

```text
lagoon-build-deploy:
  enabled: true
  rabbitMQUsername: lagoon
  rabbitMQPassword: <from lagoon core>
  rabbitMQHostname: <IP from rabbitmq>
  lagoonTargetName: <cluster name>
  taskSSHHost: <IP of ssh service loadbalancer>
  taskSSHPort: "22"
  taskAPIHost: "api.lagoon.example.com"

```

```text
helm upgrade --install --create-namespace --namespace lagoon --values values.yaml  lagoon-remote lagoon/lagoon-remote
```

### Harbor

Regular Harbor Installation

{% embed url="https://github.com/goharbor/harbor-helm" %}

simple example without object storage and just storage in a persistent volume

```text
helm upgrade \
		--install \
		--create-namespace \
		--namespace harbor \
		--wait \
		--set "expose.ingress.annotations.kubernetes\.io\/tls-acme=\"true\"" \
		--set "expose.ingress.hosts.core=harbor.lagoon.example.com" \
		--set "externalURL=https://harbor.lagoon.example.com" \
		--set chartmuseum.enabled=false \
		--set clair.enabled=false \
		--set notary.enabled=false \
		--set trivy.enabled=true \
		--set jobservice.jobLogger=stdout \
		--set registry.replicas=1 \
		--version=1.5.2 \
		harbor \
		harbor/harbor
```

### AddKubernetes

```text
mutation addKubernetes {
  addKubernetes(input:
{
  name: "cluster1.example.com",
  consoleUrl: "https://example.com",
  routerPattern: "${environment}.${project}.cluster1.example.com"
}
  ) {
    id
  }
}
```

### Lagoon cli

```text
lagoon config add --graphql https://api.lagoon.lag01.dplpoc.reload.dk/graphql --ui https://ui.lagoon.lag01.dplpoc.reload.dk --hostname 52.149.110.112 --lagoon lagoon01 --port 22
```



