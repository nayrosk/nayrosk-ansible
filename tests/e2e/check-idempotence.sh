#!/bin/sh
# Read an ansible-playbook log on stdin, copy it to stdout, and fail when the PLAY RECAP reports any
# changed, failed or unreachable task, or when no PLAY RECAP was seen at all.
set -eu

awk '
  { print; fflush() }
  /^PLAY RECAP/ { recap = 1; next }
  recap && /changed=[1-9]|failed=[1-9]|unreachable=[1-9]/ { bad = 1 }
  END {
    if (!recap) { print "check-idempotence: no PLAY RECAP found" > "/dev/stderr"; exit 1 }
    if (bad) { print "check-idempotence: FAILED, the second run is not idempotent" > "/dev/stderr"; exit 1 }
    print "check-idempotence: OK"
  }
'
