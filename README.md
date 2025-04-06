# RedisInsight Helm Chart

This Helm chart deploys RedisInsight, a powerful visualization tool for Redis, on Kubernetes clusters.

## Overview

RedisInsight provides a graphical user interface for managing, analyzing, and optimizing Redis databases. This Helm chart simplifies the deployment of RedisInsight in Kubernetes environments, with features like:

- Automatic Redis cluster configuration
- Multiple authentication methods (basic auth, OAuth2)
- Persistent storage management
- Support for TLS and encryption
- Fine-grained resource allocation

## Prerequisites

- Kubernetes 1.14+
- Helm 3.0+
- PV provisioner support in the underlying infrastructure (if persistence is enabled)

## Installation

### Add the Helm Repository

```bash
# Add the repository
helm repo add redisinsight-secure https://raw.githubusercontent.com/liranme/redisinsight-secure/main/
helm repo update
```

### Install the Chart

```bash
# Install with default configuration
helm install my-redis-insight redisinsight-secure/redisinsight

# Install with custom configuration
helm install my-redis-insight redisinsight-secure/redisinsight -f values.yaml
```

### Upgrading

```bash
helm upgrade my-redis-insight redisinsight-secure/redisinsight
```

## Uninstallation

```bash
helm uninstall my-redis-insight
```

## Development

### Commit Message Convention

This repository follows [Conventional Commits](https://www.conventionalcommits.org/) specification for commit messages. This enables automatic versioning and release notes generation.

Examples:
```
feat(auth): add support for LDAP authentication
fix: correct port binding in deployment template
docs: update installation instructions
```

See [COMMIT_CONVENTION.md](.github/COMMIT_CONVENTION.md) for detailed guidelines.

### Continuous Integration

The project uses GitHub Actions for CI/CD:

1. **Automated Versioning**: Semantic versioning based on conventional commits
2. **Chart Publishing**: Automatic packaging and publishing to GitHub Releases
3. **Commit Validation**: Enforcing conventional commit format in PRs

When you push to the main branch, the system automatically:
- Determines the next version based on commit types (fix → patch, feat → minor, BREAKING CHANGE → major)
- Updates version in Chart.yaml
- Packages the Helm chart
- Creates a GitHub Release with the packaged chart
- Updates the Helm repository index file in the main branch

## Configuration

### Important Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of RedisInsight replicas | `1` |
| `image.repository` | RedisInsight image repository | `redis/redisinsight` |
| `image.tag` | RedisInsight image tag | `"2.58"` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `clustersSetup.enabled` | Enable automatic Redis cluster configuration | `true` |
| `clustersSetup.acceptEULA` | Accept RedisInsight EULA | `false` |
| `clustersSetup.config.prunClusters` | Remove clusters that exist in RedisInsight but not in config | `true` |
| `persistence.enabled` | Enable persistent storage for RedisInsight data | `false` |
| `passwordEncryption.enabled` | Enable encryption for Redis passwords | `true` |
| `ingress.enabled` | Enable ingress resource for RedisInsight | `false` |
| `ingress.basicauth.enabled` | Enable HTTP basic authentication | `false` |
| `oauth2-proxy.enabled` | Enable OAuth2 Proxy for SSO authentication | `false` |

### Example Values File

```yaml
# Basic RedisInsight setup with a single Redis cluster
image:
  tag: "2.58"

clustersSetup:
  enabled: true
  acceptEULA: true
  config:
    redisClusters:
      - name: "my-redis"
        host: "redis.default.svc.cluster.local"
        port: 6379
        password: "my-password" # Consider using secrets for passwords

persistence:
  enabled: true
  size: 2Gi

service:
  type: ClusterIP
```

## Authentication Options

This chart offers multiple authentication methods for RedisInsight:

### Basic Authentication (Simple)

Basic authentication adds username/password protection to the RedisInsight UI. To enable:

```yaml
ingress:
  enabled: true
  basicauth:
    enabled: true
    users:
      - username: "admin"
        password: "strongpassword"
```

### OAuth2 Authentication (Enterprise SSO)

For enterprise environments requiring SSO integration:

```yaml
ingress:
  enabled: false # Disable the regular ingress when using oauth2-proxy

oauth2-proxy:
  enabled: true
  config:
    clientID: "oauth-client-id"
    clientSecret: "oauth-secret"
    cookieSecret: "cookie-encryption-secret"
    configFile: |-
      email_domains = ["company.com"]
      upstreams = ["http://redisinsight.svc.cluster.local:5540"]
```

## Redis Clusters Configuration

RedisInsight can automatically configure connections to your Redis databases:

```yaml
clustersSetup:
  enabled: true
  acceptEULA: true # Required - read and accept RedisInsight license
  config:
    prunClusters: true # Remove entries not in current config
    redisClusters:
      - name: "redis-main"
        host: "redis-master.default.svc.cluster.local"
        port: 6379
        password: "secure-password"
        username: "default"
        tls: false
      
      - name: "redis-replica"
        host: "redis-replica.default.svc.cluster.local"
        port: 6379
        tls: true
```

### Using Existing Secret for Redis Clusters

Instead of specifying Redis connections in values.yaml, you can use an existing secret:

```yaml
clustersSetup:
  enabled: true
  acceptEULA: true
  config:
    existingSecretConfig: "redis-connections-secret"
    redisClusters: [] # Ignored when existingSecretConfig is provided
```

## Storage and Persistence

RedisInsight can store its configuration data on persistent volumes:

```yaml
persistence:
  enabled: true
  storageClassName: "standard"
  accessModes:
    - ReadWriteOnce
  size: 2Gi
```

## Logging Levels

Set the logging level for the Redis cluster setup job:

```yaml
clustersSetup:
  logLevel: INFO  # Options: DEBUG, INFO, WARN, ERROR, NONE
```

## Security

### Encryption

Enable Redis password encryption:

```yaml
passwordEncryption:
  enabled: true
```

### Security Context

Custom security contexts for the RedisInsight pod:

```yaml
podSecurityContext:
  fsGroup: 1000

securityContext:
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1000
```

## Resource Allocation

```yaml
resources:
  limits:
    cpu: 1000m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

## Configuration File Reference

For detailed configuration options, refer to the [values.yaml](https://github.com/your-repo/redisinsight/blob/main/values.yaml) file.

## License

### Chart License

This Helm chart is licensed under the [Apache License 2.0](LICENSE).

### RedisInsight License

RedisInsight itself is a product of Redis Ltd. and is subject to the [RedisInsight License Terms](https://redis.io/legal/redis-insight-license-terms/). By using this chart, you accept the RedisInsight License Agreement.

**Important**: This chart helps you deploy RedisInsight, but the usage of RedisInsight itself is governed by its own license. Make sure to read and accept the RedisInsight License Terms before using this chart.
