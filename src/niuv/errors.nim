## The one error type of niuv. Every failure is a value; nothing is dropped.

import results

export results

type
  ErrKind* = enum
    ekDecl        ## a niuv.toml that is unreadable or breaks NIV-01..06
    ekRange       ## a version range where an exact version is required (NIV-10)
    ekWorkspace   ## a niuv.workspace.toml or a member that breaks NIV-07
    ekResolve     ## an unknown name, a cycle or a missing external (NIV-08)
    ekConflict    ## two versions of one name in a closure (NIV-09)
    ekLock        ## a missing, stale or unreadable lock (NIV-11, NIV-12)
    ekTool        ## a tool that is missing or differs from the lock (NIV-13)
    ekBuild       ## a compiler that failed (NIV-15, NIV-16)
    ekLicense     ## the license gate (NIV-20)
    ekUsage       ## a command line that is not understood (NIV-22)
    ekIo          ## a file or process that could not be read, written or started

  NiuvError* = object
    kind*: ErrKind
    msg*: string

  NResult*[T] = Result[T, NiuvError]

proc niuvError*(kind: ErrKind, msg: string): NiuvError {.raises: [].} =
  NiuvError(kind: kind, msg: msg)

proc `$`*(e: NiuvError): string {.raises: [].} =
  $e.kind & ": " & e.msg
