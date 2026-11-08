#ifndef CadenceCore_h
#define CadenceCore_h

#include <stdint.h>

/// Sends a JSON command to the Rust core and returns a newly allocated JSON string.
/// The caller owns the result and must pass it to cadence_core_free.
char *cadence_core_invoke(const char *request);

/// Releases a string returned by cadence_core_invoke.
void cadence_core_free(char *pointer);

/// The native command ABI version. Should be 1 for this build of the app.
uint32_t cadence_core_abi_version(void);

#endif
