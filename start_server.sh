#!/bin/bash
echo "Starting the VCP intermediate server on macOS..."
# Check if node is installed
if ! command -v node &> /dev/null
then
    echo "Node.js is not installed. Please install it first."
    exit 1
fi

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    echo "node_modules not found, installing dependencies..."
    npm install
fi

node server.js
