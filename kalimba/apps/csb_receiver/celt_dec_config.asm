// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
// *****************************************************************************

#include "celt_library.h"
#include "core_library.h"

//************************************************************************************************
// MODULE:  
//      $M.celt_dec_config;
//       Initialise the celt encoder and decoder
//************************************************************************************************

.MODULE $M.celt_dec_config; 

  .CODESEGMENT PM; 
  .DATASEGMENT DM;

$celt_dec_config:

   // -- memory only used by celt decoder
   .VAR $celt_dec_state_pool[153*2]; // this should be the overlap size * (channel mode + 1)  //CZ TODO

    // -- define scratch memory (used by both encoder and decoder)
    .VAR/DM1CIRC $celt_dm1_scratch[2500];
    .VAR/DM2CIRC $celt_dm2_scratch[2500];
      
.ENDMODULE; 


//************************************************************************************************
// Initialise the celt encoder and decoder
//************************************************************************************************
.MODULE $M.celt.init_decoder;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

$celt.init_decoder:

   $push_rLink_macro;
   
   // save sample rate
   push r0;

   // Initialise the CELT_MODE_OBJECT_FIELD
   // Required by decoder_init
   r1 = &$celt.mode.celt_512_44100_mode;
   r2 = &$celt.mode.celt_512_48000_mode;
   Null = r0 - 48000;
   if Z r1 = r2;
   M[r5 + $celt.dec.CELT_MODE_OBJECT_FIELD] = r1;

   // -- init celt decoder
   push r5;
   call $celt.decoder_init;
   pop r5;

   r8 = &$celt_dec_state_pool;
   r7 = length($celt_dec_state_pool);
   push r5;
   call $celt.alloc_state_mem;
   pop r5;

   // get sample rate 
   pop r0;
 
   // check if 48000Hz sample rate
   Null = r0 - 48000;
   if NE jump celt_decoder_not_48000;
   
   // -- allocate memory for encoder scratch vectors
   r1 = &$celt.dec.celt_512_48000_mode.dm1scratch_alloc;
   r2 = &$celt_dm1_scratch;
   r3 = &$celt.dec.celt_512_48000_mode.dm2scratch_alloc; 
   r4 = &$celt_dm2_scratch;
   call $celt.alloc_scratch_mem;
   jump $pop_rLink_and_rts;
   
celt_decoder_not_48000:

   // check if 44100Hz sample rate
   Null = r0 - 44100;
   if NE jump $pop_rLink_and_rts;

   // -- allocate memory for encoder scratch vectors
   r1 = &$celt.dec.celt_512_44100_mode.dm1scratch_alloc;
   r2 = &$celt_dm1_scratch;
   r3 = &$celt.dec.celt_512_44100_mode.dm2scratch_alloc; 
   r4 = &$celt_dm2_scratch;
   call $celt.alloc_scratch_mem;
   jump $pop_rLink_and_rts;
 
.ENDMODULE; 
