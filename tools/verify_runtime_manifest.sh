#!/bin/sh
set -u

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
MANIFEST=${1:-"$ROOT_DIR/Runtime/manifest.json"}

if [ ! -f "$MANIFEST" ]; then
    echo "Error: runtime manifest not found: $MANIFEST" >&2
    exit 64
fi

if ! ruby -rjson -e 'JSON.parse(File.read(ARGV.fetch(0)))' "$MANIFEST" 2>/dev/null; then
    echo "Error: runtime manifest is not valid JSON: $MANIFEST" >&2
    exit 65
fi

extract()
{
    ruby -rjson -e '
        value = JSON.parse(File.read(ARGV.fetch(1)))
        ARGV.fetch(0).split(".").each { |key| value = value.fetch(key) }
        puts value.nil? ? "" : value
    ' "$1" "$MANIFEST" 2>/dev/null
}

schema_version=$(extract schemaVersion)
runtime_name=$(extract runtime.name)
artifact_status=$(extract artifact.status)
artifact_delivery=$(extract artifact.delivery)
artifact_path=$(extract artifact.path)
artifact_committed=$(extract artifact.committedToGit)
artifact_sha256=$(extract artifact.sha256)
artifact_size_bytes=$(extract artifact.sizeBytes)
requires_consensus=$(extract policy.requiresConsensusBeforePush)
private_internals_allowed=$(extract policy.privateInternalsAllowed)
validation_engine_source_included=$(extract policy.validationEngineSourceIncluded)
runtime_binary_committed_by_consensus=$(extract policy.runtimeBinaryCommittedByConsensus)

if [ "$schema_version" != "slateRuntimeArtifactManifest.v1" ]; then
    echo "Error: unexpected manifest schemaVersion: $schema_version" >&2
    exit 66
fi

if [ "$runtime_name" != "slate" ]; then
    echo "Error: unexpected runtime name: $runtime_name" >&2
    exit 66
fi

if [ "$requires_consensus" != "true" ]; then
    echo "Error: manifest must require consensus before any Git push." >&2
    exit 66
fi

if [ "$private_internals_allowed" != "false" ]; then
    echo "Error: manifest must not allow private validation engine internals." >&2
    exit 66
fi

if [ "$validation_engine_source_included" != "false" ]; then
    echo "Error: manifest must not include validation engine source." >&2
    exit 66
fi

case "$artifact_delivery" in
    release-asset|installer|local-file) ;;
    *)
        echo "Error: unexpected artifact delivery: $artifact_delivery" >&2
        exit 66
        ;;
esac

case "$artifact_status" in
    pending)
        echo "Runtime manifest OK: $runtime_name artifact is pending via $artifact_delivery."
        ;;
    available)
        if [ -z "$artifact_path" ]; then
            echo "Error: available runtime artifact has no path." >&2
            exit 66
        fi
        if [ "$artifact_delivery" = "local-file" ] && [ ! -x "$ROOT_DIR/$artifact_path" ]; then
            echo "Error: local runtime artifact is not executable: $artifact_path" >&2
            exit 66
        fi
        if [ "$artifact_delivery" = "local-file" ] && [ "$artifact_committed" != "true" ]; then
            echo "Error: local runtime artifact must be marked committedToGit=true." >&2
            exit 66
        fi
        if [ "$artifact_delivery" = "local-file" ] && [ "$runtime_binary_committed_by_consensus" != "true" ]; then
            echo "Error: local runtime artifact must be marked runtimeBinaryCommittedByConsensus=true." >&2
            exit 66
        fi
        if [ "$artifact_delivery" = "local-file" ]; then
            actual_sha256=$(shasum -a 256 "$ROOT_DIR/$artifact_path" | awk '{print $1}')
            actual_size_bytes=$(stat -f '%z' "$ROOT_DIR/$artifact_path")
            if [ "$actual_sha256" != "$artifact_sha256" ]; then
                echo "Error: runtime sha256 mismatch for $artifact_path." >&2
                echo "  manifest: $artifact_sha256" >&2
                echo "  actual:   $actual_sha256" >&2
                exit 66
            fi
            if [ "$actual_size_bytes" != "$artifact_size_bytes" ]; then
                echo "Error: runtime size mismatch for $artifact_path." >&2
                echo "  manifest: $artifact_size_bytes" >&2
                echo "  actual:   $actual_size_bytes" >&2
                exit 66
            fi
        fi
        echo "Runtime manifest OK: $runtime_name artifact is available via $artifact_delivery."
        ;;
    *)
        echo "Error: unexpected artifact status: $artifact_status" >&2
        exit 66
        ;;
esac
