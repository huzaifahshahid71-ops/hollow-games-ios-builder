#import <Metal/Metal.h>

// Normalize at the device boundary: concrete descriptor setters can bypass
// hooks installed on the public descriptor superclass. Preserve the caller's object.
static inline MTLTextureDescriptor *ShimCompatibleTextureDescriptor(MTLTextureDescriptor *descriptor) {
    if (!descriptor || (NSUInteger)descriptor.storageMode != 1) return descriptor;
    MTLTextureDescriptor *copy = [descriptor copy];
    copy.resourceOptions = (MTLResourceOptions)((NSUInteger)copy.resourceOptions & ~MTLResourceStorageModeMask);
    copy.storageMode = MTLStorageModeShared;
    return copy;
}
