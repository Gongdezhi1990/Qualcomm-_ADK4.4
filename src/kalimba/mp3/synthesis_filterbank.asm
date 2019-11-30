// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef MP3DEC_SYNTHESIS_FILTERBANK_INCLUDED
#define MP3DEC_SYNTHESIS_FILTERBANK_INCLUDED

// *****************************************************************************
// MODULE:
//    $mp3dec.synthesis_filterbank
//
// DESCRIPTION:
//    Synthesis via polyphase FilterBank
//
// INPUTS:
//    - r9 = pointer to table of external memory pointers
//    - I1 = ^cbuffer  (PCM output buffer)
//    - I4 = ^synthv
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    rMAC, r0 - r8, r10, DoLoop, I0-I2, I4, I5, I7, M0-M3
//
// NOTES:
// @verbatim
//   ________________________
//   __Synthesis FilterBank__
//
//
//  Butterfly operation to convert 32-point DCT to an even-part and an
//  odd-part for further processing by a 16-point DCT matrix (even part) and
//  a modified 16-point DCT matrix (odd-part)
//
//                 _                           _   _   _
//                |                             | |     |
//                | 1 0 0 . . . . . . . 0  0  1 | |  I  |
//                | 0 1 0               0  1  0 | |  n  |
//                | 0 0 1               1  0  0 | |  p  |
//  Even-Part =   | .     .            .      . | |  u  |
//                | .       .         .       . | |  t  |
//                | .        .      .         . | |     |
//                | 0. . . . . 1  1 . . . . . 0 | |  S  |
//                |_                           _| |  a  |
//                                                |  m  |
//                                                |  p  |
//                                                |  l  |
//                                                |  e  |
//                                                |  s  |
//                                                |_   _|
//
//                 _                           _   _   _
//                |                             | |     |
//                | 1 0 0 . . . . . . . 0  0 -1 | |  I  |
//                | 0 1 0               0 -1  0 | |  n  |
//                | 0 0 1              -1  0  0 | |  p  |
//   Odd-Part =   | .     .            .      . | |  u  |
//                | .       .         .       . | |  t  |
//                | .        .      .         . | |     |
//                | 0. . . . . 1 -1 . . . . . 0 | |  S  |
//                |_                           _| |  a  |
//                                                |  m  |
//                                                |  p  |
//                                                |  l  |
//                                                |  e  |
//                                                |  s  |
//                                                |_   _|
//
//  Note: In this implementation the order that the odd-part is stored is in
//  reverse order.
//
//  The Even-part is processed by the EvenDCT and the odd part by the
//  OddDCT.  This then creates the full 32point DCT.  The result of this is
//  written such that it is for an MDCT (with a 64 point output).
//
//  ie. if:   x[i] = DCT32>64  (MPEG mdct)
//      and  x'[i] = DCT32>32  (standard dct)
//
//  then:  x[i]     =  x'[i+16]  i=0..15
//         x[i+17]  = -x'[31-i]  i=0..15
//         x[i+32]  = -x'[16-i]  i=0..15
//         x[i+48]  = -x'[i]     i=0..15
//         x[16]    =  0
//
//  Windowing is then done as decribed in the mpeg document
// @endverbatim
//
//
// *****************************************************************************
.MODULE $M.mp3dec.synthesis_filterbank;
   .CODESEGMENT MP3DEC_SYNTHESIS_FILTERBANK_PM;
   .DATASEGMENT DM;

   $mp3dec.synthesis_filterbank:

#ifdef MP3_USE_EXTERNAL_MEMORY
   r0 = M[r9 + $mp3dec.mem.GENBUF_FIELD];
   I0 = r0;
#else
   I0 = &$mp3dec.genbuf;
#endif
   I5 = I0 + (31*18);      // I0 & I5 point to wings of bufferfly

   M0 = 18;                // modify constants to access each subband
   M1 = -18;
   M2 = 36;
   M3 = -36;
   r5 = 0;
   r4 = 18;
   dct_loop:         // Subband sample loop

      r10 = 8;
      r2 = M[I0,M0],       // read first butterfly pair
       r3 = M[I5,M1];
      do dct_butfly_loop;
         r1 = r2 + r3,     // carry out 16 bufferfly operations
          r0 = M[I0,M1];   // tessellating 2 operations together for speed
         r2 = r2 - r3,
          r1 = M[I5,M0],
          M[I0,M2] = r1;
         M[I5,M3] = r2;

         r3 = r0 + r1,
          r2 = M[I0,M1];
         r0 = r0 - r1,
          r3 = M[I5,M0],
          M[I0,M2] = r3;
         M[I5,M3] = r0;
      dct_butfly_loop:
      I0 = I0 - (17*18-1);     // set pointers to next subband sample of the
      I5 = I5 + (17*18+1);     // 1st subband
      r4 = r4 - 1;
   if NZ jump dct_loop;

