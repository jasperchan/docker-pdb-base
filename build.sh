#!/bin/bash
set -e

# Configuration
IMAGE_NAME="jasperchan/pdb-base"
DOCKERFILE="Dockerfile" # Assuming the Dockerfile is in the current directory
VERSION="1.0.2"         # You can adjust this or make it a parameter

# Print banner
echo "========================================"
echo "Building and pushing ${IMAGE_NAME}:${VERSION}"
echo "========================================"

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
  echo "Error: Docker is not running or you don't have permissions."
  exit 1
fi

# Check if user is logged in to Docker Hub
if ! docker info | grep -q "Username"; then
  echo "Warning: You are not logged in to Docker Hub."
  echo "Please log in using 'docker login'"
  docker login
fi

# Build the Docker image
echo "Building Docker image..."
docker build -t ${IMAGE_NAME}:${VERSION} -f ${DOCKERFILE} .

# Tag as latest
echo "Tagging as latest..."
docker tag ${IMAGE_NAME}:${VERSION} ${IMAGE_NAME}:latest

# Push to Docker Hub
echo "Pushing ${IMAGE_NAME}:${VERSION} to Docker Hub..."
docker push ${IMAGE_NAME}:${VERSION}

echo "Pushing ${IMAGE_NAME}:latest to Docker Hub..."
docker push ${IMAGE_NAME}:latest

echo "========================================"
echo "Build and push completed successfully!"
echo "Image: ${IMAGE_NAME}:${VERSION}"
echo "========================================"
