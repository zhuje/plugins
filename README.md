# Perses Plugins

This repository contains the core plugins for [Perses](https://github.com/perses/perses)

## Development

The instructions are for the `Table` plugin, replace the name accordingly.

1. Install Cue deps with `go run ./scripts/get-schemas-deps/get-schemas-deps.go`
2. Start development server of the plugin: `cd Table; npm run dev`
3. Update the Perses configuration `config.yaml` to use development server for this plugin:
   ```yaml
   plugin:
     dev_environment:
       plugins:
         - name: Table
           disable_schema: false
           url: http://localhost:3005
           absolute_path: /absolute/path/to/plugin/repository/table
   ```
4. Start Perses backend (in `perses` repository): `./scripts/api_backend_dev.sh`
5. Start Perses frontend (in `perses` repository): `cd ui; npm run start`
