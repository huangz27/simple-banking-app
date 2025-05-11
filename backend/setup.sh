#!/bin/bash

echo "Starting banking application setup..."
echo "Node.js version: $(node -v)"
echo "NPM version: $(npm -v)"

# Install dependencies
echo "Installing dependencies..."
npm install

# Initialize the database
echo "Initializing database..."
node init-db.js

# Start the application
echo "Starting application..."
npm start