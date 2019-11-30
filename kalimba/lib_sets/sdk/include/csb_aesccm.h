// /* Copyright (c) 2017 Qualcomm Technologies International, Ltd. */
/* %%version */
/*!
    @file csb_aesccm.h
    @brief Interface to set aes-ccm keys and IV for broadcast audio.
*/

#ifndef AESCCM_H_
#define AESCCM_H_

#define AES_ROUND_KEYS_ARRAY_LENGTH 44

#ifdef KCC
#include <stdint.h>

typedef struct aesccm_params
{
    /** The 16-bit variable section of the  AESCCM initialisation vector */
    uint24_t iv;
    /** The 3x16-bit fixed section of the AESCCM initialisation vector */
    uint24_t fixed_iv[3];
    /** The expanded encryption keys most significant words */
    uint24_t round_keys_msw[AES_ROUND_KEYS_ARRAY_LENGTH];
    /** The expanded encryption keys least significant words */
    uint24_t round_keys_lsw[AES_ROUND_KEYS_ARRAY_LENGTH];
} aesccm_params_t;

/****************************************************************************
 * Functions
 ****************************************************************************/
/**
 * \brief  Set the aesccm key
 *
 * \param params The aesccm parameters.
 * \param key A pointer to an array of 8 words containing the 128-bit key
 * packed 16-bits per word.
 */
void aesccm_set_key(aesccm_params_t *params, uint24_t *key);

/**
 * \brief  Set the aesccm initialisation vector
 *
 * \param c The aesccm object
 * \param iv A word containing the 16-bit IV.
 */
void aesccm_set_iv(aesccm_params_t *c, uint24_t iv);

/**
 * \brief  Set the aesccm fixed initialisation vector
 *
 * \param c The aesccm object
 * \param iv0 Octets 0 and 1 of the 6 octet fixed IV.
 * \param iv1 Octets 2 and 3 of the 6 octet fixed IV.
 * \param iv2 Octets 4 and 5 of the 6 octet fixed IV.
 */
void aesccm_set_fixed_iv(aesccm_params_t *c, uint24_t iv0, uint24_t iv1, uint24_t iv2);

#endif /* KCC */

/** The size in words of the aesccm_params structure. */
#define AESCCM_PARAMS_STRUC_SIZE (4 + (2 * AES_ROUND_KEYS_ARRAY_LENGTH))

#ifdef KCC
#include <kalimba_c_util.h>
STRUC_SIZE_CHECK(aesccm_params_t, AESCCM_PARAMS_STRUC_SIZE);
#endif /* KCC */

#endif /* AESCCM_H_ */
