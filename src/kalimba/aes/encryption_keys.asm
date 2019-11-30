// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#include "core_library.h"

// *****************************************************************************
// MODULE:
//   $aes.set_encryption_key
//
// DESCRIPTION:
//   Convert the specified key into one suitable for the encryption routines.
//   The expanded encryption keys are stored in $round_keys_msw and $round_keys_lsw,
//   which can be thought of as 11 matrices each containing 4x4 bytes.
//
// INPUTS:
//   cipher_key - A pointer to a 8 word array containing the 128 bit (16 byte)
//                cipher key, packed 2 LS bytes in each word.
//   round_keys_msw - A pointer to a 4 * 11 word array located in DM1
//   round_keys_lsw - A pointer to a 4 * 11 word array located in DM2
//
// OUTPUTS:
//   None
//
// TRASHED REGISTERS:
//   - rMAC, r0, r1, r2, r3, r10
//
// *****************************************************************************
.MODULE $M.aes.set_encryption_key;
   .CODESEGMENT AES_SET_ENCRYPTION_KEY_PM;

   // void aes_set_encryption_key(uint24_t* cipher_key,
   //                             uint24_t* round_keys_msw,
   //                             uint24_t* round_keys_lsw);
   $_aes_set_encryption_key:
   pushm <r4, r5, r6, rLink>;
   pushm <I0, I2, I6, M1, M2>;

   // Copy the cipher key into the first four slots in round_keys 
   r10 = 4;   
   // r0 is cipher_key
   I0 = r0;
   // r1/r2 is round_keys_msw/lsw
   I2 = r1;
   I6 = r2;
   do load_cipher_key_loop;
      r4 = M[I0, 1];
      r5 = M[I0, 1];
      r6 = r4 AND 0xff;
      r6 = r6 LSHIFT 16;
      r5 = r5 OR r6;
      r4 = r4 LSHIFT -8;
      M[I2, 1] = r4,
       M[I6, 1] = r5;   
   load_cipher_key_loop:

   // Now do the key expansion   
   I0 = &$aes.round_consts;
   M1 = 3;
   M2 = -3;
   // r1/r2 is round_keys_msw/lsw
   I2 = r1;
   I6 = r2;
   r6 = 10;              // Loop counter. We will expand the key into 10 round keys
   r5 = 0xff0000;        // Used as a const for speed reasons
   key_expansion_round_loop: 
      
      // Generate the first four bytes of the round key are based 
      // on the previous round key
   
      // Read from the previous round
      r0 = M[I2, M1],    // I2 was round_keys_msw[r6 * 4 + 0] becomes +3
       r1 = M[I6, M1];   // I6 was round_keys_lsw[r6 * 4 + 0] becomes +3
      r2 = M[I2, 1],     // I2 was +3 becomes +4
       r3 = M[I6, 1];    // I6 was +3 becomes +4
      
      r4 = r3 LSHIFT -16;
      rMAC = M[$aes.te4_msw + r4];
      rMAC = rMAC AND 0xFF;
      r0 = r0 XOR rMAC; 
      rMAC = M[$aes.te4_lsw + r4];
      
      r4 = r3 LSHIFT -8;
      r4 = r4 AND 0xFF;
      rMAC = M[$aes.te4_lsw + r4];
      rMAC = rMAC AND r5;
      r1 = r1 XOR rMAC;
      
      r4 = r3 AND 0xFF;
      rMAC = M[$aes.te4_lsw + r4];
      rMAC = rMAC AND 0xFF00;
      r1 = r1 XOR rMAC;
      
      rMAC = M[$aes.te4_lsw + r2];
      rMAC = rMAC AND 0xFF;
      r1 = r1 XOR rMAC,
       r3 = M[I0, 1];    // round_consts[i]
      r0 = r0 XOR r3;
      
      // Set the loop counter for the loop below ahead of time
      // to avoid the stall
      r10 = 3;
      
      // Store the first four bytes of the round key we just generated
      M[I2, M2] = r0,    // I2 was +4 becomes +1
       M[I6, M2] = r1;   // I6 was +4 becomes +1
      
      // Now create the remaining 12 bytes based on the first 4 bytes
      // we just generated

      do key_expansion_row_loop;   
         r0 = M[I2, M1],    // I2 was +1 becomes +4
          r2 = M[I6, M1];   
         r1 = M[I2, 1],     // I2 was +4 becomes +5
          r3 = M[I6, 1];
         r0 = r0 XOR r1;
         r2 = r2 XOR r3;
         M[I2, M2] = r0,    // I2 was +5 becomes +2
          M[I6, M2] = r2;
      key_expansion_row_loop:
 
      r6 = r6 - 1;
   if NZ jump key_expansion_round_loop;

   popm <I0, I2, I6, M1, M2>;
   popm <r4, r5, r6, rLink>;
   rts;

.ENDMODULE;
