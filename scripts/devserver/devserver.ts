import { resolve } from 'node:path';
import { EventEmitter } from 'events';
import { createRsbuild, RsbuildConfig, RsbuildDevServer, RsbuildInstance } from '@rsbuild/core';
import express from 'express';
import packagejson from '../../package.json';

interface Plugins {
  prefix: string;
  rsbuild: RsbuildInstance;
}

const PROXY_PORT = 3005;

EventEmitter.defaultMaxListeners = 20;

// based on the example at:
// https://github.com/rspack-contrib/rspack-examples/blob/03aa9913fe1208173111488860a56bfd56d15aaf/rsbuild/express/server.mjs

async function start() {
  const plugins: Plugins[] = [];
  for (const workspace of packagejson.workspaces) {
    const path = resolve(workspace);
    const rsbuildConfig: RsbuildConfig = (await import(`${path}/rsbuild.config`)).default;
    const rsbuild = await createRsbuild({ cwd: path, rsbuildConfig });
    plugins.push({ prefix: rsbuildConfig.dev!.assetPrefix as string, rsbuild });
  }

  const app = express();
  const devServers: RsbuildDevServer[] = [];
  for (const plugin of plugins) {
    console.log(`Starting dev server for ${plugin.prefix} ...`);
    const devServer = await plugin.rsbuild.createDevServer();
    app.use(devServer.middlewares);
    devServers.push(devServer);

    // FIXME: Workaround to avoid some kind of deadlock when starting multiple dev servers
    await new Promise<void>((resolve, _reject) => {
      plugin.rsbuild.onDevCompileDone(() => {
        setTimeout(resolve, 3000);
      });
    });
  }

  const httpServer = app.listen(PROXY_PORT, () => {
    Promise.all(devServers.map((s) => s.afterListen()));

    console.log();
    console.log('***********************');
    console.log('Started all dev servers:');
    plugins.forEach((p) => console.log(`- http://localhost:${PROXY_PORT}${p.prefix}mf-manifest.json`));
  });
  devServers.forEach((s) => s.connectWebSocket({ server: httpServer }));

  return {
    close: async () => {
      await Promise.all(devServers.map((s) => s.close()));
      httpServer.close();
    },
  };
}

start();
