## Which licenses a sealed artifact must not contain (NIV-20).
##
## A sealed artifact is delivered to machines that do not hold its source
## offer, so the v3 copyleft family (GPL, LGPL, AGPL, version 3) is refused.
## An expression that merely offers one of them among others is refused too:
## choosing the other side of an OR is a decision for a person, not a gate.
## Future: let a declaration say which side of an OR it takes.

import std/[sequtils, strutils]

proc tokens(license: string): seq[string] {.raises: [].} =
  var cleaned = ""
  for c in license:
    cleaned.add (if c in {'(', ')'}: ' ' else: c)
  cleaned.splitWhitespace().mapIt(it.toUpperAscii)

proc isCopyleftV3*(license: string): bool {.raises: [].} =
  ## GPL-3.0, LGPL-3.0, AGPL-3.0 in SPDX's spellings (-only, -or-later, +).
  for t in tokens(license):
    for family in ["GPL", "LGPL", "AGPL"]:
      for suffix in ["-3.0", "-3.0-ONLY", "-3.0-OR-LATER", "-3.0+"]:
        if t == family & suffix: return true
  false
