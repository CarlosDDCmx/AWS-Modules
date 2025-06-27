#!/bin/bash
# This script is executed before the application is installed.

# Navigate to the app directory
cd /home/ec2-user/task-manager-app

# If docker-compose is running, take it down
if [ -f docker-compose.yml ]; then
    docker-compose -f docker-compose.yml down
fi

# Clean up any previous artifacts
rm -rf /home/ec2-user/task-manager-app/*