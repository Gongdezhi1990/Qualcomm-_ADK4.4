// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.mdct
//
// DESCRIPTION:
//    mdct (2048 sample)
//
// INPUTS:
//    - r6 = pointer to mdct structure
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - assume all
//
// *****************************************************************************
.MODULE $M.aacdec.mdct;
   .CODESEGMENT AACDEC_MDCT_PM;
   .DATASEGMENT DM;

   $aacdec.mdct:

   //                       cos(2 * pi/2048),           sin(2 * pi/2048),
   //                       cos(2 * pi/2048/8),         sin(2 * pi/2048/8),
   .VAR  sin_const[4] =     0.9999952938,               0.0030679567,
                            0.9999999264,               0.0003834951;

   .CONST INPUT_N  2048;

   // push rLink onto stack
   push rLink;

   r8 = M[r6 + $aacdec.mdct.NUM_POINTS_FIELD];
   I7 = &sin_const;

   // set up the modify registers
   M0 = 1;
   M1 = 2;
   M2 = -2;
   M3 = -1;

   //                              In(1:2048)
   //             <-I0 I1->                         <-I2 I3->
   //                | |                               | |
   //  ------------------------------- - -------------------------------
   // |<---- N/4 ----> <---- N/4 ---->| |<---- N/4 ----> <---- N/4 ---->|
   //  ------------------------------- - -------------------------------
   // |                               | |                               |
   // 1                            1024 1025                         2048


   r1 = M[r6 + $aacdec.mdct.INPUT_ADDR_FIELD];

   I0 = r1 + (INPUT_N/4 - 1);
   I1 = r1 + (INPUT_N/4);

   r1 = r1 + (INPUT_N/2);

   I2 = r1 + (INPUT_N/4 - 1);
   I3 = r1 + (INPUT_N/4);

   r10 = (INPUT_N/8);   // 2048 / 8 -- r8 LSHIFT -3;

   r0 = M[I7,M0];       // cfreq
   r1 = M[I7,M0];       // sfreq

   rMAC = M[I7,M0],     // c
    r3 = M[I2,M2];      // In((N-N4) - n)

   r7 = rMAC,
    r4 = M[I3,M1];      // In((N-N4+1) + n)

   rMAC = M[I7,M0],     // s
    r5 = M[I1,M1];      // In((N4+1) + n)

   r8 = rMAC,
    r2 = M[I0,M2];      // In((N4) - n)

   // pre process loop 1
   //
   // temp_r[1:1:256] = In[(N-N4) - n] + In[(N-N4+1) + n],  n = 0:2:510
   // temp_i[1:1:256] = In[(N4+1) + n] - In[N4 - n],      n = 0:2:510
   //
   // c[1:1:256] = cos( ((2*pi)/(8*N)) + ((2*pi*(0:1:255))/N) )
   // s[1:1:256] = sin( ((2*pi)/(8*N)) + ((2*pi*(0:1:255))/N) )
   //
   // tmp[1:1:256] = (temp_r[1:1:256] + j*temp_i[1:1:256]) * (c[1:1:256] - j*s[1:1:256]);
   // tmp_real = real(tmp);   tmp_imag=  imag(tmp);
   //

   do pre_process_loop_1;

      r3 = r3 + r4;           // temp_r = In((N-N4) - n) + In((N-N4+1) + n)
      r5 = r5 - r2;           // temp_i = In((N4+1) + n) - In((N4) - n)

      rMAC = r3 * r7;         // temp_r * c
      rMAC = rMAC + r5 * r8;  // tmp_real = (temp_r * c) + (temp_i * s)

      I7 = I3 - M1;

      M[I7,0] = rMAC,
       rMAC = r5 * r7;        // temp_i * c

      rMAC = rMAC - r3 * r8;  // tmp_imag = (temp_i * c) - (temp_r * s)

      I7 = I1 - M1;

      r5 = r8;                // s_old

      // update the multipliers: "c" and "s"
      M[I7,0] = rMAC,
       rMAC = r7 * r1;        // (-c_old) * sfreq

      rMAC = rMAC + r8 * r0;  // (-s)' = (-c_old)*sfreq + (-s)*cfreq

      r8 = rMAC,              // r5 = (-s)'
       r2 = M[I0,M2];         // In((N4) - n)

      rMAC = r7 * r0,         // (-c) * cfreq
       r4 = M[I3,M1];         // In((N-N4+1) + n)

      rMAC = rMAC - r5 * r1,  // (-c)'= (-c) * cfreq - (-s) * sfreq
       r3 = M[I2,M2];         // In((N-N4) - n)

      r7 = rMAC,
       r5 = M[I1,M1];         // In((N4+1) + n)
   pre_process_loop_1:



   // I2->                         <-I0 I1->                         <-I3
   // |                               | |                               |
   //  ------------------------------- - -------------------------------
   // |<---- N/4 ----> <---- N/4 ---->| |<---- N/4 ----> <---- N/4 ---->|
   //  ------------------------------- - -------------------------------
   // |                               | |                               |
   // 1                            1024 1025                         2048

   rMAC = 3;
   I0 = I1 - rMAC;

   r2 = M[r6 + $aacdec.mdct.INPUT_ADDR_FIELD];

   I2 = r2,
    r3 = M[I0,M2];       // In(N2 - n)

   r2 = r2 + (INPUT_N/2);

   I1 = r2,
    r4 = M[I2,M1];       // In(n)

   I3 = I3 - rMAC,
    r5 = M[I1,M1];       // In((N2+1) + n)

   r10 = (INPUT_N/8);    // 2048 / 8

   r2 = M[I3,M2];        // In((N) - n)

   // pre process loop 2
   //
   // temp_r[1:1:256] = In[N2 - n] - In[n + 1],       n = 0:2:510
   // temp_i[1:1:256] = In[(N2+1) + n] + In[N - n],   n = 0:2:510
   //
   // c[1:1:256] = cos( ((2*pi)/(8*N)) + ((2*pi*(256:1:511))/N) )
   // s[1:1:256] = sin( ((2*pi)/(8*N)) + ((2*pi*(256:1:511))/N) )
   //
   // tmp[257:1:512] = (temp_r[1:1:256] + j*temp_i[1:1:256]) * (c[1:1:256] - j*s[1:1:256]);
   // tmp_real = real(tmp);   tmp_imag =  imag(tmp);
   //

   do pre_process_loop_2;

      r3 = r3 - r4;           // temp_r = In((N2) - n) - In(n + 1);
      r5 = r5 + r2;           // temp_i = In((N2+1) + n) + In((N) - n);

      I7 = I2 - M1;

      rMAC = r3 * r7;         // temp_r * c
      rMAC = rMAC + r5 * r8;  // tmp_real = (temp_r * c) + (temp_i * s)

      M[I7,0] = rMAC;
      I7 = I1 - M1;

      rMAC = r5 * r7;         // temp_i * c
      rMAC = rMAC - r3 * r8;  // tmp_imag = (temp_i * c) - (temp_r * s)

      M[I7,0] = rMAC;

      r5 = r8;                // s_old

      // update the multipliers: "c" and "s"
      rMAC = r7 * r1;         // (-c_old) * sfreq

      rMAC = rMAC + r8 * r0;  // (-s)' = (-c_old)*sfreq + (-s)*cfreq

      r8 = rMAC,              // r5 = (-s)'
       r2 = M[I3,M2];         // In((N) - n)

      rMAC = r7 * r0,         // (-c) * cfreq
       r4 = M[I2,M1];         // In(n)

      rMAC = rMAC - r5 * r1,  // (-c)'= (-c) * cfreq - (-s) * sfreq
       r3 = M[I0,M2];         // In(N2 - n)

      r7 = rMAC,
       r5 = M[I1,M1];         // In((N2+1) + n)
   pre_process_loop_2:


   // re-arrange mdct_input_buffer so that real and imaginary input to fft are on power of 2 boundary
   // and values are in sequence

   //                                   tmp_imag[1:256]   tmp_real[1:256]
   //                                   |..............| |..............|
   //  ------------------------------- - -------------------------------
   // |<---- N/4 ----> <---- N/4 ---->| |<---- N/4 ----> <---- N/4 ---->|
   //  ------------------------------- - -------------------------------
   // |                               | |                               |
   // 1                            1024 1025                         2048


   r10 = (INPUT_N / 8);

   I2 = I3 + 3;
   I3 = I3 + 3;

   I6 = I1 - 3;
   I4 = I1 - 4;


   do pre_process_loop_3;
      r0 = M[I3,M1],
       r1 = M[I4,M2];

      M[I6,M3] = r1,
       M[I2,M0] = r0;
   pre_process_loop_3:


   r10 = (INPUT_N / 8);

   r0 = M[r6 + $aacdec.mdct.INPUT_ADDR_FIELD];
   I3 = r0;

   r0 = r0 + 1024;
   I6 = r0;

   I4 = I0 + 3;

   do pre_process_loop_4;
      r0 = M[I3,M1],
       r1 = M[I4,M1];

      M[I6,M0] = r1,
       M[I2,M0] = r0;
   pre_process_loop_4:


   // set up fft input structure and gain
   r8 = M[r6 + $aacdec.mdct.NUM_POINTS_FIELD];
   r0 = (INPUT_N / 4);       // 2048 / 4 = 512

   r1 = M[r6 + $aacdec.mdct.INPUT_ADDR_FIELD];
   r1 = r1 + 1024;
   r2 = r1 + 512;

   M[r6 + $fft.NUM_POINTS_FIELD] = r0;
   M[r6 + $fft.REAL_ADDR_FIELD] = r2;
   M[r6 + $fft.IMAG_ADDR_FIELD] = r1;

   // set up I7 and call scaleable_fft
   I7 = r6;
   r8 = $aacdec.MDCT_SCALE;

   call $math.scaleable_fft;

   r6 = I7;
   M0 = 1;

   // compensate for effect of bitreversed addressing
   r0 = M[r6 + $aacdec.mdct.INPUT_ADDR_BR_FIELD];
   #if defined(KAL_ARCH3)|| defined(KAL_ARCH5)
   		r0 = r0 + 4096;    // (r0 + 1024)
   #else
      #error Unsupported architecture
   		r0 = r0 + 16;    // (r0 + 1024)
   #endif
   I1 = r0;         // start of imag data
   #if defined(KAL_ARCH3)|| defined(KAL_ARCH5)
   		I0 = I1 + 8192;    // start of real data  (I1 + 512)
   #else
      #error Unsupported architecture
   		I0 = I1 + 32;    // start of real data  (I1 + 512)
   #endif

   I6 = &sin_const;

   // will write Out[1:1024] in first half of mdct_input_buffer
   r0 = M[r6 + $aacdec.mdct.INPUT_ADDR_FIELD];
   I5 = r0;
   I4 = I5 + 1023;

   r0 = M[I6,M0];   // cfreq
   r1 = M[I6,M0];   // sfreq

   rMAC = M[I6,M0]; // c
   r7 = rMAC;

   rMAC = M[I6,M0]; // s
   r8 = rMAC;

   r10 = (INPUT_N / 4);

   // set up the modify registers
   #if defined(KAL_ARCH3)|| defined(KAL_ARCH5)
      M0 = 64 * 0x100;
   #else
      #error Unsupported architecture
      M0 = 64;
   #endif
   M1 = 32;
   M2 = -8192;
   M3 = -2;

   // data is returned bit reversed, so enable bit reverse addressing on AG1
   rFlags = rFlags OR $BR_FLAG;

   r3 = M[I0,M0];   // temp_r
   r4 = M[I1,M0];   // temp_i

   // construct the 1024 sample mdct output from the real and imaginary outputs of the fft
   //
   //            Out[1:1024]            temp_imag[1:512] temp_real[1:512]
   // |...............................| |..............| |..............|
   //  ------------------------------- - -------------------------------
   // |<---- N/4 ----> <---- N/4 ---->| |<---- N/4 ----> <---- N/4 ---->|
   //  ------------------------------- - -------------------------------
   // |                               | |                               |
   // 1                            1024 1025                         2048

   // post processing loop 1
   //
   // c[1:1:512] = cos( ((2*pi)/(8*N)) + ((2*pi*(0:1:511))/N) )
   // s[1:1:512] = sin( ((2*pi)/(8*N)) + ((2*pi*(0:1:511))/N) )
   //
   // temp_real2[1:1:512] = ( temp_real[1:1:512] * c[1:1:256] ) + ( temp_imag[1:1:512] * s[1:1:256] )
   // temp_imag2[1:1:512] = ( temp_imag[1:1:512] * c[1:1:256] ) - ( temp_real[1:1:512] * s[1:1:256] )
   //
   // Out[1:2:1023] = -temp_real2[1:1:512];
   // Out[1024:-2:2] = temp_imag2[1:1:512];
   //

   do post_process_loop_1;

      rMAC = r3 * r7;         // temp_real * c
      rMAC = rMAC + r4 * r8;  // temp_real2 = (temp_real * c) + (temp_imag * s)

      rMAC = -rMAC;

      M[I5,2] = rMAC,         // Out(2n) = -temp_real2
       rMAC = r4 * r7;        // temp_imag * c

      rMAC = rMAC - r3 * r8;  // temp_imag2 = (temp_imag * c) - (temp_real * s)

      r5 = r8;                // s_old

      // update the multipliers: "c" and "s"
      M[I4, M3] = rMAC,       // Out(1024-2n) = temp_imag2
       rMAC = r7 * r1;        // (-c_old) * sfreq

      rMAC = rMAC + r8 * r0;  // (-s)' = (-c_old)*sfreq + (-s)*cfreq

      r8 = rMAC;              // r8 = (-s)'

      rMAC = r7 * r0;         // (-c) * cfreq

      rMAC = rMAC - r5 * r1,  // (-c)'= (-c) * cfreq - (-s) * sfreq
       r3 = M[I0,M0];         // temp_real

      r7 = rMAC,
       r4 = M[I1,M0];         // temp_imag
   post_process_loop_1:


   // disable bit reversed addressing on AG1
   rFlags = rFlags AND $NOT_BR_FLAG;


   // pop rLink from stack
   jump $pop_rLink_and_rts;


.ENDMODULE;


