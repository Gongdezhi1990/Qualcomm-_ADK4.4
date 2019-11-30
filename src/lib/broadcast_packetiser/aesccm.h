/****************************************************************************
Copyright (c) 2016 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4

FILE NAME
    aesccm.h

DESCRIPTION
    Private header file for aesccm.

*/

#ifndef AESCCM_H_
#define AESCCM_H_

#include "broadcast_packetiser.h"
#include "broadcast_packet_ttp.h"

/*! 32-bit AESCCM MAC */
typedef uint32 aesccm_mac_t;

/*! 128-bit AESCCM nonce */
typedef struct __aesccm_nonce
{
    uint8 n[16];
} aesccm_nonce_t;

/*! 16 bytes of zeros for use as IV in crypto. */
extern const uint8 zeros_16[16];

/*!
@brief Initialise the aesccm configuration.
@param config The configuration to initialise.
*/
void aesccmInit(aesccm_config_t *config);

/*!
@brief Setup the AESCCM nonce for authentication.
@param a The aesccm configuration.
@param t The TTP.
@param len The number of octets to be authenticated.
@param nonce [OUT] The nonce.
*/
void aesccmSetupAuthenticationNonce(aesccm_config_t *a, ttp_t *t, uint16 len,
                                    aesccm_nonce_t *nonce);

/*!
@brief Setup the AESCCM nonce for encryption.
@param a The aesccm configuration.
@param t The TTP.
@param nonce [OUT] The nonce.
*/
void aesccmSetupEncryptionNonce(aesccm_config_t *a, ttp_t *t,
                                aesccm_nonce_t *nonce);

/*!
@brief Get the MAC from the nonce following a CBC calculation.
@param nonce The nonce calculated in the final step of the CBC calculation.
@return The mac (the least significant 32 bits of the nonce.
*/
aesccm_mac_t aesccmNonceToMac(aesccm_nonce_t *nonce);

#endif
