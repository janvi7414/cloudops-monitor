#!/bin/bash

set -e

echo "Running backend tests..."
cd backend
npm test

echo "Running frontend build..."
cd ../frontend
npm run build

echo "All tests passed."