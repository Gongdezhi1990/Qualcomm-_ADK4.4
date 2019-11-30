// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"
#include "stack.h"

//.warning "aac fft should load twiddle table dynamically"

// *****************************************************************************
// MODULE:
//    $aacdec.imdct
//
// DESCRIPTION:
//    1024 / 512 / 128 sample IMDCT routine
//
// INPUTS:
//    - r6 = pointer to imdct structure:
//         $aacdec.imdct.NUM_POINTS_FIELD
//            - number of input data points (1024 / 512 / 128)
//         $aacdec.imdct.INPUT_ADDR_FIELD
//            - pointer to input data (circular)
//         $aacdec.imdct.INPUT_ADDR_BR_FIELD
//            - bit reversed pointer to input data (circular)
//         $aacdec.imdct.OUTPUT_ADDR_FIELD
//            - pointer to output data (circular)
//         $aacdec.imdct.OUTPUT_ADDR_BR_FIELD
//            - bit reversed pointer to output data (circular)
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - everything including $aacdec.tmp but L0 & L1
//
// *****************************************************************************
.MODULE $M.aacdec.imdct;
   .CODESEGMENT AACDEC_IMDCT_PM;
   .DATASEGMENT DM;

   $aacdec.imdct:


#ifdef AACDEC_ELD_ADDITIONS
   // The cos and sin variables are stored in the following order:
   //       sin_const =  cos(          pi/128),      sin(          pi/128),
   //                    cos(          pi/512),      sin(          pi/512),
   //                    cos(          pi/512/8),    sin(          pi/512/8),
   //                    cos( 16.125 * pi/128),      sin( 16.125 * pi/128),
   //                    cos( 64.125 * pi/512),      sin( 64.125 * pi/512),
   //                    cos( 32.125 * pi/128),      sin( 32.125 * pi/128),
   //                    cos(128.125 * pi/512),      sin(128.125 * pi/512),
   //                    cos( 48.125 * pi/128),      sin( 48.125 * pi/128),
   //                    cos(192.125 * pi/512),      sin(192.125 * pi/512),
   //
   // Here we could get rid of the values for N = 128 as they are not needed for ELD.
   // They have been left in the table (10 words wasted) to leave most of the function below unchanged.
   .VAR  sin_const_eld[18] = 0.9996988186,               0.0245412285,
                             0.9999811752,               0.0061358846,
                             0.9999997059,               0.0007669903,
                             0.9227011283,               0.3855160538,
                             0.9235857463,               0.3833919265,
                             0.7049340803,               0.7092728264,
                             0.7065642291,               0.7076489173,
                             0.3798472089,               0.9250492407,
                             0.3819747131,               0.9241727753;
#endif // AACDEC_ELD_ADDITIONS
   // The cos and sin variables are stored in the following order:
   //       sin_const =  cos(          pi/128),      sin(          pi/128),
   //                    cos(          pi/1024),     sin(          pi/1024),
   //                    cos(          pi/1024/8),   sin(          pi/1024/8),
   //                    cos( 16.125 * pi/128),      sin( 16.125 * pi/128),
   //                    cos(128.125 * pi/1024),     sin(128.125 * pi/1024),
   //                    cos( 32.125 * pi/128),      sin( 32.125 * pi/128),
   //                    cos(256.125 * pi/1024),     sin(256.125 * pi/1024),
   //                    cos( 48.125 * pi/128),      sin( 48.125 * pi/128),
   //                    cos(384.125 * pi/1024),     sin(384.125 * pi/1024),
   .VAR  sin_const[18] = 0.9996988186,               0.0245412285,
                         0.9999952938,               0.0030679567,
                         0.9999999264,               0.0003834951,
                         0.9227011283,               0.3855160538,
                         0.9237327073,               0.3830377075,
                         0.7049340803,               0.7092728264,
                         0.7068355571,               0.7073779012,
                         0.3798472089,               0.9250492407,
                         0.3823291008,               0.9240262218;

   // push rLink onto stack
   push rLink;

   r8 = M[r6 + $aacdec.imdct.NUM_POINTS_FIELD];

   I2 = &sin_const;
#ifdef AACDEC_ELD_ADDITIONS
   I3 = &sin_const_eld;
   Null = r8 - 512;
   if EQ I2 = I3;
#endif // AACDEC_ELD_ADDITIONS

   // set up the modify registers
   M0 = 1;
   M1 = 2;
   M2 = -2;

   // check how may data points we are using
   Null = r8 - 1024;
   if POS I2 = I2 + M1;

#ifdef AACDEC_ELD_ADDITIONS
   Null = r8 - 512;
   if EQ I2 = I2 + M1;
