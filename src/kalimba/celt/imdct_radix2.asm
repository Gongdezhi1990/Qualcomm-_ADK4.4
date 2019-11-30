// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef CELT_IMDCT_INCLUDED
#define CELT_IMDCT_INCLUDED
#include "stack.h"
#include "fft.h"
#include "celt_decoder.h"
// *****************************************************************************
// MODULE:
//    $celt.imdct_radix2
//
// DESCRIPTION:
//    performs IMDCT transform on decoded frequency spectrum
//
// INPUTS:
//    - I0/L0 = buffer pointer to read the byte from
//    - r5 = pointer to the structure
//
// OUTPUTS:
//   I0 = input (must be circular due to fft)
//   I5 = out 
//   r8 = imdct size
//   r6 = 0 -> left 1-> right
//   r4 = shift output
// TRASHED REGISTERS:
//    Assume everthing
//
// NOTET:
// 1- CELT supports any even frame size value between 64 and 512 samples, this function
//   is usable only for radix2 frame sizes, for other frame size values, an external
//   function is required to do IMDCT operation with the same interface
// 2- The code is similar to AAC decoder imdct, with some modifications
// ***************************************************************************************
.MODULE $M.celt.imdct_radix2;
   .CODESEGMENT CELT_IMDCT_RADIX2_PM;
   .DATASEGMENT DM;
   $celt.imdct_radix2:
   // push rLink onto stack
   $push_rLink_macro;

   .VAR temp[6];
   M[temp + 0] = r5; 
   M[temp + 1] = r8; 
   M[temp + 2] = r6; 
   r0 = I0;
   M[temp + 3] = r0;
   r0 = I5;
   M[temp + 4] = r0;
   M[temp + 5] = r4;
   .VAR scale_factor;
   .VAR tmp_var;
   
   // get the trig from mode object
   I7 = &$celt.dec.fft_struct;
   r2 = r8 LSHIFT -1;
   M[$celt.dec.fft_struct + $fft.NUM_POINTS_FIELD] = r2;
   r0 = I0;
   M[$celt.dec.fft_struct + $fft.REAL_ADDR_FIELD] = r0;
   r0 = I5;
   M[$celt.dec.fft_struct + $fft.IMAG_ADDR_FIELD] = r0;
  
   // get scale factor from mode object
   r0 = M[r5 + $celt.dec.MODE_TRIG_OFFSET_FIELD];
   r1 = &$celt.mode.TRIG_VECTOR_SIZE;
   NULL = M[r5 + $celt.dec.SHORT_BLOCKS_FIELD];
   if Z r1 = 0;
   I2 = r0 + r1;
   r0 = M[I2, 1];
   M[scale_factor] = r0;
   r0 = M[I2, 1];

   // set up the modify registers
   M0 = 1;
   M1 = 2;
   M2 = -2;

   // need to copy the odd values into the output buffer
   r10 = r8 LSHIFT -1;
   r10 = r10 - M0;

   // set a pointer to the start of the copy, and the target
   // and two buffers as output pointers for below
   I4 = I0;                         // input
   I0 = I0 + r8, r2 = M[I2,M0];                  // cfreq
   I0 = I0 - M0, r3 = M[I2,M0];                  // sfreq
   r0 = M[r5 + $celt.dec.IMDCT_OUTPUT_FIELD];
   I6 = r0;
   r4 = M[r5 + $celt.dec.TEMP_FFT_FIELD];
   I5 = r4, r0 = M[I0,M2];
   do pre_copy_loop;
      r0 = M[I0,M2],
       M[I5,M0] = r0;
   pre_copy_loop:
   M[I5,M0] = r0;

   // set up two registers to work through the input in opposite directions
   I0 = I4;                         // input
   I5 = r4, r4 = M[I2,M0];                  // c

   // to make the additions easier below set c= -c & s= -s
   r4 = -r4, r5 = M[I2,M0];   // r4 = -c
   r5 = -r5, r0 = M[I0, M1];  // r5 = -s
 
   // use M3 as a loop counter
   M3 = 3;
   M2 = 0;

   // tmp used to store c
   I1 = &tmp_var;
   outer_pre_process_loop:
      r10 = r8 LSHIFT -3;              // r10 = N/8
      //I2 = I2 + 2;
      do pre_process_loop;
      
         // process the data
         rMAC = r0 * r4, r1 = M[I5, M0];        // rMAC = (-tempr) * (-c)
         rMAC = rMAC + r1 * r5;                 // rMAC = temp*c + tempi*(-s)
         rMAC = r0 * r5, M[I4, M0] = rMAC;      // rMAC = (-tempr)*(-s)
         rMAC = rMAC - r1 * r4;                 // rMAC = tempr*s - tempi*(-c)
         
         // update the multipliers: "c" and "s"
         rMAC = r4 * r2, M[I6, M0] = rMAC;      // (-c) * cfreq
         rMAC = rMAC - r5 * r3, r0 = M[I0, M1]; // (-c)'= (-c) * cfreq - (-s) * sfreq
         rMAC = r4 * r3, M[I1,M2] = rMAC;       // (-c_old) * sfreq
         rMAC = rMAC + r5 * r2;                 // (-s)' = (-c_old)*sfreq + (-s)*cfreq
         r5 = rMAC, r4 = M[I1,M2];              // r5 = (-s)'
      pre_process_loop:

      // load the constant points mid way to improve accuracy
      r4 = M[I2,M0];
      r4 = -r4, r5 = M[I2,M0];
      r5 = -r5;
      M3 = M3 - M0;
   if POS jump outer_pre_process_loop;

   // set up data in fft_structure
   I7 = &$celt.dec.fft_struct;

   // -- call the ifft --
   r8 = M[scale_factor];
   call $math.scaleable_ifft;
   
   r5 = M[temp + 0]; //pointer to objcet
   r8 = M[temp + 1]; //N
   r6 = M[temp + 2]; //c
   
   // get the trig from mode object
   r0 = M[r5 + $celt.dec.MODE_TRIG_OFFSET_FIELD];
   r1 = $celt.mode.TRIG_VECTOR_SIZE;
   NULL = M[r5 + $celt.dec.SHORT_BLOCKS_FIELD];
   if Z r1 = 0;
   I2 = r0 + r1;
   I2 = I2 + 2;

   // re-set up the number of points
   r1 = I7;
   r10 = r8 LSHIFT -1;
 
   // set up the shift registers
   M0 = 1;
   M1 = 2;
   M2 = -2;

   // copy the data out of the temporary store after the IFFT
   r2 = M[temp + 3];
   I0 = r2;
   I0 = I0 + r10;                      // I0 points to the second half

   r2 = M[temp + 4];
   I4 = r2;
   I7 = r2;

   r10 = r10 - M0, r0 = M[I4, M0];                    // r10 = N/2 - 1
                                                      // do one read and write outside the loop
   do copy_loop;
      r0 = M[I4, M0], M[I0, M0] = r0;
   copy_loop:
   




   // calculate some bit reverse constants
   r6 = SIGNDET r8, M[I0, M0] = r0; // perform the last memory write
   #if defined(KAL_ARCH3) || defined(KAL_ARCH5)
   r6 = r6 + 2;                     // would use -7, but splitting data in half
   #else
   r6 = r6 - 6;                     // would use -7, but splitting data in half
   #endif
   r7 = 1;                          // r7 used as loop counter, set for below
   r6 = r7 LSHIFT r6;
   M3 = r6;                         // bit reverse shift register
   r6 = r6 LSHIFT -1;               // shift operator for I1 initialisation

   r0 = M[temp + 3];
   call $math.address_bitreverse;
   I0 = r1;
   I1 = I0 + r6, r2 = M[I2, M0];                     // imaginary ifft component
 

  /*
   M[I0, M0] = r0;
   r0 = M[temp + 3];
   call $math.address_bitreverse;
   r10 = r8 LSHIFT -1;  
   I0 = r1;
   r0 = r0 + 1;
   call $math.address_bitreverse;
   M3 = r1 - I0;
   r0 = r0 + r10;
   r0 = r0 - 1;
   call $math.address_bitreverse;
   I2 = r1, r2 = M[I2, M0];*/
  
                                                   // cfreq
   //r10 = r8 LSHIFT -1;                               // r10 = N/2
   // set up pointers to output buffers
   r3 = M[I2, M0];                                   // sfreq
   I6 = I7 - M0, r4 = M[I2, M0];                     // c
   I6 = I6 + r8, r5 = M[I2, M0];                     // s

   // store the constant locations in r6
   r6 = I2;

   // data is returned bit reversed, so enable bit reverse addressing on AG1
   rFlags = rFlags OR $BR_FLAG;

   // load bit reversed tmp c location
   I2 = BITREVERSE(&tmp_var);
   //call save_I0;
   M0 = 0, r0 = M[I0, M3];                 // tempr

   // use r7 as outer loop counter, set above
   post_process_loop1:

      r10 = r8 LSHIFT -3;             // r10 = N/8
      do inner_post_process_loop1;
         //call save_I1;
         rMAC = r0 * r4, r1 = M[I1, M3];                 // rMAC = tempr * c
                                                         // tempi
         rMAC = rMAC - r1 * r5;                          // rMAC = tempr*c - tempi*s
         rMAC = r1 * r4, M[I6, M2] = rMAC;               // rMAC = tempi * c
                                                         // I6 = tr
         rMAC = rMAC + r0 * r5;                          // rMAC = tempi*c + tempr*s
         
         // update the multipliers: "c" and "s"
         rMAC = r4 * r2, M[I7, M1] = rMAC;               // c * cfreq
        // call save_I0;
         rMAC = rMAC - r5 * r3, r0 = M[I0, M3];          // c' = c * cfreq - s * sfreq
         rMAC = r4 * r3, M[I2,M0] = rMAC;                // c_old * sfreq
         rMAC = rMAC + r5 * r2;                          // s' = c_old*sfreq + s*cfreq
         r5 = rMAC, r4 = M[I2,M0];                       // r5 = s'
      inner_post_process_loop1:

      // load more accurate data for c and s
      r4 = M[r6];
      r5 = M[r6 + 1];
      r6 = r6 + 2;
      r7 = r7 - 1;
   if POS jump post_process_loop1;

   // use r7 as loop counter but check for Zero condition to loop
   post_process_loop2:
      r10 = r8 LSHIFT -3;              // r10 = N/8
      do inner_post_process_loop2;
        // call save_I1;
         rMAC = r0 * r5, r1 = M[I1, M3];                  // rMAC = tempr*s
                                                          // tempi
         rMAC = rMAC + r1 * r4;                           // rMAC = tempr*s + tempi * c
         rMAC = r0 * r4,M[I7, M1] = rMAC;                 // rMAC = tempr * c
         rMAC = rMAC - r1 * r5;                           // rMAC = tempr*c - tempi*s
         
         // Update the multipliers: "c" and "s"
         rMAC = r4 * r2, M[I6, M2] = rMAC;                // c * cfreq
         //call save_I0;
         rMAC = rMAC - r5 * r3, r0 = M[I0, M3];                        // c' = c * cfreq - s * sfreq
         
         
         rMAC = r4 * r3, M[I2,M0] = rMAC;                 // c_old * sfreq
         rMAC = rMAC + r5 * r2;                           // s' = c_old*sfreq + s*cfreq
         r5 = rMAC, r4 = M[I2,M0];                        // r5 = s'          
      inner_post_process_loop2:
      // load more accurate data for c and s
      r4 = M[r6];
      r5 = M[r6 + 1];
      r6 = r6 + 2;//4;
      r7 = r7 + 1;
      // to save instruction check zero condition, as r7 will come through as -1
      // the first time, so add one each time.
   if Z jump post_process_loop2;

   // disable bit reversed addressing on AG1
   rFlags = rFlags AND $NOT_BR_FLAG;

   L4 = 0;
   L5 = 0;
#ifdef BASE_REGISTER_MODE
    push Null;
    pop B4;
    push Null;
    pop B5;
#endif
   // -- see if shift is required
   r4 = M[temp + 5];
   if Z jump end;
   r7 = 0x400000;
   r8 = -22 - r4;
   r8 = r7 LSHIFT r8;
   
   // -- get output address
   r0 = M[temp + 4];
   I2 = r0;
   
   // -- get output length
   r10 = M[temp + 1];   
   M0 = -1;   
   M1 = 2;
   r10 = r10 - 1;
   r0 = 1.0;
   
   // -- shift and round
   rMAC = M[I2, 1];          
   rMAC = rMAC + r8 * r7;
   do shift_round_loop;
      r1 = rMAC ASHIFT r4, rMAC = M[I2, M0];   
      rMAC = rMAC + r8 * r7, M[I2, M1] = r1;    
   shift_round_loop:
   r1 = rMAC ASHIFT r4, rMAC = M[I2, M0];
   M[I2, M1] = r1;
   end:
   
   r5 = M[temp + 0]; //pointer to objcet
  
   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;


#endif
