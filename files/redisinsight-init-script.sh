#!/bin/sh
# Disable immediate exit on error to allow processing of all clusters
set -e

# Make sure POSIX/sh compatibility mode is used
if [ -n "$BASH_VERSION" ]; then
  # If running in bash, use more compatible mode
  set +o posix
fi

# Setup logging system
LOG_LEVEL="${LOG_LEVEL:-{{ .Values.clustersSetup.logLevel | default "INFO" }}}"

# Get timestamp in ISO 8601 format
get_timestamp() {
  date "+%Y-%m-%d %H:%M:%S"
}

# Function to mask sensitive information in JSON
mask_sensitive() {
  # Check if input is valid JSON
  if ! echo "$1" | jq '.' > /dev/null 2>&1; then
    # If not valid JSON, just return the input as is
    echo "$1"
  else
    # Mask sensitive fields in valid JSON
    echo "$1" | jq 'walk(if type == "object" then 
      with_entries(
        if .key == "password" then .value = "***" 
        elif .key == "auth_pass" then .value = "***"
        elif .key == "auth-pass" then .value = "***"
        elif .key == "client_password" then .value = "***" 
        elif .key == "client-password" then .value = "***" 
        elif .key == "tls_password" then .value = "***"
        elif .key == "tls-password" then .value = "***"
        elif .key == "secret" then .value = "***"
        else . end
      ) 
    else . end)'
  fi
}

# Log levels: ERROR=1, WARN=2, INFO=3, DEBUG=4
log_error() { 
  if [ "$LOG_LEVEL" = "ERROR" ] || [ "$LOG_LEVEL" = "WARN" ] || [ "$LOG_LEVEL" = "INFO" ] || [ "$LOG_LEVEL" = "DEBUG" ]; then 
    echo "[$(get_timestamp)][ERROR] $*" >&2
  fi
}
log_warn() { 
  if [ "$LOG_LEVEL" = "WARN" ] || [ "$LOG_LEVEL" = "INFO" ] || [ "$LOG_LEVEL" = "DEBUG" ]; then 
    echo "[$(get_timestamp)][WARN] $*"
  fi
}
log_info() { 
  if [ "$LOG_LEVEL" = "INFO" ] || [ "$LOG_LEVEL" = "DEBUG" ]; then 
    echo "[$(get_timestamp)][INFO] $*"
  fi
}
log_debug() { 
  if [ "$LOG_LEVEL" = "DEBUG" ]; then 
    echo "[$(get_timestamp)][DEBUG] $*"
  fi
}

# Function to safely log JSON data with sensitive info masked
log_json() {
  if [ "$LOG_LEVEL" = "DEBUG" ]; then
    masked_json=$(mask_sensitive "$2")
    echo "[$(get_timestamp)][DEBUG] $1: $masked_json"
  fi
}

log_info "Initializing RedisInsight cluster setup with LOG_LEVEL=$LOG_LEVEL"

# Get RedisInsight connection details
REDISINSIGHT_HOST="${REDISINSIGHT_HOST:-{{ include "redisinsight.fullname" . }}.{{ .Release.Namespace }}.svc.cluster.local}"
REDISINSIGHT_PORT="${REDISINSIGHT_PORT:-{{ .Values.service.port }}}"
ACCEPT_EULA="{{ .Values.clustersSetup.acceptEULA | default false }}"

# Wait for RedisInsight to become available
log_info "Waiting for RedisInsight to become available..."
log_debug "URL: http://${REDISINSIGHT_HOST}:${REDISINSIGHT_PORT}/api/docs"
until curl -s "http://${REDISINSIGHT_HOST}:${REDISINSIGHT_PORT}/api/docs" > /dev/null 2>&1; do
  log_info "RedisInsight is not yet available, waiting..."
  sleep 5
done

log_info "Waiting for RedisInsight API to be fully functional..."
sleep 10

log_info "RedisInsight is available, accepting EULA..."

