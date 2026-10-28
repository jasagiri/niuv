/* The C entry of a Nim program built as a WASI reactor for a component
 * (NIV-44). wasi-libc's reactor exports _initialize, which runs the
 * constructors; this one runs the Nim program's top level, so the module is
 * initialised before the host calls an export. A reactor has no arguments.
 */
int cmdCount;
char **cmdLine;
void NimMain(void);

__attribute__((constructor))
static void niuvNimInit(void) {
  NimMain();
}
