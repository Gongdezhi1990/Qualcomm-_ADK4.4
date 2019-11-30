// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// Part of ADK_CSR867x.WIN. 4.4
// *****************************************************************************

#include "celt_library.h"
#include "core_library.h"
//************************************************************************************************
// MODULE:  
//      $M.celt_config;
//       Initialise the celt encoder and decoder
//************************************************************************************************

//************************************************************************************************
// MODULE:  
//      $M.celt_enc_config;
//       Initialise the celt encoder 
//***********************************************************************************************

.MODULE $M.celt.encoder.config;
  .DATASEGMENT DM;
    // allocate persistent memory for celt encoder
   .VAR $celt_enc_state_pool[153*2];
.ENDMODULE;

//************************************************************************************************
// Initialise the celt encoder and decoder
//************************************************************************************************

.MODULE $M.celt.encoder.init;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

$celt.encoder.init:

   // push rLink onto stack
   $push_rLink_macro;

   // save sample rate
   push r0;
    
   // -- init celt encoder
   push r5;
   call $celt.encoder_init;
   pop r5;
   
   r8 = &$celt_enc_state_pool;
   r7 = length($celt_enc_state_pool);
   push r5;
   call $celt.alloc_state_mem;
   pop r5;
   
   // get sample rate 
   pop r0;
 
   // check if 48000Hz sample rate
   Null = r0 - 48000;
   if NE jump celt_encoder_not_48000;
   
   // -- allocate memory for encoder scratch vectors
   r1 = &$celt.enc.celt_512_48000_mode.dm1scratch_alloc;
   r2 = &$_scratch_dm1;
   r3 = &$celt.enc.celt_512_48000_mode.dm2scratch_alloc; 
   r4 = &$_scratch_dm2;
   call $celt.alloc_scratch_mem;
   jump $pop_rLink_and_rts;
   
celt_encoder_not_48000:

   // check if 44100Hz sample rate
   Null = r0 - 44100;
   if NE jump $pop_rLink_and_rts;

   // -- allocate memory for encoder scratch vectors
   r1 = &$celt.enc.celt_512_44100_mode.dm1scratch_alloc;
   r2 = &$_scratch_dm1;
   r3 = &$celt.enc.celt_512_44100_mode.dm2scratch_alloc; 
   r4 = &$_scratch_dm2;
   call $celt.alloc_scratch_mem;
   jump $pop_rLink_and_rts;
 
.ENDMODULE; 