# Accept EULA with required fields
if [ "$ACCEPT_EULA" = true ]; then
  EULA_PAYLOAD='{
    "theme": "{{ .Values.clustersSetup.theme | default "DARK" }}",
    "agreements": {
    "eula": true,
    "analytics": {{ .Values.clustersSetup.analytics | default true }},
    "notifications": {{ .Values.clustersSetup.notifications | default true }},
    "encryption": {{ .Values.clustersSetup.encryption | default true }}
    }
  }'
  log_json "EULA payload" "$EULA_PAYLOAD"
  EULA_RESULT=$(curl -s -X PATCH "http://${REDISINSIGHT_HOST}:${REDISINSIGHT_PORT}/api/settings" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "$EULA_PAYLOAD")
  log_json "EULA result" "$EULA_RESULT"

  if echo "$EULA_RESULT" | grep -qi "error"; then
    log_error "EULA acceptance failed. Exiting."
    exit 1
  fi
fi

log_info "Waiting for RedisInsight to process EULA settings..."
sleep 15

log_info "EULA accepted, adding Redis clusters..."

# File containing cluster configuration
CLUSTER_CONFIG_FILE="/etc/redis-cluster-config/clusters.json"
if [ ! -f "$CLUSTER_CONFIG_FILE" ]; then
  log_error "Cluster configuration file not found at $CLUSTER_CONFIG_FILE"
  exit 1
fi

log_info "Reading cluster configuration from $CLUSTER_CONFIG_FILE"
if [ "$LOG_LEVEL" = "DEBUG" ]; then
  CLUSTER_CONFIG=$(cat "$CLUSTER_CONFIG_FILE")
  log_json "Cluster config" "$CLUSTER_CONFIG"
fi

# Get the list of expected cluster names from the config file
EXPECTED_CLUSTERS=$(jq -r 'keys[]' "$CLUSTER_CONFIG_FILE")
log_debug "Expected clusters from config: $EXPECTED_CLUSTERS"

# Check if pruning is enabled
PRUNE_CLUSTERS={{ .Values.clustersSetup.config.prunClusters | default false }}
log_info "Pruning mode enabled: $PRUNE_CLUSTERS"

# Use simple string variables to track outcomes instead of arrays
FAILED_CLUSTERS=""
SKIPPED_CLUSTERS=""
REMOVED_CLUSTERS=""

# Create a temporary JSON file to store cluster config
TMPJSON=$(mktemp)
log_debug "Created temporary JSON file: $TMPJSON"

# If pruning is enabled, get the current list of clusters and remove those not in config
if [ "$PRUNE_CLUSTERS" = true ]; then
  log_info "Pruning enabled. Checking for clusters to remove..."
  
  # Get the list of existing clusters from RedisInsight
  log_debug "Fetching existing clusters from RedisInsight..."
  EXISTING_CLUSTERS_RESPONSE=$(curl -s -X GET "http://${REDISINSIGHT_HOST}:${REDISINSIGHT_PORT}/api/databases" -H "Accept: application/json")
  log_json "Existing clusters" "$EXISTING_CLUSTERS_RESPONSE"
  
  # Process each existing cluster
  log_debug "Processing existing clusters..."
  echo "$EXISTING_CLUSTERS_RESPONSE" | jq -c '.[]' | while read -r cluster; do
    cluster_id=$(echo "$cluster" | jq -r '.id')
    cluster_name=$(echo "$cluster" | jq -r '.name')
    log_debug "Found existing cluster: $cluster_name (ID: $cluster_id)"
    
    # Check if this cluster is in our expected list
    if ! echo "$EXPECTED_CLUSTERS" | grep -q -x "$cluster_name"; then
      log_info "Cluster '$cluster_name' exists in RedisInsight but not in config. Removing..."
      DELETE_RESULT=$(curl -s -X DELETE "http://${REDISINSIGHT_HOST}:${REDISINSIGHT_PORT}/api/databases/${cluster_id}" \
        -H "Accept: application/json")
      
      if echo "$DELETE_RESULT" | grep -qi "error"; then
        log_error "Failed to remove cluster '$cluster_name'"
        log_json "Error details" "$DELETE_RESULT"
      else
        log_info "Successfully removed cluster '$cluster_name'"
        REMOVED_CLUSTERS="$REMOVED_CLUSTERS $cluster_name"
      fi
      
      sleep 2
    else
      log_debug "Cluster '$cluster_name' is in config, keeping it"
    fi
  done
  
  log_info "Pruning complete."
