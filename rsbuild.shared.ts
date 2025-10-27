// Copyright 2024 The Perses Authors
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import { ModuleFederationOptions, pluginModuleFederation } from '@module-federation/rsbuild-plugin';
import { mergeRsbuildConfig, RsbuildConfig } from '@rsbuild/core';

/** The base path for all plugin assets. This should match the path where plugins are stored on the Perses server.
 * @see {@link https://github.com/perses/perses}
 */
const PLUGINS_PATH = '/plugins';

/**
 * Standard shared dependencies for Perses plugins.
 * These dependencies are marked as singletons to ensure only one instance
 * is loaded across all plugins and the host application.
 *
 * Dependencies are organized by category for better maintainability.
 */
export const SHARED_DEPENDENCIES = {
  // React ecosystem
  react: {
    requiredVersion: '18.2.0',
    singleton: true,
  },
  'react-dom': {
    requiredVersion: '18.2.0',
    singleton: true,
  },
  'react-hook-form': {
    singleton: true,
  },
  'react-router-dom': {
    singleton: true,
  },

  // Emotion CSS-in-JS
  '@emotion/react': {
    requiredVersion: '^11.11.3',
    singleton: true,
  },
  '@emotion/styled': {
    singleton: true,
  },

  // Form handling
  '@hookform/resolvers': {
    singleton: true,
  },

  // Data fetching
  '@tanstack/react-query': {
    singleton: true,
  },

  // Date/time utilities
  'date-fns': {
    singleton: true,
  },
  'date-fns-tz': {
    singleton: true,
  },

  // Utilities
  lodash: {
    singleton: true,
  },

  // Charts and visualization
  echarts: {
    singleton: true,
  },

  // Perses ecosystem
  '@perses-dev/components': {
    singleton: true,
  },
  '@perses-dev/plugin-system': {
    singleton: true,
  },
  '@perses-dev/explore': {
    singleton: true,
  },
  '@perses-dev/dashboards': {
    singleton: true,
  },
} as const;

/**
 * Type-safe shared dependency configuration
 */
export type SharedDependencyConfig = typeof SHARED_DEPENDENCIES;

/**
 * Configuration options for building a Perses plugin with rsbuild.
 * @see {@link createConfigForPlugin}
 */
interface PluginConfigOptions {
  /**
   * The name of the plugin. Typically PascalCase
   */
  name: string;
  /**
   * Any rsbuild configuration options to merge with the base config. Note that
   * the `server.port` and `output.assetPrefix` are automatically set based on
   * the plugin name but can be overridden here. Additionally, the
   * ModuleFederation plugin is automatically added after any plugins specified
   * here. It's options can be configured via the `moduleFederation` property.
   *
   * @see {@link getRsbuildConfig}
   */
  rsbuildConfig?: RsbuildConfig;
  /**
   * Module Federation configuration options to pass to the Module Federation
   * plugin. Note that the `name` is inherited from the `name` property defined
   * alongside this object. Any values defined here will be merged over the base
   * config.
   *
   * @see {@link getBaseModuleFederationConfig}
   */
  moduleFederation?: ModuleFederationOptions;
}

/**
 * Creates a complete rsbuild configuration for a Perses plugin, including sensible defaults for the dev server, output
 * asset prefix, and module federation plugin configuration.
 *
 * @param options Configuration options for the plugin build.
 * @returns A complete rsbuild configuration object.
 *
 * @example
 * ```ts
 * import { createConfigForPlugin } from './rsbuild.shared';
 * import type { RsbuildConfig } from '@rsbuild/core';
 * import type { ModuleFederationOptions } from '@module-federation/rsbuild-plugin';
 *
 * const config: RsbuildConfig = createConfigForPlugin({
 *   name: 'MyPlugin',
 *   rsbuildConfig: {
 *     // any additional rsbuild config options here
 *   },
 *   moduleFederation: {
 *     // any additional module federation options here
 *   },
 * });
 * ```
 */
export function createConfigForPlugin(options: PluginConfigOptions) {
  const { name, rsbuildConfig = {}, moduleFederation = {} } = options;

  const mfConfig: ModuleFederationOptions = {
    ...getBaseModuleFederationConfig(name), // base config first
    ...moduleFederation, // then any user config overrides
  };

  const baseConfig: RsbuildConfig = getRsbuildConfig(name);
  const rsbuildConfigWithMfPlugin: RsbuildConfig = { plugins: [pluginModuleFederation(mfConfig)] };

  return mergeRsbuildConfig(
    baseConfig, // base config first
    rsbuildConfig, // then any user config overrides
    rsbuildConfigWithMfPlugin // then add the Module Federation plugin last
  );
}

