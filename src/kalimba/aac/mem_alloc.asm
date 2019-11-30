// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.tmp_mem_pool_allocate
//
// DESCRIPTION:
//    Temporary memory pool allocate
//
// INPUTS:
//    - r0 = number of words to allocate
//
// OUTPUTS:
//    - r0 = set to -ve on error otherwise unaffected
//    - r1 = pointer to memory to use
//
// TRASHED REGISTERS:
//    r2
//
// *****************************************************************************
.MODULE $M.aacdec.tmp_mem_pool_allocate;
   .CODESEGMENT AACDEC_TMP_MEM_POOL_ALLOCATE_PM;
   .DATASEGMENT DM;

   $aacdec.tmp_mem_pool_allocate:

   Null = r0;
   if NEG rts;
 #ifndef AAC_USE_EXTERNAL_MEMORY
   r1 = M[$aacdec.tmp_mem_pool_end];
   M[$aacdec.tmp_mem_pool_end] = r1 + r0;

   r2 = r1 + r0;
   r2 = r2 - (&$aacdec.tmp_mem_pool + $aacdec.TMP_MEM_POOL_LENGTH);
 #else 
   r1 = M[$aacdec.tmp_mem_pool_end_ptr];
   r2 = r1 + r0 ;
   M[$aacdec.tmp_mem_pool_end_ptr] = r2 ; //r1 + r0;

  // r2 = r1 + r0;
   r3 = M[$aacdec.tmp_mem_pool_ptr];
   r3 = r3 + 2504; 
   r2 = r2 - r3 ; // (&$aacdec.tmp_mem_pool + $aacdec.TMP_MEM_POOL_LENGTH);
 #endif 
 
   #ifdef AACDEC_CALL_ERROR_ON_MALLOC_FAIL
      if GT call $error;
   #else
      if LE jump ok;
         r0 = -1;
      ok:
   #endif

   Null = r0;
   rts;

.ENDMODULE;





// *****************************************************************************
// MODULE:
//    $aacdec.tmp_mem_pool_free
//
// DESCRIPTION:
//    Temporary memory pool free
//
// INPUTS:
//    - r0 = number of words to free
//
// OUTPUTS:
//    - r0 = set to -ve on error otherwise unaffected
//
// TRASHED REGISTERS:
//    r1
//
// *****************************************************************************
.MODULE $M.aacdec.tmp_mem_pool_free;
   .CODESEGMENT AACDEC_TMP_MEM_POOL_FREE_PM;
   .DATASEGMENT DM;

   $aacdec.tmp_mem_pool_free:

   Null = r0;
   if NEG rts;
 #ifndef AAC_USE_EXTERNAL_MEMORY
   r1 = M[$aacdec.tmp_mem_pool_end];
   M[$aacdec.tmp_mem_pool_end] = r1 - r0;

   r1 = r1 - r0;
   r1 = r1 - &$aacdec.tmp_mem_pool;
  #else 
   r1 = M[$aacdec.tmp_mem_pool_end_ptr];
   r2 = r1- r0 ;
   M[$aacdec.tmp_mem_pool_end_ptr] = r2 ; // r1 - r0;

   r1 = r1 - r0;
   r2 = M[$aacdec.tmp_mem_pool_ptr];
   r1 = r1 - r2;//&$aacdec.tmp_mem_pool;
   #endif 
   #ifdef AACDEC_CALL_ERROR_ON_MALLOC_FAIL
      if NEG call $error;
   #else
      if POS jump ok;
         r0 = -1;
      ok:
   #endif

   Null = r0;
   rts;

.ENDMODULE;





// *****************************************************************************
// MODULE:
//    $aacdec.tmp_mem_pool_free_all
//
// DESCRIPTION:
//    Temporary memory pool free all
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    r0
//
// *****************************************************************************
.MODULE $M.aacdec.tmp_mem_pool_free_all;
   .CODESEGMENT AACDEC_TMP_MEM_POOL_FREE_ALL_PM;
   .DATASEGMENT DM;

   $aacdec.tmp_mem_pool_free_all:
 #ifndef AAC_USE_EXTERNAL_MEMORY
   r0 = &$aacdec.tmp_mem_pool;
   M[$aacdec.tmp_mem_pool_end] = r0;
 #else
   r0 = M[$aacdec.tmp_mem_pool_ptr];//&$aacdec.tmp_mem_pool;
   M[$aacdec.tmp_mem_pool_end_ptr] = r0;
 #endif 
   rts;

