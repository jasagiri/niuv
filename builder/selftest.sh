#!/bin/sh
# The guest program of the builder image's acceptance run (K4-1). kite starts
# it as the guest's init with --exit-status, with the source tree mounted
# read-only at /work and an output directory read-write at /out. Writes one
# "ok|FAIL name: value" line per check to /out/selftest.txt and exits 0 only
# when every check is ok.
PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin
HOME=/tmp
export PATH HOME
out=/out/selftest.txt
failed=0
: > "$out" || exit 90

check() { # name expected-substring actual
  if printf '%s' "$3" | grep -qF -- "$2"; then
    printf 'ok   %s: %s\n' "$1" "$3" >> "$out"
  else
    printf 'FAIL %s: wanted [%s], got [%s]\n' "$1" "$2" "$3" >> "$out"
    failed=1
  fi
}

check nim "Version 2.2.12" "$(nim -v 2>&1 | head -1)"
check otp_release "29" "$(erl -noshell -eval 'io:format("~s", [erlang:system_info(otp_release)]), halt().' 2>&1)"
check otp_version "29.1.1" "$(cat /opt/otp/lib/erlang/releases/*/OTP_VERSION 2>&1)"
check erts "" "$(erl -noshell -eval 'io:format("erts ~s", [erlang:system_info(version)]), halt().' 2>&1)"
check gleam "gleam 1.19.1" "$(gleam --version 2>&1)"
niuv_help=$(niuv --help 2>&1); niuv_code=$?
check niuv_help "niuv" "$(printf '%s' "$niuv_help" | head -1)"
check niuv_help_exit "0" "$niuv_code"

# The C compiler and the Erlang compiler work, not only print versions.
mkdir -p /tmp/t && cd /tmp/t || exit 91
printf 'echo "built-by-nim"\n' > h.nim
check nim_compile "built-by-nim" "$(nim c --hints:off -o:h h.nim >/dev/null 2>&1 && ./h)"
printf '%s\n' '-module(m).' '-export([f/0]).' 'f() -> built_by_erlc.' > m.erl
check erlc_compile "built_by_erlc" "$(erlc m.erl 2>&1 && erl -noshell -pa . -eval 'io:format("~p", [m:f()]), halt().' 2>&1)"

# The mounts are what the run asked for.
check work_visible 'name = "niuv"' "$(grep -m1 '^name' /work/niuv.toml 2>&1)"
check work_read_only "refused" "$(touch /work/should-not-exist 2>/dev/null && echo written || echo refused)"
check out_writable "written" "$(touch /out/probe && echo written || echo refused)"
rm -f /out/probe
check no_network "only lo" "$(if [ "$(ls /sys/class/net 2>&1 | tr '\n' ' ')" = "lo " ]; then echo "only lo"; else echo "interfaces: $(ls /sys/class/net 2>&1 | tr '\n' ' ')"; fi)"

[ "$failed" -eq 0 ] && echo "RESULT ok" >> "$out" || echo "RESULT FAIL" >> "$out"
exit "$failed"
