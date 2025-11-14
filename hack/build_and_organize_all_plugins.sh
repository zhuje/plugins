#!/bin/bash

# Script to build and organize all plugins
# This script will:
# 1. Build each plugin
# 2. Create a .plugins directory
# 3. Copy each plugin to .plugins/{plugin_name}-{version}
# 4. Organize files as specified in .plugins/{plugin_name}-{version} structure

# Check if running with bash
if [ -z "$BASH_VERSION" ]; then
    echo "❌ Error: This script requires bash to run"
    echo "Please run with: bash $0"
    exit 1
fi

set -e  # Exit on any error

echo "Starting comprehensive plugin build and organization..."

# List of all plugins to process
# Comment out the plugins you don't want to build
PLUGINS=(
    "prometheus"
    "barchart"
    "datasourcevariable"
    "flamechart"
    "gaugechart"
    "heatmapchart"
    "histogramchart"
    "logstable"
    "loki"
    "markdown"
    "piechart"
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
)

# Function to get plugin name and version from plugins.yaml
get_plugin_info_from_yaml() {
    local plugin_dir="$1"

    # Check if plugins.yaml exists
    if [ ! -f "plugins.yaml" ]; then
        return 1
    fi

    # Parse YAML file to find matching plugin
    local current_name=""
    local current_version=""
    local found_match=0

    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*\"(.+)\" ]]; then
            current_name="${BASH_REMATCH[1]}"
        elif [[ $line =~ ^[[:space:]]*version:[[:space:]]*\"(.+)\" ]]; then
            current_version="${BASH_REMATCH[1]}"

            # Check if this matches our plugin directory (case insensitive comparison)
            if [[ -n "$current_name" && -n "$current_version" ]]; then
                local lowercase_name=$(echo "$current_name" | tr '[:upper:]' '[:lower:]')
                local lowercase_dir=$(echo "$plugin_dir" | tr '[:upper:]' '[:lower:]')

                if [[ "$lowercase_name" == "$lowercase_dir" ]]; then
                    echo "${current_name}-${current_version}"
                    return 0
                fi

                current_name=""
                current_version=""
            fi
        fi
    done < "plugins.yaml"

    return 1
}

# Function to get versioned plugin name
get_versioned_plugin_name() {
    local plugin_dir="$1"

    # Try to get name and version from plugins.yaml
    local yaml_result=$(get_plugin_info_from_yaml "$plugin_dir")
    if [[ $? -eq 0 && -n "$yaml_result" ]]; then
        echo "$yaml_result"
        return 0
    fi

    # Fallback: Extract version from package.json
    if [ -f "../$plugin_dir/package.json" ]; then
        local version=$(grep '"version":' "../$plugin_dir/package.json" | sed 's/.*"version":[[:space:]]*"\([^"]*\)".*/\1/')
        if [[ -n "$version" ]]; then
            # Create a capitalized name
            local capitalized_name=$(echo "$plugin_dir" | sed 's/.*/\L&/; s/[a-z]/\u&/')
            echo "${capitalized_name}-${version}"
            return 0
        fi
    fi

    # Final fallback: use directory name as-is
    echo "$plugin_dir"
    return 1
}


# Function to check if directory exists and has package.json
check_plugin_directory() {
    local plugin_name="$1"
    if [ ! -d "../$plugin_name" ]; then
        echo "❌ Plugin directory '../$plugin_name' not found. Skipping..."
        return 1
    fi
    if [ ! -f "../$plugin_name/package.json" ]; then
        echo "❌ Plugin '../$plugin_name' does not have package.json. Skipping..."
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

    cd "../$plugin_name"

    # Check if npm run build script exists by parsing package.json
    if [ ! -f "package.json" ]; then
        echo "❌ No package.json found for $plugin_name. Skipping..."
        cd ../hack
        return 1
    fi

    if grep -A 10 '"scripts"' package.json | grep -q '"build"'; then
        echo "Installing dependencies for $plugin_name..."
        npm install
        INSTALL_EXIT_CODE=$?

        if [ $INSTALL_EXIT_CODE -ne 0 ]; then
            echo "❌ npm install failed for $plugin_name (exit code: $INSTALL_EXIT_CODE)"
            cd ../hack
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
            cd ../hack
            return 1
        elif [ $BUILD_EXIT_CODE -ne 0 ]; then
            echo "⚠️  Build completed with warnings for $plugin_name (exit code: $BUILD_EXIT_CODE)"
            echo "However, dist directory exists. Continuing with file organization..."
        else
            echo "✅ Build completed successfully for $plugin_name!"
        fi
    else
        echo "❌ No build script found for $plugin_name. Skipping..."
        cd ../hack
        return 1
    fi

    cd ../hack
    return 0
}

# Function to organize files for a single plugin
organize_plugin() {
    local plugin_name="$1"
    local versioned_name=$(get_versioned_plugin_name "$plugin_name")

    echo ""
    echo "📁 Organizing plugin: $plugin_name -> $versioned_name"
    echo "==========================================="

    # Remove existing .plugins/{versioned_name} if it exists
    if [ -d ".plugins/$versioned_name" ]; then
        echo "Removing existing .plugins/$versioned_name directory..."
        rm -rf ".plugins/$versioned_name"
    fi

    # Also remove old plugin_name directory if it exists (for cleanup)
    if [ -d ".plugins/$plugin_name" ]; then
        echo "Removing old .plugins/$plugin_name directory..."
        rm -rf ".plugins/$plugin_name"
    fi

    # Create the .plugins/{versioned_name} directory
    mkdir -p ".plugins/$versioned_name"

    echo "Copying built artifacts from ../$plugin_name/dist to .plugins/$versioned_name..."

    # Copy files from {plugin_name}/dist (built artifacts) - only if they exist
    if [ -d "../$plugin_name/dist/__mf" ]; then
        cp -r "../$plugin_name/dist/__mf" ".plugins/$versioned_name/"
    fi
    if [ -f "../$plugin_name/dist/LICENSE" ]; then
        cp "../$plugin_name/dist/LICENSE" ".plugins/$versioned_name/"
    fi
    if [ -f "../$plugin_name/dist/README.md" ]; then
        cp "../$plugin_name/dist/README.md" ".plugins/$versioned_name/"
    fi
    if [ -d "../$plugin_name/dist/lib" ]; then
        cp -r "../$plugin_name/dist/lib" ".plugins/$versioned_name/"
    fi
    if [ -f "../$plugin_name/dist/mf-manifest.json" ]; then
        cp "../$plugin_name/dist/mf-manifest.json" ".plugins/$versioned_name/"
    fi
    if [ -f "../$plugin_name/dist/mf-stats.json" ]; then
        cp "../$plugin_name/dist/mf-stats.json" ".plugins/$versioned_name/"
    fi
    if [ -f "../$plugin_name/dist/package.json" ]; then
        cp "../$plugin_name/dist/package.json" ".plugins/$versioned_name/"
    fi

    # Copy files from plugin source directory - only if they exist
    echo "Copying source files..."
    if [ -d "../$plugin_name/cue.mod" ]; then
        cp -r "../$plugin_name/cue.mod" ".plugins/$versioned_name/"
    fi
    if [ -d "../$plugin_name/schemas" ]; then
        cp -r "../$plugin_name/schemas" ".plugins/$versioned_name/"
    fi

    echo "✅ $plugin_name organization completed as $versioned_name!"
}

# Main execution starts here
echo "Processing ${#PLUGINS[@]} plugins..."

# Step 1: Create .dev directory and plugins subdirectory
if [ ! -d ".plugins" ]; then
    echo "Creating .plugins directory..."
    mkdir .plugins
    echo ".plugins directory created successfully!"
else
    echo ".plugins directory already exists"
fi

# Plugin mapping will be loaded on-demand from plugins.yaml
echo "📋 Using plugins.yaml for plugin name and version mapping"

# Step 2: Process each plugin
successful_builds=0
failed_builds=0
skipped_builds=0

declare -a ORGANIZED_PLUGINS

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
        versioned_name=$(get_versioned_plugin_name "$plugin")
        ORGANIZED_PLUGINS+=("$versioned_name")
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
    echo "📁 Successfully organized plugins with versioned names:"
    for versioned_plugin in "${ORGANIZED_PLUGINS[@]}"; do
        if [ -d ".plugins/$versioned_plugin" ]; then
            echo "   ✓ .plugins/$versioned_plugin/"
        fi
    done
fi

echo ""
echo "🎯 All completed plugins are now available in the .plugins/ directory"
echo "📁 Location: $(pwd)/.plugins/"

if [ $failed_builds -eq 0 ] && [ $skipped_builds -eq 0 ]; then
    echo ""
    echo "🎊 ALL PLUGINS PROCESSED SUCCESSFULLY!"
else
    echo ""
    echo "⚠️  Some plugins encountered issues. Check the log above for details."
fi