#endif // AACDEC_ELD_ADDITIONS

   // need to copy the odd values into the output buffer
   r10 = r8 LSHIFT -1;
   r10 = r10 - M0;

   // set a pointer to the start of the copy, and the target
   // and two buffers as output pointers for below
   r1 = M[r6 + $aacdec.imdct.INPUT_ADDR_FIELD];
   I0 = r1;                         // input
   I4 = r1;                         // input
   I0 = I0 + r8,
    r2 = M[I2,M0];                  // cfreq
   I0 = I0 - M0,
    r3 = M[I2,M0];                  // sfreq

   r1 = M[r6 + $aacdec.imdct.OUTPUT_ADDR_FIELD];
   I5 = r1;                         // output
   I6 = r1;                         // output
   I5 = I5 + r8,
    r0 = M[I0,M2];

   do pre_copy_loop;
      r0 = M[I0,M2],
       M[I5,M0] = r0;
   pre_copy_loop:

   M[I5,M0] = r0;

   // set up two registers to work through the input in opposite directions
   I0 = I4;                         // input
   I5 = I6;                         // output
   I5 = I5 + r8,
    r4 = M[I2,M0];                  // c

   // to make the additions easier below set c= -c & s= -s
   r4 = -r4,                        // r4 = -c
    r5 = M[I2,M0];                  // s
   r5 = -r5,                        // r5 = -s
    r0 = M[I0, M1];                 // -tempr

   // use M3 as a loop counter
   M3 = 3;
   M2 = 0;

   // tmp used to store c
   I1 = &$aacdec.tmp;

   outer_pre_process_loop:

      r10 = r8 LSHIFT -3;              // r10 = N/8
      I2 = I2 + 2;
      do pre_process_loop;

         // process the data
         rMAC = r0 * r4,                  // rMAC = (-tempr) * (-c)
          r1 = M[I5, M0];                 // tempi

         rMAC = rMAC + r1 * r5;           // rMAC = temp*c + tempi*(-s)

         rMAC = r0 * r5,                  // rMAC = (-tempr)*(-s)
          M[I4, M0] = rMAC;

         rMAC = rMAC - r1 * r4;           // rMAC = tempr*s - tempi*(-c)

         // update the multipliers: "c" and "s"
         rMAC = r4 * r2,                  // (-c) * cfreq
          M[I6, M0] = rMAC;

         rMAC = rMAC - r5 * r3,           // (-c)'= (-c) * cfreq - (-s) * sfreq
          r0 = M[I0, M1];

         rMAC = r4 * r3,                  // (-c_old) * sfreq
          M[I1,M2] = rMAC;
         rMAC = rMAC + r5 * r2;           // (-s)' = (-c_old)*sfreq + (-s)*cfreq

         r5 = rMAC,                       // r5 = (-s)'
          r4 = M[I1,M2];
      pre_process_loop:

      // load the constant points mid way to improve accuracy
      r4 = M[I2,M0];

      r4 = -r4,
       r5 = M[I2,M0];

      r5 = -r5;
      M3 = M3 - M0;
   if POS jump outer_pre_process_loop;

   // set up data in fft_structure
   // I7 is what the ifft actually uses
   I7 = r6;
   r2 = r8 LSHIFT -1;
   M[r6 + $fft.NUM_POINTS_FIELD] = r2;

   // -- call the ifft --
   // set up for a scaled 64point IFFT (gain of 64)
   r8 = 1.0;               // (64*0.5^6)^(1/6)
   // set up for a scaled 512point IFFT (gain of 64)
   r7 = 0.79370052598410;  // (64*0.5^9)^(1/9)
   Null = r2 - 512;
   if Z r8 = r7;
#ifdef AACDEC_ELD_ADDITIONS
   // set up for a scaled 256point IFFT (gain of 64)
   r7 = 0.840896415253715;  // (64*0.5^8)^(1/8)
   Null = r2 - 256;
   if Z r8 = r7;
#endif // AACDEC_ELD_ADDITIONS
   call $math.scaleable_ifft;


   // re-set up the number of points
   r1 = I7;
   r10 = M[r1 + $aacdec.imdct.NUM_POINTS_FIELD]; // r10 = N/2
   r8 = r10 LSHIFT 1;
   M[r1 + $aacdec.imdct.NUM_POINTS_FIELD] = r8;

   // set up the shift registers
   M0 = 1;
   M1 = 2;
   M2 = -2;

   // copy the data out of the temporary store after the IFFT
   r2 = M[r1 + $aacdec.imdct.INPUT_ADDR_FIELD];
   I0 = r2;
   I0 = I0 + r10;                      // I0 points to the second half

   r2 = M[r1 + $aacdec.imdct.OUTPUT_ADDR_FIELD];
   I4 = r2;
   I7 = r2;

#ifdef AACDEC_ELD_ADDITIONS
   // for AAC ELD we write the output buffer from an offset == half the size of IMDCT
   r0 = M[$aacdec.audio_object_type];
   Null = r0 - $aacdec.ER_AAC_ELD;
   if EQ I7 = I7 + r10;
