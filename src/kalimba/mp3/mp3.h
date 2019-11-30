// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef MP3_HEADER_INCLUDED
#define MP3_HEADER_INCLUDED

    #ifdef DEBUG_ON
       #define DEBUG_MP3DEC
       #define ENABLE_PROFILER_MACROS
    #endif

#ifdef MP3_USE_EXTERNAL_MEMORY
    // Decoder
    .CONST       $mp3dec.mem.OABUF_LEFT_FIELD               0;
    .CONST       $mp3dec.mem.OABUF_RIGHT_FIELD              1;
    .CONST       $mp3dec.mem.SYNTHV_LEFT_FIELD              2;
    .CONST       $mp3dec.mem.SYNTHV_RIGHT_FIELD             3;
    .CONST       $mp3dec.mem.GENBUF_FIELD                   4;
    .CONST       $mp3dec.mem.BITRES_FIELD                   5;
    .CONST       $mp3dec.mem.NUM_FIELDS                     6;
#endif

    // Sizes of buffers
    .CONST       $mp3dec.mem.OABUF_LEFT_LENGTH              576;
    .CONST       $mp3dec.mem.OABUF_RIGHT_LENGTH             576;
    .CONST       $mp3dec.mem.SYNTHV_LEFT_LENGTH             1024;
    .CONST       $mp3dec.mem.SYNTHV_RIGHT_LENGTH            1024;
    .CONST       $mp3dec.mem.GENBUF_LENGTH                  576;
    .CONST       $mp3dec.mem.BITRES_LENGTH                  650;

   // general mp3 constants
   .CONST        $mp3dec.MAX_AUDIO_FRAME_SIZE_IN_WORDS      576;  // i.e. 1 granule
   .CONST        $mp3dec.MAX_MP3_FRAME_SIZE_IN_BYTES        1044;
   .CONST        $mp3dec.MIN_MP3_FRAME_SIZE_IN_BYTES        96;
   .CONST        $mp3dec.CAN_IDLE                           0;
   .CONST        $mp3dec.DONT_IDLE                          1;
   .CONST        $mp3dec.ENABLE_RFC_3119                    1;
   .CONST        $mp3dec.DISABLE_RFC_3119                   0;

   // block type masks
   .CONST        $mp3dec.LONG_MASK                          1;
   .CONST        $mp3dec.START_MASK                         2;
   .CONST        $mp3dec.SHORT_MASK                         4;
   .CONST        $mp3dec.END_MASK                           8;
   .CONST        $mp3dec.MIXED_MASK                         16;

   // granule and channel mask
   .CONST        $mp3dec.CHANNEL_MASK                       1;
   .CONST        $mp3dec.GRANULE_MASK                       2;

   // crc generator polynomial
   .CONST        $mp3dec.CRC_GENPOLY                        0x800500;
   .CONST        $mp3dec.CRC_INITVAL                        0xFFFF00;

   // mpeg layers
   .CONST        $mp3dec.LAYER_I                            3;
   .CONST        $mp3dec.LAYER_II                           2;
   .CONST        $mp3dec.LAYER_III                          1;
   .CONST        $mp3dec.LAYER_RESERVED                     0;

   // mpeg versions
   .CONST        $mp3dec.MPEG1                              0;
   .CONST        $mp3dec.MPEG2                              1;
   .CONST        $mp3dec.MPEG2p5                            2;
   .CONST        $mp3dec.MPEG_reserved                      3;

   // Sampling frequencies
   .CONST        $mp3dec.SAMPFREQ_RESERVED                  3;
   // The following values are formed from 'sampling_frequency header field' + 3*frame_version
   .CONST        $mp3dec.SAMPFREQ_44K1                      0;
   .CONST        $mp3dec.SAMPFREQ_48K                       1;
   .CONST        $mp3dec.SAMPFREQ_32K                       2;
   .CONST        $mp3dec.SAMPFREQ_22K05                     3;
   .CONST        $mp3dec.SAMPFREQ_24K                       4;
   .CONST        $mp3dec.SAMPFREQ_16K                       5;
   .CONST        $mp3dec.SAMPFREQ_11K025                    6;
   .CONST        $mp3dec.SAMPFREQ_12K                       7;
   .CONST        $mp3dec.SAMPFREQ_8K                        8;

   // channel modes
   .CONST        $mp3dec.STEREO                             0;
   .CONST        $mp3dec.JOINT_STEREO                       1;
   .CONST        $mp3dec.DUAL_CHANNEL                       2;
   .CONST        $mp3dec.SINGLE_CHANNEL                     3;

   // intensity and middle/side stereo masks
   .CONST        $mp3dec.IS_MASK                            1;
   .CONST        $mp3dec.MS_MASK                            2;

   // scalefactor band info
   .CONST        $mp3dec.NUM_LONG_SF_BANDS                  22;
   .CONST        $mp3dec.NUM_SHORT_SF_BANDS                 13;
   .CONST        $mp3dec.NUM_SUBBANDS                       32;

   // intensity stereo illegal position
   .CONST        $mp3dec.ILLEGAL_IS_POS                     7;

   // huffman escape code
   .CONST        $mp3dec.HUFF_ESC                           15;

#endif
