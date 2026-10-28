/* __multi3 (128-bit multiply) for wasm32 when no compiler-rt is at hand
 * (NIV-36). Homebrew's llvm ships no wasm32 compiler-rt; std/times needs
 * this one routine. `brew install wasi-runtimes` would provide the real
 * library and make this file unused; installing it is the owner's call.
 *
 * optnone: at -O1 and above clang recognises the 64x64 schoolbook product
 * below as a 128-bit multiply and lowers it back into a call to __multi3,
 * which then calls itself until the stack runs out.
 */
#include <stdint.h>

typedef __int128 ti_int;
typedef unsigned __int128 tu_int;

__attribute__((optnone, noinline))
static tu_int mul64x64(uint64_t a, uint64_t b) {
  const uint64_t lowMask = 0xffffffffu;
  uint64_t aLo = a & lowMask, aHi = a >> 32, bLo = b & lowMask, bHi = b >> 32;
  uint64_t lolo = aLo * bLo;
  uint64_t hilo = aHi * bLo;
  uint64_t lohi = aLo * bHi;
  uint64_t hihi = aHi * bHi;
  uint64_t cross = (lolo >> 32) + (hilo & lowMask) + lohi;
  uint64_t lo = (cross << 32) | (lolo & lowMask);
  uint64_t hi = hihi + (hilo >> 32) + (cross >> 32);
  return ((tu_int)hi << 64) | lo;
}

__attribute__((optnone, noinline))
ti_int __multi3(ti_int a, ti_int b) {
  uint64_t aLo = (uint64_t)a, aHi = (uint64_t)((tu_int)a >> 64);
  uint64_t bLo = (uint64_t)b, bHi = (uint64_t)((tu_int)b >> 64);
  tu_int low = mul64x64(aLo, bLo);
  uint64_t hi = (uint64_t)(low >> 64) + aHi * bLo + aLo * bHi;
  return (ti_int)(((tu_int)hi << 64) | (uint64_t)low);
}
