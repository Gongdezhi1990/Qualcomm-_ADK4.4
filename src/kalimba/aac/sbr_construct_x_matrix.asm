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
//    $aacdec.sbr_construct_x_matrix
//
// DESCRIPTION:
//    - sets kx_band, kx_prev, M_band and M_prev in sbr_info
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0-3, r5-6
//
// *****************************************************************************
.MODULE $M.aacdec.sbr_construct_x_matrix;
   .CODESEGMENT AACDEC_SBR_CONSTRUCT_X_MATRIX_PM;
   .DATASEGMENT DM;

   $aacdec.sbr_construct_x_matrix:

   // push rLink onto stack
   push rLink;


   // r5 = kx
   // r6 = M
   r5 = M[$aacdec.sbr_info + $aacdec.SBR_kx];
   r6 = M[$aacdec.sbr_info + $aacdec.SBR_M];


   // if (headercount ~= 0)
   r0 = M[$aacdec.sbr_info + $aacdec.SBR_header_count];
   if Z jump use_old_values;

      // if(numTimeSlotsRate <= sbr.t_E(ch, 1))
      //    kx_band = sbr.kx_prev;
      //    M_band = sbr.M_prev;
      // else
      //    kx_band = sbr.Kx;
      //    M_band = sbr.M;
      // end;
      r0 = M[&$aacdec.current_channel];
      r0 = r0 * 6 (int);

      r0 = M[($aacdec.sbr_np_info + $aacdec.SBR_t_E) + r0];
#ifndef AACDEC_ELD_ADDITIONS
      Null = r0 - $aacdec.SBR_numTimeSlotsRate;
#else 
      r1 = M[$aacdec.SBR_numTimeSlotsRate_eld];
	  NULL = r0-r1;
#endif //AACDEC_ELD_ADDITIONS
      if LT jump not_prev;
         r2 = M[$aacdec.sbr_info + $aacdec.SBR_kx_prev];
         r3 = M[$aacdec.sbr_info + $aacdec.SBR_M_prev];
         M[$aacdec.tmp_mem_pool + $aacdec.SBR_kx_band] = r2;
         M[$aacdec.tmp_mem_pool + $aacdec.SBR_M_band] = r3;
         jump out_main_if;

      not_prev:
         M[$aacdec.tmp_mem_pool + $aacdec.SBR_kx_band] = r5;
         M[$aacdec.tmp_mem_pool + $aacdec.SBR_M_band] = r6;


   out_main_if:
   use_old_values:


   // sbr.kx_prev = sbr.Kx;
   // sbr.M_prev = sbr.M;
   M[$aacdec.sbr_info + $aacdec.SBR_kx_prev] = r5;
   M[$aacdec.sbr_info + $aacdec.SBR_M_prev] = r6;


   // pop rLink from stack
   jump $pop_rLink_and_rts;



.ENDMODULE;

#endif
