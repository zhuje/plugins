#!/bin/bash

# Script to build and organize all plugins
# This script will:
# 1. Build each plugin
# 2. Create a .dev directory with plugins subdirectory (.dev/plugins/)
# 3. Copy each plugin to .dev/plugins/{plugin_name}
# 4. Organize files as specified in .dev/plugins/{plugin_name} structure

set -e  # Exit on any error

echo "Starting comprehensive plugin build and organization..."

# List of all plugins to process
PLUGINS=(
    "barchart"
    "clickhouse"
    "datasourcevariable"
    "flamechart"
    "gaugechart"
    "heatmapchart"
    "histogramchart"
    "logstable"
    "loki"
    "markdown"
    "piechart"
    "prometheus"
    "pyroscope"
    "scatterchart"
    "statchart"
    "staticlistvariable"
    "statushistorychart"
    "table"
    "tempo"
    "timeserieschart"
    "timeseriestable"
    "tracetable"
    "tracingganttchart"
    "victorialogs"
)

# Function to check if directory exists and has package.json
check_plugin_directory() {
    local plugin_name="$1"
    if [ ! -d "$plugin_name" ]; then
        echo "❌ Plugin directory '$plugin_name' not found. Skipping..."
        return 1
    fi
    if [ ! -f "$plugin_name/package.json" ]; then
        echo "❌ Plugin '$plugin_name' does not have package.json. Skipping..."
        return 1
    fi
    return 0
}

# Function to build a single plugin
build_plugin() {
    local plugin_name="$1"
    echo ""
    echo "🔨 Building plugin: $plugin_name"
    echo "==========================================="

    cd "$plugin_name"

    # Check if npm run build script exists by parsing package.json
    if [ ! -f "package.json" ]; then
        echo "❌ No package.json found for $plugin_name. Skipping..."
        cd ..
        return 1
    fi

    if grep -A 10 '"scripts"' package.json | grep -q '"build"'; then
        echo "Installing dependencies for $plugin_name..."
        npm install
        INSTALL_EXIT_CODE=$?

        if [ $INSTALL_EXIT_CODE -ne 0 ]; then
            echo "❌ npm install failed for $plugin_name (exit code: $INSTALL_EXIT_CODE)"
            cd ..
            return 1
        else
            echo "✅ Dependencies installed successfully for $plugin_name"
        fi

        echo "Running npm run build in $plugin_name directory..."
        npm run build
        BUILD_EXIT_CODE=$?

        # Check if the build produced the necessary files
        if [ ! -d "dist" ]; then
            echo "❌ Build failed for $plugin_name - dist directory not found"
            cd ..
            return 1
        elif [ $BUILD_EXIT_CODE -ne 0 ]; then
            echo "⚠️  Build completed with warnings for $plugin_name (exit code: $BUILD_EXIT_CODE)"
            echo "However, dist directory exists. Continuing with file organization..."
        else
            echo "✅ Build completed successfully for $plugin_name!"
        fi
    else
        echo "❌ No build script found for $plugin_name. Skipping..."
        cd ..
        return 1
    fi

    cd ..
    return 0
}

# Function to organize files for a single plugin
organize_plugin() {
    local plugin_name="$1"

    echo ""
    echo "📁 Organizing plugin: $plugin_name"
    echo "==========================================="

    # Remove existing .dev/plugins/{plugin_name} if it exists
    if [ -d ".dev/plugins/$plugin_name" ]; then
        echo "Removing existing .dev/plugins/$plugin_name directory..."
        rm -rf ".dev/plugins/$plugin_name"
    fi

    # Create the .dev/plugins/{plugin_name} directory
    mkdir -p ".dev/plugins/$plugin_name"

    echo "Copying built artifacts from $plugin_name/dist..."

    # Copy files from {plugin_name}/dist (built artifacts) - only if they exist
    if [ -d "$plugin_name/dist/__mf" ]; then
        cp -r "$plugin_name/dist/__mf" ".dev/plugins/$plugin_name/"
    fi
    if [ -f "$plugin_name/dist/LICENSE" ]; then
        cp "$plugin_name/dist/LICENSE" ".dev/plugins/$plugin_name/"
    fi
    if [ -f "$plugin_name/dist/README.md" ]; then
        cp "$plugin_name/dist/README.md" ".dev/plugins/$plugin_name/"
    fi
    if [ -d "$plugin_name/dist/lib" ]; then
        cp -r "$plugin_name/dist/lib" ".dev/plugins/$plugin_name/"
    fi
    if [ -f "$plugin_name/dist/mf-manifest.json" ]; then
        cp "$plugin_name/dist/mf-manifest.json" ".dev/plugins/$plugin_name/"
    fi
    if [ -f "$plugin_name/dist/mf-stats.json" ]; then
        cp "$plugin_name/dist/mf-stats.json" ".dev/plugins/$plugin_name/"
    fi
    if [ -f "$plugin_name/dist/package.json" ]; then
        cp "$plugin_name/dist/package.json" ".dev/plugins/$plugin_name/"
    fi

    # Copy files from plugin source directory - only if they exist
    echo "Copying source files..."
    if [ -d "$plugin_name/cue.mod" ]; then
        cp -r "$plugin_name/cue.mod" ".dev/plugins/$plugin_name/"
    fi
    if [ -d "$plugin_name/schemas" ]; then
        cp -r "$plugin_name/schemas" ".dev/plugins/$plugin_name/"
    fi

    echo "✅ $plugin_name organization completed!"
}

# Main execution starts here
echo "Processing ${#PLUGINS[@]} plugins..."

# Step 1: Create .dev directory and plugins subdirectory
echo ""
echo "📁 Creating .dev directory and plugins subdirectory..."
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

# Step 2: Process each plugin
successful_builds=0
failed_builds=0
skipped_builds=0

for plugin in "${PLUGINS[@]}"; do
    echo ""
    echo "🔄 Processing plugin: $plugin"
    echo "========================================================"

    # Check if plugin directory exists
    if ! check_plugin_directory "$plugin"; then
        ((skipped_builds++))
        continue
    fi

    # Build the plugin
    if build_plugin "$plugin"; then
        # If build successful, organize the files
        organize_plugin "$plugin"
        ((successful_builds++))
        echo "✅ $plugin completed successfully!"
    else
        echo "❌ $plugin build failed!"
        ((failed_builds++))
    fi
done

# Step 3: Final verification and summary
echo ""
echo "🎉 FINAL SUMMARY"
echo "========================================================"
echo "Total plugins processed: ${#PLUGINS[@]}"
echo "✅ Successful builds: $successful_builds"
echo "❌ Failed builds: $failed_builds"
echo "⚠️  Skipped builds: $skipped_builds"
echo ""

if [ $successful_builds -gt 0 ]; then
    echo "📁 Successfully organized plugins:"
    for plugin in "${PLUGINS[@]}"; do
        if [ -d ".dev/plugins/$plugin" ]; then
            echo "   ✓ .dev/plugins/$plugin/"
        fi
    done
fi

echo ""
echo "🎯 All completed plugins are now available in the .dev/plugins/ directory"
echo "📁 Location: $(pwd)/.dev/plugins/"

if [ $failed_builds -eq 0 ] && [ $skipped_builds -eq 0 ]; then
    echo ""
    echo "🎊 ALL PLUGINS PROCESSED SUCCESSFULLY!"
else
    echo ""
    echo "⚠️  Some plugins encountered issues. Check the log above for details."
fi