function getAssetPrefix(name: string): string {
  return `${PLUGINS_PATH}/${name}/`;
}

function getRsbuildConfig(name: string): RsbuildConfig {
  const assetPrefix = getAssetPrefix(name);

  return {
    server: {
      port: 3000 + Math.floor(Math.random() * 1000),
      strictPort: false,
      printUrls: process.env.PERSES_CLI
        ? ({ port, protocol }) => {
            // custom output for `percli plugin start` to detect port for dev server
            console.log(`[PERSES_PLUGIN] NAME="${name}" PORT="${port}" PROTOCOL="${protocol}"\n`);
            console.log(`Local: ${protocol}://localhost:${port}`);
            return [];
          }
        : true,
      cors: { origin: '*' },
    },
    dev: { assetPrefix },
    source: { entry: { main: './src/index-federation.ts' } },
    output: {
      copy: [{ from: 'package.json' }, { from: 'README.md' }, { from: '../LICENSE', to: './LICENSE', toType: 'file' }],
      distPath: {
        root: 'dist',
        js: '__mf/js',
        css: '__mf/css',
        font: '__mf/font',
      },
    },
    tools: {
      htmlPlugin: false,
      rspack: (config) => {
        config.output = config.output || {};
        // Set to 'auto' to allow runtime override via __webpack_public_path__
        config.output.publicPath = 'auto';
        return config;
      },
    },
  };
}

function getBaseModuleFederationConfig(name: string): ModuleFederationOptions {
  return {
    name,
    dts: false,
    runtime: false,
    getPublicPath: `function() { const prefix = window.PERSES_PLUGIN_ASSETS_PATH || window.PERSES_APP_CONFIG?.api_prefix || ""; return prefix + "${getAssetPrefix(name)}"; }`,
    shared: SHARED_DEPENDENCIES,
  };
}

/**
 * Helper function to merge additional dependencies with the standard shared dependencies.
 * Useful for plugins that need extra dependencies not covered by SHARED_DEPENDENCIES.
 *
 * @param additionalDeps Additional shared dependencies specific to the plugin
 * @returns Merged shared dependencies configuration
 *
 * @example
 * ```ts
 * const customShared = mergeSharedDependencies({
 *   '@perses-dev/core': { singleton: true },
 *   'use-resize-observer': { requiredVersion: '^9.1.0', singleton: true }
 * });
 * ```
 */
export function mergeSharedDependencies(additionalDeps: Record<string, any>) {
  return {
    ...SHARED_DEPENDENCIES,
    ...additionalDeps,
  };
}

/**
 * Common shared dependencies for plugins that need additional Perses packages.
 * Includes all standard dependencies plus commonly used extras.
 */
export const EXTENDED_SHARED_DEPENDENCIES = mergeSharedDependencies({
  '@perses-dev/core': { singleton: true },
});

/**
 * Creates a simplified configuration for standard Perses visualization plugins.
 * This is a convenience function that provides sensible defaults for most chart plugins.
 *
 * @param name The name of the plugin (PascalCase)
 * @param port The dev server port number
 * @param exposes Module Federation expose configuration
 * @param additionalShared Optional additional shared dependencies
 * @returns A complete rsbuild configuration object
 *
 * @example
 * ```ts
 * import { createVisualizationPlugin } from './rsbuild.shared';
 *
 * // Simple usage
 * export default createVisualizationPlugin('MyChart', 3020, {
 *   './MyChart': './src/plugins/MyChart.tsx'
 * });
 *
 * // With additional shared dependencies
 * export default createVisualizationPlugin('MyChart', 3020, {
 *   './MyChart': './src/plugins/MyChart.tsx'
 * }, {
 *   'use-resize-observer': { requiredVersion: '^9.1.0', singleton: true }
 * });
 * ```
 */
export function createVisualizationPlugin(
  name: string,
  port: number,
  exposes: Record<string, string>,
  additionalShared?: Record<string, any>
) {
  return createConfigForPlugin({
    name,
    rsbuildConfig: {
      server: { port },
      plugins: [
        // Most visualization plugins use React
        require('@rsbuild/plugin-react').pluginReact(),
      ],
    },
    moduleFederation: {
      exposes,
      shared: additionalShared ? mergeSharedDependencies(additionalShared) : undefined,
    },
  });
}
