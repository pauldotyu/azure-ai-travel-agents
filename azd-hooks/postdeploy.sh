#!/bin/bash

# Reusable postdeploy script for AKS services
# Usage: ./azd-hooks/postdeploy.sh [service_name]

set -e

SERVICE_NAME=${1:-"unknown"}

echo "Cleaning up deployment artifacts for service: $SERVICE_NAME"

# Remove temporary files
rm -f draft.yaml
rm -rf manifests

echo "Cleanup completed for $SERVICE_NAME"
