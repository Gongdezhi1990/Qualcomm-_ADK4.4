// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifndef CELT_LIBRARY_INCLUDED
#define CELT_LIBRARY_INCLUDED

  #include "celt_library.h"
 
#if defined(KAL_ARCH2) || defined(KAL_ARCH3) || defined(KAL_ARCH5)
 
   #include "segments.asm"
   #include "celt.asm"
   #include "celt_dec.asm" 
   #include "compute_allocation.asm" 
   #include "decoder_init.asm" 
   #include "decode_flags.asm" 
   #include "deemphasis.asm" 
   #include "frame_decode.asm" 
   #include "get_bits.asm" 
   #include "imdct_radix2.asm" 
   #include "imdct_window_overlapadd.asm" 
   #include "laplace.asm" 
   #include "math_functions.asm" 
   #include "transient_process.asm"
   #include "pitch.asm"
   #include "plc.asm"
   #include "range_dec.asm" 
   #include "rate.asm" 
   #include "unquant_bands.asm" 
   #include "vq.asm"      
   #include "mode_objects.asm" 
   #include "celt_enc.asm"
   #include "frame_encode.asm"
   #include "encoder_init.asm"
   #include "preemphasis.asm"
   #include "mdct_radix2.asm"
   #include "window_reshuffle.asm"
   #include "mdct_analysis.asm"
   #include "bands_processing.asm"
   #include "range_enc.asm"
   #include "put_bits.asm"
   #include "encode_flags.asm"
   #include "quant_bands.asm"
   #include "imdct_nonradix2.asm"
   #include "mdct_nonradix2.asm"   
#else
   #error "CELT can not be built for BC3-MM"
#endif // CELT_LIBRARY_INCLUDED

#endif
