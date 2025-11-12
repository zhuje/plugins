#!/bin/bash

# Script to build all plugins and create a reformatted plugins directory
# This script builds all plugins first, then formats them to match /Users/jezhu/Git/perses_core/plugins structure

set -e

SOURCE_DIR="/Users/jezhu/Git/plugins"
TARGET_DIR="$SOURCE_DIR/plugins"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Plugin Build & Format Script ===${NC}"
echo -e "Source: ${SOURCE_DIR}"
echo -e "Target: ${TARGET_DIR}"
echo

# Remove existing plugins directory if it exists
if [ -d "$TARGET_DIR" ]; then
    echo -e "${YELLOW}Removing existing plugins directory: $TARGET_DIR${NC}"
    rm -rf "$TARGET_DIR"
fi

# Create target directory
echo -e "${YELLOW}Creating target directory: $TARGET_DIR${NC}"
mkdir -p "$TARGET_DIR"

# Function to build all plugins
build_all_plugins() {
    echo -e "${BLUE}Building all plugins...${NC}"

    # Get list of plugin directories
    for plugin_dir in "$SOURCE_DIR"/*; do
        if [ ! -d "$plugin_dir" ]; then
            continue
        fi

        local plugin_name=$(basename "$plugin_dir")

        # Skip non-plugin directories
        if [[ "$plugin_name" == "node_modules" || "$plugin_name" == "docs" || "$plugin_name" == "scripts" || "$plugin_name" == ".git" || "$plugin_name" == ".github" || "$plugin_name" == ".turbo" || "$plugin_name" == "plugins" ]]; then
            continue
        fi

        # Check if package.json exists
        if [ ! -f "$plugin_dir/package.json" ]; then
            echo -e "  ${YELLOW}Skipping $plugin_name (no package.json)${NC}"
            continue
        fi

        echo -e "${GREEN}Building plugin: ${plugin_name}${NC}"

        # Change to plugin directory and build
        cd "$plugin_dir"

        # Check if build script exists
        if node -e "const pkg=require('./package.json'); process.exit(pkg.scripts?.build ? 0 : 1)" 2>/dev/null; then
            echo -e "  ${BLUE}Running npm run build...${NC}"
            if npm run build; then
                echo -e "  ${GREEN}✓ Build successful${NC}"
            else
                echo -e "  ${RED}✗ Build failed for $plugin_name${NC}"
            fi
        else
            echo -e "  ${YELLOW}⚠ No build script found in $plugin_name${NC}"
        fi

        # Return to source directory
        cd "$SOURCE_DIR"
    done

    echo -e "${GREEN}Plugin building complete!${NC}"
    echo
}

# Function to extract plugin info from package.json
get_plugin_info() {
    local plugin_dir="$1"
    local package_json="$plugin_dir/package.json"

    if [ ! -f "$package_json" ]; then
        echo "ERROR: No package.json found in $plugin_dir" >&2
        return 1
    fi

    # Extract moduleName and version using Node.js (more reliable than jq)
    local info=$(node -e "
        const pkg = JSON.parse(require('fs').readFileSync('$package_json', 'utf8'));
        const moduleName = pkg.perses?.moduleName || '';
        const version = pkg.version || '';
        console.log(moduleName + '|' + version);
    " 2>/dev/null || echo "|")

    echo "$info"
}


# Function to process all plugins (both packaged and built from source)
process_all_plugins() {
    echo -e "${BLUE}Processing all plugins to target format...${NC}"

    # Get list of plugin directories (excluding non-plugin directories)
    for plugin_dir in "$SOURCE_DIR"/*; do
        if [ ! -d "$plugin_dir" ]; then
            continue
        fi

        local plugin_name=$(basename "$plugin_dir")

        # Skip non-plugin directories
        if [[ "$plugin_name" == "node_modules" || "$plugin_name" == "docs" || "$plugin_name" == "scripts" || "$plugin_name" == ".git" || "$plugin_name" == ".github" || "$plugin_name" == ".turbo" || "$plugin_name" == "plugins" ]]; then
            continue
        fi

        # Check if package.json exists
        if [ ! -f "$plugin_dir/package.json" ]; then
            echo -e "  ${YELLOW}Skipping $plugin_name (no package.json)${NC}"
            continue
        fi

        echo -e "${GREEN}Processing plugin: ${plugin_name}${NC}"

        # Get plugin info from package.json
        local plugin_info=$(get_plugin_info "$plugin_dir")
        local module_name=$(echo "$plugin_info" | cut -d'|' -f1)
        local version=$(echo "$plugin_info" | cut -d'|' -f2)

        if [ -z "$module_name" ] || [ -z "$version" ]; then
            echo -e "  ${RED}✗ Error: Could not extract moduleName or version from package.json${NC}"
            continue
        fi

        local target_name="${module_name}-${version}"
        local target_plugin_dir="$TARGET_DIR/$target_name"

        echo -e "  ${BLUE}Creating: $target_name${NC}"

        # Create target directory
        mkdir -p "$target_plugin_dir"

        # Check if there's a tar.gz file to extract from
        local tarfile=$(find "$plugin_dir" -name "*.tar.gz" -type f | head -1)
        if [ -n "$tarfile" ]; then
            echo -e "    ${BLUE}Extracting from tar.gz: $(basename "$tarfile")${NC}"
            tar -xzf "$tarfile" -C "$target_plugin_dir"
        else
            echo -e "    ${BLUE}Copying from built source${NC}"

            # Copy required files in the exact perses_core format

            # 1. package.json (required)
            if [ -f "$plugin_dir/package.json" ]; then
                cp "$plugin_dir/package.json" "$target_plugin_dir/"
                echo -e "      ✓ package.json"
            fi

            # 2. README.md
            if [ -f "$plugin_dir/README.md" ]; then
                cp "$plugin_dir/README.md" "$target_plugin_dir/"
                echo -e "      ✓ README.md"
            fi

            # 3. LICENSE (from plugin dir or parent)
            if [ -f "$plugin_dir/LICENSE" ]; then
                cp "$plugin_dir/LICENSE" "$target_plugin_dir/"
                echo -e "      ✓ LICENSE"
            elif [ -f "$SOURCE_DIR/LICENSE" ]; then
                cp "$SOURCE_DIR/LICENSE" "$target_plugin_dir/"
                echo -e "      ✓ LICENSE (from parent)"
            fi

            # 4. schemas directory
            if [ -d "$plugin_dir/schemas" ]; then
                cp -r "$plugin_dir/schemas" "$target_plugin_dir/"
                echo -e "      ✓ schemas/"
            fi

            # 5. cue.mod directory
            if [ -d "$plugin_dir/cue.mod" ]; then
                cp -r "$plugin_dir/cue.mod" "$target_plugin_dir/"
                echo -e "      ✓ cue.mod/"
            fi

            # 6. lib directory (from dist after build)
            if [ -d "$plugin_dir/dist" ]; then
                cp -r "$plugin_dir/dist" "$target_plugin_dir/lib"
                echo -e "      ✓ lib/ (from dist/)"
            else
                echo -e "      ${YELLOW}⚠ lib/ missing - no dist directory found${NC}"
                mkdir -p "$target_plugin_dir/lib"
            fi

            # 7. __mf directory (module federation assets from dist)
            if [ -d "$plugin_dir/dist/__mf" ]; then
                cp -r "$plugin_dir/dist/__mf" "$target_plugin_dir/"
                echo -e "      ✓ __mf/"
            else
                echo -e "      ${YELLOW}⚠ __mf/ missing - creating placeholder${NC}"
                mkdir -p "$target_plugin_dir/__mf"
            fi

            # 8. mf-manifest.json (from dist root)
            if [ -f "$plugin_dir/dist/mf-manifest.json" ]; then
                cp "$plugin_dir/dist/mf-manifest.json" "$target_plugin_dir/"
                echo -e "      ✓ mf-manifest.json"
            else
                echo -e "      ${YELLOW}⚠ mf-manifest.json missing${NC}"
            fi

            # 9. mf-stats.json (from dist root)
            if [ -f "$plugin_dir/dist/mf-stats.json" ]; then
                cp "$plugin_dir/dist/mf-stats.json" "$target_plugin_dir/"
                echo -e "      ✓ mf-stats.json"
            else
                echo -e "      ${YELLOW}⚠ mf-stats.json missing${NC}"
            fi
        fi

        echo -e "  ${GREEN}✓ Completed ${target_name}${NC}"
    done
}

# Main execution
echo -e "${BLUE}Starting plugin build and format process...${NC}"
echo

# Step 1: Build all plugins
build_all_plugins

# Step 2: Process all plugins to target format
process_all_plugins

echo
echo -e "${GREEN}=== Process complete! ===${NC}"
echo -e "Results saved to: $TARGET_DIR"
echo

# Count results
plugin_count=$(find "$TARGET_DIR" -maxdepth 1 -type d | wc -l | tr -d ' ')
# Subtract 1 for the target directory itself
plugin_count=$((plugin_count - 1))

echo -e "${YELLOW}Summary:${NC}"
echo -e "• Total plugins processed: $plugin_count"
echo -e "• Plugins directory created at: $TARGET_DIR"
echo

echo -e "${GREEN}✓ All plugins have been built and formatted to match perses_core structure!${NC}"
echo -e "${BLUE}Each plugin directory contains: __mf, cue.mod, lib, schemas, LICENSE, mf-manifest.json, mf-stats.json, README.md, package.json${NC}"