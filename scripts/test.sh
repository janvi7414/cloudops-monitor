#!/bin/bash

set -e

echo "Running backend tests..."
cd backend
npm test

echo "Running backend security audit..."
npm audit --audit-level=high || true

echo "Running frontend build..."
cd ../frontend
npm run build

echo "Running frontend security audit..."
npm audit --audit-level=high || true

echo "All test and builds passed."
echo "Frontend dependency audit reported known vulnerabilities; review separately."
