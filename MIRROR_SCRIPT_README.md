# Plugin Build & Format Script

## Overview

This script (`mirror_plugins_format.sh`) builds all plugins and creates a local `plugins` directory with properly formatted plugin structures that match `/Users/jezhu/Git/perses_core/plugins`.

## What it does

### Step 1: Build All Plugins
- Automatically runs `npm run build` in each plugin directory
- Checks for build script existence before attempting to build
- Provides colored output showing build progress and results

### Step 2: Format All Plugins
The script creates properly formatted plugin directories with the exact structure expected:

**Required structure for each plugin:**
- `__mf/` - Module federation assets
- `cue.mod/` - CUE module configuration
- `lib/` - Built library files (from `dist/`)
- `schemas/` - Plugin schemas
- `LICENSE` - License file
- `mf-manifest.json` - Module federation manifest
- `mf-stats.json` - Module federation statistics
- `README.md` - Plugin documentation
- `package.json` - Package configuration

### For Packaged Plugins (with .tar.gz files)
- Extracts existing `.tar.gz` files which already contain the proper structure
- Example: `scatterchart/ScatterChart-0.9.0.tar.gz` → `plugins/ScatterChart-0.9.0/`

### For Unpackaged Plugins (built from source)
- Reads `package.json` to extract `perses.moduleName` and `version`
- Creates directory named `${moduleName}-${version}`
- Copies files from build output (`dist/`) and source directories
- Ensures all required files are present

## Directory Structure Transformation

### Before (Source Format)
```
/Users/jezhu/Git/plugins/
├── scatterchart/
│   ├── ScatterChart-0.9.0.tar.gz  # ✅ Packaged
│   ├── src/
│   ├── dist/ (after build)
│   └── package.json
├── clickhouse/  # Build from source
│   ├── src/
│   ├── dist/ (created by build)
│   └── package.json (moduleName: "ClickHouse", version: "0.2.0")
└── ...
```

### After (Local plugins/ directory)
```
/Users/jezhu/Git/plugins/plugins/
├── ScatterChart-0.9.0/          # ✅ Extracted from tar.gz
│   ├── __mf/
│   ├── lib/
│   ├── schemas/
│   ├── cue.mod/
│   ├── LICENSE
│   ├── mf-manifest.json
│   ├── mf-stats.json
│   ├── package.json
│   └── README.md
├── ClickHouse-0.2.0/            # ✅ Built from source
│   ├── __mf/  (from dist/)
│   ├── lib/   (from dist/)
│   ├── schemas/
│   ├── cue.mod/
│   ├── LICENSE
│   ├── mf-manifest.json
│   ├── mf-stats.json
│   ├── package.json
│   └── README.md
└── ... (all other plugins)
```

## Usage

1. **Run the script:**
   ```bash
   cd /Users/jezhu/Git/plugins
   ./mirror_plugins_format.sh
   ```

2. **The script will:**
   - **Step 1:** Build all plugins automatically using `npm run build`
   - **Step 2:** Create a local `plugins/` directory with properly formatted plugin structures
   - Display colored output showing build and formatting progress
   - Handle both packaged (.tar.gz) and source plugins seamlessly

3. **Expected output:**
   ```
   === Plugin Build & Format Script ===
   Building all plugins...
   ✓ Building plugin: barchart
   ✓ Building plugin: clickhouse
   ...
   Processing all plugins to target format...
   ✓ Processing plugin: barchart -> BarChart-0.10.0
   ✓ Processing plugin: clickhouse -> ClickHouse-0.2.0
   ...
   === Process complete! ===
   • Total plugins processed: 24
   • Plugins directory created at: /Users/jezhu/Git/plugins/plugins
   ```

## Key Features

- **🔨 Automated Building:** Builds all plugins first to ensure fresh artifacts
- **📦 Smart Processing:** Handles both packaged (.tar.gz) and source plugins
- **🎯 Exact Format Match:** Creates structure identical to `/Users/jezhu/Git/perses_core/plugins`
- **🌈 Colored Output:** Clear visual progress indicators
- **🔄 Clean Rebuild:** Removes and recreates `plugins/` directory for clean results
- **✅ Complete Structure:** Ensures all required files are present

## Plugin Types Handled

**All plugins are now processed automatically:**
- **Packaged plugins** (with .tar.gz) - extracted directly
- **Source plugins** (built during script execution) - copied from build output
- Examples: barchart, clickhouse, loki, prometheus, tempo, etc.

## Notes

- The script automatically builds all plugins before formatting
- Creates a clean `plugins/` directory each time it runs
- Uses Node.js to reliably parse `package.json` files
- Handles missing files gracefully with informative warnings
- All plugins will have the exact structure expected by perses_core