#ifdef MP3_USE_EXTERNAL_MEMORY
   r0 = M[r9 + $mp3dec.mem.GENBUF_FIELD];
   I0 = r0;
#else
   I0 = &$mp3dec.genbuf;           // set pointer to 1st subband sample of even-part
#endif

   r4 = 18;


   #ifdef BASE_REGISTER_MODE // Save I4 for the windowing section of process_32_samples_loop
      push I4;
   #endif

   process_32samples_loop:  // Subband sample loop - process 32 subband samples
      I7 = &$mp3dec.dct16_even;

   #ifdef BASE_REGISTER_MODE // Both B4 and B5 need to take the current value of I4 for the L4 = 64 section.
      push I4;
      B4 = M[SP - 1];
      pop B5;
   #endif

      L4 = 64;                 // set length to 64 to cope with wrap around of dct
      L5 = 64;
      M2 = 48;
      r0 = M[I4,M2];           // dummy read: V_ptr1 = 48;
      I5 = I4;                 //             V_ptr2 = 48;

      M0 = 18;                 // modify constants required
      M1 = 1;
      M2 = -2;
      M3 = (-15*18);

      r10 = 16;
      r0 = M[I0,M0],           // get 1st col data
       r1 = M[I7,M1];
      do evendct_outerloop;    // EVEN DCT (matrix multiply)

         rMAC = r0 * r1,          // multiply 1st col data
          r0 = M[I0,M0],          // get 2nd col data
          r1 = M[I7,M1];

         rMAC = rMAC + r0 * r1,   // do cols 2-14.
          r0 = M[I0,M0],
          r1 = M[I7,M1];
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,M0],
          r1 = M[I7,M1];
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,M0],
          r1 = M[I7,M1];
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,M0],
          r1 = M[I7,M1];
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,M0],
          r1 = M[I7,M1];
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,M0],
          r1 = M[I7,M1];
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,M0],
          r1 = M[I7,M1];
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,M0],
          r1 = M[I7,M1];
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,M0],
          r1 = M[I7,M1];
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,M0],
          r1 = M[I7,M1];
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,M0],
          r1 = M[I7,M1];
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,M0],
          r1 = M[I7,M1];
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,M0],
          r1 = M[I7,M1];

         rMAC = rMAC + r0 * r1,   // do col 15.
          r0 = M[I0,M3],          // setting pointer back to 1st col
          r1 = M[I7,M1];

         rMAC = rMAC + r0 * r1,   // multiply 16th col data
          r0 = M[I0,M0],          // get 1st col data
          r1 = M[I7,M1];

         M[I5,M2] = rMAC;         // x[i+32] = -x'[16-i] //  x[i+17] = -x'[31-i]
         Null = r10 - 9;
         if NEG rMAC = -rMAC;
         M[I4,2] = rMAC;          // x[i+48] = -x'[i]    //  x[i]    = x'[i+16]
      evendct_outerloop:

      M[I5,0] = r5;            // x[16] = 0

      I7 = &$mp3dec.dct16_odd;
      I0 = I0 + (30*18);       // set pointer to start of odd-part

      M0 = 31;
      r0 = M[I4,M0];           // dummy read: V_ptr1 = 47;
      I5 = I4;
      M0 = -18;
      r0 = M[I5,2];            // dummy read: V_ptr2 = 49;
      M3 = (15*18);

      r10 = 16;
      r0 = M[I0,M0],           // get 1st col data
       r1 = M[I7,M1];
      do odddct_outerloop;     // EVEN DCT (matrix multiply)

         rMAC = r0 * r1,          // multiply 1st col data
          r0 = M[I0,M0],          // get 2nd col data
          r1 = M[I7,M1];

         rMAC = rMAC + r0 * r1,   // do cols 2-14.
          r0 = M[I0,M0],
          r1 = M[I7,M1];
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,M0],
          r1 = M[I7,M1];
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,M0],
          r1 = M[I7,M1];
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,M0],
          r1 = M[I7,M1];
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,M0],
          r1 = M[I7,M1];
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,M0],
          r1 = M[I7,M1];
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,M0],
          r1 = M[I7,M1];
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,M0],
          r1 = M[I7,M1];
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,M0],
          r1 = M[I7,M1];
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,M0],
          r1 = M[I7,M1];
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,M0],
          r1 = M[I7,M1];
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,M0],
          r1 = M[I7,M1];
         rMAC = rMAC + r0 * r1,
          r0 = M[I0,M0],
          r1 = M[I7,M1];

         rMAC = rMAC + r0 * r1,   // do col 15.
          r0 = M[I0,M3],          // setting pointer back to 1st col
          r1 = M[I7,M1];

         rMAC = rMAC + r0 * r1,   // multiply 16th col data
          r0 = M[I0,M0],          // get 1st col data
          r1 = M[I7,M1];

         M[I4,M2] = rMAC;         // x[i+32] = -x'[16-i] // x[i+17] = -x'[31-i]
         Null = r10 - 9;
         if NEG rMAC = -rMAC;
         M[I5,2] = rMAC;          // x[i+48] = -x'[i]    // x[i]    =  x'[i+16]
      odddct_outerloop:

      I0 = I0 - (18*30-1);     // set pointer to the start of the next
                               // subband sample of the 1st subband - ready
                               // for next time around Synth32Sampleloop

      L4 = 1024;               // length = 1024 for windowing
      I2 = &$mp3dec.synthwin_coef;

      #ifdef BASE_REGISTER_MODE
         B4 = M[SP - 1]; // Need the original value of I4 for the windowing loop.
      #endif

      M0 = -15;
      r0 = M[I4,M0];           // dummy read: V_ptr1 = 0;

      M0 = 32;
      M1 = 96;
      M2 = (-15*32 + 1);
      M3 = (1 - ((96+32)*7+96));

      r10 = 32;

      r0 = M[I4,M1],
       r1 = M[I2,M0];

      do window_loop;          // the inner loop has been unwrapped for speed

         // Window V vector to generate PCM sample
         rMAC = r0 * r1,
          r0 = M[I4,M0],
          r1 = M[I2,M0];
         rMAC = rMAC + r0 * r1,
          r0 = M[I4,M1],
          r1 = M[I2,M0];
         rMAC = rMAC + r0 * r1,
          r0 = M[I4,M0],
          r1 = M[I2,M0];
         rMAC = rMAC + r0 * r1,
          r0 = M[I4,M1],
          r1 = M[I2,M0];
         rMAC = rMAC + r0 * r1,
          r0 = M[I4,M0],
          r1 = M[I2,M0];
         rMAC = rMAC + r0 * r1,
          r0 = M[I4,M1],
          r1 = M[I2,M0];
         rMAC = rMAC + r0 * r1,
          r0 = M[I4,M0],
          r1 = M[I2,M0];
         rMAC = rMAC + r0 * r1,
          r0 = M[I4,M1],
          r1 = M[I2,M0];
         rMAC = rMAC + r0 * r1,
          r0 = M[I4,M0],
          r1 = M[I2,M0];
         rMAC = rMAC + r0 * r1,
          r0 = M[I4,M1],
          r1 = M[I2,M0];
         rMAC = rMAC + r0 * r1,
          r0 = M[I4,M0],
          r1 = M[I2,M0];
         rMAC = rMAC + r0 * r1,
          r0 = M[I4,M1],
          r1 = M[I2,M0];
         rMAC = rMAC + r0 * r1,
          r0 = M[I4,M0],
          r1 = M[I2,M0];
         rMAC = rMAC + r0 * r1,
          r0 = M[I4,M1],
          r1 = M[I2,M0];

         rMAC = rMAC + r0 * r1,
          r0 = M[I4,M3],
          r1 = M[I2,M2];
         rMAC = rMAC + r0 * r1,
          r0 = M[I4,M1],
          r1 = M[I2,M0];

         r2 = rMAC * 8 (int) (sat);  // scale so that PCM data is between -1.0 and + 1.0 (24bit)
         M[I1,1] = r2;               // store 24-bit PCM output into cbuffer

      window_loop:

      M0 = -192;               // dummy read: V_ptr1 = -64
      r0 = M[I4,M0];           // (ie the shift down for next time around loop);

      r4 = r4 - 1;
   if NZ jump process_32samples_loop;

   L4 = 0;                  // set length regs back to zero
   L5 = 0;
   #ifdef BASE_REGISTER_MODE
      pop B4; // We placed an extra word on the stack to hold I4; remove it.
      push Null;
      B5 = M[SP - 1];
      pop B4;
   #endif
   rts;

.ENDMODULE;

#endif
