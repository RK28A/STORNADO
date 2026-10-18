/* stornado_diag.c — Dispatch firmware du protocole diagnostic (SQUELETTE).
 *
 * Cible : soft-core (RISC-V/MicroBlaze/Nios) ou petit MCU pilotant le PHY USB.
 * Rôle : décoder les cadres STORNADO (voir docs/usb-protocol.md), répondre aux
 * commandes de diagnostic bornées aux buffers embarqués / banc de test.
 *
 * PORTÉE : aucun accès à la mémoire hôte. WRITE_TEST_PATTERN /
 * READ_DIAGNOSTIC_BUFFER opèrent UNIQUEMENT sur diag_buffer[] ci-dessous.
 *
 * ÉTAT : logique de framing/dispatch posée ; les lectures de capteurs
 * (température, tensions) et l'accès aux registres NVMe via le bus de contrôle
 * sont des stubs à relier au matériel. Ne pas présenter comme testé sur cible.
 */
#include <stdint.h>
#include <string.h>

#define MAGIC0 'S'
#define MAGIC1 'T'
#define MAGIC2 'R'
#define MAGIC3 'N'
#define PROTO_VERSION 1u
#define HEADER_LEN 18u
#define DIAG_BUFFER_BYTES 4096u

enum msg_type {
    MT_PING = 0x0001, MT_GET_INFO = 0x0002, MT_GET_STATUS = 0x0003,
    MT_GET_TEMPERATURE = 0x0004, MT_GET_COUNTERS = 0x0005,
    MT_GET_NVME_STATE = 0x0006, MT_GET_QUEUE_STATUS = 0x0007,
    MT_START_BENCHMARK = 0x0008, MT_STOP_BENCHMARK = 0x0009,
    MT_RESET_COUNTERS = 0x000A, MT_READ_DIAG_BUFFER = 0x000B,
    MT_WRITE_TEST_PATTERN = 0x000C, MT_ACK = 0x8000, MT_ERROR = 0x8001
};

enum err_code { E_OK = 0, E_BAD_CRC = 1, E_UNKNOWN_TYPE = 4,
                E_BAD_LENGTH = 5, E_OUT_OF_RANGE = 6 };

static uint8_t  diag_buffer[DIAG_BUFFER_BYTES];
static uint32_t cnt_reads, cnt_writes, cnt_errors;

/* --- plateforme : à implémenter pour la cible --- */
extern int  usb_read(uint8_t *dst, uint32_t max);   /* octets reçus du PHY */
extern void usb_write(const uint8_t *src, uint32_t len);
extern int32_t hw_read_temperature_c(void);         /* stub matériel */
extern void hw_read_nvme_state(uint8_t *en, uint8_t *rdy, uint8_t *cfs);

/* CRC-32 IEEE 802.3, little-endian, identique au codec Python/RTL. */
static uint32_t crc32(const uint8_t *d, uint32_t n)
{
    uint32_t c = 0xFFFFFFFFu;
    for (uint32_t i = 0; i < n; i++) {
        c ^= d[i];
        for (int k = 0; k < 8; k++)
            c = (c & 1u) ? (c >> 1) ^ 0xEDB88320u : (c >> 1);
    }
    return c ^ 0xFFFFFFFFu;
}

static void send_frame(uint16_t type, uint32_t seq,
                       const uint8_t *payload, uint32_t plen)
{
    uint8_t hdr[HEADER_LEN];
    hdr[0]=MAGIC0; hdr[1]=MAGIC1; hdr[2]=MAGIC2; hdr[3]=MAGIC3;
    hdr[4]=PROTO_VERSION; hdr[5]=HEADER_LEN;
    hdr[6]=type & 0xFF;       hdr[7]=type >> 8;
    hdr[8]=0;                 hdr[9]=0;                 /* flags */
    hdr[10]=seq & 0xFF; hdr[11]=(seq>>8)&0xFF; hdr[12]=(seq>>16)&0xFF; hdr[13]=(seq>>24)&0xFF;
    hdr[14]=plen & 0xFF; hdr[15]=(plen>>8)&0xFF; hdr[16]=(plen>>16)&0xFF; hdr[17]=(plen>>24)&0xFF;

    /* CRC sur VER..PAYLOAD */
    uint32_t c = 0xFFFFFFFFu;
    for (uint32_t i = 4; i < HEADER_LEN; i++) {
        c ^= hdr[i]; for (int k=0;k<8;k++) c=(c&1u)?(c>>1)^0xEDB88320u:(c>>1);
    }
    for (uint32_t i = 0; i < plen; i++) {
        c ^= payload[i]; for (int k=0;k<8;k++) c=(c&1u)?(c>>1)^0xEDB88320u:(c>>1);
    }
    c ^= 0xFFFFFFFFu;

    usb_write(hdr, HEADER_LEN);
    if (plen) usb_write(payload, plen);
    uint8_t crcb[4] = { c&0xFF, (c>>8)&0xFF, (c>>16)&0xFF, (c>>24)&0xFF };
    usb_write(crcb, 4);
}

static void send_error(uint32_t seq, uint16_t code)
{
    uint8_t p[2] = { code & 0xFF, code >> 8 };
    send_frame(MT_ERROR, seq, p, 2);
}

void dispatch(uint16_t type, uint32_t seq, const uint8_t *payload, uint32_t plen)
{
    switch (type) {
    case MT_PING:
        send_frame(MT_ACK, seq, payload, plen);
        break;
    case MT_GET_INFO: {
        static const char info[] = "STORNADO\0fw=0.1.0";
        send_frame(MT_ACK, seq, (const uint8_t *)info, sizeof(info));
        break;
    }
    case MT_GET_TEMPERATURE: {
        int32_t t = hw_read_temperature_c();
        send_frame(MT_ACK, seq, (uint8_t *)&t, sizeof(t));
        break;
    }
    case MT_GET_COUNTERS: {
        uint32_t c[3] = { cnt_reads, cnt_writes, cnt_errors };
        send_frame(MT_ACK, seq, (uint8_t *)c, sizeof(c));
        break;
    }
    case MT_RESET_COUNTERS:
        cnt_reads = cnt_writes = cnt_errors = 0;
        send_frame(MT_ACK, seq, 0, 0);
        break;
    case MT_GET_NVME_STATE: {
        uint8_t s[3]; hw_read_nvme_state(&s[0], &s[1], &s[2]);
        send_frame(MT_ACK, seq, s, 3);
        break;
    }
    case MT_WRITE_TEST_PATTERN:
        if (plen > DIAG_BUFFER_BYTES) { send_error(seq, E_OUT_OF_RANGE); break; }
        memcpy(diag_buffer, payload, plen);   /* borné au buffer embarqué */
        send_frame(MT_ACK, seq, 0, 0);
        break;
    case MT_READ_DIAG_BUFFER: {
        uint32_t n = plen >= 4 ? *(const uint32_t *)payload : 0;
        if (n > DIAG_BUFFER_BYTES) { send_error(seq, E_OUT_OF_RANGE); break; }
        send_frame(MT_ACK, seq, diag_buffer, n);
        break;
    }
    default:
        send_error(seq, E_UNKNOWN_TYPE);
    }
}
