#!/bin/bash

set -e

echo "Running backend tests..."
cd backend
npm ci
npm test

echo "Running backend security audit..."
npm audit --audit-level=high || true

echo "Running frontend build..."
cd ../frontend
npm ci
npm run build

echo "Running frontend security audit..."
npm audit --audit-level=high || true

cd ..

echo "Building backend Docker image..."
docker build -t cloudops-backend:test ./backend

echo "Building frontend Docker image..."
docker build -t cloudops-frontend:test ./frontend

echo "Scanning backend Docker image..."
trivy image --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed --quiet cloudops-backend:test

echo "Scanning frontend Docker image..."
trivy image --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed --quiet cloudops-frontend:test

echo "All tests, builds and security scans completed."
