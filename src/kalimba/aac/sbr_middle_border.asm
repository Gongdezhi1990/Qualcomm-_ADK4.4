// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#ifdef AACDEC_SBR_ADDITIONS

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.sbr_middle_border
//
// DESCRIPTION:
//    Calculate the 'middleBorder'
//
// INPUTS:
//    - r2 SBR_bs_num_env[ch]
//    - r5 current channel (0/1)
//
// OUTPUTS:
//    - r3 SBR_middle_border_index[ch]
//
// TRASHED REGISTERS:
//    - none
//
// *****************************************************************************
.MODULE $M.aacdec.sbr_middle_border;
   .CODESEGMENT AACDEC_SBR_MIDDLE_BORDER_PM;
   .DATASEGMENT DM;

   $aacdec.sbr_middle_border:

   // switch(SBR_bs_frame_class[ch])
   r3 = M[($aacdec.sbr_np_info + $aacdec.SBR_bs_frame_class) + r5];

   // case SBR_FIXFIX
   Null = r3 - $aacdec.SBR_FIXFIX;
   if NZ jump not_case_fixfix;
      r3 = r2 LSHIFT -1;
      rts;
   // case SBR_VARFIX
   not_case_fixfix:
#ifdef AACDEC_ELD_ADDITIONS
// case SBR_LDTRAN
   Null = r3 - $aacdec.SBR_LDTRAN;
   if NZ rts;
      r3 = 1;
      rts;
#else 
   Null = r3 - $aacdec.SBR_VARFIX;
   if NZ jump not_case_varfix;
      r3 = M[($aacdec.sbr_np_info + $aacdec.SBR_bs_pointer) + r5];
      // if(SBR_bs_pointer[ch]==0)
      if NZ jump bs_pointer_ne_zero;
         r3 = 1;
         rts;
      // if(SBR_bs_pointer[ch]==1)
      bs_pointer_ne_zero:
      Null = r3 - 1;
      if NZ jump bs_pointer_ne_one;
         r3 = r2 - 1;
         rts;
      bs_pointer_ne_one:
         r3 = r3 - 1;
         rts;
   // case SBR_FIXVAR | SBR_VARFIX
   not_case_varfix:
   // if(SBR_bs_pointer[ch] > 1)
   r3 = M[($aacdec.sbr_np_info + $aacdec.SBR_bs_pointer) + r5];
   Null = r3 - 1;
   if LE jump bs_pointer_le_one;
      r3 = r2 - r3;
      r3 = r3 + 1;
      rts;
   bs_pointer_le_one:
   r3 = r2 - 1;
   rts;
#endif 

.ENDMODULE;

#endif
