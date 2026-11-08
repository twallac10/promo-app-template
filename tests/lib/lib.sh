# Shared helpers for tests/test_*.sh. bash 3.2 compatible.
TIERS="dev stg prd"

fail() { echo "$*" >&2; exit 1; }

# Kubernetes JSON schemas for Flux CRDs, generated from the installed flux CLI
# and cached under .cache/ keyed by its version.
flux_schemas() {
  local v dir
  v=$(flux version --client -o json 2>/dev/null | jq -r .flux)
  dir="$ROOT/.cache/schemas-$v"
  if [ ! -d "$dir" ]; then
    mkdir -p "$dir.tmp"
    flux install --export | yq -o json -I0 'select(.kind=="CustomResourceDefinition")' |
      jq -c '.spec as $s | $s.versions[] | {g: $s.group, k: ($s.names.kind|ascii_downcase), v: .name, schema: .schema.openAPIV3Schema}' |
      while read -r line; do
        g=$(echo "$line" | jq -r .g); k=$(echo "$line" | jq -r .k); ver=$(echo "$line" | jq -r .v)
        mkdir -p "$dir.tmp/$g"
        echo "$line" | jq '.schema | walk(if type=="object" and has("properties") and (has("additionalProperties")|not) and ((."x-kubernetes-preserve-unknown-fields")|not) then .additionalProperties=false else . end)' > "$dir.tmp/$g/${k}_${ver}.json"
      done
    mv "$dir.tmp" "$dir"
  fi
  echo "$dir"
}

# kubeconform -strict with Flux schemas; reads manifests on stdin.
kconform() {
  local s
  s=$(flux_schemas)
  kubeconform -strict -summary -schema-location default \
    -schema-location "$s/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json" -
}

build_tier() { kubectl kustomize "$ROOT/tiers/$1"; }
