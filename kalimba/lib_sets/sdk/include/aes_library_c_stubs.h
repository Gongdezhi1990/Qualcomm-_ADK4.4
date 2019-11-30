// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

// Header file for C stubs of "aes" library

#if !defined(AES_LIBRARY_C_STUBS_H)
#define AES_LIBRARY_C_STUBS_H

#define AES_ROUND_KEYS_ARRAY_LENGTH (4 * 11)

#ifdef KCC

#include <stdlib.h>
#include <stdint.h>

/* PUBLIC FUNCTION PROTOTYPES ***********************************************/
void aes_set_encryption_key(uint24_t* cipher_key,
                            uint24_t* round_keys_msw,
                            uint24_t* round_keys_lsw);
void aes_set_decryption_key(uint24_t* cipher_key,
                            uint24_t* round_keys_msw,
                            uint24_t* round_keys_lsw);
void aes_encrypt_frame(uint24_t* input_data,
                       uint24_t* output_data,
                       uint24_t* round_keys_msw,
                       uint24_t* round_keys_lsw);
void aes_decrypt_frame(uint24_t* input_data,
                       uint24_t* output_data,
                       uint24_t* round_keys_msw,
                       uint24_t* round_keys_lsw);

#endif /* KCC */

#endif
