// Host-only build-tool workaround for Mono's nunbox-arbitrary argument parser.
// It passes '=4096' to atoi after an off-by-one prefix length calculation.
#include <stdlib.h>
#include <stdint.h>
static int fixed_atoi(const char *s) { return (int)strtol(s && s[0]=='=' ? s+1:s,0,10); }
__attribute__((used)) static struct { const void *replacement,*original; } entry
__attribute__((section("__DATA,__interpose")))={(const void *)fixed_atoi,(const void *)atoi};
