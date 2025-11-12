#!/bin/bash

# Script to build and organize all plugins with versioned naming
# This script will:
# 1. Build each plugin
# 2. Create a .dev directory with plugins subdirectory (.dev/plugins/)
# 3. Copy each plugin to .dev/plugins/{PluginName-version}
# 4. Organize files using versioned naming from plugin-names.yaml

echo "Starting comprehensive plugin build and organization with versioned naming..."

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

# Create associative array for plugin name mapping
declare -A PLUGIN_MAPPING

# Function to read plugin-names.yaml and create mapping
load_plugin_mapping() {
    echo "📋 Loading plugin name mapping from plugin-names.yaml..."

    # Check if plugin-names.yaml exists
    if [ ! -f ".dev/plugins/plugin-names.yaml" ]; then
        echo "⚠️  plugin-names.yaml not found at .dev/plugins/plugin-names.yaml"
        echo "Will fallback to package.json version extraction"
        return 1
    fi

    # Parse YAML file and create mapping
    local current_name=""
    local current_version=""

    while IFS= read -r line; do
        if [[ $line =~ ^[[:space:]]*-[[:space:]]*name:[[:space:]]*\"(.+)\" ]]; then
            current_name="${BASH_REMATCH[1]}"
        elif [[ $line =~ ^[[:space:]]*version:[[:space:]]*\"(.+)\" ]]; then
            current_version="${BASH_REMATCH[1]}"

            # Create mapping when we have both name and version
            if [[ -n "$current_name" && -n "$current_version" ]]; then
                # Convert plugin name to lowercase for mapping key
                local key=$(echo "$current_name" | tr '[:upper:]' '[:lower:]' | sed 's/chart$/chart/')
                # Special case mappings for directory names that don't match exactly
                case "$key" in
                    "barchart") PLUGIN_MAPPING["barchart"]="BarChart-${current_version}" ;;
                    "gaugechart") PLUGIN_MAPPING["gaugechart"]="GaugeChart-${current_version}" ;;
                    "heatmapchart") PLUGIN_MAPPING["heatmapchart"]="HeatMapChart-${current_version}" ;;
                    "histogramchart") PLUGIN_MAPPING["histogramchart"]="HistogramChart-${current_version}" ;;
                    "logstable") PLUGIN_MAPPING["logstable"]="LogsTable-${current_version}" ;;
                    "piechart") PLUGIN_MAPPING["piechart"]="PieChart-${current_version}" ;;
                    "scatterchart") PLUGIN_MAPPING["scatterchart"]="ScatterChart-${current_version}" ;;
                    "statchart") PLUGIN_MAPPING["statchart"]="StatChart-${current_version}" ;;
                    "statushistorychart") PLUGIN_MAPPING["statushistorychart"]="StatusHistoryChart-${current_version}" ;;
                    "timeserieschart") PLUGIN_MAPPING["timeserieschart"]="TimeSeriesChart-${current_version}" ;;
                    "timeseriestable") PLUGIN_MAPPING["timeseriestable"]="TimeSeriesTable-${current_version}" ;;
                    "tracetable") PLUGIN_MAPPING["tracetable"]="TraceTable-${current_version}" ;;
                    "tracingganttchart") PLUGIN_MAPPING["tracingganttchart"]="TracingGanttChart-${current_version}" ;;
                    "datasourcevariable") PLUGIN_MAPPING["datasourcevariable"]="DatasourceVariable-${current_version}" ;;
                    "staticlistvariable") PLUGIN_MAPPING["staticlistvariable"]="StaticListVariable-${current_version}" ;;
                    "flamechart") PLUGIN_MAPPING["flamechart"]="FlameChart-${current_version}" ;;
                    *) PLUGIN_MAPPING["$key"]="${current_name}-${current_version}" ;;
                esac

                echo "   📌 Mapped '$key' -> '${PLUGIN_MAPPING[$key]}'"
                current_name=""
                current_version=""
            fi
        fi
    done < ".dev/plugins/plugin-names.yaml"

    echo "✅ Plugin mapping loaded successfully!"
    return 0
}