fi

# Process clusters from clusters.json
log_info "Processing cluster data for addition..."
for cluster_name in $(jq -r 'keys[]' "$CLUSTER_CONFIG_FILE"); do
  # Extract all cluster properties into variables
  jq -r --arg name "$cluster_name" '.[$name]' "$CLUSTER_CONFIG_FILE" > "$TMPJSON"
  log_debug "Processing cluster: $cluster_name"
  
  # Get required fields
  name="$cluster_name"
  host=$(jq -r '.host // empty' "$TMPJSON")
  
  # Skip empty clusters
  if [ -z "$name" ] || [ -z "$host" ]; then
    log_warn "Missing required fields (name or host) for cluster, skipping..."
    continue
  fi

  # Check if cluster already exists by querying the API directly
  log_debug "Checking if cluster '$name' already exists..."
  EXISTING_CHECK_RESPONSE=$(curl -s -X GET "http://${REDISINSIGHT_HOST}:${REDISINSIGHT_PORT}/api/databases" -H "Accept: application/json")
  
  # Use jq and grep to see if the current name exists in the response.
  if echo "$EXISTING_CHECK_RESPONSE" | jq -e -r '.[] | .name' | grep -q -x "$name"; then
    log_info "Cluster '$name' already exists, skipping..."
    SKIPPED_CLUSTERS="$SKIPPED_CLUSTERS $name"
    continue
  fi
  
  log_info "Adding cluster '$name'..."
  
  # Pass all fields from the original configuration, ensuring only the required ones have defaults
  CLUSTER_PAYLOAD=$(jq -n --argjson orig "$(cat "$TMPJSON")" --arg name "$name" '{
    name: $name,
    host: ($orig.host // ""),
    port: ($orig.port // 6379) | tonumber
  } + ($orig | del(.name, .host, .port)) | walk(
    if type == "string" and (. == "true" or . == "false") then
      if . == "true" then true else false end
    elif type == "string" and (. | tostring | test("^[0-9]+$")) then
      . | tonumber
    else .
    end
  ) | with_entries(select(.value != null))')
  
  # Log the payload with sensitive info masked
  log_json "CLUSTER_PAYLOAD" "$CLUSTER_PAYLOAD"
  
  ADD_RESULT=$(curl -s -X POST "http://${REDISINSIGHT_HOST}:${REDISINSIGHT_PORT}/api/databases" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -d "$CLUSTER_PAYLOAD")
  log_json "Result for cluster '$name'" "$ADD_RESULT"
  
  if echo "$ADD_RESULT" | grep -qi "error"; then
    log_error "Failed to add cluster '$name'"
    FAILED_CLUSTERS="$FAILED_CLUSTERS $name"
  else
    log_info "Successfully added cluster '$name'"
  fi
  
  sleep 2
done

log_debug "Cleaning up temporary files..."
rm -f "$TMPJSON" 2>/dev/null || true

# Report results
if [ -n "$FAILED_CLUSTERS" ]; then
  log_error "The following clusters failed to be added:$FAILED_CLUSTERS"
else
  log_info "All new Redis clusters have been added successfully."
fi

if [ -n "$SKIPPED_CLUSTERS" ]; then
  log_info "The following clusters were already present and skipped:$SKIPPED_CLUSTERS"
fi

if [ -n "$REMOVED_CLUSTERS" ]; then
  log_info "The following clusters were removed (pruned):$REMOVED_CLUSTERS"
fi

# Exit with error if any cluster addition failed
if [ -n "$FAILED_CLUSTERS" ]; then
  log_error "Exiting with error due to failed cluster additions"
  exit 1
fi
log_info "Script completed successfully"
exit 0
