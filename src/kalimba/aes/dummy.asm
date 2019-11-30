// /* Copyright (c) 2017 Qualcomm Technologies International, Ltd. */
/* Part of ADK_CSR867x.WIN. 4.4 */

#include "aes_library_c_stubs.h"

// *****************************************************************************
// MODULE:
//   $aes.dummy
//
// DESCRIPTION:
//   Dummy aes routines.
//
// TRASHED REGISTERS:
//   - r10, rMAC, I3, I7
//
// *****************************************************************************
.MODULE $M.aes.dummy;
.CODESEGMENT AES_DUMMY_PM;

    // void aes_set_encryption_key(uint24_t* cipher_key,
    //                             uint24_t* round_keys_msw,
    //                             uint24_t* round_keys_lsw);
    // void aes_set_decryption_key(uint24_t* cipher_key,
    //                             uint24_t* round_keys_msw,
    //                             uint24_t* round_keys_lsw);
    $_aes_set_encryption_key:
    $_aes_set_decryption_key:
        r10 = AES_ROUND_KEYS_ARRAY_LENGTH;
        I3 = r1;
        I7 = r2;
        rMAC = 0;
        do zero_key_loop;
            M[I3,1] = rMAC, M[I7,1] = rMAC;
        zero_key_loop:
        rts;

    // void aes_decrypt_frame(unsigned int* input_data,
    //                        unsigned int* output_data,
    //                        unsigned int* round_keys_msw,
    //                        unsigned int* round_keys_lsw);
    // void aes_encrypt_frame(unsigned int* input_data,
    //                        unsigned int* output_data,
    //                        unsigned int* round_keys_msw,
    //                        unsigned int* round_keys_lsw);
    $_aes_decrypt_frame:
    $_aes_encrypt_frame:
        r10 = 8;
        I3 = r0;
        I7 = r1;
        do copy_loop;
            rMAC = M[I3,1];
            M[I7,1] = rMAC;
        copy_loop:
        rts;
.ENDMODULE;