.ENDMODULE;





// *****************************************************************************
// MODULE:
//    $aacdec.frame_mem_pool_allocate
//
// DESCRIPTION:
//    Frame memory pool allocate
//
// INPUTS:
//    - r0 = number of words to allocate
//
// OUTPUTS:
//    - r0 = set to -ve on error otherwise unaffected
//    - r1 = pointer to memory to use
//
// TRASHED REGISTERS:
//    r2
//frame_mem_pool_ptr
// *****************************************************************************
.MODULE $M.aacdec.frame_mem_pool_allocate;
   .CODESEGMENT AACDEC_FRAME_MEM_POOL_ALLOCATE_PM;
   .DATASEGMENT DM;

   $aacdec.frame_mem_pool_allocate:

   Null = r0;
   if NEG rts;
 #ifndef AAC_USE_EXTERNAL_MEMORY
   r1 = M[$aacdec.frame_mem_pool_end];
   M[$aacdec.frame_mem_pool_end] = r1 + r0;
   r2 = r1 + r0;
   r2 = r2 - (&$aacdec.frame_mem_pool + $aacdec.FRAME_MEM_POOL_LENGTH);
#else 
   
   r1 = M[$aacdec.frame_mem_pool_end_ptr];
   r2 = r1 + r0;
   M[$aacdec.frame_mem_pool_end_ptr] = r2 ; // r1 + r0;

   r2 = r1 + r0;
   r3 = M[$aacdec.frame_mem_pool_ptr];
   r3 = r3 + 1696;
   r2 = r2 - r3 ; // (r3 + $aacdec.FRAME_MEM_POOL_LENGTH);
#endif 
   #ifdef AACDEC_CALL_ERROR_ON_MALLOC_FAIL
      if GT call $error;
   #else
      if LE jump ok;
         r0 = -1;
      ok:
   #endif

   Null = r0;
   rts;

.ENDMODULE;





// *****************************************************************************
// MODULE:
//    $aacdec.frame_mem_pool_free
//
// DESCRIPTION:
//    Frame memory pool free
//
// INPUTS:
//    - r0 = number of words to free
//
// OUTPUTS:
//    - r0 = set to -ve on error otherwise unaffected
//
// TRASHED REGISTERS:
//    r1
//
// *****************************************************************************
.MODULE $M.aacdec.frame_mem_pool_free;
   .CODESEGMENT AACDEC_FRAME_MEM_POOL_FREE_PM;
   .DATASEGMENT DM;

   $aacdec.frame_mem_pool_free:

   Null = r0;
   if NEG rts;
 #ifndef AAC_USE_EXTERNAL_MEMORY
   r1 = M[$aacdec.frame_mem_pool_end];
   M[$aacdec.frame_mem_pool_end] = r1 - r0;

   r1 = r1 - r0;
   r1 = r1 - &$aacdec.frame_mem_pool;
 #else 
   r1 = M[$aacdec.frame_mem_pool_end_ptr];
   r1 = r1 - r0;
   M[$aacdec.frame_mem_pool_end_ptr] = r1 ; // r1 - r0;

   //r1 = r1 - r0;
   r0 = M[$aacdec.frame_mem_pool_ptr];
   r1 = r1 - r0 ; //&$aacdec.frame_mem_pool;
 #endif 
   #ifdef AACDEC_CALL_ERROR_ON_MALLOC_FAIL
      if NEG call $error;
   #else
      if POS jump ok;
         r0 = -1;
      ok:
   #endif
   Null = r0;
   rts;

.ENDMODULE;





// *****************************************************************************
// MODULE:
//    $aacdec.frame_mem_pool_free_all
//
// DESCRIPTION:
//    Frame memory pool free all
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    r0
//
// *****************************************************************************
.MODULE $M.aacdec.frame_mem_pool_free_all;
   .CODESEGMENT AACDEC_FRAME_MEM_POOL_FREE_ALL_PM;
   .DATASEGMENT DM;

   $aacdec.frame_mem_pool_free_all:
 #ifndef AAC_USE_EXTERNAL_MEMORY
   r0 = &$aacdec.frame_mem_pool;
   M[$aacdec.frame_mem_pool_end] = r0;
 #else 
   r0 = M[$aacdec.frame_mem_pool_ptr] ;//&$aacdec.frame_mem_pool;
   M[$aacdec.frame_mem_pool_end_ptr] = r0;
 #endif 
   M[$aacdec.amount_unpacked] = Null;
   rts;

.ENDMODULE;
