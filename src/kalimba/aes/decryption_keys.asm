// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#include "core_library.h"

// *****************************************************************************
// MODULE:
//   $aes.set_decryption_key
//
// DESCRIPTION:
//   Convert the specified key into one suitable for the decryption routines.
//   The expanded decryption keys are stored in $round_keys_msw and $round_keys_lsw,
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
.MODULE $M.aes.set_decryption_key;
   .CODESEGMENT AES_SET_DECRYPTION_KEY_PM;

   // void aes_set_decryption_key(uint24_t* cipher_key,
   //                             uint24_t* round_keys_msw,
   //                             uint24_t* round_keys_lsw);
   $_aes_set_decryption_key:

   // Creation of decryption keys begins the same way as the encryption keys
   pushm <r1, r2, rLink>;
   call $_aes_set_encryption_key;
   popm <r1, r2, rLink>;

   pushm <r4, r5, r6, rLink>;
   pushm <I0, I1, I4, I5, I6>;

   // invert the order of the round keys
   // r1/r2 is round_keys_msw/lsw
   I0 = r1;
   I4 = r2;
   I1 = r1 + 40;
   I5 = r2 + 40;

   // invert the round keys 4 bytes at a time
   // this loop will execute 5 times
   invert_round_keys_loop:
      r10 = 4;
      do invert_row_loop;
         r0 = M[I0,0],
          r4 = M[I4,0];
         r5 = M[I1,0],
          r3 = M[I5,0];
         M[I1,1] = r0,
          M[I5,1] = r4;
         M[I0,1] = r5,
          M[I4,1] = r3;
      invert_row_loop:
      I1 = I1 - 8;
      I5 = I5 - 8;
      Null = I1 - I0;
   if NZ jump invert_round_keys_loop;

   r10 = 9*4;
   // r1/r2 is round_keys_msw/lsw
   I0 = r1 + 4;
   I4 = r2 + 4;
   do loop_for_round_key;
      r4 = M[I0, 0],
       r5 = M[I4, 0];
      r1 = M[$aes.te4_lsw + r4];
      r0 = M[$aes.te4_msw + r4];
      r1 = r1 AND 0xFF;
      r2 = M[$aes.td0_msw + r1];
      r3 = M[$aes.td0_lsw + r1];
      r6 = r5 LSHIFT -16;
      r6 = r6 AND 0xFF;
      r1 = M[$aes.te4_lsw + r6];
      r0 = M[$aes.te4_msw + r6];
      r1 = r1 AND 0xFF;
      rMAC = M[$aes.td1_msw + r1];
      r2 = r2 XOR rMAC;
      rMAC = M[$aes.td1_lsw + r1];
      r3 = r3 XOR rMAC;
      r6 = r5 LSHIFT -8;
      r6 = r6 AND 0xFF;
      r1 = M[$aes.te4_lsw + r6];
      r0 = M[$aes.te4_msw + r6];
      r1 = r1 AND 0xFF;
      rMAC = M[$aes.td2_msw + r1];
      r2 = r2 XOR rMAC;
      rMAC = M[$aes.td2_lsw + r1];
      r3 = r3 XOR rMAC;
      r6 = r5 AND 0xFF;
      r1 = M[$aes.te4_lsw + r6];
      r0 = M[$aes.te4_msw + r6];
      r1 = r1 AND 0xFF;
      rMAC = M[$aes.td3_msw + r1];
      r2 = r2 XOR rMAC;
      rMAC = M[$aes.td3_lsw + r1];
      r3 = r3 XOR rMAC;
      M[I0, 1] = r2,
       M[I4, 1] = r3;
   loop_for_round_key:

   popm <I0, I1, I4, I5, I6>;
   popm <r4, r5, r6, rLink>;
   rts;
.ENDMODULE;
