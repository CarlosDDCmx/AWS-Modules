#!/bin/bash
# This script validates that the service is running.
# Give the containers a moment to start up.
sleep 15 

# Check that the frontend is responding
curl -f http://localhost:80 || exit 1

# Check that the backend health check is responding
curl -f http://localhost:5000/health || exit 1