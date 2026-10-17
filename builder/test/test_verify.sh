#!/bin/sh
# E tests of the input check (NIV-32: "a SHA-256 that does not match stops the work").
# Given-When-Then, plain sh: the script under test is a shell script.
here=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/niuv-builder-test.XXXXXX") || exit 2
trap 'rm -rf "$tmp"' EXIT
fails=0
expect() { # name wanted-exit got-exit
  if [ "$2" = "$3" ]; then echo "ok   $1"; else echo "FAIL $1: wanted exit $2, got $3"; fails=$((fails + 1)); fi
}
printf 'hello\n' > "$tmp/a.tar"
good=$(shasum -a 256 "$tmp/a.tar" | cut -d' ' -f1)

echo "$good  a.tar" > "$tmp/list"
"$here/verify-inputs.sh" "$tmp" "$tmp/list" >/dev/null 2>&1
expect "Given a file and its hash, when checked, then it passes" 0 $?

# one hex digit changed
rest=${good#?}
case "$good" in 0*) bad="1$rest" ;; *) bad="0$rest" ;; esac
echo "$bad  a.tar" > "$tmp/list"
"$here/verify-inputs.sh" "$tmp" "$tmp/list" >"$tmp/err" 2>&1
expect "Given a hash that differs from the file, when checked, then it stops with 1" 1 $?
grep -q "a.tar has sha256" "$tmp/err"
expect "Given a mismatch, when it stops, then it names the file" 0 $?

echo "$good  a.tar" > "$tmp/list"
printf 'hello!\n' > "$tmp/a.tar"
"$here/verify-inputs.sh" "$tmp" "$tmp/list" >/dev/null 2>&1
expect "Given a file changed after its hash was taken, when checked, then it stops with 1" 1 $?

echo "$good  missing.tar" > "$tmp/list"
"$here/verify-inputs.sh" "$tmp" "$tmp/list" >/dev/null 2>&1
expect "Given a listed file that is absent, when checked, then it stops with 1" 1 $?

: > "$tmp/list"
"$here/verify-inputs.sh" "$tmp" "$tmp/list" >/dev/null 2>&1
expect "Given an empty list, when checked, then it stops with 2 (nothing is not verified)" 2 $?

# the real list names the three tarballs
n=$(grep -c . "$here/inputs.sha256")
expect "Given the real list, when counted, then it holds nim, otp and gleam" 3 "$n"

[ "$fails" -eq 0 ] || { echo "$fails failed"; exit 1; }
echo "all ok"
