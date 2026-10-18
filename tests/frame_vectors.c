/* frame_vectors.c - CLI harness: print a STORNADO frame as hex.
 * Usage: frame_vectors <type> <seq> <flags> [payload_hex]
 * Shares firmware/stornado_frame.c so it proves the C wire format matches Python. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "stornado_frame.h"

static int hex_nibble(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

int main(int argc, char **argv) {
    if (argc < 4) { fprintf(stderr, "usage: %s type seq flags [payload_hex]\n", argv[0]); return 2; }
    uint16_t type  = (uint16_t)strtoul(argv[1], NULL, 0);
    uint32_t seq   = (uint32_t)strtoul(argv[2], NULL, 0);
    uint16_t flags = (uint16_t)strtoul(argv[3], NULL, 0);

    uint8_t payload[65536];
    uint32_t plen = 0;
    if (argc >= 5) {
        const char *h = argv[4];
        size_t L = strlen(h);
        if (L % 2) { fprintf(stderr, "payload hex must have even length\n"); return 2; }
        for (size_t i = 0; i < L; i += 2) {
            int hi = hex_nibble(h[i]), lo = hex_nibble(h[i + 1]);
            if (hi < 0 || lo < 0) { fprintf(stderr, "bad hex\n"); return 2; }
            payload[plen++] = (uint8_t)((hi << 4) | lo);
        }
    }

    uint8_t out[70000];
    size_t n = stornado_build_frame(out, type, flags, seq, payload, plen);
    for (size_t i = 0; i < n; i++) printf("%02x", out[i]);
    printf("\n");
    return 0;
}
