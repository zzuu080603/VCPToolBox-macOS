#!/bin/bash
echo "Updating VCPToolBox using Git..."

# Pull latest changes from Git
echo "Pulling latest changes..."
git pull

# Install/update Python dependencies
echo "Installing/updating Python dependencies for SciCalculator..."
cd Plugin/SciCalculator && pip3 install -r requirements.txt && cd ../..
echo "Installing/updating Python dependencies for VideoGenerator..."
cd Plugin/VideoGenerator && pip3 install -r requirements.txt && cd ../..

# Install/update Node.js dependencies
echo "Installing/updating Node.js dependencies..."
npm install

echo "Update complete."
