#include "include/speeder_shims.h"

CFRunLoopSourceRef SpeederCreateRunLoopSourceForMachPort(CFMachPortRef port) {
    return CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0);
}
