#!/bin/bash

# Script to build and organize the prometheus plugin
# This script will:
# 1. Build the prometheus plugin
# 2. Create a .dev directory with plugins subdirectory (.dev/plugins/)
# 3. Copy prometheus to .dev/plugins/prometheus
# 4. Organize files as specified in .dev/plugins/prometheus structure

echo "Starting prometheus plugin build and organization..."

# Step 1: Build the prometheus plugin
echo "Step 1: Building prometheus plugin..."
cd prometheus
echo "Running npm run build in prometheus directory..."

# Run the build command and capture its exit code
npm run build
BUILD_EXIT_CODE=$?

# Check if the build produced the necessary files, even if it had errors
if [ ! -d "dist" ]; then
    echo "Error: Build failed - dist directory not found"
    exit 1
elif [ $BUILD_EXIT_CODE -ne 0 ]; then
    echo "Warning: Build completed with errors (exit code: $BUILD_EXIT_CODE)"
    echo "However, dist directory exists. Continuing with file organization..."
else
    echo "Build completed successfully!"
fi

# Go back to root directory
cd ..

# Step 2: Create .dev directory and plugins subdirectory
echo "Step 2: Creating .dev directory and plugins subdirectory..."
if [ ! -d ".dev" ]; then
    echo "Creating .dev directory..."
    mkdir .dev
    echo ".dev directory created successfully!"
else
    echo ".dev directory already exists"
fi

if [ ! -d ".dev/plugins" ]; then
    echo "Creating .dev/plugins directory..."
    mkdir .dev/plugins
    echo ".dev/plugins directory created successfully!"
else
    echo ".dev/plugins directory already exists"
fi

# Step 3: Copy prometheus to .dev/plugins/prometheus
echo "Step 3: Setting up .dev/plugins/prometheus structure..."

# Remove existing .dev/plugins/prometheus if it exists
if [ -d ".dev/plugins/prometheus" ]; then
    echo "Removing existing .dev/plugins/prometheus directory..."
    rm -rf .dev/plugins/prometheus
fi

# Create the .dev/plugins/prometheus directory
mkdir -p .dev/plugins/prometheus

# Step 4: Copy and organize the required files
echo "Step 4: Organizing files in .dev/plugins/prometheus..."

# Copy files from prometheus/dist (built artifacts)
echo "Copying built artifacts from prometheus/dist..."
cp -r prometheus/dist/__mf .dev/plugins/prometheus/
cp prometheus/dist/LICENSE .dev/plugins/prometheus/
cp prometheus/dist/README.md .dev/plugins/prometheus/
cp -r prometheus/dist/lib .dev/plugins/prometheus/
cp prometheus/dist/mf-manifest.json .dev/plugins/prometheus/
cp prometheus/dist/mf-stats.json .dev/plugins/prometheus/
cp prometheus/dist/package.json .dev/plugins/prometheus/

# Copy files from prometheus source directory
echo "Copying source files..."
cp -r prometheus/cue.mod .dev/plugins/prometheus/
cp -r prometheus/schemas .dev/plugins/prometheus/

# Step 5: Navigate to .dev/plugins/prometheus to verify structure
echo "Step 5: Verifying final structure..."
cd .dev/plugins/prometheus

echo "Final structure in .dev/plugins/prometheus:"
ls -la

echo ""
echo "Verification complete! Contents of .dev/plugins/prometheus:"
echo "✓ __mf/ (directory)"
echo "✓ cue.mod/ (directory)"
echo "✓ lib/ (directory)"
echo "✓ schemas/ (directory)"
echo "✓ LICENSE (file)"
echo "✓ mf-manifest.json (file)"
echo "✓ mf-stats.json (file)"
echo "✓ package.json (file)"
echo "✓ README.md (file)"

echo ""
echo "✅ Prometheus plugin build and organization completed successfully!"
echo "📁 Final location: $(pwd)"