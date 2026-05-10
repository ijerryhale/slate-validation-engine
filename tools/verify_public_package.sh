#!/bin/sh
set -u

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/slate-public-package.XXXXXX") || exit 66
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

EXPECTED_ROOT="$TMP_DIR/expected-root"
REQUIRED_APP="$TMP_DIR/required-app"
EXPECTED_APP_SOURCE="$TMP_DIR/expected-app-source"
ACTUAL="$TMP_DIR/actual"
ACTUAL_ROOT="$TMP_DIR/actual-root"
ACTUAL_APP_SOURCE="$TMP_DIR/actual-app-source"
MISSING="$TMP_DIR/missing"
MISSING_APP="$TMP_DIR/missing-app"
MISSING_APP_SOURCE="$TMP_DIR/missing-app-source"
UNEXPECTED="$TMP_DIR/unexpected"
UNEXPECTED_APP_SOURCE="$TMP_DIR/unexpected-app-source"
PRIVATE_SOURCE="$TMP_DIR/private-source"
PRIVATE_STRINGS="$TMP_DIR/private-strings"
PRIVATE_PATHS="$TMP_DIR/private-paths"
LOCAL_XCODE_STATE="$TMP_DIR/local-xcode-state"
VERIFY_HOME="$TMP_DIR/home"

cat >"$EXPECTED_ROOT" <<'EOF'
.gitattributes
.gitignore
LICENSE.md
README.md
Runtime/README.md
Runtime/manifest.json
Runtime/slate
docs/apple-events.md
docs/cli-contract.md
docs/fixture-policy.md
docs/report-schema.md
docs/runtime-package.md
examples/README.md
examples/examples.json
fixtures/README.md
fixtures/examples/README.md
fixtures/examples/examples.json
fixtures/fixtures.json
fixtures/golden/analyze/json-source-basic.analyze.json
fixtures/golden/readiness/xml-source-missing-path.readiness.txt
fixtures/golden/report/json-chapter-basic.report.json
fixtures/golden/report/json-source-basic.report.json
fixtures/golden/report/json-source-missing-path.report.json
fixtures/golden/report/json-source-nonlocal-url.report.json
fixtures/golden/report/xml-asset-role-text.report.json
fixtures/golden/report/xml-chapter-basic.report.json
fixtures/golden/report/xml-source-basic.report.json
fixtures/golden/report/xml-source-missing-path.report.json
fixtures/golden/report/xml-source-nonlocal-url.report.json
fixtures/media_img/valid/chapter_probe_a.png
fixtures/media_img/valid/chapter_probe_b.png
fixtures/media_img/valid/chapter_probe_c.png
fixtures/media_json/invalid/source-missing-path.json
fixtures/media_json/invalid/source-nonlocal-url.json
fixtures/media_json/valid/chapter-basic.json
fixtures/media_json/valid/source-basic.json
fixtures/media_mov/valid/source-chapters-crop.mov
fixtures/media_pkg/invalid/source-missing-path.itmsp/metadata.xml
fixtures/media_pkg/invalid/source-nonlocal-url.itmsp/metadata.xml
fixtures/media_pkg/valid/asset-role-text.itmsp/metadata.xml
fixtures/media_pkg/valid/chapter-basic.itmsp/metadata.xml
fixtures/media_pkg/valid/source-chapters-crop.itmsp/chapter_img/chapter-crop-01.png
fixtures/media_pkg/valid/source-chapters-crop.itmsp/chapter_img/chapter-crop-02.png
fixtures/media_pkg/valid/source-chapters-crop.itmsp/chapter_img/chapter-crop-03.png
fixtures/media_pkg/valid/source-chapters-crop.itmsp/metadata.xml
fixtures/media_pkg/valid/source-basic.itmsp/metadata.xml
fixtures/media_sub/valid/itt/dialogue-basic.itt
fixtures/media_sub/valid/itt/dialogue-regions.itt
fixtures/media_sub/valid/itt/sidecar-derived.itt
fixtures/media_sub/valid/scc/caption-basic.scc
fixtures/media_sub/valid/srt/subtitle-basic.srt
fixtures/media_sub/valid/ttml/source-basic-01-dialogue.ttml
fixtures/media_sub/valid/ttml/source-basic-01-sdh.ttml
fixtures/verify_golden.sh
public-repo.json
schemas/runtime-manifest.schema.json
schemas/validation-report.schema.json
tools/README.md
tools/verify_public_package.sh
tools/verify_runtime_manifest.sh
EOF

