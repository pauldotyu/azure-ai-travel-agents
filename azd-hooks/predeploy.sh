#!/bin/bash

# Reusable predeploy script for AKS services
# Usage: ./azd-hooks/predeploy.sh <service_name> <language_type> <port>

set -e

SERVICE_NAME=$1
LANGUAGE_TYPE=$2
PORT=${3:-8080}
SERVICEPORT=${4:-80}

if [ -z "$SERVICE_NAME" ] || [ -z "$LANGUAGE_TYPE" ]; then
    echo "Usage: $0 <service_name> <language_type> [port] [service_port]"
    echo "Example: $0 api javascript 4000 80"
    exit 1
fi

# Convert service name to uppercase and replace hyphens with underscores for env var
SERVICE_ENV_NAME=$(echo "SERVICE_${SERVICE_NAME}" | tr '[:lower:]' '[:upper:]' | tr '-' '_')

echo "Generating Kubernetes manifests for service: $SERVICE_NAME"

# Get the image name and tag from the environment variable
set +e  # Temporarily disable exit on error
IMAGENAME=$(azd env get-value "${SERVICE_ENV_NAME}_IMAGE_NAME" 2>&1)
EXIT_CODE=$?
set -e  # Re-enable exit on error

if [ $EXIT_CODE -ne 0 ] || [ -z "$IMAGENAME" ] || [[ "$IMAGENAME" == *"ERROR"* ]] || [[ "$IMAGENAME" == *"not found"* ]]; then
    # If the image name environment variable doesn't exist, create a default based on the pattern
    REGISTRY=$(azd env get-value "AZURE_CONTAINER_REGISTRY_ENDPOINT" 2>/dev/null || echo "localhost")
    ENV_NAME=$(azd env get-value "AZURE_ENV_NAME" 2>/dev/null || echo "dev")
    IMAGENAME="${REGISTRY}/ai-travel-agents/${SERVICE_NAME}-${ENV_NAME}:latest"
    echo "Image name not found in environment, using default: $IMAGENAME"
fi

NAME=$(echo "$IMAGENAME" | cut -d':' -f1)
TAG=$(echo "$IMAGENAME" | cut -d':' -f2)

# Create the draft.yaml file with the necessary configuration
# Map language types to Draft-compatible names
DRAFT_LANGUAGE_TYPE="$LANGUAGE_TYPE"
case "$LANGUAGE_TYPE" in
    "dotnet")
        DRAFT_LANGUAGE_TYPE="csharp"
        ;;
    "javascript")
        DRAFT_LANGUAGE_TYPE="javascript"
        ;;
    "java")
        DRAFT_LANGUAGE_TYPE="java"
        ;;
    "python")
        DRAFT_LANGUAGE_TYPE="python"
        ;;
esac

cat <<EOF > draft.yaml
deployType: "manifests"
languageType: "$DRAFT_LANGUAGE_TYPE"
deployVariables:
  - name: "PORT"
    value: "$PORT"
  - name: "SERVICEPORT"
    value: "$SERVICEPORT"
  - name: "APPNAME"
    value: "$SERVICE_NAME"
  - name: "IMAGENAME"
    value: "$NAME"
  - name: "IMAGETAG"
    value: "$TAG"
  - name: "ENABLEWORKLOADIDENTITY"
    value: "true"
  - name: "SERVICEACCOUNT"
    value: "travelagent"
EOF

# Add ENVVARS for API service (special case)
if [ "$SERVICE_NAME" = "api" ]; then
    cat <<EOF >> draft.yaml
  - name: "ENVVARS"
    value: "{\"key1\":\"value1\",\"key2\":\"value2\"}"
EOF
fi

echo "Creating Kubernetes manifests..."
# Create k8s manifests
draft create --deploy-type manifests --deployment-only --skip-file-detection --create-config draft.yaml

echo "Kubernetes manifests generated successfully for $SERVICE_NAME"
