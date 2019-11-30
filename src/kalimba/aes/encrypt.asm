// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#include "core_library.h"


// *****************************************************************************
// MODULE:
//   $aes.encrypt_frame
//
// DESCRIPTION:
//   Encrypts one frame (16 bytes) of plain text. Uses approximately 1000 cycles
//   in total.
//
// INPUTS:
//   input_data - A pointer to the input buffer.
//                8 words, each containing 2 bytes of plain text
//   output_data - A pointer to the output buffer. At least 8 words.
//   round_keys_msw/lsw - the 11 4x4 byte encryption round keys made from the
//                        encryption key.
//
// OUTPUTS:
//   16 bytes of cipher text
//
// TRASHED REGISTERS:
//   - rMAC, r0, r1, r2, r3, r10
//
// *****************************************************************************
.MODULE $M.aes.encrypt_frame;
   .CODESEGMENT AES_ENCRYPT_FRAME_PM;

   // void aes_encrypt_frame(unsigned int* input_data,
   //                        unsigned int* output_data,
   //                        unsigned int* round_keys_msw,
   //                        unsigned int* round_keys_lsw);
   $_aes_encrypt_frame:
   pushm <r4, r5, r6, rLink>;
   pushm <I0, I1, I2, I4, I5, I6, L1, L5>;
   // Push pointer to output_data
   push r1;

   // ***********************
   // XOR plain text with key
   // Results go into s
   // ***********************

   r10 = 4;
   // round_keys_msw/lsw pointed to by r2/r3
   I2 = r2;
   I6 = r3;
   // input_data pointed to by r0
   I1 = r0;
   I0 = &$aes.s_msw;
   I4 = &$aes.s_lsw;
   
   do xor_plain_text_loop;
      r0 = M[I1, 1];
      r1 = M[I1, 1];
      r2 = r0 AND 0xff;
      r2 = r2 LSHIFT 16;
      r1 = r1 OR r2;
      r0 = r0 LSHIFT -8;
      rMAC = M[I2, 1];     // takes round_keys_msw
      r0 = r0 XOR rMAC;    // s_msw
      rMAC = M[I6, 1];     // takes round_keys_lsw
      r1 = r1 XOR rMAC,    // s_lsw
       M[I0, 1] = r0;      // save s_msw
      M[I4, 1] = r1;       // save s_lsw
   xor_plain_text_loop:
   

   // ***************
   // first 9 rounds:
   // ***************

   // Turn on circular behaviour for input arrays
   L1 = 4;  
   L5 = 4;
   
   r6 = 9;
   encrypt_round_loop:
      // Set I0, I4, I5 and I1 to point to the appropriate
      // input and output arrays
      Null = r6 AND 1;
      if Z jump even;
         // Set output to t
         I0 = &$aes.t_msw;
         I4 = &$aes.t_lsw;
         
         // Set intput to s
         I5 = &$aes.s_msw;
         I1 = &$aes.s_lsw+1;
         jump end_of_setup;
      even:
         // Set output to s
         I0 = &$aes.s_msw;
         I4 = &$aes.s_lsw;
         
         // Set intput to t
         I5 = &$aes.t_msw;
         I1 = &$aes.t_lsw+1;
      end_of_setup:

      r10 = 4;
      r2 = M[I5, 1],
       r3 = M[I1, 1];
      do encrypt_row_loop;
         r0 = M[$aes.te0_msw + r2];
         r3 = r3 LSHIFT -16;
         r1 = M[$aes.te0_lsw + r2];
         rMAC = M[$aes.te1_msw + r3];
         r0 = r0 XOR rMAC,
          r4 = M[I1, 1];
         rMAC = M[$aes.te1_lsw + r3];
         r4 = r4 LSHIFT -8;
         r4 = r4 AND 0xFF;
         r1 = r1 XOR rMAC;
         rMAC = M[$aes.te2_msw + r4];
         r0 = r0 XOR rMAC,
          r5 = M[I1, -1];
         rMAC = M[$aes.te2_lsw + r4];
         r5 = r5 AND 0xFF;
         r1 = r1 XOR rMAC,
          r2 = M[I5, 1];
         rMAC = M[$aes.te3_msw + r5];
         r0 = r0 XOR rMAC,
          r3 = M[I1, 1];
         rMAC = M[$aes.te3_lsw + r5];
         r1 = r1 XOR rMAC,
          rMAC = M[I2,1];
         r0 = r0 XOR rMAC,
          rMAC = M[I6,1];
         r1 = r1 XOR rMAC,
          M[I0,1] = r0;
         M[I4,1] = r1;
      encrypt_row_loop:   
   r6 = r6 - 1;
   if NZ jump encrypt_round_loop;

   // **********
   // last round
   // **********

   // Set output to cipher_text
   pop r0;
   I0 = r0;

   r10 = 4;
   r6 = 0xff0000; // This is used as a const because it is faster than the literal
   I5 = &$aes.t_msw;
   I1 = &$aes.t_lsw+1;
   do last_round_loop;   
      r2 = M[I5,1],
       r5 = M[I1,1];
      r3 = M[I1,1];      
      r0 = M[$aes.te4_msw + r2];
      r5 = r5 LSHIFT -16;
      r0 = r0 AND 0xFF;
      r1 = M[$aes.te4_lsw + r5];
      r3 = r3 LSHIFT -8;
      r3 = r3 AND 0xFF;
      r1 = r1 AND r6,
         r4 = M[I1,-1];
      rMAC = M[$aes.te4_lsw + r3];
      rMAC = rMAC AND 0xFF00;
      r4 = r4 AND 0xFF;
      r1 = r1 XOR rMAC;
      rMAC = M[$aes.te4_lsw + r4];
      rMAC = rMAC AND 0xFF;
      r1 = r1 XOR rMAC, 
       rMAC = M[I2,1];
      r0 = r0 XOR rMAC, 
       rMAC = M[I6,1];
      r1 = r1 XOR rMAC; 
      
      r0 = r0 LSHIFT 8;
      r2 = r1 LSHIFT -16;
      r1 = r1 AND 0xffff;
      r0 = r0 OR r2;
      M[I0,1] = r0;
      M[I0,1] = r1;
   last_round_loop:

   popm <I0, I1, I2, I4, I5, I6, L1, L5>;
   popm <r4, r5, r6, rLink>;
   rts;
.ENDMODULE;
