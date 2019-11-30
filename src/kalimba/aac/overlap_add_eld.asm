// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifdef AACDEC_ELD_ADDITIONS

#include "aac_library.h"

// *****************************************************************************
// MODULE:
//    $aacdec.overlap_add_eld
//
// DESCRIPTION:
//    AAC ELD overlap-add
//
// INPUTS:
//    - r4 - frame size (512|480)
//    - I1 - overlap-add write pointer
//    - I2 - transform buffer read pointer
//    - I3 - overlap-add read pointer
//    - I4 - Low Delay window read pointer
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0, r2, r5, r10, rMAC, I1-I4, M1
//
// NOTE:
//   All the INPUTS registers are calculated by function $aacdec.windowing_eld. 
//
// *****************************************************************************
.MODULE $M.aacdec.overlap_add_eld;
   .CODESEGMENT AACDEC_OVERLAP_ADD_ELD_PM;
   .DATASEGMENT DM;

   $aacdec.overlap_add_eld:

   // We do some very basic safety checks to establish if $aacdec.windowing_eld,
   // which calculates the input arguments passed into this function, did not
   // exit early in which case the inputs may contain random values.
   r5 = M[$aacdec.codec_struc];
   Null = M[$aacdec.current_channel];
   if NZ jump right_chan;
   left_chan:
      r0 = M[r5 + $codec.DECODER_OUT_LEFT_BUFFER_FIELD];
      // if no buffer connected just exit
      // (eg. only playing 1 channel of a stereo stream)
      if Z rts;
      jump chan_select_done;
   right_chan:
      r0 = M[r5 + $codec.DECODER_OUT_RIGHT_BUFFER_FIELD];
      // if no buffer connected just exit
      // (eg. only playing 1 channel of a stereo stream)
      if Z rts;
   chan_select_done:
   
   // update the first part of overlap_add buffer
   // Loop counter = 2*$aacdec.FRAME_SIZE_X (== 1024|960) 
   r10 = r4 LSHIFT 1;
   r10 = r10 - 1;
   M1 = 1;
   
   rMAC = M[I3,M1];
   r0 = M[I2,M1], r2 = M[I4,M1];   
   do update_overlap_add1;
      rMAC = rMAC + r0*r2,    r0 = M[I2,M1],  r2 = M[I4,M1];
      M[I1,M1] = rMAC;
      rMAC = M[I3,M1];
   update_overlap_add1:
   rMAC = rMAC + r0*r2;
   M[I1,M1] = rMAC;

   // Update the rest of overlap_add buffer.
   // Loop counter = $aacdec.FRAME_SIZE_X - $aacdec.delay_shift
   // A maximum of $aacdec.FRAME_SIZE_X will be updated.
   r2 = M[$aacdec.delay_shift];
   r10 = r4 - r2; 
   r10 = r10 - 1;

   r0 = M[I2,M1], r2 = M[I4,M1];   
   do update_overlap_add2;
      rMAC = r0*r2,    r0 = M[I2,M1],  r2 = M[I4,M1];
      M[I1,M1] = rMAC;
   update_overlap_add2:
   rMAC = r0*r2;
   M[I1,M1] = rMAC;

   rts;
   
.ENDMODULE;

#endif //AACDEC_ELD_ADDITIONS
