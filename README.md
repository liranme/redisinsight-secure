# RedisInsight-secure Helm Chart

[![Artifact Hub](https://img.shields.io/endpoint?url=https://artifacthub.io/badge/repository/redisinsight-secure)](https://artifacthub.io/packages/search?repo=redisinsight-secure)

This Helm chart deploys RedisInsight, a powerful visualization tool for Redis, on Kubernetes clusters.

## Overview

RedisInsight provides a graphical user interface for managing, analyzing, and optimizing Redis databases. This Helm chart simplifies the deployment of RedisInsight in Kubernetes environments, with features like:

- Preconfigured database connections via JSON file
- Multiple authentication methods (basic auth, OAuth2)
- Persistent storage management
- Support for TLS and encryption
- Fine-grained resource allocation
- Configurable logging and permissions
- Custom environment variables

## Prerequisites

- Kubernetes 1.14+
- Helm 3.0+
- PV provisioner support in the underlying infrastructure (if persistence is enabled)

## Installation

### Add the Helm Repository

```bash
# Add the repository
helm repo add redisinsight-secure https://raw.githubusercontent.com/liranme/redisinsight-secure/main/helm/charts
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

## Configuration

### Important Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `replicaCount` | Number of RedisInsight replicas | `1` |
| `image.repository` | RedisInsight image repository | `redis/redisinsight` |
| `image.tag` | RedisInsight image tag | `"2.68"` |
| `image.pullPolicy` | Image pull policy | `IfNotPresent` |
| `preconfig.enabled` | Enable preconfigured database connections via JSON file | `false` |
| `preconfig.existingSecret` | Use existing secret for preconfigured database connections | `""` |
| `config.logLevel` | Configure the log level of RedisInsight | `"info"` |
| `config.databaseManagement` | Enable/disable database connection management | `true` |
| `config.extraEnvVars` | Additional environment variables for RedisInsight | `[]` |
| `persistence.enabled` | Enable persistent storage for RedisInsight data | `false` |
| `passwordEncryption.enabled` | Enable encryption for Redis passwords | `true` |
| `ingress.enabled` | Enable ingress resource for RedisInsight | `false` |
| `ingress.basicauth.enabled` | Enable HTTP basic authentication | `false` |
| `oauth2-proxy.enabled` | Enable OAuth2 Proxy for SSO authentication | `false` |

### Example Values File

```yaml
# Basic RedisInsight setup with preconfigured database connections
image:
  tag: "2.68"

preconfig:
  enabled: true
  databases: |
    [
      {
        "host": "redis-master.default.svc.cluster.local",
        "port": 6379,
        "name": "redis-cluster",
        "username": "default",
        "password": "my-password" # Consider using secrets for passwords
      }
    ]

config:
  logLevel: "debug"
  databaseManagement: false
  extraEnvVars:
    - name: RI_PROXY_PATH
      value: "/redisinsight"

persistence:
  enabled: true
  size: 2Gi

service:
  type: ClusterIP
```

## Preconfigured Database Connections

RedisInsight supports preconfiguring database connections using a JSON file. This method allows you to securely manage database connections with passwords and sensitive information stored in Kubernetes secrets.

### Using Embedded JSON Configuration

```yaml
preconfig:
  enabled: true
  databases: |-
    [
      {
        "host": "redis-master.default.svc.cluster.local",
        "port": 6379,
        "name": "redis-cluster",
        "username": "default", 
        "password": "redis-password",
        "tls": false
      }
    ]
```

### Using Existing Secret for Preconfigured Connections

For enhanced security, you can create a Kubernetes secret containing the preconfigured database connections:

```yaml
preconfig:
  enabled: true
  existingSecret: "my-redisinsight-config-secret"
```

The secret should contain a key named `preconfig.json` with the database configuration in JSON format.

```bash
# Example command to create the secret:
kubectl create secret generic my-redisinsight-config-secret \
  --from-file=preconfig.json=/path/to/preconfig.json
```

## Application Configuration

### Log Level

Configure the logging level for RedisInsight:

```yaml
config:
  logLevel: "debug"  # Options: error, warn, info, http, verbose, debug, silly
```

### Database Management

Control whether users can add, edit, or delete database connections:

```yaml
config:
  databaseManagement: false  # Disable database connection management in the UI
```

### Custom Environment Variables

Set any additional environment variables needed for RedisInsight:

```yaml
config:
  extraEnvVars:
    - name: RI_PROXY_PATH
      value: "/redisinsight"
    - name: RI_CUSTOM_SETTING
      value: "custom-value"
    # Using a secret for sensitive values
    - name: RI_SENSITIVE_SETTING
      valueFrom:
        secretKeyRef:
          name: my-secret
          key: sensitive-value
```

### Auto Restart on Configuration Changes

The Helm chart includes built-in support for automatically restarting pods when configuration changes are detected. This ensures that any changes to environment variables, database configurations, or secrets are immediately applied without manual intervention.

The following changes will trigger an automatic pod restart:
- Changes to application environment variables in the `config` section
- Changes to preconfigured database connections (when enabled)
- Changes to encryption keys (when password encryption is enabled)
- Changes to basic authentication configuration (when enabled)

You can disable the automatic pod restarts by setting:

```yaml
deployment:
  autoRestartOnConfigChange: false
```

This is useful in environments where you want to control pod restarts manually or if you experience unwanted restarts during Helm upgrades when no actual configuration has changed.

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

This chart includes [oauth2-proxy](https://oauth2-proxy.github.io/oauth2-proxy/) integration to provide secure authentication for RedisInsight. The oauth2-proxy acts as an authentication layer in front of RedisInsight, supporting various identity providers including:

- Google
- GitHub
- Azure AD
- Okta
- Keycloak
- OIDC providers
- And many others

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

#### Semantic Release Process

This project uses [semantic-release](https://github.com/semantic-release/semantic-release) with [semantic-release-helm3](https://github.com/nflaig/semantic-release-helm) plugin to automate the release process. The workflow:

1. Analyzes commits since the last release using conventional commit format
2. Determines the next semantic version number
3. Generates release notes based on commit messages
4. Updates the version in Chart.yaml (and optionally appVersion)
5. Packages the Helm chart automatically
6. Creates a new GitHub release with appropriate tags
7. Updates the Helm repository index

To use this system effectively:
- Always follow the conventional commit format
- Create a GitHub personal access token with `repo` scope and add it as a repository secret named `RELEASE_TOKEN`
- Push changes to the main branch to trigger releases

## Configuration File Reference

For detailed configuration options, refer to the [values.yaml](https://github.com/your-repo/redisinsight/blob/main/values.yaml) file.

## License

### Chart License

This Helm chart is licensed under the [Apache License 2.0](LICENSE).

### RedisInsight License

RedisInsight itself is a product of Redis Ltd. and is subject to the [RedisInsight License Terms](https://redis.io/legal/redis-insight-license-terms/). By using this chart, you accept the RedisInsight License Agreement.

**Important**: This chart helps you deploy RedisInsight, but the usage of RedisInsight itself is governed by its own license. Make sure to read and accept the RedisInsight License Terms before using this chart.
