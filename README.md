# RedisInsight Helm Chart

This Helm chart deploys RedisInsight, a graphical Redis management tool, on Kubernetes.

## Features

- Deploy RedisInsight with persistent storage
- Optional password encryption
- Pre-configured Redis clusters setup
- Ingress support for external access

## Installation

```bash
# Add the Helm repository (update with your actual repo)
helm repo add myrepo https://charts.example.com/
helm repo update

# Install the chart
helm install redisinsight myrepo/redisinsight
```

## Configuration

### Pre-configuring Redis Clusters

The chart supports pre-configuring RedisInsight with Redis clusters, which is useful for providing immediate access to your Redis instances.

To enable this feature, set `clustersSetup.enabled` to `true` and provide your Redis clusters in `clustersSetup.redisClusters`:

```yaml
clustersSetup:
  enabled: true
  # Configure the container used for setup
  image:
    repository: curlimages/curl
    tag: "7.87.0"
    pullPolicy: IfNotPresent
  # Configure resources for the setup container
  resources:
    limits:
      cpu: 200m
      memory: 128Mi
    requests:
      cpu: 100m
      memory: 64Mi
  # List of Redis clusters to configure
  redisClusters:
    - name: production
      endpoint: redis-prod.example.com
      password: prod-password
      user_name: default
    
    - name: staging
      endpoint: redis-staging.example.com
      password: staging-password
      user_name: default
```

This will deploy a sidecar container that waits for RedisInsight to be ready, then adds the configured Redis clusters. The sidecar container automatically handles EULA acceptance and verifies the connections are properly established.

See the [example values file](examples/redis-clusters-values.yaml) for a complete configuration.

### Password Encryption

Optionally enable password encryption for the RedisInsight configuration:

```yaml
passwordEncryption:
  enabled: true
```

### Persistence

By default, the chart uses ephemeral storage. To enable persistence:

```yaml
persistence:
  enabled: true
  storageClassName: standard
  size: 1Gi
```

### Ingress

For external access, enable and configure the Ingress:

```yaml
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: redisinsight.example.com
      paths:
        - path: /
          pathType: Prefix
```

## Examples

See the [examples](examples/) directory for configuration examples.
