/* The C entry of a Nim program built for wasm32-wasip1 (NIV-35).
 *
 * The program is compiled with --noMain: wasi-libc's _start calls a main of
 * two arguments, and the main Nim writes takes three (argc, argv, env), a
 * signature mismatch that traps in wasm. This main hands argc and argv to the
 * variables std/cmdline reads, runs the Nim program and returns its result
 * (programResult, which std/unittest sets when a check fails).
 */
#include <stdint.h>

int cmdCount;
char **cmdLine;
extern intptr_t nim_program_result;
void NimMain(void);

int main(int argc, char **argv) {
  cmdCount = argc;
  cmdLine = argv;
  NimMain();
  return (int)nim_program_result;
}
