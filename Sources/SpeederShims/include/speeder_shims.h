#ifndef SPEEDER_SHIMS_H
#define SPEEDER_SHIMS_H

#include <CoreFoundation/CoreFoundation.h>

/*
 * Swift name lookup for CFMachPortCreateRunLoopSource is unreliable: depending on
 * the import set of the file that uses it, the symbol can end up invisible and
 * the event tap cannot be attached to a run loop. Wrapping the call in a C
 * target keeps the build deterministic.
 */

CF_RETURNS_RETAINED
CFRunLoopSourceRef SpeederCreateRunLoopSourceForMachPort(CFMachPortRef port);

#endif /* SPEEDER_SHIMS_H */
