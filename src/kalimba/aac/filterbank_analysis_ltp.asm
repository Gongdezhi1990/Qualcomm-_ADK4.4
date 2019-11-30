// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.filterbank_analysis_ltp
//
// DESCRIPTION:
//    Analysis filterbank (windowing and mdct)
//
// INPUTS:
//    - I2 = pointer to mdct input buffer
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - assume all
//
// *****************************************************************************
.MODULE $M.aacdec.filterbank_analysis_ltp;
   .CODESEGMENT AACDEC_FILTERBANK_ANALYSIS_LTP_PM;
   .DATASEGMENT DM;

   $aacdec.filterbank_analysis_ltp:

   // push rLink onto stack
   push rLink;

   // window the 2048 sample mdct-input
   // flag not to update prev_window_shape
   M0 = -1;
 #ifndef AAC_USE_EXTERNAL_MEMORY
   I5 = &$aacdec.tmp_mem_pool;
 #else 
   r4 = M[$aacdec.tmp_mem_pool_ptr];
   I5 = r4 ; // M[r9 + $aac.mem.TMP_MEM_POOL_PTR];//&$aacdec.tmp_mem_pool;
 #endif 
   call $aacdec.windowing;
   M0 = 2;
   //I5 = &$aacdec.tmp_mem_pool+1024;
  #ifndef AAC_USE_EXTERNAL_MEMORY
   r4 = &$aacdec.tmp_mem_pool + 1024;
  #else 
   r4 = M[$aacdec.tmp_mem_pool_ptr];
   r4 = r4 + 1024;//
   //r4 = &$aacdec.tmp_mem_pool + 1024;
  #endif 
   call $aacdec.windowing;

   // initialise input structure for mdct
   r6 = &$aacdec.mdct_information;
   r0 = 2048;
   M[r6 + $aacdec.mdct.NUM_POINTS_FIELD] = r0;
   #ifndef AAC_USE_EXTERNAL_MEMORY
   r0 = &$aacdec.tmp_mem_pool;
   #else 
   r0 = M[$aacdec.tmp_mem_pool_ptr] ; //&$aacdec.tmp_mem_pool;
   #endif 
   M[r6 + $aacdec.mdct.INPUT_ADDR_FIELD] = r0;
   #ifndef AAC_USE_EXTERNAL_MEMORY    
   r0 = BITREVERSE(&$aacdec.tmp_mem_pool);
   #else 
   call $math.address_bitreverse;
   r0 = r1 ; // BITREVERSE(&$aacdec.tmp_mem_pool);
   #endif 
   M[r6 + $aacdec.mdct.INPUT_ADDR_BR_FIELD] = r0;

   // do the mdct
   call $aacdec.mdct;

   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;
