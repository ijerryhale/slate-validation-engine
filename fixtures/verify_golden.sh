#!/bin/sh
set -u

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_DIR=$(CDPATH= cd -- "$ROOT_DIR/.." && pwd)
SLATE_CLI=${SLATE_CLI:-"$REPO_DIR/Runtime/slate"}

if [ ! -x "$SLATE_CLI" ]; then
    echo "Error: slate CLI not found or not executable: $SLATE_CLI" >&2
    echo "Install the public runtime at Runtime/slate or set SLATE_CLI=/path/to/slate." >&2
    exit 64
fi

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/slate-public-golden.XXXXXX") || exit 66
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

normalize_stdout()
{
    REPO_DIR_FOR_PERL=$REPO_DIR perl -0pe '
        BEGIN {
            $repo = $ENV{"REPO_DIR_FOR_PERL"};
            $json = $repo;
            $json =~ s{/}{\\/}g;
        }
        s/\Q$repo\E/<repo>/g;
        s/\Q$json\E/<repo>/g;
    '
}

run_case()
{
    case_id=$1
    expected_exit=$2
    golden_path=$3
    shift 3

    raw_stdout="$TMP_DIR/$case_id.stdout.raw"
    stdout_path="$TMP_DIR/$case_id.stdout"
    stderr_path="$TMP_DIR/$case_id.stderr"

    "$SLATE_CLI" "$@" >"$raw_stdout" 2>"$stderr_path"
    actual_exit=$?

    normalize_stdout <"$raw_stdout" >"$stdout_path"

    if [ "$actual_exit" -ne "$expected_exit" ]; then
        echo "FAIL $case_id: exit $actual_exit, expected $expected_exit" >&2
        return 1
    fi

    if [ -s "$stderr_path" ]; then
        echo "FAIL $case_id: unexpected stderr" >&2
        cat "$stderr_path" >&2
        return 1
    fi

    if ! diff -u "$ROOT_DIR/$golden_path" "$stdout_path"; then
        echo "FAIL $case_id: stdout differs from $golden_path" >&2
        return 1
    fi

    echo "ok $case_id"
    return 0
}

failures=0

run_case report-movie 0 golden/report/movie.report.json \
    report --observed-state "$ROOT_DIR/observed/movie.json" || failures=$((failures + 1))
run_case analyze-movie-issues 2 golden/analyze/movie-issues.analyze.json \
    analyze --observed-state "$ROOT_DIR/observed/movie-issues.json" || failures=$((failures + 1))
run_case readiness-movie-issues 2 golden/readiness/movie-issues.readiness.txt \
    readiness --observed-state "$ROOT_DIR/observed/movie-issues.json" || failures=$((failures + 1))
run_case report-package-only 2 golden/report/package-only.report.json \
    report --package "$ROOT_DIR/media_json/valid/source-basic.json" || failures=$((failures + 1))

if [ "$failures" -ne 0 ]; then
    echo "$failures golden output check(s) failed." >&2
    exit 1
fi

echo "All public validation golden outputs match."