# Function to get versioned plugin name
get_versioned_plugin_name() {
    local plugin_dir="$1"

    # Check if we have a mapping from the YAML file
    if [[ -n "${PLUGIN_MAPPING[$plugin_dir]}" ]]; then
        echo "${PLUGIN_MAPPING[$plugin_dir]}"
        return 0
    fi

    # Fallback: Extract version from package.json
    if [ -f "$plugin_dir/package.json" ]; then
        local version=$(grep '"version":' "$plugin_dir/package.json" | sed 's/.*"version":[[:space:]]*"\([^"]*\)".*/\1/')
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

    # Check if npm run build script exists
    if npm run | grep -q "build"; then
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

# Function to organize files for a single plugin with versioned naming
organize_plugin() {
    local plugin_name="$1"
    local versioned_name=$(get_versioned_plugin_name "$plugin_name")

    echo ""
    echo "📁 Organizing plugin: $plugin_name -> $versioned_name"
    echo "==========================================="

    # Remove existing .dev/plugins/{versioned_name} if it exists
    if [ -d ".dev/plugins/$versioned_name" ]; then
        echo "Removing existing .dev/plugins/$versioned_name directory..."
        rm -rf ".dev/plugins/$versioned_name"
    fi

    # Create the .dev/plugins/{versioned_name} directory
    mkdir -p ".dev/plugins/$versioned_name"

    echo "Copying built artifacts from $plugin_name/dist..."

    # Copy files from {plugin_name}/dist (built artifacts) - only if they exist
    if [ -d "$plugin_name/dist/__mf" ]; then
        cp -r "$plugin_name/dist/__mf" ".dev/plugins/$versioned_name/"
    fi
    if [ -f "$plugin_name/dist/LICENSE" ]; then
        cp "$plugin_name/dist/LICENSE" ".dev/plugins/$versioned_name/"
    fi
    if [ -f "$plugin_name/dist/README.md" ]; then
        cp "$plugin_name/dist/README.md" ".dev/plugins/$versioned_name/"
    fi
    if [ -d "$plugin_name/dist/lib" ]; then
        cp -r "$plugin_name/dist/lib" ".dev/plugins/$versioned_name/"
    fi
    if [ -f "$plugin_name/dist/mf-manifest.json" ]; then
        cp "$plugin_name/dist/mf-manifest.json" ".dev/plugins/$versioned_name/"
    fi
    if [ -f "$plugin_name/dist/mf-stats.json" ]; then
        cp "$plugin_name/dist/mf-stats.json" ".dev/plugins/$versioned_name/"
    fi
    if [ -f "$plugin_name/dist/package.json" ]; then
        cp "$plugin_name/dist/package.json" ".dev/plugins/$versioned_name/"
    fi

    # Copy files from plugin source directory - only if they exist
    echo "Copying source files..."
    if [ -d "$plugin_name/cue.mod" ]; then
        cp -r "$plugin_name/cue.mod" ".dev/plugins/$versioned_name/"
    fi
    if [ -d "$plugin_name/schemas" ]; then
        cp -r "$plugin_name/schemas" ".dev/plugins/$versioned_name/"
    fi

    echo "✅ $plugin_name organization completed as $versioned_name!"
}

# Main execution starts here
echo "Processing ${#PLUGINS[@]} plugins with versioned naming..."

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

# Step 2: Load plugin name mapping
load_plugin_mapping

# Step 3: Process each plugin
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
        echo "✅ $plugin completed successfully as $versioned_name!"
    else
        echo "❌ $plugin build failed!"
        ((failed_builds++))
    fi
done

# Step 4: Final verification and summary
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
        if [ -d ".dev/plugins/$versioned_plugin" ]; then
            echo "   ✓ .dev/plugins/$versioned_plugin/"
        fi
    done
fi

echo ""
echo "🎯 All completed plugins are now available in the .dev/plugins/ directory with versioned names"
echo "📁 Location: $(pwd)/.dev/plugins/"

if [ $failed_builds -eq 0 ] && [ $skipped_builds -eq 0 ]; then
    echo ""
    echo "🎊 ALL PLUGINS PROCESSED SUCCESSFULLY WITH VERSIONED NAMING!"
else
    echo ""
    echo "⚠️  Some plugins encountered issues. Check the log above for details."
fi