/* Included (clang -include) into Nim's system module, and nothing else, when
 * niuv builds a freestanding component (NIV-41: the core imports only what its
 * world names).
 *
 * Why: since Nim 2.2.12, with -d:useMalloc and --os:standalone, the system
 * module's raiseOutOfMem and nimSizeOverflow write a line to stderr with
 * fwrite and fflush and then call exit (lib/system/mmdisp.nim, mm/malloc.nim,
 * system.nim). Those pull wasi-libc's stdio and exit into the core, and with
 * them the wasi_snapshot_preview1 imports clock_time_get, fd_write, fd_seek,
 * fd_close and proc_exit, which no freestanding world has. A freestanding
 * core has no stderr and no process to exit; panics trap (NIV-42), so these
 * two fatal paths trap too.
 *
 * Why not define fwrite, fflush, stderr and exit for the whole link: a guest
 * that calls stdio itself must still be refused by wasm-tools (NIV-42), not
 * turned into a trap without a word. Only the system module sees these macros.
 *
 * Future: drop this file when Nim's standalone raiseOutOfMem and
 * nimSizeOverflow go through the panic of panicoverride.nim.
 */
#include <stdio.h>
#include <stdlib.h>

#undef stderr
#define stderr ((FILE *)0)
#define fwrite(p, size, n, f) ((void)(p), (void)(size), (void)(n), (void)(f), __builtin_trap(), (size_t)0)
#define fflush(f) ((void)(f), __builtin_trap(), 0)
#define exit(code) ((void)(code), __builtin_trap())
