module: "github.com/perses/plugins/prometheus@v0"
language: {
	version: "v0.11.0"
}
source: {
	kind: "git"
}
deps: {
	"github.com/perses/perses/cue@v0": {
		v:       "v0.0.1-test"
		default: true
	}
}