cat >"$REQUIRED_APP" <<'EOF'
slate-application/.gitignore
slate-application/README.md
slate-application/build_public_apps.sh
slate-application/Runtime/SlateChapterRuntime
slate-application/Runtime/SlatePackageRuntime
slate-application/Runtime/SlateReviewRuntime
slate-application/Runtime/SlateTimelineRuntime
slate-application/Runtime/SlateTrackRuntime
slate-application/Runtime/SlateValidationRuntime
slate-application/Runtime/libSlateRuntime.a
slate-application/Slate.xcodeproj/project.pbxproj
slate-application/Slate.xcodeproj/xcshareddata/xcschemes/Slate.xcscheme
slate-application/Slate.xcodeproj/xcshareddata/xcschemes/paneharness.xcscheme
slate-application/Slate/Slate/Runtime/SlateRuntimeManifest.json
slate-application/_tools/harnessapp/Info.plist
slate-application/_tools/harnessapp/README.md
slate-application/_tools/harnessapp/paneharness.swift
slate-application/public-application.json
EOF

sort -o "$EXPECTED_ROOT" "$EXPECTED_ROOT"
sort -o "$REQUIRED_APP" "$REQUIRED_APP"

public_app_source_allowlist()
{
    ruby - "$1" "$2" <<'RUBY'
project_file = ARGV.fetch(0)
app_dir = File.expand_path(ARGV.fetch(1))
text = File.read(project_file)
objects = {}

forbidden_public_source_paths = %w[
  Slate/Controller/AppController+MoviePersistence.m
  Slate/Controller/AppController+TrailerExport.m
  Slate/OtherSources/ErrorException.h
  Slate/OtherSources/ErrorException.m
  Slate/OtherSources/NSImage+movie.h
  Slate/OtherSources/NSImage+movie.m
  Slate/OtherSources/NSNumber+MacTypes.h
  Slate/OtherSources/NSNumber+MacTypes.m
  Slate/OtherSources/NSString+MacTypes.h
  Slate/OtherSources/NSString+MacTypes.m
  Slate/OtherSources/RuntimeCLI.h
  Slate/Slate/MediaSupport/SMAudioLayoutSupport.h
  Slate/View/ConnStatusView.h
  Slate/View/ConnStatusView.m
]

present_forbidden = forbidden_public_source_paths.select { |path| File.exist?(File.join(app_dir, path)) }
unless present_forbidden.empty?
  warn "error: forbidden private Slate.app source/header file(s) present:"
  present_forbidden.sort.each { |path| warn "  - #{path}" }
  exit 65
end

project_references_forbidden = forbidden_public_source_paths.select do |path|
  name = File.basename(path)
  text.include?("/* #{name} */") || text.include?("/* #{name} in Sources */")
end
unless project_references_forbidden.empty?
  warn "error: forbidden private Slate.app source/header project reference(s) present:"
  project_references_forbidden.sort.each { |path| warn "  - #{path}" }
  exit 65
end

text.each_line do |line|
  next unless line =~ /^\t\t([0-9A-F]+)(?: \/\* ([^*]+) \*\/)? = \{(.*)\};\s*$/
  id = Regexp.last_match(1)
  comment = Regexp.last_match(2)
  body = Regexp.last_match(3)
  isa = body[/\bisa = ([^;]+);/, 1]
  objects[id] = { comment: comment, body: body, isa: isa }
end

text.scan(/^\t\t([0-9A-F]+)(?: \/\* ([^*]+) \*\/)? = \{\n(.*?)^\t\t\};/m) do |id, comment, body|
  isa = body[/\bisa = ([^;]+);/, 1]
  objects[id] = { comment: comment, body: body, isa: isa }
end

parents = {}
objects.each do |id, object|
  next unless object[:isa] == "PBXGroup"
  children = object[:body][/children = \((.*?)\);/m, 1].to_s
  children.scan(/\b([0-9A-F]{24})\b/) { |child| parents[child.first] = id }
end

unquote = lambda do |value|
  next nil if value.nil?
  value = value.strip
  value.start_with?('"') && value.end_with?('"') ? value[1..-2].gsub('\"', '"') : value
end

group_path = nil
group_path = lambda do |id|
  object = objects[id]
  next [] unless object
  source_tree = object[:body][/sourceTree = ([^;]+);/, 1].to_s.strip
  path = unquote.call(object[:body][/\bpath = ((?:"(?:\\.|[^"])*")|[^;]+);/, 1])
  base = []
  base = group_path.call(parents[id]) if source_tree != "SOURCE_ROOT" && parents[id]
  path ? base + [path] : base
end

file_path = lambda do |id|
  object = objects[id]
  next nil unless object
  source_tree = object[:body][/sourceTree = ([^;]+);/, 1].to_s.strip
  next nil if ["<absolute>", "SDKROOT", "BUILT_PRODUCTS_DIR"].include?(source_tree)
  path = unquote.call(object[:body][/\bpath = ((?:"(?:\\.|[^"])*")|[^;]+);/, 1]) || object[:comment]
  base = source_tree == "SOURCE_ROOT" ? [] : group_path.call(parents[id])
  (base + [path]).join("/")
end

build_file_ref = {}
objects.each do |id, object|
  next unless object[:isa] == "PBXBuildFile"
  ref = object[:body][/\bfileRef = ([0-9A-F]+)\b/, 1]
  build_file_ref[id] = ref if ref
end

allowlist = []
unresolved_sources = []
objects.each_value do |object|
  next unless object[:isa] == "PBXSourcesBuildPhase"
  files = object[:body][/files = \((.*?)\);/m, 1].to_s
  files.scan(/\b([0-9A-F]{24})\b/) do |build_id|
    ref = build_file_ref[build_id.first]
    path = file_path.call(ref) if ref
    if path.nil?
      unresolved_sources << build_id.first
    elsif path.match?(/\.(?:m|mm|c|cc|cpp|swift)$/)
      allowlist << path
    end
  end
end

prefix_headers = text.scan(/GCC_PREFIX_HEADER = ([^;]+);/).flatten.map { |value| unquote.call(value) }.uniq
allowlist.concat(prefix_headers.select { |path| File.file?(File.join(app_dir, path)) })

local_headers = Dir.chdir(app_dir) { Dir.glob("{Slate,_tools}/**/*.{h,hpp,pch}") }.sort
headers_by_basename = local_headers.group_by { |path| File.basename(path) }
queue = allowlist.dup
unresolved_imports = []

until queue.empty?
  relative_path = queue.shift
  absolute_path = File.join(app_dir, relative_path)
  next unless File.file?(absolute_path)

  File.readlines(absolute_path, chomp: true).each do |line|
    next unless line =~ /^\s*#\s*(?:import|include)\s+"([^"]+)"/

    import = Regexp.last_match(1)
    candidates = []
    relative_candidate = File.expand_path(File.join(File.dirname(absolute_path), import))
    if relative_candidate.start_with?(app_dir + File::SEPARATOR)
      candidate = relative_candidate.delete_prefix(app_dir + File::SEPARATOR)
      candidates << candidate if local_headers.include?(candidate)
    end
    candidates.concat(local_headers.select { |path| path.end_with?("/#{import}") || path == import })
    candidates.concat(headers_by_basename.fetch(File.basename(import), []))

    resolved = candidates.uniq.first
    if resolved.nil?
      unresolved_imports << "#{relative_path}: #{import}"
      next
    end

    next if allowlist.include?(resolved)
    allowlist << resolved
    queue << resolved
  end
end

unless unresolved_sources.empty?
  warn "error: unresolved source build file references:"
  unresolved_sources.uniq.sort.each { |id| warn "  - #{id}" }
  exit 65
end

unless unresolved_imports.empty?
  warn "error: unresolved local header import(s):"
  unresolved_imports.uniq.sort.each { |entry| warn "  - #{entry}" }
  exit 65
end

puts allowlist.uniq.sort
RUBY
}

cd "$ROOT_DIR" || exit 66
mkdir -p "$VERIFY_HOME" || exit 66

find . -type f ! -path './.git/*' -print \
    | sed 's#^\./##' \
    | LC_ALL=C sort >"$ACTUAL"

grep -v '^slate-application/' "$ACTUAL" >"$ACTUAL_ROOT"

comm -23 "$EXPECTED_ROOT" "$ACTUAL_ROOT" >"$MISSING"
comm -13 "$EXPECTED_ROOT" "$ACTUAL_ROOT" >"$UNEXPECTED"

: >"$MISSING_APP"
while IFS= read -r path; do
    if [ ! -f "$path" ]; then
        echo "$path" >>"$MISSING_APP"
    fi
done <"$REQUIRED_APP"

failures=0

if [ -e slate-application/_tools/harnessapp/ae_eventids.txt ]; then
    echo "Error: private Apple Event ID inventory leaked into public package:" >&2
    echo "  slate-application/_tools/harnessapp/ae_eventids.txt" >&2
    failures=$((failures + 1))
fi

if public_app_source_allowlist "slate-application/Slate.xcodeproj/project.pbxproj" "slate-application" >"$EXPECTED_APP_SOURCE"; then
    {
        if [ -d slate-application/Slate ]; then
            find slate-application/Slate -type f \( \
                -name '*.m' -o \
                -name '*.mm' -o \
                -name '*.c' -o \
                -name '*.cc' -o \
                -name '*.cpp' -o \
                -name '*.swift' -o \
                -name '*.h' -o \
                -name '*.hpp' -o \
                -name '*.pch' \
            \) -print
        fi
        if [ -d slate-application/_tools/harnessapp ]; then
            find slate-application/_tools/harnessapp -type f \( \
                -name '*.m' -o \
                -name '*.mm' -o \
                -name '*.c' -o \
                -name '*.cc' -o \
                -name '*.cpp' -o \
                -name '*.swift' -o \
                -name '*.h' -o \
                -name '*.hpp' -o \
                -name '*.pch' \
            \) -print
        fi
    } | sed 's#^slate-application/##' | LC_ALL=C sort >"$ACTUAL_APP_SOURCE"

    comm -23 "$EXPECTED_APP_SOURCE" "$ACTUAL_APP_SOURCE" >"$MISSING_APP_SOURCE"
    comm -13 "$EXPECTED_APP_SOURCE" "$ACTUAL_APP_SOURCE" >"$UNEXPECTED_APP_SOURCE"
else
    echo "Error: could not derive public Slate application source allowlist." >&2
    failures=$((failures + 1))
    : >"$MISSING_APP_SOURCE"
    : >"$UNEXPECTED_APP_SOURCE"
fi

if [ -s "$MISSING" ]; then
    echo "Error: required public package file(s) missing:" >&2
    sed 's/^/  /' "$MISSING" >&2
    failures=$((failures + 1))
fi

if [ -s "$MISSING_APP" ]; then
    echo "Error: required public Slate application file(s) missing:" >&2
    sed 's/^/  /' "$MISSING_APP" >&2
    failures=$((failures + 1))
fi

if [ -s "$MISSING_APP_SOURCE" ]; then
    echo "Error: required public Slate application source/header file(s) missing:" >&2
    sed 's#^#  slate-application/#' "$MISSING_APP_SOURCE" >&2
    failures=$((failures + 1))
fi

if [ -s "$UNEXPECTED_APP_SOURCE" ]; then
    echo "Error: public Slate application source/header file(s) outside the project source graph:" >&2
    sed 's#^#  slate-application/#' "$UNEXPECTED_APP_SOURCE" >&2
    failures=$((failures + 1))
fi

if [ -s "$UNEXPECTED" ]; then
    echo "Error: unexpected public package file(s):" >&2
    sed 's/^/  /' "$UNEXPECTED" >&2
    failures=$((failures + 1))
fi

find . -type f ! -path './.git/*' ! -path './slate-application/*' \( \
    -name '*.m' -o \
    -name '*.mm' -o \
    -name '*.h' -o \
    -name '*.hpp' -o \
    -name '*.c' -o \
    -name '*.cc' -o \
    -name '*.cpp' -o \
    -name '*.swift' -o \
    -name '*.py' -o \
    -name '*.js' -o \
    -name '*.ts' \
\) -print | sed 's#^\./##' | LC_ALL=C sort >"$PRIVATE_SOURCE"

if [ -s "$PRIVATE_SOURCE" ]; then
    echo "Error: private implementation source-shaped file(s) present:" >&2
    sed 's/^/  /' "$PRIVATE_SOURCE" >&2
    failures=$((failures + 1))
fi

if find . -type f -name '.DS_Store' ! -path './.git/*' | grep . >/dev/null 2>&1; then
    echo "Error: .DS_Store file(s) present:" >&2
    find . -type f -name '.DS_Store' ! -path './.git/*' | sed 's#^\./#  #' >&2
    failures=$((failures + 1))
fi

find ./slate-application -type f ! -path './slate-application/build/*' \( \
    -path '*/xcuserdata/*' -o \
    -name '*.xcuserstate' \
\) -print | sed 's#^\./##' | LC_ALL=C sort >"$LOCAL_XCODE_STATE"

if [ -s "$LOCAL_XCODE_STATE" ]; then
    echo "Error: local Xcode user-state file(s) present:" >&2
    sed 's/^/  /' "$LOCAL_XCODE_STATE" >&2
    failures=$((failures + 1))
fi

find . -type f ! -path './.git/*' ! -path './Runtime/slate' ! -path './slate-application/Runtime/*' ! -path './slate-application/build/*' ! -path './tools/verify_public_package.sh' \( \
    -name '*.md' -o \
    -name '*.json' -o \
    -name '*.sh' -o \
    -name '*.xml' -o \
    -name '*.itt' -o \
    -name '*.scc' -o \
    -name '*.srt' -o \
    -name '*.ttml' -o \
    -name '*.h' -o \
    -name '*.m' -o \
    -name '*.mm' -o \
    -name '*.swift' -o \
    -name '*.pbxproj' -o \
    -name '.gitattributes' -o \
    -name '.gitignore' \
\) -print0 \
    | xargs -0 grep -nE '(/Users/jhale|Desktop/Slate|fixture_reference|____tools|___task_notes|AssistantOwned|Jeff Porcaro|porcaro)' \
    >"$PRIVATE_PATHS" 2>/dev/null

if [ -s "$PRIVATE_PATHS" ]; then
    echo "Error: private path or fixture string(s) present:" >&2
    sed 's/^/  /' "$PRIVATE_PATHS" >&2
    failures=$((failures + 1))
fi

find . -type f ! -path './.git/*' ! -path './slate-application/*' ! -path './Runtime/slate' ! -path './tools/verify_public_package.sh' \( \
    -name '*.md' -o \
    -name '*.json' -o \
    -name '*.sh' -o \
    -name '*.xml' -o \
    -name '*.itt' -o \
    -name '*.scc' -o \
    -name '*.srt' -o \
    -name '*.ttml' -o \
    -name '.gitattributes' -o \
    -name '.gitignore' \
\) -print0 \
    | xargs -0 grep -nE '(/Users/jhale|Desktop/Slate|fixture_reference|SMPkgSession|SMValidation|DictionaryKeys|slate_main|NSAppleEventDescriptor|NSWindow|NSView)' \
    >"$PRIVATE_STRINGS" 2>/dev/null

if [ -s "$PRIVATE_STRINGS" ]; then
    echo "Error: private path, harness, or implementation string(s) present:" >&2
    sed 's/^/  /' "$PRIVATE_STRINGS" >&2
    failures=$((failures + 1))
fi

if [ ! -x Runtime/slate ]; then
    echo "Error: Runtime/slate is missing or not executable." >&2
    failures=$((failures + 1))
fi

if [ ! -x tools/verify_runtime_manifest.sh ]; then
    echo "Error: tools/verify_runtime_manifest.sh is missing or not executable." >&2
    failures=$((failures + 1))
fi

if [ ! -x fixtures/verify_golden.sh ]; then
    echo "Error: fixtures/verify_golden.sh is missing or not executable." >&2
    failures=$((failures + 1))
fi

if [ "$failures" -ne 0 ]; then
    echo "Public package verification failed." >&2
    exit 1
fi

HOME="$VERIFY_HOME" tools/verify_runtime_manifest.sh || exit $?
HOME="$VERIFY_HOME" fixtures/verify_golden.sh || exit $?

echo "Public package verification OK."
