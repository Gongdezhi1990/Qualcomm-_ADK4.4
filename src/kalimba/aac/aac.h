// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef AAC_HEADER_INCLUDED
#define AAC_HEADER_INCLUDED

#include "aac_consts.h"

   // -- Define build options --
   #ifdef AACDEC_SBR_ADDITIONS
       #define AACDEC_SBR_V_NOISE_IN_FLASH
       #define AACDEC_SBR_LOG2_TABLE_IN_FLASH
       #define AACDEC_SBR_QMF_STOP_CHANNEL_OFFSET_IN_FLASH
       #define AACDEC_SBR_Q_DIV_TABLE_IN_FLASH
       #define AACDEC_SBR_HUFFMAN_IN_FLASH
   #endif
   #ifdef AACDEC_PARAMETRIC_STEREO_ADDITIONS
       #define AACDEC_PARAMETRIC_STEREO_PHI_FRACT_TABLES_IN_FLASH
   #endif

   // this allows for shorter audio output buffers.
   // Plain AAC outputs 1024 samples per frame, AAC+SBR outputs 2048 samples per frame.
   // This makes each call to frame_decode only perform half of the synthesis
   // filterbank resulting in 1024 samples being output per call, hence smaller output
   // buffers required
   #ifdef AACDEC_SBR_ADDITIONS
      #ifndef AACDEC_ELD_ADDITIONS
       #define AACDEC_SBR_HALF_SYNTHESIS
   #endif
   #endif

   #define AACDEC_PACK_SPECTRAL_HUFFMAN_IN_FLASH
   #ifdef AACDEC_PACK_SPECTRAL_HUFFMAN_IN_FLASH
      // Also pack the scalefactor huffman table in flash?
      #define AACDEC_PACK_SCALEFACTOR_HUFFMAN_IN_FLASH
   #endif


   // -- Define supported file/streaming types --
   // define "AACDEC_ADTS_OLD_FORMAT_WITH_EMPHASIS_BITS" if old format
   // ADTS frames required.  These have 2 extra emphasis bits in the
   // fixed header.  Note: These 2 bits were removed in corrigendum
   // 14496-3:2002
   //.define AACDEC_ADTS_OLD_FORMAT_WITH_EMPHASIS_BITS

   // Pull in all formats by default, this allows a message from the VM
   // to configure which format we're working with.
   #define AACDEC_MP4_FILE_TYPE_SUPPORTED
   #define AACDEC_ADTS_FILE_TYPE_SUPPORTED
   #define AACDEC_LATM_FILE_TYPE_SUPPORTED

   // aacPlus v1 - AAC+SBR
   // aacPlus v2 - AAC+SBR+PS
   // so never have PS additions but not SBR additions
   #ifndef AACDEC_SBR_ADDITIONS
      #ifdef AACDEC_PARAMETRIC_STEREO_ADDITIONS
         .undef AACDEC_PARAMETRIC_STEREO_ADDITIONS
         .WARNING Parametric Stereo has been disabled as SBR has not been enabled
      #endif
   #endif


   // -- General AAC high level constants --
   #ifdef AACDEC_SBR_ADDITIONS
      #ifdef AACDEC_SBR_HALF_SYNTHESIS
          .CONST $aacdec.MAX_AUDIO_FRAME_SIZE_IN_WORDS      1024;
      #else
          .CONST $aacdec.MAX_AUDIO_FRAME_SIZE_IN_WORDS      2048;
      #endif
   #else
      .CONST $aacdec.MAX_AUDIO_FRAME_SIZE_IN_WORDS          1024;
   #endif

    // **************************************************************************
    //                          MEMORY POOL constants
    // **************************************************************************

    #ifdef AACDEC_PARAMETRIC_STEREO_ADDITIONS
        .CONST $aacdec.FRAME_MEM_POOL_LENGTH                (($aacdec.SBR_N * 4) + ($aacdec.X_SBR_WIDTH * (26+12)));
    #else
        #ifdef AACDEC_PACK_SPECTRAL_HUFFMAN_IN_FLASH
            #ifdef AACDEC_PACK_SCALEFACTOR_HUFFMAN_IN_FLASH
                .CONST $aacdec.FRAME_MEM_POOL_LENGTH        1696;
            #else
                .CONST $aacdec.FRAME_MEM_POOL_LENGTH        1576;
            #endif
        #else
            #ifdef AACDEC_SBR_ADDITIONS
                .CONST $aacdec.FRAME_MEM_POOL_LENGTH        1379;
            #else
                .CONST $aacdec.FRAME_MEM_POOL_LENGTH        440;
            #endif
        #endif
    #endif

   .CONST $aacdec.MAX_AAC_FRAME_SIZE_IN_BYTES               1536; //  needed for 8KHz @80kbps -> 1536byte frame
   .CONST $aacdec.MIN_AAC_FRAME_SIZE_IN_BYTES               1536;
   .CONST $aacdec.MIN_MP4_FRAME_SIZE_IN_BYTES               1536;
   .CONST $aacdec.MIN_ADTS_FRAME_SIZE_IN_BYTES              24;   // Needed for VBR silence frames
   .CONST $aacdec.MIN_LATM_FRAME_SIZE_IN_BYTES              16;   // Needed for VBR silence frames

   .CONST $aacdec.CAN_IDLE                                  0;
   .CONST $aacdec.DONT_IDLE                                 1;

#ifndef USE_PACKED_ENCODED_DATA
   #define BITPOS_START (16)
   #define BITPOS_START_MASK (0x8000)
#else
   #define BITPOS_START (24)
   #define BITPOS_START_MASK (0x800000)
#endif


   // -- Required for using the fft library - make sure we can fft at least 512 points
   #ifndef FFT_TWIDDLE_NEED_512_POINT
      #define FFT_TWIDDLE_NEED_512_POINT
   #endif /* FFT_TWIDDLE_NEED_512_POINT */

   // -- This enables garbage detection for latm streams, helps preventing long stalls on
   // garbage inputs
   #define AACDEC_ENABLE_LATM_GARBAGE_DETECTION

#endif
