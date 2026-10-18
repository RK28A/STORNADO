/* stornado_frame.c - STORNADO frame encoding (single source of truth). */
#include "stornado_frame.h"

uint32_t stornado_crc32(const uint8_t *data, size_t n)
{
    uint32_t c = 0xFFFFFFFFu;
    for (size_t i = 0; i < n; i++) {
        c ^= data[i];
        for (int k = 0; k < 8; k++)
            c = (c & 1u) ? (c >> 1) ^ 0xEDB88320u : (c >> 1);
    }
    return c ^ 0xFFFFFFFFu;
}

size_t stornado_build_frame(uint8_t *out, uint16_t type, uint16_t flags,
                            uint32_t seq, const uint8_t *payload, uint32_t plen)
{
    out[0] = 'S'; out[1] = 'T'; out[2] = 'R'; out[3] = 'N';
    out[4] = STORNADO_PROTO_VERSION;
    out[5] = STORNADO_HEADER_LEN;
    out[6] = type & 0xFF;  out[7] = (type >> 8) & 0xFF;
    out[8] = flags & 0xFF; out[9] = (flags >> 8) & 0xFF;
    out[10] = seq & 0xFF; out[11] = (seq >> 8) & 0xFF;
    out[12] = (seq >> 16) & 0xFF; out[13] = (seq >> 24) & 0xFF;
    out[14] = plen & 0xFF; out[15] = (plen >> 8) & 0xFF;
    out[16] = (plen >> 16) & 0xFF; out[17] = (plen >> 24) & 0xFF;

    for (uint32_t i = 0; i < plen; i++)
        out[STORNADO_HEADER_LEN + i] = payload[i];

    /* CRC over VER..PAYLOAD */
    uint32_t crc = stornado_crc32(out + 4, (STORNADO_HEADER_LEN - 4) + plen);
    size_t end = STORNADO_HEADER_LEN + plen;
    out[end + 0] = crc & 0xFF;      out[end + 1] = (crc >> 8) & 0xFF;
    out[end + 2] = (crc >> 16) & 0xFF; out[end + 3] = (crc >> 24) & 0xFF;
    return end + 4;
}