#endif //AACDEC_ELD_ADDITIONS

   r10 = r10 - M0,                     // r10 = N/2 - 1
    r0 = M[I4, M0];                    // do one read and write outside the loop

   do copy_loop;
      r0 = M[I4, M0],
       M[I0, M0] = r0;
   copy_loop:

   // calculate some bit reverse constants
   r6 = SIGNDET r8,
    M[I0, M0] = r0;                 // perform the last memory write
   #if defined(KAL_ARCH3)|| defined(KAL_ARCH5)
      r6 = r6 + 2;                     // would use +1, but splitting data in half
   #else
      #error Unsupported architecture
      r6 = r6 - 6;                     // would use -7, but splitting data in half
   #endif
   r7 = 1;                          // r7 used as loop counter, set for below
   r6 = r7 LSHIFT r6;
   M3 = r6;                         // bit reverse shift register
   r6 = r6 LSHIFT -1;               // shift operator for I1 initialisation

   // post process the data
   I2 = &sin_const;
#ifdef AACDEC_ELD_ADDITIONS
   I3 = &sin_const_eld;
   Null = r8 - 512;
   if EQ I2 = I3;
#endif // AACDEC_ELD_ADDITIONS

   Null = r8 - 1024;
   if POS I2 = I2 + M1;

#ifdef AACDEC_ELD_ADDITIONS
   Null = r8 - 512;
   if EQ I2 = I2 + M1;
#endif // AACDEC_ELD_ADDITIONS

   r2 = M[r1 + $aacdec.imdct.INPUT_ADDR_BR_FIELD];
   I0 = r2;                         // real ifft component
   I1 = I0 + r6,                    // imaginary ifft component
    r2 = M[I2, M0];                 // cfreq

   r10 = r8 LSHIFT -1;              // r10 = N/2

   // set up pointers to output buffers
   r3 = M[I2, M0];                  // sfreq
   I6 = I7 - M0,
    r4 = M[I2, M0];                 // c
   I6 = I6 + r8,
    r5 = M[I2, M0];                 // s

   // store the constant locations in r6
   r6 = I2 + 2;

   // data is returned bit reversed, so enable bit reverse addressing on AG1
   rFlags = rFlags OR $BR_FLAG;

   // load bit reversed tmp c location
   I2 = BITREVERSE(&$aacdec.tmp);
   M0 = 0,
    r0 = M[I0, M3];                 // tempr

   // use r7 as outer loop counter, set above
   post_process_loop1:

      r10 = r8 LSHIFT -3;             // r10 = N/8

      do inner_post_process_loop1;

         rMAC = r0 * r4,                  // rMAC = tempr * c
          r1 = M[I1, M3];                 // tempi

         rMAC = rMAC - r1 * r5;           // rMAC = tempr*c - tempi*s


         rMAC = r1 * r4,                  // rMAC = tempi * c
          M[I6, M2] = rMAC;               // I6 = tr

         rMAC = rMAC + r0 * r5;           // rMAC = tempi*c + tempr*s

         // update the multipliers: "c" and "s"
         rMAC = r4 * r2,                  // c * cfreq
          M[I7, M1] = rMAC;

         rMAC = rMAC - r5 * r3,           // c' = c * cfreq - s * sfreq
          r0 = M[I0, M3];

         rMAC = r4 * r3,                  // c_old * sfreq
          M[I2,M0] = rMAC;

         rMAC = rMAC + r5 * r2;           // s' = c_old*sfreq + s*cfreq

         r5 = rMAC,                       // r5 = s'
          r4 = M[I2,M0];

      inner_post_process_loop1:

      // load more accurate data for c and s
      r4 = M[r6];
      r5 = M[r6 + 1];
      r6 = r6 + 4;
      r7 = r7 - 1;
   if POS jump post_process_loop1;

   // use r7 as loop counter but check for Zero condition to loop

   post_process_loop2:

      r10 = r8 LSHIFT -3;              // r10 = N/8

      do inner_post_process_loop2;

         rMAC = r0 * r5,                  // rMAC = tempr*s
          r1 = M[I1, M3];                 // tempi

         rMAC = rMAC + r1 * r4;           // rMAC = tempr*s + tempi * c

         rMAC = r0 * r4,                  // rMAC = tempr * c
          M[I7, M1] = rMAC;

         rMAC = rMAC - r1 * r5;           // rMAC = tempr*c - tempi*s

         // Update the multipliers: "c" and "s"
         rMAC = r4 * r2,                  // c * cfreq
          M[I6, M2] = rMAC;

         rMAC = rMAC - r5 * r3,           // c' = c * cfreq - s * sfreq
          r0 = M[I0, M3];

         rMAC = r4 * r3,                  // c_old * sfreq
          M[I2,M0] = rMAC;

         rMAC = rMAC + r5 * r2;           // s' = c_old*sfreq + s*cfreq

         r5 = rMAC,                       // r5 = s'
          r4 = M[I2,M0];

      inner_post_process_loop2:

      // load more accurate data for c and s
      r4 = M[r6];
      r5 = M[r6 + 1];
      r6 = r6 + 4;
      r7 = r7 + 1;
      // to save instruction check zero condition, as r7 will come through as -1
      // the first time, so add one each time.
   if Z jump post_process_loop2;

   // disable bit reversed addressing on AG1
   rFlags = rFlags AND $NOT_BR_FLAG;

   L4 = 0;
   L5 = 0;

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;
