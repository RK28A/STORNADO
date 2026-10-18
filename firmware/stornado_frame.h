/* stornado_frame.h - Single source of truth for STORNADO frame encoding.
 * Shared by the firmware and the C<->Python vector test. Pure, no platform deps.
 * See docs/usb-protocol.md. */
#ifndef STORNADO_FRAME_H
#define STORNADO_FRAME_H

#include <stdint.h>
#include <stddef.h>

#define STORNADO_HEADER_LEN 18u
#define STORNADO_PROTO_VERSION 1u

/* CRC-32 IEEE 802.3 (little-endian), identical to the Python/RTL codecs. */
uint32_t stornado_crc32(const uint8_t *data, size_t n);

/* Build a full frame into out (must hold HEADER_LEN + plen + 4 bytes).
 * Returns the total frame length. */
size_t stornado_build_frame(uint8_t *out, uint16_t type, uint16_t flags,
                            uint32_t seq, const uint8_t *payload, uint32_t plen);

#endif /* STORNADO_FRAME_H */
