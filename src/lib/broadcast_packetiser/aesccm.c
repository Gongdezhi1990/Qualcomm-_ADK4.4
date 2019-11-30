/****************************************************************************
Copyright (c) 2016 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4

FILE NAME
    aesccm.c
*/

#include <aesccm.h>

/*! 16 bytes of zeros */
const uint8 zeros_16[16] = {0};

/* Write the common elements of the nonce (common between authentication
   and encryption). */
static void aesccmSetupNonceCommon(aesccm_config_t *a, ttp_t *t,
                                   aesccm_nonce_t *nonce)
{
    uint8 *p = nonce->n;

    /* Skip the first byte of the nonce, which is for flags */
    p[1] = t->extension;
    p[2] = (uint8)(t->base >> 24) & 0xff;
    p[3] = (uint8)(t->base >> 16) & 0xff;
    p[4] = (uint8)(t->base >> 8) & 0xff;
    p[5] = (uint8)t->base & 0xff;

    p[6] = (uint8)(a->dynamic_iv >> 8) & 0xff;
    p[7] = (uint8)a->dynamic_iv & 0xff;

    p[8] = (uint8)(a->fixed_iv[0] >> 8) & 0xff;
    p[9] = (uint8)a->fixed_iv[0] & 0xff;
    p[10] = (uint8)(a->fixed_iv[1] >> 8) & 0xff;
    p[11] = (uint8)a->fixed_iv[1] & 0xff;
    p[12] = (uint8)(a->fixed_iv[2] >> 8) & 0xff;
    p[13] = (uint8)a->fixed_iv[2] & 0xff;
}

void aesccmSetupAuthenticationNonce(aesccm_config_t *a, ttp_t *t, uint16 len,
                                    aesccm_nonce_t *nonce)
{
    nonce->n[0] = 0x09;
    aesccmSetupNonceCommon(a, t, nonce);
    nonce->n[14] = (uint8)(len >> 8) & 0xff;
    nonce->n[15] = (uint8)len & 0xff;
}

void aesccmSetupEncryptionNonce(aesccm_config_t *a, ttp_t *t,
                                aesccm_nonce_t *nonce)
{
    nonce->n[0] = 0x01;
    aesccmSetupNonceCommon(a, t, nonce);
    /* Initialise counter to 0 */
    nonce->n[14] = 0;
    nonce->n[15] = 0;
}

aesccm_mac_t aesccmNonceToMac(aesccm_nonce_t *nonce)
{
    aesccm_mac_t mac;
    mac = (uint32)nonce->n[0];
    mac |= (uint32)nonce->n[1] << 8;
    mac |= (uint32)nonce->n[2] << 16;
    mac |= (uint32)nonce->n[3] << 24;
    return mac;
}

static void swap_bytes(uint8 *a, uint8 *b)
{
    uint8 tmp = *a;
    *a = *b;
    *b = tmp;
    
}

/*! @brief Initialise the aesccm configuration. */
void aesccmInit(aesccm_config_t *config)
{
    /* Key endianness is swapped on Bluecore vs Hydra versions,
       swap on Hydra to be backwards compatible */
    uint8 *key = config->key;
    swap_bytes(key + 0, key + 1);
    swap_bytes(key + 2, key + 3);
    swap_bytes(key + 4, key + 5);
    swap_bytes(key + 6, key + 7);
    swap_bytes(key + 8, key + 9);
    swap_bytes(key + 10, key + 11);
    swap_bytes(key + 12, key + 13);
    swap_bytes(key + 14, key + 15);
}
