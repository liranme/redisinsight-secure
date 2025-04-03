#!/usr/bin/env bash
# Disable immediate exit on error to allow processing of all clusters
set -o pipefail

# Get RedisInsight connection details
REDISINSIGHT_HOST="${REDISINSIGHT_HOST:-{{ include "redisinsight.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local}"
REDISINSIGHT_PORT="${REDISINSIGHT_PORT:-{{ .Values.service.port }}}"

# Wait for RedisInsight to become available
echo "Waiting for RedisInsight to become available..."
echo "URL: http://${REDISINSIGHT_HOST}:${REDISINSIGHT_PORT}/api/docs"
until curl -s "http://${REDISINSIGHT_HOST}:${REDISINSIGHT_PORT}/api/docs" > /dev/null 2>&1; do
  echo "RedisInsight is not yet available, waiting..."
  sleep 5
done

echo "Waiting for RedisInsight API to be fully functional..."
sleep 10

echo "RedisInsight is available, accepting EULA..."

# Accept EULA with required fields
EULA_PAYLOAD='{
  "theme": "{{ .Values.clustersSetup.theme | default "DARK" }}",
  "agreements": {
    "eula": true,
    "analytics": {{ .Values.clustersSetup.analytics | default true }},
    "notifications": {{ .Values.clustersSetup.notifications | default true }},
    "encryption": {{ .Values.clustersSetup.encryption | default true }}
  }
}'
EULA_RESULT=$(curl -s -X PATCH "http://${REDISINSIGHT_HOST}:${REDISINSIGHT_PORT}/api/settings" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d "$EULA_PAYLOAD")
echo "$EULA_RESULT"

if echo "$EULA_RESULT" | grep -qi "error"; then
  echo "EULA acceptance failed. Exiting."
  exit 1
fi

echo "Waiting for RedisInsight to process EULA settings..."
sleep 15

echo "EULA accepted, adding Redis clusters..."

# File containing cluster configuration
CLUSTER_CONFIG_FILE="/etc/redis-cluster-config/clusters.json"
if [ ! -f "$CLUSTER_CONFIG_FILE" ]; then
  echo "Error: Cluster configuration file not found at $CLUSTER_CONFIG_FILE"
  exit 1
fi

echo "Reading cluster configuration from $CLUSTER_CONFIG_FILE (passwords masked)"
jq 'map_values(.password = "***")' "$CLUSTER_CONFIG_FILE"

# Use simple string variables to track outcomes instead of arrays
FAILED_CLUSTERS=""
SKIPPED_CLUSTERS=""

# Create a temporary JSON file to store cluster config
TMPJSON=$(mktemp)

# Process clusters from clusters.json
echo "Processing cluster data..."
for cluster_name in $(jq -r 'keys[]' "$CLUSTER_CONFIG_FILE"); do
  # Extract all cluster properties into variables
  jq -r --arg name "$cluster_name" '.[$name]' "$CLUSTER_CONFIG_FILE" > "$TMPJSON"
  
  # Get required fields
  name="$cluster_name"
  endpoint=$(jq -r '.endpoint' "$TMPJSON")
  password=$(jq -r '.password' "$TMPJSON")
  username=$(jq -r '.user_name // "default"' "$TMPJSON")
  
  # Get optional fields with defaults if not present - ensure proper JSON types
  port=$(jq -r '.port // 6379' "$TMPJSON")
  provider=$(jq -r '.provider // "AWS"' "$TMPJSON")
  tls=$(jq -r '.tls // false' "$TMPJSON")
  verifyServerCert=$(jq -r '.verifyServerCert // false' "$TMPJSON")
  db=$(jq -r '.db // 0' "$TMPJSON")
  # Convert timeout to milliseconds and ensure it's at least 1000
  timeout=$(jq -r '.timeout // 60' "$TMPJSON")
  timeout=$((timeout * 1000))
  if [ "$timeout" -lt 1000 ]; then
    timeout=1000
  fi
  if [ "$timeout" -gt 1000000000 ]; then
    timeout=1000000000
  fi
  compressor="NONE"
  
  # Skip empty clusters
  if [ -z "$name" ] || [ -z "$endpoint" ]; then
    echo "Missing required fields for cluster, skipping..."
    continue
  fi

  # Check if cluster already exists by querying the API directly
  echo "Checking if cluster '$name' already exists..."
  EXISTING_CHECK_RESPONSE=$(curl -s -X GET "http://${REDISINSIGHT_HOST}:${REDISINSIGHT_PORT}/api/databases" -H "Accept: application/json")
  
  # Use jq and grep to see if the current name exists in the response.
  if echo "$EXISTING_CHECK_RESPONSE" | jq -e -r '.[] | .name' | grep -q -x "$name"; then
    echo "Cluster '$name' already exists, skipping..."
    SKIPPED_CLUSTERS="$SKIPPED_CLUSTERS $name"
    continue
  fi
  
  echo "Adding cluster '$name'..."
  # Create JSON payload using jq to ensure proper JSON formatting
  CLUSTER_PAYLOAD=$(jq -n \
    --arg name "$name" \
    --arg host "$endpoint" \
    --argjson port "$port" \
    --arg username "$username" \
    --arg password "$password" \
    --argjson db "$db" \
    --arg provider "$provider" \
    --argjson tls "$tls" \
    --argjson verifyServerCert "$verifyServerCert" \
    --argjson timeout "$timeout" \
    --arg compressor "$compressor" \
    '{
      name: $name,
      host: $host,
      port: $port,
      username: $username,
      password: $password,
      db: $db,
      provider: $provider,
      tls: $tls,
      verifyServerCert: $verifyServerCert,
      timeout: $timeout,
      compressor: $compressor
    }')
  echo "CLUSTER_PAYLOAD: $CLUSTER_PAYLOAD"
  ADD_RESULT=$(curl -s -X POST "http://${REDISINSIGHT_HOST}:${REDISINSIGHT_PORT}/api/databases" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "$CLUSTER_PAYLOAD")
  echo "Result for cluster '$name': $ADD_RESULT"
  
  if echo "$ADD_RESULT" | grep -qi "error"; then
    echo "Failed to add cluster '$name'"
    FAILED_CLUSTERS="$FAILED_CLUSTERS $name"
  else
    echo "Successfully added cluster '$name'"
  fi
  
  sleep 2
done

rm -f "$TMPJSON" 2>/dev/null || true

# Report results
if [ -n "$FAILED_CLUSTERS" ]; then
  echo "The following clusters failed to be added:$FAILED_CLUSTERS"
else
  echo "All new Redis clusters have been added successfully."
fi

if [ -n "$SKIPPED_CLUSTERS" ]; then
  echo "The following clusters were already present and skipped:$SKIPPED_CLUSTERS"
fi

sleep 10
# Exit with error if any cluster addition failed
if [ -n "$FAILED_CLUSTERS" ]; then
  exit 1
fi
exit 0
