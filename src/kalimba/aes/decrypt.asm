// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#include "core_library.h"

// *****************************************************************************
// MODULE:
//   $aes.decrypt_frame
//
// DESCRIPTION:
//   Decrypts one frame (16 bytes) of cipher text. Uses approximately 1000 cycles
//   in total.
//
// INPUTS:
//   input_data - A pointer to the input buffer.
//                8 words, each containing 2 bytes of cipher text
//   output_data - A pointer to the output buffer. At least 8 words.
//   round_keys_msw/lsw - the 11 4x4 byte decryption round keys made from the
//                        decryption key.
//
// OUTPUTS:
//   16 bytes of plain text
//
// TRASHED REGISTERS:
//   - rMAC, r0, r1, r2, r3, r10
//
// *****************************************************************************
.MODULE $M.aes.decrypt_frame;
   .CODESEGMENT AES_DECRYPT_FRAME_PM;

   // void aes_decrypt_frame(unsigned int* input_data,
   //                        unsigned int* output_data,
   //                        unsigned int* round_keys_msw,
   //                        unsigned int* round_keys_lsw);
   $_aes_decrypt_frame:
   pushm <r4, r5, r6, rLink>;
   pushm <I0, I1, I2, I4, I5, I6, L1, L5>;
   // Push pointer to output_data
   push r1;

   // ************************
   // XOR cipher text with key
   // Results go into s
   // ************************

   r10 = 4;
   // round_keys_msw/lsw pointed to by r2/r3
   I2 = r2;
   I6 = r3;
   // input_data pointed to by r0
   I1 = r0;
   I0 = &$aes.s_msw;
   I4 = &$aes.s_lsw;

   do xor_input_loop;
      r0 = M[I1, 1];
      r0 = r0 AND 0xffff;
      r1 = M[I1, 1];
      r1 = r1 AND 0xffff;
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
   xor_input_loop:


   // ***************
   // first 9 rounds:
   // ***************

   // Our frame has 16 bytes that can be thought of as forming a 4x4 matrix
   // like this:
   //
   //   0 1 2 3
   //   4 5 6 7
   //   8 9 a b
   //   c d e f
   //
   // Each round takes one matrix as input and produces one as output. The
   // output of one round is the input of the next.
   // Here's a simple explanation of the process ignoring the fact that we
   // only have 24 bit registers and need 32 bit ones.
   //
   // The first row (0 1 2 3) of the output matrix is formed from the diagonal
   // of the input (0 5 a f). We use 4 256-entry lookup tables 
   // (td0 td1 td2 td3). Each entry in the table is a 32 bit number. We look
   // up byte 0 in td0, byte 1 in td1 etc and XOR all the results together.
   // Finally we XOR with 32 bits from the expanded key and write the result
   // into the output matrix.
   //
   // We repeat this but using the diagonal shifted down one place (4 9 e 3)
   // as the input and outputting to the next row of the output matrix
   // (4 5 6 7). We also use the next 32 bits of the expanded key.
   

   // Turn on circular behaviour for input arrays
   L1 = 4;
   L5 = 4;

   r6 = 9;
   round_loop:
      // Set I0, I4, I5 and I1 to point to the appropriate
      // input and output arrays
      Null = r6 AND 1;
      if Z jump even;
         // Set output to t
         I0 = &$aes.t_msw;
         I4 = &$aes.t_lsw;

         // Set intput to s
         I5 = &$aes.s_msw;
         I1 = &$aes.s_lsw+3;
         jump end_of_setup;
      even:
         // Set output to s
         I0 = &$aes.s_msw;
         I4 = &$aes.s_lsw;

         // Set intput to t
         I5 = &$aes.t_msw;
         I1 = &$aes.t_lsw+3;
      end_of_setup:

      r10 = 4;
      r2 = M[I5, 1],
       r3 = M[I1, -1];
      do row_loop;
         r0 = M[$aes.td0_msw + r2];
         r3 = r3 LSHIFT -16;
         r1 = M[$aes.td0_lsw + r2];
         rMAC = M[$aes.td1_msw + r3];
         r0 = r0 XOR rMAC,
          r4 = M[I1, -1];
         rMAC = M[$aes.td1_lsw + r3];
         r4 = r4 LSHIFT -8;
         r4 = r4 AND 0xFF;
         r1 = r1 XOR rMAC;
         rMAC = M[$aes.td2_msw + r4];
         r0 = r0 XOR rMAC,
          r5 = M[I1, -1];
         rMAC = M[$aes.td2_lsw + r4];
         r5 = r5 AND 0xFF;
         r1 = r1 XOR rMAC,
          r2 = M[I5, 1];
         rMAC = M[$aes.td3_msw + r5];
         r0 = r0 XOR rMAC,
          r3 = M[I1, -1];
         rMAC = M[$aes.td3_lsw + r5];
         r1 = r1 XOR rMAC, 
          rMAC = M[I2,1];
         r0 = r0 XOR rMAC, 
          rMAC = M[I6,1];
         r1 = r1 XOR rMAC, 
          M[I0,1] = r0;
         M[I4,1] = r1;
      row_loop:
   r6 = r6 - 1;
   if NZ jump round_loop;


   // **********
   // last round
   // **********

   pop r0;
   I0 = r0;

   r10 = 4;
   r6 = 0xff0000;
   I5 = &$aes.t_msw;
   I1 = &$aes.t_lsw + 3;
   do last_round_loop;
      r2 = M[I5, 1],
       r5 = M[I1, -1];
      r3 = M[I1, -1];
      r0 = M[$aes.td4_msw + r2];
      r5 = r5 LSHIFT -16;
      r0 = r0 AND 0xFF;
      r1 = M[$aes.td4_lsw + r5];
      r3 = r3 LSHIFT -8;
      r3 = r3 AND 0xFF;
      r1 = r1 AND r6,
       r4 = M[I1, -1];
      rMAC = M[$aes.td4_lsw + r3];
      rMAC = rMAC AND 0xFF00;
      r4 = r4 AND 0xFF;
      r1 = r1 XOR rMAC;
      rMAC = M[$aes.td4_lsw + r4];
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
