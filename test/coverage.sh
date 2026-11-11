#!/bin/bash
# Line coverage of get_env from the bats tests, per function, with bash's own xtrace.
# Usage: test/coverage.sh [function...]  (named functions also list their missed lines)
# A command over several lines counts once. Lines are classified roughly, so it is an estimate.
set -eu
testDir=$(cd "${0%/*}" && pwd)
script="${testDir}/../get_env"
tmp=$(mktemp -d)
trap 'rm -r "${tmp}"' EXIT

# BASH_ENV is read by every non-interactive bash, so get_env is traced both when the
# tests run it and when they source it.
cat >"${tmp}/env.sh" <<EOF
exec {coverageFd}>>"${tmp}/trace"
BASH_XTRACEFD=\${coverageFd}
PS4='+COVERAGE:\${BASH_SOURCE}:\${LINENO}: '
set -x
EOF
BASH_ENV="${tmp}/env.sh" bats "${testDir}" >"${tmp}/bats" || {
    grep '^not ok' "${tmp}/bats" >&2
    echo "Tests failed, coverage is not complete" >&2
}
grep -a -o '^+*COVERAGE:[^:]*/get_env:[0-9]*' "${tmp}/trace" | sed 's/.*://' | sort -un >"${tmp}/hit"

awk -v show=" $* " '
NR == FNR { hit[$1] = 1; next }
# Number of double quotes that are not escaped.
function quotes(text,    copy) { copy = text; return gsub(/"/, "", copy) - gsub(/\\"/, "", text) }
function continues(text) { return text ~ /(\\|\||&&)[[:space:]]*$/ }
# Count the statement from ${first}, covered if any of its lines ran.
function statement() {
    total++
    if (ran) covered++
    else missed = missed sprintf("         %d: %s\n", first, substr(firstLine, 1, 70))
    span = ""
}
function report(    pct) {
    if (name == "" || total == 0) return
    pct = int(100 * covered / total)
    printf "%4d%%  %3d/%-3d %s\n", pct, covered, total, name
    if (index(show, " " name " ")) printf "%s", missed
    allCovered += covered; allTotal += total
}
function newSection(sectionName) { report(); name = sectionName; total = covered = 0; missed = "" }
{
    line = $0
    # A statement over several lines: bash reports it on its last line.
    if (span != "") {
        if (FNR in hit) ran = 1
        if (span == "heredoc" && line ~ "^[[:space:]]*" terminator "$") statement()
        else if (span == "string" && quotes(line) % 2 == 1) statement()
        else if (span == "paren" && line ~ /^[[:space:]]*\)/) statement()
        else if (span == "continued" && !continues(line)) statement()
        next
    }
    if (line ~ /^[A-Za-z_][A-Za-z0-9_]*\(\)[[:space:]]*\{/) { newSection(substr(line, 1, index(line, "(") - 1)); next }
    if (line ~ /^### End of functions/) { newSection("(main flow)"); next }
    # Comments, blank lines, keywords and case labels are not run.
    if (line ~ /^[[:space:]]*(#.*)?$/) next
    if (line ~ /^[[:space:]]*(\}|fi|done|else|esac|;;|then|do|\{)[[:space:]]*$/) next
    if (line ~ /^[[:space:]]*\(?[^()]*\)[[:space:]]*(;;)?[[:space:]]*$/) next

    first = FNR; firstLine = line; ran = (FNR in hit)
    if (match(line, /<<-?[[:space:]]*'"'"'?[A-Z]+/)) {
        terminator = substr(line, RSTART, RLENGTH); gsub(/[^A-Z]/, "", terminator); span = "heredoc"
    } else if (quotes(line) % 2 == 1) span = "string"
    else if (line ~ /\$\([[:space:]]*$/) span = "paren"
    else if (continues(line)) span = "continued"
    else statement()
}
END {
    report()
    printf "TOTAL  %d/%d = %d%%\n", allCovered, allTotal, int(100 * allCovered / allTotal)
}' "${tmp}/hit" "${script}"
