// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#ifdef AACDEC_PARAMETRIC_STEREO_ADDITIONS

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.ps_inverse_8point_fft
//
// DESCRIPTION:
//    -
//
// INPUTS:
//    - r10  pointer to inv_fft_input[n][0]
//    - I0   pointer to real(output_vector)
//    - I4   pointer to imag(output_vector)
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - toupdate
//
// *****************************************************************************
.MODULE $M.aacdec.ps_inverse_8point_fft;
   .CODESEGMENT AACDEC_PS_INVERSE_8POINT_FFT_PM;
   .DATASEGMENT DM;



   $aacdec.ps_inverse_8point_fft:


   r0 = M[r10 + 0];
   r1 = M[r10 + 8];
   r0 = r0 + r1;  // r0 = input_vector[0] + input_vector[8] = a0

   r1 = M[r10 + 4];
   r2 = M[r10 + 12];
   r3 = M[r10 + 9];
   r1 = r1 + r2;  // r1 = input_vector[4] + input_vector[12] = b0

   r2 = M[r10 + 1];
   r4 = M[r10 + 13];
   r2 = r2 + r3;  // r2 = input_vector[1] + input_vector[9] = c0

   r3 = M[r10 + 5];
   r5 = r0 + r1;  // r5 = (input_vector[0]+input_vector[8]) + (input_vector[4]+input_vector[12]) = a0 + b0
   r3 = r3 + r4;  // r3 = input_vector[5] + input_vector[13] = d0

   r6 = r2 + r3;  // r6 = (input_vector[1]+input_vector[9]) + (input_vector[5]+input_vector[13]) = c0 + d0
   r7 = r0 - r1;  // r7 = (input_vector[0]+input_vector[8]) - (input_vector[4]+input_vector[12]) = a0 - b0
   r8 = r2 - r3;  // r8 = (input_vector[1]+input_vector[9]) - (input_vector[5]+input_vector[13]) = c0 - d0

   r0 = M[r10 + 2];
   r1 = M[r10 + 10];
   r2 = M[r10 + 14];
   r0 = r0 + r1;  // r0 = input_vector[2] + input_vector[10] = a0

   r1 = M[r10 + 6];
   r3 = M[r10 + 11];
   r1 = r1 + r2;  // r1 = input_vector[6] + input_vector[14] = b0

   r2 = M[r10 + 3];
   r4 = M[r10 + 15];
   r2 = r2 + r3;  // r2 = input_vector[3] + input_vector[11] = c0

   r3 = M[r10 + 7];
   r0 = r0 - r1;  // r0 = (input_vector[2]+input_vector[10]) - (input_vector[6]+input_vector[14]) = a0 - b0
   r3 = r3 + r4;  // r3 = input_vector[7] + input_vector[15] = d0

   r4 = r0 + r1;  // r4 = (input_vector[2]+input_vector[10]) + (input_vector[6]+input_vector[14]) = a0 + b0
   r1 = r2 + r3;  // r1 = (input_vector[3]+input_vector[11]) + (input_vector[7]+input_vector[15]) = c0 + d0
   r2 = r2 - r3;  // r2 = (input_vector[3]+input_vector[11]) - (input_vector[7]+input_vector[15]) = c0 - d0

   M[(&$aacdec.frame_mem_pool + 1024)] = r5 + r4;
   M[(&$aacdec.tmp_mem_pool + 2048)] = r6 + r1;

   M[(&$aacdec.frame_mem_pool + 1024) + 2] = r7 - r2;
   M[(&$aacdec.tmp_mem_pool + 2048) + 2] = r8 + r0;

   M[(&$aacdec.frame_mem_pool + 1024) + 4] = r5 - r4;
   M[(&$aacdec.tmp_mem_pool + 2048) + 4] = r6 - r1;

   M[(&$aacdec.frame_mem_pool + 1024) + 6] = r7 + r2;
   M[(&$aacdec.tmp_mem_pool + 2048) + 6] = r8 - r0;

   r0 = M[r10 + 0];
   r1 = M[r10 + 8];
   r2 = M[r10 + 12];
   r0 = r0 - r1;  // r0 = input_vector[0] - input_vector[8] = a1

   r1 = M[r10 + 4];
   r3 = M[r10 + 9];
   r1 = r1 - r2;  // r1 = input_vector[4] - input_vector[12] = c1

   r2 = M[r10 + 1];
   r4 = M[r10 + 13];
   r2 = r2 - r3;  // r2 = input_vector[1] - input_vector[9] = d1

   r3 = M[r10 + 5];
   r7 = r2 + r1;  // r7 = (input_vector[1]-input_vector[9]) + (input_vector[4]-input_vector[12]) = d1 + c1
   r3 = r3 - r4;  // r3 = input_vector[5] - input_vector[13] = b1

   r5 = r0 - r3;  // r5 = (input_vector[0]-input_vector[8]) - (input_vector[5]-input_vector[13]) = a1 - b1
   r6 = r0 + r3;  // r6 = (input_vector[0]-input_vector[8]) + (input_vector[5]-input_vector[13]) = a1 + b1
   r8 = r2 - r1;  // r8 = (input_vector[1]-input_vector[9]) - (input_vector[4]-input_vector[12]) = d1 - c1

   r0 = M[r10 + 2];
   r1 = M[r10 + 10];
   r2 = M[r10 + 15];
   r0 = r0 - r1;  // r0 = input_vector[2] - input_vector[10] = a1

   r1 = M[r10 + 7];
   r3 = M[r10 + 11];
   r1 = r1 - r2;  // r1 = input_vector[7] - input_vector[15] = b1

   r2 = M[r10 + 3];
   r4 = M[r10 + 14];
   r2 = r2 - r3;  // r2 = input_vector[3] - input_vector[11] = d1

   r3 = M[r10 + 6];
   r0 = r0 + r1;  // r0 = (input_vector[2]-input_vector[10]) + (input_vector[7]-input_vector[15]) = a1 + b1
   r3 = r3 - r4;  // r3 = input_vector[6] - input_vector[14] = c1

   r4 = r0 - r1;  // r4 = (input_vector[2]-input_vector[10]) - (input_vector[7]-input_vector[15]) = a1 - b1
   r1 = r2 + r3;  // r1 = (input_vector[3]-input_vector[11]) + (input_vector[6]-input_vector[14]) = d1 + c1
   r2 = r2 - r3;  // r2 = (input_vector[3]-input_vector[11]) - (input_vector[6]-input_vector[14]) = d1 - c1

   rMAC = $aacdec.PS_COS_PI_OVER_FOUR;

   // r3 = temp_real_1
   r3 = r4 - r1;
   r3 = r3 * rMAC (frac);
   // save r10
   M[$aacdec.tmp + $aacdec.PS_HYBRID_TYPE_A_FIR_TEMP_R10] = r10;
   // r10 = temp_real_2
   r10 = r0 + r2;
   r10 = r10 * rMAC (frac);

   M[(&$aacdec.frame_mem_pool + 1024) + 1] = r5 + r3;
   M[(&$aacdec.frame_mem_pool + 1024) + 3] = r6 - r10;
   M[(&$aacdec.frame_mem_pool + 1024) + 5] = r5 - r3;
   M[(&$aacdec.frame_mem_pool + 1024) + 7] = r6 + r10;

   // r3 = temp_imag_1
   r3 = r4 + r1;
   r3 = r3 * rMAC (frac);
   // r10 = temp_imag_2
   r10 = r0 - r2;
   r10 = r10 * rMAC (frac);

   M[(&$aacdec.tmp_mem_pool + 2048) + 1] = r7 + r3;
   M[(&$aacdec.tmp_mem_pool + 2048) + 3] = r8 + r10;
   M[(&$aacdec.tmp_mem_pool + 2048) + 5] = r7 - r3;
   M[(&$aacdec.tmp_mem_pool + 2048) + 7] = r8 - r10;

   // restore r10
   r10 = M[$aacdec.tmp + $aacdec.PS_HYBRID_TYPE_A_FIR_TEMP_R10];



   rts;




.ENDMODULE;

#endif
