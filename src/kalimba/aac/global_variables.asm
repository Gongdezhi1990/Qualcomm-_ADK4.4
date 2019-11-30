// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

//#include "stack.h"
//#include "core_library.h"
//#include "codec_library.h"
//#include "kalimba_standard_messages.h"
//#include "fft.h"

// Truncation macro to prevent underflow warnings
#if defined(KAL_ARCH3) || defined(KAL_ARCH5)
   #define NO_UF(x)     (((x)<(2.0**-24)) && ((x)>-(2.0**-24))) ? 0.0 : (x)
#else
   #define NO_UF(x)     (x)
#endif

// *****************************************************************************
// MODULE:
//    $aacdec.variables
//
// DESCRIPTION:
//    Variables
//
// *****************************************************************************
.MODULE $aacdec;
   .DATASEGMENT DM;

   .VAR num_bytes_available;
   .VAR convert_mono_to_stereo;


   // **************************************************************************
   //                            HEADER data
   // **************************************************************************

   // file formats
   .VAR read_frame_function = $error;
   .VAR skip_function = 0;
   .VAR skip_amount_ms = 0;
   .VAR skip_amount_ls = 0;

   // header info
   .VAR frame_underflow;
   .VAR frame_version;
   .VAR frame_length;
   .VAR no_raw_data_blocks_in_frame;
   .VAR protection_absent;
   .VAR id3_skip_num_bytes;
   .VAR frame_corrupt;
   .VAR possible_frame_corruption;

 #ifdef AAC_ENABLE_ROUTING_OPTIONS
   .VAR routing_mode;//0 default(non tws) 1 Left , 2 //right , 3 l+R/2 
 #endif 
   #ifdef DEBUG_AACDEC
      .VAR/DM1      frame_corrupt_errors = 0;
      .VAR/DM1      lostsync_errors = 0;
      .VAR/DM1      frame_count = 0;
      #ifdef AACDEC_ENABLE_LATM_GARBAGE_DETECTION
         .VAR/DM1      frame_garbage_errors = 0;
      #endif
   #endif

   // Lookup table to slightly speedup generating a bit mask
#ifndef USE_PACKED_ENCODED_DATA
   .VAR   bitmask_lookup[17] =
#else
   .VAR   bitmask_lookup[25] =
#endif
                 0b000000000000000000000000,
                 0b000000000000000000000001,
                 0b000000000000000000000011,
                 0b000000000000000000000111,
                 0b000000000000000000001111,
                 0b000000000000000000011111,
                 0b000000000000000000111111,
                 0b000000000000000001111111,
                 0b000000000000000011111111,
                 0b000000000000000111111111,
                 0b000000000000001111111111,
                 0b000000000000011111111111,
                 0b000000000000111111111111,
                 0b000000000001111111111111,
                 0b000000000011111111111111,
                 0b000000000111111111111111,
#ifndef USE_PACKED_ENCODED_DATA
                 0b000000001111111111111111;
#else
                 0b000000001111111111111111,
                 0b000000011111111111111111,
                 0b000000111111111111111111,
                 0b000001111111111111111111,
                 0b000011111111111111111111,
                 0b000111111111111111111111,
                 0b001111111111111111111111,
                 0b011111111111111111111111,
                 0b111111111111111111111111;
#endif

   .VAR get_bitpos;
   .VAR read_bit_count;
   .VAR frame_num_bits_avail;
   .VAR getbits_saved_I0;
   .VAR getbits_saved_L0;
   .VAR getbits_saved_bitpos;


   // We only support limited sampling frequencies.  This table returns an
   // offset to be used when accessing other frequency dependent tables.
   // A negative number indicates an unsupported frequency
   #ifndef USE_AAC_TABLES_FROM_FLASH
      .VAR sampling_freq_lookup[16] =
         -1,   // 96000Hz
         -1,   // 88200Hz
         -1,   // 64000Hz
          0,   // 48000Hz
          1,   // 44100Hz
          2,   // 32000Hz
          3,   // 24000Hz
          4,   // 22050Hz
          5,   // 16000Hz
          6,   // 12000Hz
          7,   // 11025Hz
          8,   // 8000Hz
         -1,   // reserved
         -1,   // reserved
         -1,   // reserved
         -1;   // reserved
   #endif
   .VAR sf_index;

   // channel configuration
   .VAR channel_configuration;

   // object type
   .VAR audio_object_type;
   .VAR extension_audio_object_type;
   .VAR sbr_present;

#ifdef AACDEC_ELD_ADDITIONS
   .VAR frame_length_flag;

   .VAR ld_sbr_present_flag;
   .VAR ld_sbr_sampling_rate;
   .VAR ld_sbr_crc_flag;
   .VAR delay_shift;
   .VAR $aacdec.SBR_numTimeSlots_eld ;
   .VAR $aacdec.SBR_numTimeSlotsRate_eld ;
#endif // AACDEC_ELD_ADDITIONS

   // latm header fields
   .VAR latm.audio_mux_version;
   .VAR latm.audio_mux_version_a;
   .VAR latm.mux_slot_length_bytes;
   .VAR latm.current_subframe;
   .VAR latm.num_subframes;
   .VAR latm.prevbitpos;
   .VAR latm.taraBufferFullnesss;
   .VAR latm.asc_len;
   .VAR latm.latm_buffer_fullness;
   .VAR latm.other_data_len_bits;








   // **************************************************************************
   //                            SCALEFACTOR data
   // **************************************************************************

   #ifdef USE_AAC_TABLES_FROM_FLASH
      .VAR swb_offset[52] =  // gen win, size = max of long win sizes
          0,   0,   0,    0,   0,    0,   0,   0,   0,   0,   0,   0,   0,   0,
          0,   0,   0,    0,   0,    0,   0,   0,   0,   0,   0,   0,   0,   0,
          0,   0,   0,    0,   0,    0,   0,   0,   0,   0,   0,   0,   0,   0,
          0,   0,   0,    0,   0,    0,   0,   0,   0,   0;
   #else

   #ifdef AACDEC_ELD_ADDITIONS
      .VAR num_swb_long_window_512[NUM_SUPPORTED_FREQS_ELD] =
         36,   // 48000Hz
         36,   // 44100Hz
         37,   // 32000Hz
         31,   // 24000Hz
         31;   // 22050Hz

      .VAR num_swb_long_window_480[NUM_SUPPORTED_FREQS_ELD] =
         35,   // 48000Hz
         35,   // 44100Hz
         37,   // 32000Hz
         30,   // 24000Hz
         30;   // 22050Hz

      .VAR eld_swb_offset_long_48_512[] =  // 48000Hz long win, scalefactor band offsets
          0,   4,   8,   12,  16,  20,  24,  28,  32,  36,  40,  44,  48,  52,
          56,  60,  68,  76,  84,  92,  100, 112, 124, 136, 148, 164, 184, 208,
          236, 268, 300, 332, 364, 396, 428, 460, 512;

      .VAR eld_swb_offset_long_32_512[] =  // 32000Hz long win, scalefactor band offsets
          0,   4,   8,   12,  16,  20,  24,  28,  32,  36,  40,  44,  48,  52,
          56,  64,  72,  80,  88,  96,  108, 120, 132, 144, 160, 176, 192, 212,
          236, 260, 288, 320, 352, 384, 416, 448, 480, 512;

      .VAR eld_swb_offset_long_24_512[] =  // 24000Hz long win, scalefactor band offsets
          0,   4,   8,   12,  16,  20,  24,  28,  32,  36,  40,  44,  52,  60,
          68,  80,  92,  104, 120, 140, 164, 192, 224, 256, 288, 320, 352, 384,
          416, 448, 480, 512;

      .VAR eld_swb_offset_long_48_480[] =  // 48000Hz long win, scalefactor band offsets
          0,   4,   8,   12,  16,  20,  24,  28,  32,  36,  40,  44,  48,  52,
          56,  64,  72,  80,  88,  96,  108, 120, 132, 144, 156, 172, 188, 212,
          240, 272, 304, 336, 368, 400, 432, 480;

      .VAR eld_swb_offset_long_32_480[] =  // 32000Hz long win, scalefactor band offsets
          0,   4,   8,   12,  16,  20,  24,  28,  32,  36,  40,  44,  48,  52,
          56,  60,  64,  72,  80,  88,  96,  104, 112, 124, 136, 148, 164, 180,
          200, 224, 256, 288, 320, 352, 384, 416, 448, 480;

      .VAR eld_swb_offset_long_24_480[] =  // 24000Hz long win, scalefactor band offsets
          0,   4,   8,   12,  16,  20,  24,  28,  32,  36,  40,  44,  52,  60,
          68,  80,  92,  104, 120, 140, 164, 192, 224, 256, 288, 320, 352, 384,
          416, 448, 480;

      .VAR swb_offset_long_table_512[NUM_SUPPORTED_FREQS_ELD] =
          &eld_swb_offset_long_48_512,  // 48000Hz
          &eld_swb_offset_long_48_512,  // 44100Hz
          &eld_swb_offset_long_32_512,  // 32000Hz
          &eld_swb_offset_long_24_512,  // 24000Hz
          &eld_swb_offset_long_24_512;  // 22050Hz

      .VAR swb_offset_long_table_480[NUM_SUPPORTED_FREQS_ELD] =
          &eld_swb_offset_long_48_480,  // 48000Hz
          &eld_swb_offset_long_48_480,  // 44100Hz
          &eld_swb_offset_long_32_480,  // 32000Hz
          &eld_swb_offset_long_24_480,  // 24000Hz
          &eld_swb_offset_long_24_480;  // 22050Hz
   #endif // AACDEC_ELD_ADDITIONS

      .VAR num_swb_long_window[NUM_SUPPORTED_FREQS] =
         49,   // 48000Hz
         49,   // 44100Hz
         51,   // 32000Hz
         47,   // 24000Hz
         47,   // 22050Hz
         43,   // 16000Hz
         43,   // 12000Hz
         43,   // 11025Hz
         40;   // 8000Hz


      .VAR num_swb_short_window[NUM_SUPPORTED_FREQS] =
         14,   // 48000Hz
         14,   // 44100Hz
         14,   // 32000Hz
         15,   // 24000Hz
         15,   // 22050Hz
         15,   // 16000Hz
         15,   // 12000Hz
         15,   // 11025Hz
         15;   // 8000Hz


      .VAR swb_offset_long_48[] =  // 48000Hz long win, scalefactor band offsets
          0,   4,   8,   12,  16,  20,  24,  28,  32,  36,  40,  48,  56,  64,
          72,  80,  88,  96,  108, 120, 132, 144, 160, 176, 196, 216, 240, 264,
          292, 320, 352, 384, 416, 448, 480, 512, 544, 576, 608, 640, 672, 704,
          736, 768, 800, 832, 864, 896, 928, 1024;

      .VAR swb_offset_long_32[] =  // 32000Hz long win, scalefactor band offsets
          0,   4,   8,   12,  16,  20,  24,  28,  32,  36,  40,  48,  56,  64,
          72,  80,  88,  96,  108, 120, 132, 144, 160, 176, 196, 216, 240, 264,
          292, 320, 352, 384, 416, 448, 480, 512, 544, 576, 608, 640, 672, 704,
          736, 768, 800, 832, 864, 896, 928, 960, 992, 1024;

      .VAR swb_offset_long_24[] =  // 24000Hz long win, scalefactor band offsets
          0,   4,   8,   12,  16,  20,  24,  28,  32,  36,  40,  44,  52,  60,
          68,  76,  84,  92,  100, 108, 116, 124, 136, 148, 160, 172, 188, 204,
          220, 240, 260, 284, 308, 336, 364, 396, 432, 468, 508, 552, 600, 652,
          704, 768, 832, 896, 960, 1024;

      .VAR swb_offset_long_16[] =  // 16000Hz long win, scalefactor band offsets
          0,   8,   16,  24,  32,  40,  48,  56,  64,  72,  80,  88,  100, 112,
          124, 136, 148, 160, 172, 184, 196, 212, 228, 244, 260, 280, 300, 320,
          344, 368, 396, 424, 456, 492, 532, 572, 616, 664, 716, 772, 832, 896,
          960, 1024;

      .VAR swb_offset_long_8[] =   // 8000Hz long win, scalefactor band offsets
          0,   12,  24,  36,  48,  60,  72,  84,  96,  108, 120, 132, 144, 156,
          172, 188, 204, 220, 236, 252, 268, 288, 308, 328, 348, 372, 396, 420,
          448, 476, 508, 544, 580, 620, 664, 712, 764, 820, 880, 944, 1024;



      .VAR swb_offset_short_48[] =  // 48000Hz short win, scalefactor band offsets
          0,   4,   8,   12,  16,  20,  28,  36,  44,  56,  68,  80,  96,  112, 128;

      .VAR swb_offset_short_24[] =  // 24000Hz short win, scalefactor band offsets
          0,   4,   8,   12,  16,  20,  24,  28,  36,  44,  52,  64,  76,  92,  108, 128;

      .VAR swb_offset_short_16[] =  // 16000Hz short win, scalefactor band offsets
          0,   4,   8,   12,  16,  20,  24,  28,  32,  40,  48,  60,  72,  88,  108, 128;

      .VAR swb_offset_short_8[] =   // 8000Hz short win, scalefactor band offsets
          0,   4,   8,   12,  16,  20,  24,  28,  36,  44,  52,  60,  72,  88,  108, 128;


      .VAR swb_offset_long_table[NUM_SUPPORTED_FREQS] =
          &swb_offset_long_48,  // 48000Hz
          &swb_offset_long_48,  // 44100Hz
          &swb_offset_long_32,  // 32000Hz
          &swb_offset_long_24,  // 24000Hz
          &swb_offset_long_24,  // 22050Hz
          &swb_offset_long_16,  // 16000Hz
          &swb_offset_long_16,  // 12000Hz
          &swb_offset_long_16,  // 11025Hz
          &swb_offset_long_8;   // 8000Hz



      .VAR swb_offset_short_table[NUM_SUPPORTED_FREQS] =
          &swb_offset_short_48,  // 48000Hz
          &swb_offset_short_48,  // 44100Hz
          &swb_offset_short_48,  // 32000Hz
          &swb_offset_short_24,  // 24000Hz
          &swb_offset_short_24,  // 22050Hz
          &swb_offset_short_16,  // 16000Hz
          &swb_offset_short_16,  // 12000Hz
          &swb_offset_short_16,  // 11025Hz
          &swb_offset_short_8;   // 8000Hz

   #endif

   // **************************************************************************
   //                          DEQUANTIZATION data
   // **************************************************************************

   .VAR two2qtrx_lookup[4] =
           0.500000000,     // 2^(-4/4)
           0.594603557,     // 2^(-3/4)
           0.707106781,     // 2^(-2/4)
           0.840896415;     // 2^(-1/4)


   //  X^(4/3) Speedup coefficients: generated with x43calc.m
   .VAR x43_lookup1[36] =
                19,        17,        16,        15,        13,        12,
                11,         9,         8,   -293917,   -616693,   -489404,
           -388337,   -616117,   -488490,   -386889,   -611539,   -481283,
           2347326,   3223450,   2558622,   2031047,   3224934,   2560978,
           2034788,   3236826,   2579897,   4698663,   8008380,   6356045,
           5044462,   8006523,   6353098,   5039788,   7991706,   6329649;

   .VAR x43_lookup2[36] =
                 0,        19,        16,        15,        14,        12,
                11,        10,         8,         0,   -243538,   -773114,
           -613505,   -486756,   -772095,   -611890,   -484200,   -764028,
                 0,    642908,   2041202,   1620255,   1286237,   2042538,
           1622376,   1289608,   2053254,         0,   2243000,   7120915,
           5651609,   4485264,   7118577,   5647899,   4479382,   7099944;

   #ifndef AACDEC_SBR_ADDITIONS  // used as part of sbr_x_imag padding when sbr included
      .VAR x43_lookup32[64] =
                    0,         1,         2,         3,         3,         4,
                    4,         4,         5,         5,         5,         5,
                    5,         5,         6,         6,         6,         6,
                    6,         6,         6,         6,         6,         7,
                    7,         7,         7,         7,         7,         7,
                    7,         7,         0,   4194304,   5284492,   4536925,
              6658043,   4482599,   5716167,   7020488,   4194304,   4907533,
              5647721,   6413033,   7201919,   8013048,   4422630,   4848770,
              5284492,   5729391,   6183105,   6645302,   7115683,   7593972,
              8079916,   4286640,   4536925,   4790711,   5047904,   5308416,
              5572165,   5839073,   6109068,   6382079;
   #endif





   // **************************************************************************
   //                               TNS data
   // **************************************************************************

   // TNS structure
#ifdef AACDEC_ELD_ADDITIONS
   .VAR $aacdec.temp_u[64];
   .VAR $aacdec.synthesis.temp1[64];
   .VAR $aacdec.synthesis.temp2[128];
   .VAR $aacdec.synthesis.temp3[128];
   .VAR $aacdec.synthesis.g_w_buffer[640];

   .VAR tns_max_sfb_long_table_512[NUM_SUPPORTED_FREQS_ELD] =
        31,   // 48000Hz
        32,   // 44100Hz
        37,   // 32000Hz
        31,   // 24000Hz
        31;   // 22050Hz
   .VAR tns_max_sfb_long_table_480[NUM_SUPPORTED_FREQS_ELD] =
        31,   // 48000Hz
        32,   // 44100Hz
        37,   // 32000Hz
        30,   // 24000Hz
        30;   // 22050Hz
#endif //AACDEC_ELD_ADDITIONS

   .VAR tns_max_sfb_long_table[NUM_SUPPORTED_FREQS] =
        40,   // 48000Hz
        42,   // 44100Hz
        51,   // 32000Hz
        46,   // 24000Hz
        46,   // 22050Hz
        42,   // 16000Hz
        42,   // 12000Hz
        42,   // 11025Hz
        39;   // 8000Hz


   // TNS coefs for fast conversion of bitfields from the aac stream to lpc coefs
   .VAR tns_lookup_coefs[24] =
       +0.0000000000,  0.4338837391,  0.7818314825,  0.9749279122,
       -0.9848077530, -0.8660254038, -0.6427876097, -0.3420201433,
        0.0000000000,  0.2079116908,  0.4067366431,  0.5877852523,
        0.7431448255,  0.8660254038,  0.9510565163,  0.9945218954,
       -0.9957341763, -0.9618256432, -0.8951632914, -0.7980172273,
       -0.6736956436, -0.5264321629, -0.3612416662, -0.1837495178;

   // buffer to maintain the input-stream 'history' of the tns_encode fir filter
   .VAR/DMCIRC tns_fir_input_history[TNS_MAX_ORDER_LONG];


   // **************************************************************************
   //                              PNS data
   // **************************************************************************

   // sqrt(3)/2 used by pns decode
   .VAR sqrt_three_over_two = 0.8660254038;
   .VAR pns_rand_num = 0xDEAD00;


   // **************************************************************************
   //                              MP4 data
   // **************************************************************************

   .VAR channel_count;

   .VAR mp4_moov_atom_size_ms;
   .VAR mp4_moov_atom_size_ls;

   .VAR mp4_sequence_flags_initialised = 0;

   .VAR mp4_discard_amount_ms;
   .VAR mp4_discard_amount_ls;

   .VAR found_first_mdat;
   .VAR found_moov;

   // calculated using STSZ/STZ2 atom (either product/sum of 32 bit values)
   // 64 bits. only 16 bits of mdat_size[0] are used
   .VAR mdat_size[3] = 0, 0, 0;
   .VAR sample_count[2] = 0,0;
   .VAR mdat_processed = 0;
   .VAR temp_bit_count; // used to calculate bytes read from mdat

   // Fast Forward/Fast Rewind related parameters

   //position of STSZ in the file
   .VAR stsz_offset[2];
   //position of STSS in the file
   .VAR stss_offset[2];
   // size of mdat to skip for fast fwd/rewind
   .VAR ff_rew_skip_amount[2];
   .VAR mp4_frame_count;

   // status of mp4 FF/REW
   .VAR mp4_ff_rew_status;


    // offset of mdat from begining of the file
   .VAR mdat_offset[2] = 0, 0;
   .VAR mp4_file_offset[2] = 0, 0;

   // Num samples to fast forward / rewind (if negative)
   .VAR fast_fwd_samples_ms;
   .VAR fast_fwd_samples_ls;

   .VAR avg_bit_rate;

   // sampling frequencies
   .VAR sample_rate_tags[12] =
      96000,
      88200,
      64000,
      48000,
      44100,
      32000,
      24000,
      22050,
      16000,
      12000,
      11025,
      8000;


   // flags to indicate whether in a particular routine incase frame_underflow occurs
   // and need to resume with it when more data available
   .VAR mp4_decoding_started     = 0;
   .VAR mp4_header_parsed        = 0;
   .VAR mp4_in_moov              = 0;
   .VAR mp4_in_discard_atom_data = 0;


   // **************************************************************************
   //                              LTP data
   // **************************************************************************

   .VAR ltp_coefs[8] =
      // original coefficients divided by 4 to compensate for x4 by $aacdec.overlap_add;
      0.14270725,  0.17415400,   0.20325100,   0.22782600,
      0.24622500,  0.26697350,   0.29865025,   0.34238325;

   .VAR mdct_information[$aacdec.mdct.STRUC_SIZE];

   .VAR imdct_info[$aacdec.imdct.STRUC_SIZE];


   // **************************************************************************
   //                        WINDOWING data
   // **************************************************************************

   // Rotation matrix =   [ cos(pi/N)   -sin(pi/N)
   //                       sin(pi/N)    cos(pi/N) ]
   // just store cos(pi/N) and sin(pi/N)
   //
   // Starting vector =   [ cos(pi/N/2)
   //                       sin(pi/N/2) ]
   // N=2048
   .BLOCK sin2048_coefs;
      .VAR sin2048_init_vector[2] = 0.9999997059,  0.0007669903;
      .VAR sin2048_rotation_matrix[2] = 0.9999988235,  0.0015339802;  // [cos(pi/2048) sin(pi/2048)]
   .ENDBLOCK;
   // N=256
   .BLOCK sin256_coefs;
      .VAR sin256_init_vector[2]  = 0.9999811753,  0.0061358846;
      .VAR sin256_rotation_matrix[2]  = 0.9999247018,  0.0122715383;  // [cos(pi/256) sin(pi/256)]
   .ENDBLOCK;

   //  Kaiser window polynomial fit coefficients: generated with kaiser_generate.m
   .VAR kaiser2048_coefs[36] =
       +0.0003828354,  +0.0224643906,  +0.0523265891,  +0.1343142927,  -0.0299551922,  +210,
       +0.1145978775,  +0.3115340074,  +0.2592987506,  -0.0108654896,  -0.0631660178,  +210,
       +0.5100967816,  +0.5758919995,  -0.0008818654,  -0.2141262944,  +0.0651965208,  +92,  // split at halfway point
       +0.5100967816,  +0.5758919995,  -0.0008818654,  -0.2141262944,  +0.0651965208,  +98,
       +0.8692721937,  +0.3290540106,  -0.2648256370,  +0.0320950729,  +0.0353308851,  +180,
       +0.9894981150,  +0.0517153546,  -0.0990314628,  +0.0869802760,  -0.0293442242,  +234;

   .VAR kaiser256_coefs[36] =
       +0.0000241752,  +0.0028029329,  +0.0073619623,  +0.0600559776,  +0.0457888540,  +26,
       +0.0592348859,  +0.2295280147,  +0.3056280595,  +0.1657036557,  -0.1665639444,  +28,
       +0.5075518468,  +0.6991855142,  +0.0209393097,  -0.4259068627,  +0.1667795857,  +10, // split at halfway point
       +0.5075518468,  +0.6991855142,  +0.0209393097,  -0.4259068627,  +0.1667795857,  +14,
       +0.9168486198,  +0.2972068181,  -0.3854267702,  +0.1926917615,  -0.0170969141,  +23,
       +0.9982646973,  +0.0125103377,  -0.0342462435,  +0.0414374941,  -0.0185043712,  +27;

   .BLOCK previous_window_shape;
      .VAR previous_window_shape_left;
      .VAR previous_window_shape_right;
   .ENDBLOCK;

   .BLOCK previous_window_sequence;
      .VAR previous_window_sequence_left;
      .VAR previous_window_sequence_right;
   .ENDBLOCK;


   // **************************************************************************
   //                            HUFFMAN data
   // **************************************************************************

   #ifdef AACDEC_PACK_SCALEFACTOR_HUFFMAN_IN_FLASH
      #ifndef AACDEC_PACK_SPECTRAL_HUFFMAN_IN_FLASH
         .ERROR "AACDEC_PACK_SPECTRAL_HUFFMAN_IN_FLASH" must also be defined.
         .ERROR "AACDEC_PACK_SCALEFACTOR_HUFFMAN_IN_FLASH" cannot be defined on its own."AACDEC_PACK_SPECTRAL_HUFFMAN_IN_FLASH" must also be defined.
      #endif
   #endif

   #ifdef AACDEC_PACK_SPECTRAL_HUFFMAN_IN_FLASH
      // include the packed tables from another file
      #include "huffman_tables_packed.asm"

   #else
      // include the tables from another file
      #include "huffman_tables.asm"
   #endif


   .VAR huffman_offsets[12] =
            0,   // scf book
           -1,   // cbook 1
           -1,   // cbook 2
            0,   // cbook 3
            0,   // cbook 4
           -4,   // cbook 5
           -4,   // cbook 6
            0,   // cbook 7
            0,   // cbook 8
            0,   // cbook 9
            0,   // cbook 10
            0;   // cbook 11

   .VAR amount_unpacked=0;

   // **************************************************************************
   //                            ICS INFO data
   // **************************************************************************

   .VAR common_window;
   .VAR current_ics_ptr;
   .VAR current_spec_ptr;
   .VAR current_channel;

   .VAR/DM2 ics_left[ics.STRUC_SIZE];
   .VAR/DM2 ics_right[ics.STRUC_SIZE];


   // **************************************************************************
   //                          MEMORY POOL data
   // **************************************************************************

   // dynamic memory which is reset on a frame by frame basis - used for TNS data, sect_cb and scalefactors
   #ifdef AACDEC_SBR_ADDITIONS
      .BLOCK/DM2CIRC frame_mem_pool;
         .VAR fmp_start[$aacdec.SBR_N*2];
         .VAR sbr_temp_1[$aacdec.SBR_N];       // circ
         .VAR sbr_temp_3[$aacdec.SBR_N];       // circ

         .VAR fmp_remains[$aacdec.FRAME_MEM_POOL_LENGTH-($aacdec.SBR_N+$aacdec.SBR_N+$aacdec.SBR_N*2)];
      .ENDBLOCK;
   #else
#ifndef EXTERNAL_POOLS
      #ifdef AAC_LOWRAM
      #ifndef AAC_USE_EXTERNAL_MEMORY
         .VAR/DM_SCRATCH frame_mem_pool[$aacdec.FRAME_MEM_POOL_LENGTH];
      #else 
         .VAR frame_mem_pool_ptr;
      #endif 
      #else
         #ifndef AAC_USE_EXTERNAL_MEMORY
         .VAR/DM2_SCRATCH frame_mem_pool[$aacdec.FRAME_MEM_POOL_LENGTH];
         #else 
         .VAR frame_mem_pool_ptr;
         #endif 
      #endif
#endif
   #endif
   #ifndef AAC_USE_EXTERNAL_MEMORY
   .VAR frame_mem_pool_end = &frame_mem_pool;
   #else 
   .VAR frame_mem_pool_end_ptr;// = &frame_mem_pool;
   #endif 


   // imaginary part of X_sbr for the current channel starts at (&$aacdec.sbr_x_imag + 1536). The block is
   // constructed this way so that the first 2048 elements of tmp_mem_pool will be on a circular buffer
   // boundary as required in filterbank for bitreversing. See sbr_global_variables.asm for structure of X_sbr
   #ifdef AACDEC_SBR_ADDITIONS
      .BLOCK/DM1CIRC sbr_x_imag;
         .VAR v_buffer_left[$aacdec.SBR_N*10];       // circ
         .VAR x43_lookup32[64] =
                       0,         1,         2,         3,         3,         4,
                       4,         4,         5,         5,         5,         5,
                       5,         5,         6,         6,         6,         6,
                       6,         6,         6,         6,         6,         7,
                       7,         7,         7,         7,         7,         7,
                       7,         7,         0,   4194304,   5284492,   4536925,
                 6658043,   4482599,   5716167,   7020488,   4194304,   4907533,
                 5647721,   6413033,   7201919,   8013048,   4422630,   4848770,
                 5284492,   5729391,   6183105,   6645302,   7115683,   7593972,
                 8079916,   4286640,   4536925,   4790711,   5047904,   5308416,
                 5572165,   5839073,   6109068,   6382079;
         .VAR dct4_64_table [192] =
                0.49996250,   0.49905900,   0.49695350,   0.49365050,   0.48915850,   0.48348800,
                0.47665300,   0.46866950,   0.45955700,   0.44933700,   0.43803500,   0.42567750,
                0.41229450,   0.39791850,   0.38258350,   0.36632700,   0.34918800,   0.33120800,
                0.31242950,   0.29289900,   0.27266250,   0.25176900,   0.23026950,   0.20821500,
                0.18565850,   0.16265500,   0.13926000,   0.11552900,   0.09152000,   0.06729050,
                0.04289865,   0.01840360,  -0.50610000,  -0.52972000,  -0.55206500,  -0.57308000,
               -0.59271500,  -0.61092000,  -0.62765500,  -0.64288000,  -0.65655500,  -0.66864500,
               -0.67912500,  -0.68797000,  -0.69516000,  -0.70067500,  -0.70450000,  -0.70663000,
               -0.70705500,  -0.70577500,  -0.70280000,  -0.69813000,  -0.69177500,  -0.68375500,
               -0.67409000,  -0.66280000,  -0.64991000,  -0.63546000,  -0.61947500,  -0.60200000,
               -0.58307500,  -0.56274000,  -0.54105500,  -0.51806500,  -0.49382650,  -0.46839850,
               -0.44184250,  -0.41422150,  -0.38560300,  -0.35605550,  -0.32565000,  -0.29446000,
               -0.26256100,  -0.23002900,  -0.19694300,  -0.16338250,  -0.12942850,  -0.09516300,
               -0.06066800,  -0.02602665,   0.00867730,   0.04336030,   0.07793900,   0.11232950,
                0.14645000,   0.18021700,   0.21355050,   0.24636900,   0.27859450,   0.31014850,
                0.34095550,   0.37094100,   0.40003300,   0.42816100,   0.45525750,   0.48125750,
                0.50000000,   0.49939750,   0.49759250,   0.49458850,   0.49039250,   0.48501550,
                0.47847000,   0.47077200,   0.46194000,   0.45199450,   0.44096050,   0.42886450,
                0.41573500,   0.40160400,   0.38650500,   0.37047550,   0.35355350,   0.33577950,
                0.31719650,   0.29784950,   0.27778500,   0.25705150,   0.23569850,   0.21377750,
                0.19134150,   0.16844500,   0.14514250,   0.12149000,   0.09754500,   0.07336500,
                0.04900855,   0.02453380,  -0.50000000,  -0.52393000,  -0.54660000,  -0.56795500,
               -0.58794000,  -0.60650500,  -0.62361500,  -0.63921500,  -0.65328000,  -0.66577000,
               -0.67666000,  -0.68591500,  -0.69352000,  -0.69945500,  -0.70370000,  -0.70625500,
                0.00000000,  -0.70625500,  -0.70370000,  -0.69945500,  -0.69352000,  -0.68591500,
               -0.67666000,  -0.66577000,  -0.65328000,  -0.63921500,  -0.62361500,  -0.60650500,
               -0.58794000,  -0.56795500,  -0.54660000,  -0.52393000,  -0.50000000,  -0.47486400,
               -0.44858400,  -0.42122300,  -0.39284750,  -0.36352550,  -0.33332800,  -0.30232700,
               -0.27059800,  -0.23821700,  -0.20526200,  -0.17181300,  -0.13794950,  -0.10375400,
               -0.06930850,  -0.03469605,   0.00000000,   0.03469615,   0.06930850,   0.10375400,
                0.13794950,   0.17181300,   0.20526250,   0.23821700,   0.27059800,   0.30232700,
                0.33332800,   0.36352550,   0.39284750,   0.42122300,   0.44858400,   0.47486400;
         .VAR X_sbr_2env_imag [$aacdec.X_SBR_LEFTRIGHT_2ENV_SIZE*2];
         .VAR X_sbr_curr_imag [$aacdec.X_SBR_LEFTRIGHT_SIZE];
         // dynamic memory which is used for different things during a single frame
         // cleared after requentising_and_scaling
         .VAR tmp_mem_pool[2048+512];            // circ                      // together these make up
         .VAR sbr_temp_2[$aacdec.SBR_N];             // circ                       // the tmp_mem_pool as
         .VAR sbr_temp_4[$aacdec.SBR_N];             // circ                       // used by the rest
         .VAR tmp_mem_pool_ext[$aacdec.TMP_MEM_POOL_LENGTH-(2048+512+$aacdec.SBR_N+$aacdec.SBR_N)];      // of the library
      .ENDBLOCK;
   #else
#ifndef EXTERNAL_POOLS
   #ifndef AAC_USE_EXTERNAL_MEMORY
      .VAR/DM1CIRC_SCRATCH tmp_mem_pool[$aacdec.TMP_MEM_POOL_LENGTH];

	  .VAR tmp_mem_pool_end = &tmp_mem_pool;
   #else 
       .VAR tmp_mem_pool_ptr;; 
	   .VAR tmp_mem_pool_end_ptr;
	#endif 
#else 
    .VAR tmp_mem_pool_end = &tmp_mem_pool;
#endif
   #endif



/*
----------------------------------- Worst case memory pool usage -------------------------------


!!!!!!!!!!!!!!!!! NOTE THE PS INFORMATION IN HERE IS BASED UPON PRE CHANGELIST 184699 FILES !!!!!!!!!!!!!!!!

frame mem pool:                                                initial  max
----------------

   ltp_data.asm
      allocate left ltp structure                              0        42
      allocate right ltp structure                             42       84

   decode_cpe.asm
      allocate ms_used array                                   84       136

   huffman_unpack.asm
      possibly allocate scalefactor huffman tables                 120 words
      (only if spectral tables also unpacked)

   tns_data.asm
      allocate left tns structure                              136      240
      allocate right tns structure                             240      344

   huffman_unpack.asm
      possibly allocate and free spectral huffman tables           1232 words allocated and freed

   sbr_envelope.asm
      allocate memory for sbr_E_envelope at end of pool        344      664
      allocate and free two arrays for huffman tables          664      904

   sbr_noise.asm
      allocate and free two arrays for huffman tables          664      904

   sbr_envelope.asm
      allocate and free two arrays for huffman tables          664      904

   sbr_noise.asm
      allocate and free two arrays for huffman tables          664      904

   ps_data.asm
      allocate and free arrays for huffman tables              664      840

   tns_encdec.asm
      allocate memory for lpc coefficients                     664      688

   tns_encdec.asm
      allocate memory for lpc coefficients                     688      712

   tns_encdec.asm
      allocate memory for lpc coefficients                     712      736

   tns_encdec.asm
      allocate memory for lpc coefficients                     736      760

   FREE ALL (except sbr_E_envelope)

   sbr_limiter_frequency_table.asm
      allocate memory for sbr_F_table_lim                      320      468
      allocate and free limTable array                         468      568
      allocate and free patchBorders array                     468      532

   sbr_estimate_currant_envelope.asm
      allocate memory for sbr_E_curr                           468      713

   sbr_calculate_gain.asm
      allocate memory for lim_boost mantissas                  713      1268
      allocate and free memory for lim_boost exponents         1268     1379

   sbr_hf_assembly.asm
      free lim_boost mantissas and sbr_E_curr                  1268     1268

   ps_hybrid_analysis
      allocate and free something                              468      ????

   ps_decorrelate.asm
      allocate and free P array                                468      1748

   sbr_estimate_currant_envelope.asm
      allocate memory for sbr_E_curr                           468      713

   sbr_calculate_gain.asm
      allocate memory for lim_boost mantissas                  713      1268
      allocate and free memory for lim_boost exponents         1268     1379

   Free sbr_E_envelope memory                                  1268     1268
      (now sbr_E_orig_mantissa)

   sbr_hf_assembly.asm
      free lim_boost mantissas and sbr_E_curr                  948      948

   reconstruct_channels
      free  sbr_F_table_lim                                    148      148

   FREE ALL


   TOTALS:
   All ram - AAC                  440
   All ram - AAC+SBR             1379
   All ram - AAC+SBR+PS          1748
   Spectral data in flash        1576 (= 344 + 1232)
   Scalefactor data in flash     1696 (= 344 + 1232 + 120)

   Note: sbr_E_envelope is stored without using the allocate/free framework.
      This is why it can be kept passed 'free all's and freed at any point


tmp mem pool:                                                  pre      max
----------------

   program_element_config.asm
      allocate and free program_element_config array           0        6

   calc_sfb_and_wingroup.asm
      allocate left sect_sfb_offset array                      0        128

   section_data.asm
      allocate left sect_cb array                              128      248
      allocate left sect_start array                           248      368
      allocate left sect_end array                             368      488
      allocate left sfb_cb array                               488      608

   scalefactor_data.asm
      allocate left scalefactor array                          608      728

   pulse_data
      allocate left pulse_struc array                          728      740

   calc_sfb_and_wingroup.asm
      allocate right sect_sfb_offset array                     740      868

   section_data.asm
      allocate right sect_cb array                             868      988
      allocate right sect_start array                          988      1108
      allocate right sect_end array                            1108     1228
      allocate right sfb_cb array                              1228     1348

   scalefactor_data.asm
      allocate right scalefactor array                         1348     1468

   pulse_data.asm
      allocate right pulse_struc array                         1468     1480

   sbr_fmaster_table_calc_fscale_eq_zero.asm
      allocate and free sbr_cDk array                          1480     1608
      (same for _gt_zero.asm)

   sbr_envelope.asm
      allocate memory for sbr_E_envelope in middle of pool     1480     1800

   sbr_noise.asm
      allocate left sbr_Q_envelope                             1800     1810

   sbr_noise.asm
      allocate right sbr_Q_envelope                            1810     1820

   reorder_spec.asm
      allocate and free left temp array                        1820     2844

   reorder_spec.asm
      allocate and free right temp array                       1820     2844

   FREE ALL (except sbr_E_envelope)

   filterbank.asm
      allocate and free buf_left array                         320      1344

   filterbanks.asm
      allocate and free buf_right array                        320      1344

   FREE ALL (except sbr_E_envelope)

   sbr_analysis_filterbank.asm
      allocate X_sbr_shared                                    320      2368

   sbr_hf_assembly.asm
      allocate and free memory for filt arrays                 2368     2466

   ps_hybrid_type_a_filter.asm
      allocate and free temp_real array                        2368     2376

   ps_decorrelate.asm
      allocate and free gain_transient_ratio array             2368     3008

   Free X_sbr_shared                                           2368     2368

   FREE ALL (except sbr_E_envelope)

   sbr_analysis_filterbank.asm
      allocate X_sbr_shared                                    320      2368

   Free sbr_E_envelope memory                                  2368     2368
      (now sbr_E_orig_mantissa)

   sbr_hf_assembly.asm
      allocate and free memory for filt arrays                 2048     2146

   Free X_sbr_shared                                           2048     2048

   FREE ALL


   TOTALS:

   AAC            2504
   AAC+SBR        2844
   AAC+SBR+PS     3008

   Note: sbr_E_envelope is stored without using the allocate/free framework.
      This is why it can be kept passed 'free all's and freed at any point

*/



   // **************************************************************************
   //                            MISC data
   // **************************************************************************

   .VAR syntatic_element_func_table[] =
            &$aacdec.decode_sce,                //SCE
            &$aacdec.decode_cpe,                //CPE
            -1,                                 //CCE - not allowed for stereo streams
            -1,                                 //LFE - not allowed for stereo streams
            &$aacdec.discard_dse,               //DSE
            &$aacdec.program_element_config,    //PCE
            &$aacdec.decode_fil,                //FIL
            0;                                  //END - escape loop


   // currently we only allow decoding of stereo (1 CPE) and mono (1 SCE)
   .VAR num_SCEs;
   .VAR num_CPEs;

   // temporary data used internally by functions
   .VAR tmp[40];

   // copy of the pointer to the codec structure
   .VAR codec_struc;

   // Flag indicating if ics_ics_info has been called successfully
   .VAR/DM ics_info_done;

   #ifdef AACDEC_SBR_ADDITIONS
      // real part of X_sbr for the current channel starts at (&$aacdec.sbr_real + 512). The
      // block is constructed this way so that buf_left and buf_right can be circular buffers.
      // See sbr_global_variables.asm for structure of X_sbr
      .BLOCK/DM2CIRC sbr_x_real;
         .VAR sbr_synthesis_post_process_imag[128] =
                               0,  -0.024541228522910,  -0.049067674327420,  -0.073564563599670,  -0.098017140329560,  -0.122410675199220,  -0.146730474455360,  -0.170961888760300,
              -0.195090322016130,  -0.219101240156870,  -0.242980179903260,  -0.266712757474900,  -0.290284677254460,  -0.313681740398890,  -0.336889853392220,  -0.359895036534990,
              -0.382683432365090,  -0.405241314004990,  -0.427555093430280,  -0.449611329654610,  -0.471396736826000,  -0.492898192229780,  -0.514102744193220,  -0.534997619887100,
              -0.555570233019600,  -0.575808191417850,  -0.595699304492430,  -0.615231590580630,  -0.634393284163650,  -0.653172842953780,  -0.671558954847020,  -0.689540544737070,
              -0.707106781186550,  -0.724247082951470,  -0.740951125354960,  -0.757208846506480,  -0.773010453362740,  -0.788346427626610,  -0.803207531480640,  -0.817584813151580,
              -0.831469612302550,  -0.844853565249710,  -0.857728610000270,  -0.870086991108710,  -0.881921264348350,  -0.893224301195520,  -0.903989293123440,  -0.914209755703530,
              -0.923879532511290,  -0.932992798834740,  -0.941544065183020,  -0.949528180593040,  -0.956940335732210,  -0.963776065795440,  -0.970031253194540,  -0.975702130038530,
              -0.980785280403230,  -0.985277642388940,  -0.989176509964780,  -0.992479534598710,  -0.995184726672200,  -0.997290456678690,  -0.998795456205170,  -0.999698818696200,
              -1.000000000000000,  -0.999698818696200,  -0.998795456205170,  -0.997290456678690,  -0.995184726672200,  -0.992479534598710,  -0.989176509964780,  -0.985277642388940,
              -0.980785280403230,  -0.975702130038530,  -0.970031253194540,  -0.963776065795440,  -0.956940335732210,  -0.949528180593040,  -0.941544065183020,  -0.932992798834740,
              -0.923879532511290,  -0.914209755703530,  -0.903989293123440,  -0.893224301195520,  -0.881921264348360,  -0.870086991108710,  -0.857728610000270,  -0.844853565249710,
              -0.831469612302550,  -0.817584813151580,  -0.803207531480640,  -0.788346427626610,  -0.773010453362740,  -0.757208846506480,  -0.740951125354960,  -0.724247082951470,
              -0.707106781186550,  -0.689540544737070,  -0.671558954847020,  -0.653172842953780,  -0.634393284163650,  -0.615231590580630,  -0.595699304492430,  -0.575808191417850,
              -0.555570233019600,  -0.534997619887100,  -0.514102744193220,  -0.492898192229780,  -0.471396736826000,  -0.449611329654610,  -0.427555093430280,  -0.405241314004990,
              -0.382683432365090,  -0.359895036534990,  -0.336889853392220,  -0.313681740398890,  -0.290284677254460,  -0.266712757474900,  -0.242980179903260,  -0.219101240156870,
              -0.195090322016130,  -0.170961888760300,  -0.146730474455360,  -0.122410675199220,  -0.098017140329560,  -0.073564563599670,  -0.049067674327420,  -0.024541228522910;
         .VAR X_sbr_other_real [X_SBR_LEFTRIGHT_SIZE];
         .VAR X_sbr_2env_real [X_SBR_LEFTRIGHT_2ENV_SIZE*2];
         .VAR X_sbr_curr_real [X_SBR_LEFTRIGHT_SIZE];
         .VAR buf_left[1024];                                  // circ
         .VAR buf_right[1024];                                 // circ
      #ifdef AACDEC_ELD_ADDITIONS
         .VAR ifft_re[$aacdec.POWER_OF_2_IFFT_SIZE];           // circ
      #endif // AACDEC_ELD_ADDITIONS
      .ENDBLOCK;
   #else
      #ifdef AAC_LOWRAM
      #ifndef AAC_USE_EXTERNAL_MEMORY
         .VAR/DM1CIRC buf_left[1024];
         .VAR/DM2CIRC buf_right[1024];
      #else 

      .VAR buf_left_ptr;
      .VAR buf_right_ptr;
      #endif
      
      #else
      #ifndef AAC_USE_EXTERNAL_MEMORY
         .VAR/DM2CIRC buf_left[1024];
         .VAR/DM2CIRC buf_right[1024];
      #else 
      .VAR buf_left_ptr;
      .VAR buf_right_ptr;
      #endif 
      #endif
   #endif

      #ifdef AACDEC_ELD_ADDITIONS

         // Optimisation - shortened by removing the first 128 coefficients which are 0
         .VAR/DM2 win_512_ld[$aacdec.WIN_512_LD_SIZE] =
            0.001694170,   0.002838725,   0.004238385,   0.005863205,   0.007662775,   0.009588320,   0.011594045,   0.013646295,
            0.015722515,   0.017801305,   0.019862495,   0.021898915,   0.023915470,   0.025916785,   0.027906710,   0.029888615,
            0.031865865,   0.033841820,   0.035819685,   0.037799880,   0.039780480,   0.041760120,   0.043738115,   0.045715175,
            0.047693090,   0.049673855,   0.051659585,   0.053652280,   0.055653485,   0.057664335,   0.059685665,   0.061719610,
            0.063769555,   0.065838525,   0.067929060,   0.070042645,   0.072179930,   0.074341455,   0.076527655,   0.078737970,
            0.080970965,   0.083225350,   0.085499955,   0.087793165,   0.090103000,   0.092427740,   0.094765955,   0.097116610,
            0.099479000,   0.101852560,   0.104236870,   0.106631560,   0.109036220,   0.111450415,   0.113873710,   0.116306050,
            0.118747710,   0.121198835,   0.123659445,   0.126129435,   0.128608595,   0.131096650,   0.133593240,   0.136098150,
            0.138611310,   0.141132570,   0.143661680,   0.146198140,   0.148741235,   0.151290275,   0.153844570,   0.156402540,
            0.158961925,   0.161520860,   0.164077895,   0.166631985,   0.169182350,   0.171728305,   0.174269340,   0.176805940,
            0.179339325,   0.181870360,   0.184399500,   0.186926735,   0.189451745,   0.191974180,   0.194493650,   0.197009560,
            0.199521180,   0.202027875,   0.204529100,   0.207024095,   0.209511990,   0.211992115,   0.214464025,   0.216927205,
            0.219381050,   0.221825070,   0.224258930,   0.226683160,   0.229098795,   0.231506510,   0.233906545,   0.236298610,
            0.238682175,   0.241056825,   0.243422250,   0.245777970,   0.248123395,   0.250458180,   0.252782200,   0.255095660,
            0.257398855,   0.259691955,   0.261974990,   0.264247935,   0.266510755,   0.268763400,   0.271005800,   0.273237875,
            0.275459580,   0.277670905,   0.279871880,   0.282062565,   0.284243075,   0.286413550,   0.288574170,   0.290725150,
            0.292462445,   0.294592555,   0.296711630,   0.298819680,   0.300916735,   0.303002805,   0.305077905,   0.307142060,
            0.309195280,   0.311237585,   0.313268995,   0.315289560,   0.317299360,   0.319298485,   0.321287015,   0.323265005,
            0.325232475,   0.327189435,   0.329135905,   0.331071915,   0.332997495,   0.334912675,   0.336817495,   0.338711970,
            0.340596095,   0.342469860,   0.344333265,   0.346186290,   0.348028890,   0.349861035,   0.351682685,   0.353493790,
            0.355294310,   0.357084185,   0.358863370,   0.360631805,   0.362389445,   0.364136230,   0.365872095,   0.367596960,
            0.369310705,   0.371013215,   0.372704370,   0.374384085,   0.376052290,   0.377708925,   0.379353925,   0.380987185,
            0.382608545,   0.384217850,   0.385814940,   0.387399695,   0.388972015,   0.390531795,   0.392078945,   0.393613350,
            0.395134895,   0.396643470,   0.398138955,   0.399621220,   0.401090135,   0.402545560,   0.403987360,   0.405415405,
            0.406829575,   0.408229745,   0.409615800,   0.410987640,   0.412345185,   0.413688365,   0.415017095,   0.416331310,
            0.417630930,   0.418915880,   0.420186085,   0.421441485,   0.422682005,   0.423907585,   0.425118160,   0.426313695,
            0.427494180,   0.428659605,   0.429809965,   0.430945260,   0.432065505,   0.433170700,   0.434260865,   0.435336055,
            0.436396375,   0.437441920,   0.438472795,   0.439489120,   0.440491030,   0.441478645,   0.442452115,   0.443411660,
            0.444357595,   0.445290240,   0.446209915,   0.447116955,   0.448011690,   0.448894465,   0.449765630,   0.450625710,
            0.451475430,   0.452315520,   0.453146705,   0.453969730,   0.454785335,   0.455594280,   0.456397320,   0.457195365,
            0.457989490,   0.458780765,   0.459570245,   0.460358450,   0.461145350,   0.461930910,   0.462714965,   0.463494730,
            0.464264800,   0.465019645,   0.465753635,   0.466458695,   0.467124315,   0.467739870,   0.468294910,   0.468782935,
            0.469470360,   0.469613900,   0.469777385,   0.469956450,   0.470145520,   0.470338970,   0.470531290,   0.470720420,
            0.470907745,   0.471094815,   0.471283140,   0.471473310,   0.471664990,   0.471857810,   0.472051400,   0.472245610,
            0.472440530,   0.472636245,   0.472832840,   0.473030370,   0.473228860,   0.473428325,   0.473628795,   0.473830270,
            0.474032735,   0.474236170,   0.474440575,   0.474645950,   0.474852345,   0.475059800,   0.475268360,   0.475478020,
            0.475688755,   0.475900525,   0.476113290,   0.476327065,   0.476541900,   0.476757855,   0.476974970,   0.477193265,
            0.477412690,   0.477633215,   0.477854790,   0.478077430,   0.478301170,   0.478526070,   0.478752165,   0.478979460,
            0.479207910,   0.479437465,   0.479668080,   0.479899745,   0.480132500,   0.480366385,   0.480601430,   0.480837630,
            0.481074930,   0.481313275,   0.481552610,   0.481792930,   0.482034265,   0.482276650,   0.482520130,   0.482764680,
            0.483010255,   0.483256800,   0.483504250,   0.483752600,   0.484001880,   0.484252120,   0.484503350,   0.484755560,
            0.485008690,   0.485262665,   0.485517440,   0.485772985,   0.486029335,   0.486286520,   0.486544575,   0.486803470,
            0.487063155,   0.487323555,   0.487584615,   0.487846310,   0.488108675,   0.488371750,   0.488635555,   0.488900080,
            0.489165255,   0.489431025,   0.489697315,   0.489964115,   0.490231455,   0.490499375,   0.490767900,   0.491037025,
            0.491306685,   0.491576820,   0.491847370,   0.492118320,   0.492389705,   0.492661555,   0.492933900,   0.493206740,
            0.493480015,   0.493753670,   0.494027650,   0.494301945,   0.494576600,   0.494851640,   0.495127115,   0.495403010,
            0.495679275,   0.495955855,   0.496232705,   0.496509810,   0.496787215,   0.497064960,   0.497343085,   0.497621600,
            0.497900460,   0.498179630,   0.498459070,   0.498738740,   0.499018605,   0.499298625,   0.499578760,   0.499858965,
            0.500141075,   0.500421595,   0.500702360,   0.500983325,   0.501264445,   0.501545695,   0.501827020,   0.502108395,
            0.502389770,   0.502671105,   0.502952370,   0.503233565,   0.503514725,   0.503795895,   0.504077120,   0.504358390,
            0.504639650,   0.504920845,   0.505201920,   0.505482875,   0.505763735,   0.506044550,   0.506325350,   0.506606130,
            0.506886825,   0.507167390,   0.507447755,   0.507727920,   0.508007910,   0.508287765,   0.508567510,   0.508847135,
            0.509126580,   0.509405770,   0.509684645,   0.509963195,   0.510241445,   0.510519440,   0.510797205,   0.511074725,
            0.511351935,   0.511628755,   0.511905125,   0.512181020,   0.512456475,   0.512731520,   0.513006190,   0.513280460,
            0.513554265,   0.513827540,   0.514100205,   0.514372245,   0.514643685,   0.514914565,   0.515184905,   0.515454685,
            0.515723840,   0.515992300,   0.516260000,   0.516526920,   0.516793085,   0.517058535,   0.517323295,   0.517587350,
            0.517850640,   0.518113100,   0.518374670,   0.518635330,   0.518895120,   0.519154075,   0.519412230,   0.519669570,
            0.519926030,   0.520181560,   0.520436085,   0.520689600,   0.520942140,   0.521193740,   0.521444440,   0.521694225,
            0.521943050,   0.522190850,   0.522437575,   0.522683225,   0.522927845,   0.523171485,   0.523414190,   0.523655960,
            0.523896750,   0.524136515,   0.524375210,   0.524612840,   0.524849455,   0.525085110,   0.525319870,   0.525553730,
            0.525786660,   0.526018605,   0.526249535,   0.526479445,   0.526708380,   0.526936385,   0.527163500,   0.527389740,
            0.527615090,   0.527839530,   0.528063040,   0.528285620,   0.528507295,   0.528728080,   0.528948005,   0.529167130,
            0.529385545,   0.529603345,   0.529820625,   0.530037220,   0.530252710,   0.530466675,   0.530678730,   0.530889545,
            0.531100820,   0.531314290,   0.531531545,   0.531750250,   0.531964185,   0.532166955,   0.532352215,   0.532514980,
            0.532405380,   0.532348825,   0.532225020,   0.532040010,   0.531806910,   0.531538595,   0.531247265,   0.530941825,
            0.530628060,   0.530311455,   0.529997090,   0.529685660,   0.529373630,   0.529057430,   0.528733640,   0.528400000,
            0.528055350,   0.527698575,   0.527328675,   0.526946645,   0.526555415,   0.526157890,   0.525756860,   0.525354055,
            0.524950220,   0.524546050,   0.524142170,   0.523738235,   0.523332950,   0.522925015,   0.522513140,   0.522095045,
            0.521667495,   0.521227260,   0.520771220,   0.520297260,   0.519804230,   0.519291035,   0.518756630,   0.518200945,
            0.517624880,   0.517029340,   0.516415235,   0.515784060,   0.515137870,   0.514478715,   0.513808585,   0.513129020,
            0.512441110,   0.511745920,   0.511044460,   0.510337250,   0.509624305,   0.508905615,   0.508181145,   0.507450225,
            0.506711575,   0.505963890,   0.505205875,   0.504436420,   0.503654575,   0.502859410,   0.502049980,   0.501225160,
            0.500383670,   0.499524210,   0.498645505,   0.497746900,   0.496828320,   0.495889730,   0.494931170,   0.493955120,
            0.492966470,   0.491970185,   0.490971130,   0.489972660,   0.488976620,   0.487984775,   0.486998740,   0.486016630,
            0.485033120,   0.484042730,   0.483040090,   0.482022080,   0.480987780,   0.479936380,   0.478867100,   0.477780090,
            0.476676455,   0.475557310,   0.474423820,   0.473278315,   0.472124290,   0.470965275,   0.469804765,   0.468645770,
            0.467490785,   0.466342280,   0.465202515,   0.464068855,   0.462933775,   0.461789550,   0.460628655,   0.459448210,
            0.458249990,   0.457035955,   0.455808115,   0.454569875,   0.453326010,   0.452081355,   0.450840575,   0.449604670,
            0.448370945,   0.447136560,   0.445898715,   0.444655735,   0.443407075,   0.442152225,   0.440890705,   0.439622640,
            0.438348765,   0.437069830,   0.435786590,   0.434499790,   0.433210185,   0.431918515,   0.430625530,   0.429331965,
            0.428021180,   0.426721925,   0.425415465,   0.424102750,   0.422784715,   0.421462290,   0.420136390,   0.418807930,
            0.417477825,   0.416146965,   0.414816215,   0.413485675,   0.412154665,   0.410822480,   0.409488345,   0.408150085,
            0.406804110,   0.405446775,   0.404074620,   0.402688705,   0.401294600,   0.399898055,   0.398504770,   0.397119065,
            0.395743900,   0.394382160,   0.393036450,   0.391702950,   0.390371440,   0.389031395,   0.387672570,   0.386290935,
            0.384888685,   0.383468270,   0.382032205,   0.380584255,   0.379129460,   0.377672910,   0.376219620,   0.374773170,
            0.373335675,   0.371909200,   0.370495725,   0.369095735,   0.367708205,   0.366332040,   0.364965965,   0.363604565,
            0.362238305,   0.360857470,   0.359452575,   0.358019660,   0.356560280,   0.355076250,   0.353569500,   0.352045420,
            0.350512825,   0.348980685,   0.347457780,   0.345948860,   0.344454655,   0.342975705,   0.341512490,   0.340064260,
            0.338629005,   0.337204680,   0.335789205,   0.334380405,   0.332975975,   0.331573610,   0.330170970,   0.328765135,
            0.327352625,   0.325929920,   0.324493545,   0.323041070,   0.321571105,   0.320082300,   0.318573400,   0.317045170,
            0.315500410,   0.313942000,   0.312372885,   0.310797365,   0.309221125,   0.307649885,   0.306089330,   0.304544055,
            0.303017550,   0.301513270,   0.300034580,   0.298582940,   0.297157900,   0.295758935,   0.294385340,   0.293032475,
            0.291691765,   0.290354455,   0.289011780,   0.287654320,   0.286272020,   0.284854790,   0.283392885,   0.281884300,
            0.280334755,   0.278750320,   0.277137255,   0.275506505,   0.273873660,   0.272254535,   0.270664680,   0.269113720,
            0.267605360,   0.266143065,   0.264729895,   0.263359985,   0.262018540,   0.260690360,   0.259360425,   0.258017850,
            0.256655850,   0.255267800,   0.253847330,   0.252394655,   0.250916540,   0.249420005,   0.247912030,   0.246399525,
            0.244928740,   0.243398205,   0.241897145,   0.240426815,   0.238982880,   0.237560755,   0.236155755,   0.234762010,
            0.233372430,   0.231979890,   0.230577480,   0.229163035,   0.227739150,   0.226308635,   0.224874330,   0.223440055,
            0.222010625,   0.220590890,   0.219185470,   0.217793860,   0.216410410,   0.215029235,   0.213644565,   0.212252860,
            0.210852835,   0.209443290,   0.208023165,   0.206594485,   0.205162360,   0.203732025,   0.202308620,   0.200894715,
            0.199490330,   0.198095365,   0.196709700,   0.195332595,   0.193962680,   0.192598565,   0.191238865,   0.189882380,
            0.188528100,   0.187175030,   0.185822190,   0.184469345,   0.183116980,   0.181765620,   0.180415765,   0.179067665,
            0.177721310,   0.176376690,   0.175033775,   0.173692650,   0.172353495,   0.171016480,   0.169681795,   0.168349610,
            0.167020135,   0.165693555,   0.164370065,   0.163049720,   0.161732465,   0.160418225,   0.159106940,   0.157798515,
            0.156492865,   0.155189935,   0.153889705,   0.152592230,   0.151297625,   0.150006010,   0.148717495,   0.147432140,
            0.146149945,   0.144870895,   0.143594985,   0.142322260,   0.141052810,   0.139786730,   0.138524100,   0.137264960,
            0.136009270,   0.134756995,   0.133508110,   0.132262665,   0.131020790,   0.129782630,   0.128548310,   0.127317915,
            0.126091470,   0.124868990,   0.123650500,   0.122436035,   0.121225665,   0.120019465,   0.118817500,   0.117619795,
            0.116426310,   0.115237005,   0.114051845,   0.112870850,   0.111694090,   0.110521645,   0.109353595,   0.108189930,
            0.107030585,   0.105875475,   0.104724520,   0.103577675,   0.102434935,   0.101296305,   0.100161780,   0.099031295,
            0.097904720,   0.096781925,   0.095662780,   0.094547210,   0.093435200,   0.092326750,   0.091221860,   0.090120820,
            0.089024205,   0.087932605,   0.086846610,   0.085766800,   0.084693775,   0.083628110,   0.082570405,   0.081521235,
            0.080494870,   0.079482805,   0.078480130,   0.077486295,   0.076500755,   0.075522950,   0.074552330,   0.073588330,
            0.072630405,   0.071677995,   0.070730555,   0.069787850,   0.068849965,   0.067916995,   0.066989030,   0.066066145,
            0.065148410,   0.064235890,   0.063328645,   0.062426765,   0.061530370,   0.060639580,   0.059754500,   0.058875215,
            0.058001735,   0.057134100,   0.056272320,   0.055416460,   0.054566590,   0.053722795,   0.052885140,   0.052053665,
            0.051228360,   0.050409210,   0.049596200,   0.048789360,   0.047988750,   0.047194420,   0.046406440,   0.045624820,
            0.044849535,   0.044080555,   0.043317850,   0.042561440,   0.041811370,   0.041067700,   0.040330480,   0.039599720,
            0.038875380,   0.038157420,   0.037445805,   0.036740540,   0.036041675,   0.035349255,   0.034663330,   0.033983905,
            0.033310935,   0.032644370,   0.031984165,   0.031330325,   0.030682890,   0.030041900,   0.029407400,   0.028779380,
            0.028157785,   0.027542555,   0.026933640,   0.026331030,   0.025734755,   0.025144855,   0.024561360,   0.023984275,
            0.023413545,   0.022849125,   0.022290970,   0.021739085,   0.021193520,   0.020654340,   0.020121590,   0.019595280,
            0.019075355,   0.018561760,   0.018054450,   0.017553395,   0.017058600,   0.016570065,   0.016087800,   0.015611715,
            0.015141660,   0.014677470,   0.014218995,   0.013766150,   0.013318940,   0.012877360,   0.012441415,   0.012011160,
            0.011586705,   0.011168155,   0.010755620,   0.010349330,   0.009949610,   0.009556795,   0.009171205,   0.008792815,
            0.008421240,   0.008056095,   0.007696985,   0.007343630,   0.006995835,   0.006653435,   0.006316250,   0.005984355,
            0.005658045,   0.005337635,   0.005023420,   0.004715385,   0.004413205,   0.004116535,   0.003825055,   0.003538675,
            0.003257565,   0.002981885,   0.002711820,   0.002447570,   0.002189420,   0.001937650,   0.001692545,   0.001453975,
            0.001221410,   0.000994300,   0.000772085,   0.000554125,   0.000339670,   0.000127945,  -0.000081785,  -0.000289485,
           -0.000494325,  -0.000695445,  -0.000891985,  -0.001082735,  -0.001266150,  -0.001440665,  -0.001604775,  -0.001758130,
           -0.001901575,  -0.002035990,  -0.002162285,  -0.002281865,  -0.002396630,  -0.002508495,  -0.002619355,  -0.002730330,
           -0.002841800,  -0.002954105,  -0.003067540,  -0.003181555,  -0.003294720,  -0.003405585,  -0.003512700,  -0.003614910,
           -0.003711340,  -0.003801130,  -0.003883435,  -0.003957900,  -0.004024665,  -0.004083870,  -0.004135695,  -0.004180610,
           -0.004219410,  -0.004252915,  -0.004281915,  -0.004307150,  -0.004329265,  -0.004348905,  -0.004366720,  -0.004383165,
           -0.004398535,  -0.004413110,  -0.004427165,  -0.004440660,  -0.004453260,  -0.004464625,  -0.004474405,  -0.004482230,
           -0.004487705,  -0.004490440,  -0.004490050,  -0.004486170,  -0.004478480,  -0.004466650,  -0.004450380,  -0.004429570,
           -0.004404375,  -0.004374935,  -0.004341410,  -0.004304125,  -0.004263580,  -0.004220275,  -0.004174705,  -0.004127425,
           -0.004079035,  -0.004030125,  -0.003981265,  -0.003932595,  -0.003883835,  -0.003834685,  -0.003784855,  -0.003733950,
           -0.003681525,  -0.003627110,  -0.003570275,  -0.003510805,  -0.003448730,  -0.003384080,  -0.003316905,  -0.003247445,
           -0.003176150,  -0.003103470,  -0.003029845,  -0.002955580,  -0.002880835,  -0.002805775,  -0.002730550,  -0.002655185,
           -0.002579585,  -0.002503660,  -0.002427310,  -0.002350375,  -0.002272650,  -0.002193930,  -0.002114025,  -0.002032970,
           -0.001951020,  -0.001868430,  -0.001785455,  -0.001702240,  -0.001618850,  -0.001535330,  -0.001451720,  -0.001368050,
           -0.001284335,  -0.001200585,  -0.001116825,  -0.001033070,  -0.000949330,  -0.000865615,  -0.000781950,  -0.000698370,
           -0.000614945,  -0.000531755,  -0.000448860,  -0.000366335,  -0.000284245,  -0.000202650,  -0.000121620,  -0.000041205,
            0.000041070,   0.000120510,   0.000199610,   0.000278300,   0.000356495,   0.000434130,   0.000511120,   0.000587400,
            0.000662895,   0.000737535,   0.000811260,   0.000884020,   0.000955805,   0.001026595,   0.001096385,   0.001165145,
            0.001232835,   0.001299430,   0.001364875,   0.001429160,   0.001492265,   0.001554195,   0.001614950,   0.001674430,
            0.001732470,   0.001788890,   0.001843530,   0.001896365,   0.001947505,   0.001997055,   0.002045100,   0.002091750,
            0.002137095,   0.002181245,   0.002224290,   0.002266250,   0.002307055,   0.002346640,   0.002384940,   0.002421780,
            0.002456875,   0.002489935,   0.002520695,   0.002549030,   0.002574950,   0.002598465,   0.002619600,   0.002638500,
            0.002655415,   0.002670610,   0.002684320,   0.002696785,   0.002708245,   0.002718925,   0.002729045,   0.002738565,
            0.002747205,   0.002754680,   0.002760730,   0.002765085,   0.002767470,   0.002767620,   0.002765290,   0.002760325,
            0.002752680,   0.002742295,   0.002729140,   0.002713310,   0.002695035,   0.002674550,   0.002652075,   0.002627840,
            0.002602085,   0.002575045,   0.002546935,   0.002517975,   0.002488370,   0.002458325,   0.002428025,   0.002397515,
            0.002366680,   0.002335410,   0.002303605,   0.002271080,   0.002237585,   0.002202875,   0.002166720,   0.002128840,
            0.002088930,   0.002046680,   0.002001815,   0.001954185,   0.001903795,   0.001850650,   0.001794760,   0.001736340,
            0.001675785,   0.001613495,   0.001549875,   0.001485440,   0.001420820,   0.001356640,   0.001293500,   0.001231640,
            0.001170975,   0.001111405,   0.001052810,   0.000994790,   0.000936655,   0.000877730,   0.000817370,   0.000755100,
            0.000690650,   0.000623750,   0.000554155,   0.000482055,   0.000408055,   0.000332770,   0.000256815,   0.000180670,
            0.000104700,   0.000029265,  -0.000045290,  -0.000118915,  -0.000191840,  -0.000264305,  -0.000336550,  -0.000408785,
           -0.000481185,  -0.000553930,  -0.000627210,  -0.000701050,  -0.000775325,  -0.000849920,  -0.000924700,  -0.000999550,
           -0.001074360,  -0.001148990,  -0.001223320,  -0.001297310,  -0.001371025,  -0.001444560,  -0.001517980,  -0.001591295,
           -0.001664450,  -0.001737400,  -0.001810120,  -0.001882595,  -0.001954810,  -0.002026725,  -0.002098290,  -0.002169510,
           -0.002240425,  -0.002311095,  -0.002381545,  -0.002451785,  -0.002521805,  -0.002591605,  -0.002661215,  -0.002730660,
           -0.002799940,  -0.002869055,  -0.002938010,  -0.003006815,  -0.003075470,  -0.003143975,  -0.003212330,  -0.003280555,
           -0.003348685,  -0.003416760,  -0.003484815,  -0.003552890,  -0.003621040,  -0.003689310,  -0.003757770,  -0.003826475,
           -0.003895490,  -0.003964880,  -0.004034705,  -0.004105030,  -0.004175915,  -0.004247425,  -0.004319630,  -0.004392610,
           -0.004466465,  -0.004541300,  -0.004617220,  -0.004694320,  -0.004772685,  -0.004852410,  -0.004933575,  -0.005015865,
           -0.005098555,  -0.005180820,  -0.005261785,  -0.005340920,  -0.005418110,  -0.005493260,  -0.005566260,  -0.005637045,
           -0.005705570,  -0.005771790,  -0.005835675,  -0.005897195,  -0.005956340,  -0.006013095,  -0.006067465,  -0.006119455,
           -0.006169085,  -0.006216375,  -0.006261360,  -0.006304075,  -0.006344575,  -0.006382915,  -0.006419160,  -0.006453425,
           -0.006485855,  -0.006516600,  -0.006545840,  -0.006573610,  -0.006599845,  -0.006624445,  -0.006647330,  -0.006668465,
           -0.006687885,  -0.006705625,  -0.006721725,  -0.006736215,  -0.006749115,  -0.006760445,  -0.006770225,  -0.006778500,
           -0.006785340,  -0.006790820,  -0.006795015,  -0.006797935,  -0.006799505,  -0.006799655,  -0.006798305,  -0.006795435,
           -0.006791095,  -0.006785325,  -0.006778185,  -0.006769675,  -0.006759745,  -0.006748350,  -0.006735440,  -0.006721070,
           -0.006705390,  -0.006688575,  -0.006670790,  -0.006652210,  -0.006633005,  -0.006613355,  -0.006593445,  -0.006573460,
           -0.006550615,  -0.006532350,  -0.006512780,  -0.006491905,  -0.006469740,  -0.006446275,  -0.006421525,  -0.006395475,
           -0.006368125,  -0.006339465,  -0.006309485,  -0.006278160,  -0.006245480,  -0.006211415,  -0.006175950,  -0.006139135,
           -0.006101065,  -0.006061830,  -0.006021520,  -0.005980160,  -0.005937715,  -0.005894145,  -0.005849420,  -0.005803590,
           -0.005756760,  -0.005709045,  -0.005660555,  -0.005611360,  -0.005561520,  -0.005511085,  -0.005460110,  -0.005408650,
           -0.005356775,  -0.005304560,  -0.005252055,  -0.005199270,  -0.005146135,  -0.005092605,  -0.005038635,  -0.004984295,
           -0.004929795,  -0.004875315,  -0.004821040,  -0.004767100,  -0.004713615,  -0.004660675,  -0.004608385,  -0.004556820,
           -0.004506040,  -0.004456100,  -0.004407060,  -0.004358960,  -0.004311845,  -0.004265765,  -0.004220745,  -0.004176800,
           -0.004133925,  -0.004092110,  -0.004051335,  -0.004011560,  -0.003972735,  -0.003934795,  -0.003897665,  -0.003860825,
           -0.003823365,  -0.003784430,  -0.003743245,  -0.003699525,  -0.003653405,  -0.003605030,  -0.003554550,  -0.003502095,
           -0.003447795,  -0.003391770,  -0.003334145,  -0.003275035,  -0.003214580,  -0.003152895,  -0.003090110,  -0.003026335,
           -0.002961665,  -0.002896200,  -0.002830030,  -0.002763255,  -0.002695970,  -0.002628265,  -0.002560235,  -0.002491950,
           -0.002423465,  -0.002354845,  -0.002286140,  -0.002217410,  -0.002148730,  -0.002080170,  -0.002011795,  -0.001943690,
           -0.001875925,  -0.001808590,  -0.001741750,  -0.001675500,  -0.001609955,  -0.001545215,  -0.001481380,  -0.001418490,
           -0.001356535,  -0.001295490,  -0.001235330,  -0.001176050,  -0.001117655,  -0.001060150,  -0.001003545,  -0.000947880,
           -0.000893235,  -0.000839680,  -0.000787285,  -0.000736080,  -0.000686025,  -0.000637090,  -0.000589245,  -0.000542490,
           -0.000496875,  -0.000452430,  -0.000409200,  -0.000367220,  -0.000326545,  -0.000287225,  -0.000249300,  -0.000212755,
           -0.000177515,  -0.000143500,  -0.000110625,  -0.000078805,  -0.000047940,  -0.000017915,   0.000011360,   0.000039875,
            0.000067505,   0.000094140,   0.000119665,   0.000143920,   0.000166710,   0.000187860,   0.000207190,   0.000224695,
            0.000240515,   0.000254790,   0.000267665,   0.000279345,   0.000290075,   0.000300110,   0.000309675,   0.000318905,
            0.000327840,   0.000336515,   0.000344955,   0.000353095,   0.000360775,   0.000367835,   0.000374130,   0.000379560,
            0.000384055,   0.000387545,   0.000389985,   0.000391375,   0.000391755,   0.000391185,   0.000389715,   0.000387420,
            0.000384420,   0.000380800,   0.000376675,   0.000372115,   0.000367210,   0.000362020,   0.000356615,   0.000351045,
            0.000345340,   0.000339530,   0.000333640,   0.000327670,   0.000321605,   0.000315430,   0.000309120,   0.000302670,
            0.000296055,   0.000289275,   0.000282310,   0.000275165,   0.000267830,   0.000260315,   0.000252610,   0.000244745,
            0.000236745,   0.000228640,   0.000220460,   0.000212235,   0.000204015,   0.000195830,   0.000187720,   0.000179715,
            0.000171855,   0.000164165,   0.000156665,   0.000149370,   0.000142260,   0.000135335,   0.000128575,   0.000121975,
            0.000115520,   0.000109210,   0.000103030,   0.000096990,   0.000091090,   0.000085345,   0.000079765,   0.000074355,
            0.000069135,   0.000064115,   0.000059305,   0.000054710,   0.000050335,   0.000046180,   0.000042240,   0.000038515,
            0.000034995,   0.000031685,   0.000028570,   0.000025645,   0.000022915,   0.000020360,   0.000017985,   0.000015785,
            0.000013760,   0.000011900,   0.000010210,   0.000008680,   0.000007305,   0.000006075,   0.000004990,   0.000004035,
            0.000003205,   0.000002495,   0.000001890,   0.000001390,   0.000000980,   0.000000660,   0.000000410,   0.000000230,
            NO_UF(0.000000100),  NO_UF(0.000000025),  NO_UF(-0.000000015),    NO_UF(-0.000000030),    NO_UF(-0.000000020),    NO_UF(-0.000000005),    NO_UF(0.000000005),  NO_UF(0.000000005),
            NO_UF(0.000000005),  NO_UF(0.000000005),  NO_UF(-0.000000005),    NO_UF(-0.000000020),    NO_UF(-0.000000025),    NO_UF(-0.000000015),    NO_UF(0.000000025),  NO_UF(0.000000100),
            0.000000215,   0.000000385,   0.000000615,   0.000000915,   0.000001285,   0.000001740,   0.000002275,   0.000002905,
            0.000003635,   0.000004465,   0.000005400,   0.000006450,   0.000007610,   0.000008890,   0.000010285,   0.000011810,
            0.000013455,   0.000015220,   0.000017110,   0.000019120,   0.000021250,   0.000023505,   0.000025880,   0.000028380,
            0.000031000,   0.000033745,   0.000036610,   0.000039600,   0.000042705,   0.000045930,   0.000049270,   0.000052715,
            0.000056255,   0.000059875,   0.000063570,   0.000067325,   0.000071135,   0.000074985,   0.000078875,   0.000082790,
            0.000086740,   0.000090720,   0.000094735,   0.000098780,   0.000102865,   0.000106995,   0.000111165,   0.000115380,
            0.000119620,   0.000123865,   0.000128105,   0.000132310,   0.000136465,   0.000140540,   0.000144520,   0.000148375,
            0.000152095,   0.000155660,   0.000159050,   0.000162265,   0.000165305,   0.000168160,   0.000170845,   0.000173360,
            0.000175710,   0.000177900,   0.000179940,   0.000181845,   0.000183615,   0.000185265,   0.000186805,   0.000188235,
            0.000189545,   0.000190725,   0.000191760,   0.000192635,   0.000193315,   0.000193785,   0.000194005,   0.000193950,
            0.000193585,   0.000192860,   0.000191750,   0.000190220,   0.000188255,   0.000185850,   0.000182985,   0.000179680,
            0.000175955,   0.000171850,   0.000167400,   0.000162655,   0.000157685,   0.000152560,   0.000147350,   0.000142085,
            0.000136770,   0.000131395,   0.000125955,   0.000120405,   0.000114665,   0.000108655,   0.000102290,   0.000095505,
            0.000088270,   0.000080530,   0.000072260,   0.000063470,   0.000054240,   0.000044645,   0.000034765,   0.000024675,
            0.000014420,   0.000004065,  -0.000006340,  -0.000016785,  -0.000027285,  -0.000037870,  -0.000048570,  -0.000059410,
           -0.000070410,  -0.000081590,  -0.000092975,  -0.000104560,  -0.000116325,  -0.000128250,  -0.000140300,  -0.000152460,
           -0.000164705,  -0.000177000,  -0.000189325,  -0.000201665,  -0.000214020,  -0.000226395,  -0.000238795,  -0.000251215,
           -0.000263640,  -0.000276045,  -0.000288425,  -0.000300765,  -0.000313055,  -0.000325280,  -0.000337425,  -0.000349475,
           -0.000361435,  -0.000373300,  -0.000385065,  -0.000396725,  -0.000408265,  -0.000419680,  -0.000430960,  -0.000442105,
           -0.000453095,  -0.000463930,  -0.000474595,  -0.000485085,  -0.000495385,  -0.000505490,  -0.000515385,  -0.000525060,
           -0.000534520,  -0.000543750,  -0.000552745,  -0.000561505,  -0.000570025,  -0.000578300,  -0.000586325,  -0.000594105,
           -0.000601625,  -0.000608895,  -0.000615900,  -0.000622640,  -0.000629110,  -0.000635305,  -0.000641215,  -0.000646840,
           -0.000652175,  -0.000657225,  -0.000661975,  -0.000666425,  -0.000670565,  -0.000674390,  -0.000677885,  -0.000681075,
           -0.000683985,  -0.000686665,  -0.000689170,  -0.000691525,  -0.000693740,  -0.000695815,  -0.000697755,  -0.000699565,
           -0.000701245,  -0.000702795,  -0.000704220,  -0.000705510,  -0.000706670,  -0.000707690,  -0.000708570,  -0.000709305,
           -0.000709890,  -0.000710320,  -0.000710585,  -0.000710690,  -0.000710625,  -0.000710385,  -0.000709960,  -0.000709350,
           -0.000708550,  -0.000707550,  -0.000706340,  -0.000704930,  -0.000703315,  -0.000701505,  -0.000699500,  -0.000697300,
           -0.000694905,  -0.000692320,  -0.000689540,  -0.000686565,  -0.000683400,  -0.000680050,  -0.000676505,  -0.000672775,
           -0.000668860,  -0.000664760,  -0.000660475,  -0.000656005,  -0.000651360,  -0.000646535,  -0.000641545,  -0.000636385,
           -0.000631055,  -0.000625565,  -0.000619905,  -0.000614085,  -0.000608110,  -0.000601985,  -0.000595705,  -0.000589295,
           -0.000582760,  -0.000576115,  -0.000569385,  -0.000562585,  -0.000555720,  -0.000548820,  -0.000541885,  -0.000534945;

         // Optimisation - shortened by removing the first 120 coefficients which are 0
         .VAR/DM2 win_480_ld[$aacdec.WIN_480_LD_SIZE] =
            0.000505955,   0.002201985,   0.003593345,   0.005360650,   0.007298785,   0.009379770,   0.011544935,   0.013757705,
            0.015990650,   0.018218690,   0.020426450,   0.022614175,   0.024788100,   0.026952270,   0.029107515,   0.031256070,
            0.033402315,   0.035547910,   0.037690070,   0.039826035,   0.041954285,   0.044075885,   0.046193925,   0.048310815,
            0.050429300,   0.052554460,   0.054690550,   0.056839095,   0.059001775,   0.061182050,   0.063384170,   0.065611920,
            0.067867380,   0.070150530,   0.072461700,   0.074801575,   0.077169140,   0.079561980,   0.081978315,   0.084416550,
            0.086874185,   0.089348395,   0.091836970,   0.094338305,   0.096851840,   0.099377065,   0.101913205,   0.104460275,
            0.107018875,   0.109588805,   0.112169495,   0.114761250,   0.117364955,   0.119980945,   0.122609295,   0.125249650,
            0.127901560,   0.130564710,   0.133238740,   0.135923515,   0.138618925,   0.141324835,   0.144040430,   0.146764160,
            0.149494895,   0.152231895,   0.154971460,   0.157708320,   0.160439710,   0.163163860,   0.165881455,   0.168593205,
            0.171298060,   0.173996730,   0.176694285,   0.179394215,   0.182097520,   0.184803150,   0.187507835,   0.190210335,
            0.192910345,   0.195606380,   0.198296560,   0.200979965,   0.203655775,   0.206321910,   0.208976385,   0.211618350,
            0.214247400,   0.216863765,   0.219467260,   0.222056990,   0.224635585,   0.227209410,   0.229780955,   0.232350835,
            0.234915080,   0.237468180,   0.240009135,   0.242537400,   0.245051200,   0.247548905,   0.250029930,   0.252495185,
            0.254948950,   0.257393540,   0.259829025,   0.262254875,   0.264669775,   0.267073340,   0.269465565,   0.271845890,
            0.274213655,   0.276568785,   0.278911295,   0.281241265,   0.283558810,   0.285864095,   0.288157340,   0.290438805,
            0.293599880,   0.295865320,   0.298118220,   0.300358595,   0.302586470,   0.304801860,   0.307004790,   0.309195280,
            0.311373350,   0.313539025,   0.315692375,   0.317833500,   0.319962500,   0.322079475,   0.324184465,   0.326277495,
            0.328358575,   0.330427740,   0.332485025,   0.334530470,   0.336564120,   0.338585995,   0.340596095,   0.342594410,
            0.344580935,   0.346555645,   0.348518490,   0.350469420,   0.352408395,   0.354335355,   0.356250235,   0.358152980,
            0.360043525,   0.361921800,   0.363787745,   0.365641280,   0.367482315,   0.369310705,   0.371126315,   0.372928995,
            0.374718650,   0.376495195,   0.378258555,   0.380008645,   0.381745310,   0.383468350,   0.385177580,   0.386872820,
            0.388553950,   0.390220845,   0.391873390,   0.393511455,   0.395134895,   0.396743575,   0.398337355,   0.399916075,
            0.401479570,   0.403027680,   0.404560235,   0.406077085,   0.407578080,   0.409063080,   0.410531945,   0.411984575,
            0.413420880,   0.414840770,   0.416244150,   0.417630930,   0.419001020,   0.420354330,   0.421690780,   0.423010290,
            0.424312780,   0.425598180,   0.426866460,   0.428117615,   0.429351630,   0.430568505,   0.431768245,   0.432950865,
            0.434116375,   0.435264840,   0.436396375,   0.437511100,   0.438609145,   0.439690650,   0.440755785,   0.441804700,
            0.442837585,   0.443854770,   0.444856640,   0.445843580,   0.446815995,   0.447774280,   0.448718855,   0.449650125,
            0.450568700,   0.451475430,   0.452371200,   0.453256900,   0.454133420,   0.455001675,   0.455862575,   0.456717080,
            0.457566380,   0.458411785,   0.459254620,   0.460095850,   0.460935645,   0.461773890,   0.462610580,   0.463442985,
            0.464264800,   0.465069305,   0.465849485,   0.466595570,   0.467292510,   0.467938130,   0.468471380,   0.469127810,
            0.469411110,   0.469553900,   0.469720915,   0.469907485,   0.470107170,   0.470313145,   0.470518570,   0.470720420,
            0.470920210,   0.471119830,   0.471321030,   0.471524295,   0.471729155,   0.471935165,   0.472141950,   0.472349475,
            0.472557860,   0.472767205,   0.472977600,   0.473189080,   0.473401675,   0.473615400,   0.473830270,   0.474046265,
            0.474263370,   0.474481570,   0.474700890,   0.474921380,   0.475143090,   0.475366065,   0.475590280,   0.475815695,
            0.476042255,   0.476269960,   0.476498850,   0.476728995,   0.476960460,   0.477193265,   0.477427360,   0.477662695,
            0.477899235,   0.478136985,   0.478376005,   0.478616365,   0.478858090,   0.479101160,   0.479345515,   0.479591090,
            0.479837865,   0.480085860,   0.480335130,   0.480585720,   0.480837630,   0.481090785,   0.481345130,   0.481600595,
            0.481857185,   0.482114940,   0.482373910,   0.482634120,   0.482895530,   0.483158070,   0.483421670,   0.483686285,
            0.483951950,   0.484218700,   0.484486575,   0.484755560,   0.485025595,   0.485296590,   0.485568485,   0.485841265,
            0.486114970,   0.486389640,   0.486665290,   0.486941875,   0.487219315,   0.487497525,   0.487776460,   0.488056150,
            0.488336630,   0.488617945,   0.488900080,   0.489182955,   0.489466500,   0.489750635,   0.490035355,   0.490320695,
            0.490606710,   0.490893420,   0.491180780,   0.491468715,   0.491757140,   0.492046025,   0.492335390,   0.492625280,
            0.492915730,   0.493206740,   0.493498250,   0.493790185,   0.494082485,   0.494375150,   0.494668235,   0.494961780,
            0.495255815,   0.495550310,   0.495845190,   0.496140395,   0.496435885,   0.496731705,   0.497027905,   0.497324535,
            0.497621600,   0.497919060,   0.498216875,   0.498514985,   0.498813355,   0.499111930,   0.499410670,   0.499709515,
            0.500290655,   0.500590030,   0.500889650,   0.501189465,   0.501489435,   0.501789510,   0.502089635,   0.502389770,
            0.502689860,   0.502989865,   0.503289795,   0.503589700,   0.503889630,   0.504189625,   0.504489645,   0.504789630,
            0.505089505,   0.505389235,   0.505688845,   0.505988390,   0.506287910,   0.506587410,   0.506886825,   0.507186085,
            0.507485125,   0.507783930,   0.508082550,   0.508381025,   0.508679380,   0.508977570,   0.509275515,   0.509573135,
            0.509870380,   0.510167275,   0.510463860,   0.510760185,   0.511056235,   0.511351935,   0.511647195,   0.511941935,
            0.512236145,   0.512529860,   0.512823120,   0.513115950,   0.513408300,   0.513700085,   0.513991210,   0.514281630,
            0.514571360,   0.514860435,   0.515148890,   0.515436720,   0.515723840,   0.516010175,   0.516295635,   0.516580210,
            0.516863940,   0.517146865,   0.517429005,   0.517710320,   0.517990730,   0.518270150,   0.518548540,   0.518825925,
            0.519102350,   0.519377855,   0.519652440,   0.519926030,   0.520198560,   0.520469945,   0.520740185,   0.521009325,
            0.521277405,   0.521544465,   0.521810465,   0.522075340,   0.522339015,   0.522601460,   0.522862710,   0.523122830,
            0.523381880,   0.523639870,   0.523896750,   0.524152465,   0.524406955,   0.524660240,   0.524912385,   0.525163465,
            0.525413525,   0.525662550,   0.525910490,   0.526157285,   0.526402920,   0.526647425,   0.526890855,   0.527133270,
            0.527374685,   0.527615090,   0.527854460,   0.528092770,   0.528330025,   0.528566255,   0.528801485,   0.529035745,
            0.529269140,   0.529501775,   0.529733780,   0.529965120,   0.530195375,   0.530424030,   0.530650555,   0.530875495,
            0.531100820,   0.531328660,   0.531560730,   0.531793630,   0.532019620,   0.532230930,   0.532420240,   0.532582200,
            0.532639320,   0.532490385,   0.532350980,   0.532128715,   0.531860455,   0.531557320,   0.531233110,   0.530896385,
            0.530554040,   0.530212275,   0.529872475,   0.529531030,   0.529183530,   0.528826215,   0.528457350,   0.528075890,
            0.527680345,   0.527270760,   0.526850150,   0.526422225,   0.525990470,   0.525557165,   0.525123170,   0.524689295,
            0.524256225,   0.523823070,   0.523387930,   0.522949275,   0.522505230,   0.522052500,   0.521587085,   0.521105050,
            0.520603245,   0.520080060,   0.519534255,   0.518964470,   0.518370450,   0.517753245,   0.517114000,   0.516453845,
            0.515774720,   0.515079170,   0.514369690,   0.513648560,   0.512917350,   0.512177315,   0.511429760,   0.510675570,
            0.509914870,   0.509147600,   0.508373760,   0.507592670,   0.506802795,   0.506002550,   0.505190380,   0.504364980,
            0.503525225,   0.502669995,   0.501798090,   0.500908065,   0.499998365,   0.499067385,   0.498113965,   0.497137855,
            0.496139070,   0.495117505,   0.494075640,   0.493019285,   0.491954490,   0.490887065,   0.489820755,   0.488757640,
            0.487699995,   0.486648755,   0.485599665,   0.484545895,   0.483480760,   0.482399120,   0.481299200,   0.480180140,
            0.479040900,   0.477881475,   0.476703110,   0.475507180,   0.474295150,   0.473070045,   0.471836160,   0.470597775,
            0.469358980,   0.468123150,   0.466893180,   0.465672325,   0.464460380,   0.463249870,   0.462031275,   0.460795205,
            0.459537055,   0.458258555,   0.456962125,   0.455650280,   0.454327355,   0.452999190,   0.451671750,   0.450349670,
            0.449032175,   0.447715660,   0.446396675,   0.445072480,   0.443742015,   0.442404725,   0.441059985,   0.439707790,
            0.438348970,   0.436984455,   0.435615150,   0.434241970,   0.432865820,   0.431487615,   0.430108245,   0.428728625,
            0.427371710,   0.425968280,   0.424557275,   0.423139845,   0.421717120,   0.420290230,   0.418860285,   0.417428400,
            0.415995670,   0.414563105,   0.413130715,   0.411697645,   0.410263095,   0.408825735,   0.407382165,   0.405927965,
            0.404458505,   0.402972260,   0.401474425,   0.399972155,   0.398472425,   0.396980830,   0.395501100,   0.394036745,
            0.392590615,   0.391157110,   0.389723545,   0.388277035,   0.386806845,   0.385311405,   0.383794030,   0.382257530,
            0.380705725,   0.379144300,   0.377579460,   0.376017395,   0.374462805,   0.372918410,   0.371386710,   0.369870040,
            0.368368770,   0.366881550,   0.365407220,   0.363943080,   0.362480350,   0.361007130,   0.359511415,   0.357984950,
            0.356427705,   0.354842135,   0.353230320,   0.351597945,   0.349955385,   0.348313570,   0.346682960,   0.345068710,
            0.343471510,   0.341892100,   0.340330715,   0.338785785,   0.337254755,   0.335735150,   0.334224395,   0.332719745,
            0.331218385,   0.329717525,   0.328213770,   0.326702955,   0.325180800,   0.323643150,   0.322087200,   0.320511340,
            0.318913855,   0.317293785,   0.315653140,   0.313995545,   0.312324395,   0.310644080,   0.308961015,   0.307282190,
            0.305614575,   0.303964010,   0.302334855,   0.300731285,   0.299157300,   0.297614380,   0.296101875,   0.294619295,
            0.293164680,   0.291730320,   0.290305390,   0.288879370,   0.287441230,   0.285978950,   0.284480390,   0.282933185,
            0.281332970,   0.279685930,   0.277999490,   0.276281495,   0.274545920,   0.272811880,   0.271098710,   0.269423640,
            0.267795235,   0.266217265,   0.264694470,   0.263225260,   0.261794790,   0.260384310,   0.258975400,   0.257553805,
            0.256110895,   0.254638665,   0.253129720,   0.251585365,   0.250013835,   0.248425105,   0.246820580,   0.245243450,
            0.243630640,   0.242024445,   0.240454375,   0.238917410,   0.237407820,   0.235920120,   0.234446955,   0.232979180,
            0.231508055,   0.230025445,   0.228529620,   0.227024110,   0.225512235,   0.223997715,   0.222485690,   0.220981985,
            0.219492735,   0.218020525,   0.216560285,   0.215104710,   0.213646685,   0.212181360,   0.210706940,   0.209222000,
            0.207725405,   0.206220070,   0.204712320,   0.203208580,   0.201714370,   0.200231460,   0.198759615,   0.197298790,
            0.195848460,   0.194407175,   0.192973215,   0.191544900,   0.190120730,   0.188699480,   0.187279930,   0.185860935,
            0.184442315,   0.183024685,   0.181608675,   0.180194835,   0.178783340,   0.177374160,   0.175967275,   0.174562710,
            0.173160645,   0.171761290,   0.170364870,   0.168971615,   0.167581770,   0.166195570,   0.164813240,   0.163434835,
            0.162060210,   0.160689595,   0.159320220,   0.157941865,   0.156549545,   0.155143155,   0.153727640,   0.152313390,
            0.150903280,   0.149497120,   0.148095410,   0.146698585,   0.145306665,   0.143919675,   0.142537815,   0.141161330,
            0.139790335,   0.138424920,   0.137065085,   0.135710785,   0.134361980,   0.133018685,   0.131681055,   0.130349275,
            0.129023500,   0.127704150,   0.126391645,   0.125086055,   0.123787255,   0.122493565,   0.121203700,   0.119917750,
            0.118636000,   0.117359330,   0.116088120,   0.114822290,   0.113561730,   0.112306290,   0.111056010,   0.109810985,
            0.108571450,   0.107337610,   0.106109385,   0.104886615,   0.103668465,   0.102454300,   0.101244115,   0.100038075,
            0.098836790,   0.097640455,   0.096448905,   0.095261735,   0.094078305,   0.092898465,   0.091722205,   0.090550050,
            0.089382975,   0.088221720,   0.087067000,   0.085919525,   0.084780015,   0.083649180,   0.082527735,   0.081416390,
            0.079953900,   0.078880105,   0.077816625,   0.076762785,   0.075717920,   0.074681350,   0.073652405,   0.072630405,
            0.071614685,   0.070604590,   0.069599885,   0.068600690,   0.067607110,   0.066619260,   0.065637225,   0.064661080,
            0.063690905,   0.062726790,   0.061768865,   0.060817285,   0.059872180,   0.058933650,   0.058001735,   0.057076465,
            0.056157865,   0.055246005,   0.054340980,   0.053442890,   0.052551810,   0.051667755,   0.050790715,   0.049920665,
            0.049057620,   0.048201635,   0.047352780,   0.046511140,   0.045676735,   0.044849535,   0.044029515,   0.043216630,
            0.042410915,   0.041612430,   0.040821245,   0.040037405,   0.039260895,   0.038491675,   0.037729690,   0.036974920,
            0.036227410,   0.035487220,   0.034754415,   0.034029000,   0.033310935,   0.032600155,   0.031896620,   0.031200325,
            0.030511330,   0.029829680,   0.029155420,   0.028488505,   0.027828875,   0.027176450,   0.026531195,   0.025893140,
            0.025262320,   0.024638790,   0.024022550,   0.023413545,   0.022811720,   0.022217025,   0.021629465,   0.021049110,
            0.020476040,   0.019910295,   0.019351855,   0.018800655,   0.018256625,   0.017719720,   0.017189935,   0.016667270,
            0.016151740,   0.015643265,   0.015141660,   0.014646730,   0.014158290,   0.013676260,   0.013200635,   0.012731415,
            0.012268625,   0.011812355,   0.011362735,   0.010919900,   0.010484050,   0.010055540,   0.009634785,   0.009222195,
            0.008817825,   0.008421240,   0.008031970,   0.007649545,   0.007273630,   0.006904010,   0.006540460,   0.006182845,
            0.005831365,   0.005486405,   0.005148355,   0.004817395,   0.004493230,   0.004175445,   0.003863625,   0.003557605,
            0.003257565,   0.002963705,   0.002676245,   0.002395445,   0.002121640,   0.001855205,   0.001596355,   0.001344735,
            0.001099640,   0.000860420,   0.000626355,   0.000396555,   0.000170115,  -0.000053930,  -0.000275720,  -0.000494325,
           -0.000708705,  -0.000917785,  -0.001120050,  -0.001313625,  -0.001496570,  -0.001667375,  -0.001826250,  -0.001974335,
           -0.002112665,  -0.002242640,  -0.002366390,  -0.002486260,  -0.002604580,  -0.002722920,  -0.002841800,  -0.002961630,
           -0.003082735,  -0.003204305,  -0.003324570,  -0.003441770,  -0.003554225,  -0.003660680,  -0.003760110,  -0.003851445,
           -0.003933945,  -0.004007605,  -0.004072630,  -0.004129195,  -0.004177815,  -0.004219410,  -0.004254980,  -0.004285485,
           -0.004311800,  -0.004334715,  -0.004355020,  -0.004373440,  -0.004390455,  -0.004406385,  -0.004421600,  -0.004436240,
           -0.004450010,  -0.004462470,  -0.004473205,  -0.004481775,  -0.004487705,  -0.004490520,  -0.004489740,  -0.004484950,
           -0.004475745,  -0.004461730,  -0.004442595,  -0.004418350,  -0.004389195,  -0.004355290,  -0.004316940,  -0.004274680,
           -0.004229130,  -0.004180895,  -0.004130620,  -0.004079035,  -0.004026860,  -0.003974765,  -0.003922860,  -0.003870780,
           -0.003818170,  -0.003764645,  -0.003709705,  -0.003652780,  -0.003593320,  -0.003530920,  -0.003465535,  -0.003397215,
           -0.003326000,  -0.003252140,  -0.003176150,  -0.003098590,  -0.003019975,  -0.002940665,  -0.002860845,  -0.002780715,
           -0.002700425,  -0.002619940,  -0.002539140,  -0.002457910,  -0.002376100,  -0.002293465,  -0.002209765,  -0.002124750,
           -0.002038405,  -0.001951020,  -0.001862905,  -0.001774370,  -0.001685575,  -0.001596590,  -0.001507470,  -0.001418260,
           -0.001328985,  -0.001239670,  -0.001150330,  -0.001060985,  -0.000971655,  -0.000882355,  -0.000793100,  -0.000703935,
           -0.000614945,  -0.000526220,  -0.000437835,  -0.000349880,  -0.000262435,  -0.000175575,  -0.000089375,  -0.000003910,
            0.000003895,   0.000088505,   0.000172760,   0.000256565,   0.000339830,   0.000422460,   0.000504365,   0.000585465,
            0.000665665,   0.000744890,   0.000823055,   0.000900115,   0.000976055,   0.001050860,   0.001124490,   0.001196915,
            0.001268090,   0.001337965,   0.001406530,   0.001473780,   0.001539710,   0.001604320,   0.001667510,   0.001729080,
            0.001788810,   0.001846485,   0.001902070,   0.001955700,   0.002007495,   0.002057620,   0.002106210,   0.002153390,
            0.002199295,   0.002243995,   0.002287435,   0.002329540,   0.002370225,   0.002409285,   0.002446385,   0.002481175,
            0.002513330,   0.002542730,   0.002569385,   0.002593310,   0.002614520,   0.002633240,   0.002649780,   0.002664475,
            0.002677660,   0.002689645,   0.002700705,   0.002711140,   0.002720980,   0.002729905,   0.002737575,   0.002743630,
            0.002747710,   0.002749495,   0.002748660,   0.002744930,   0.002738165,   0.002728320,   0.002715335,   0.002699245,
            0.002680305,   0.002658785,   0.002634965,   0.002609110,   0.002581500,   0.002552425,   0.002522160,   0.002490970,
            0.002459110,   0.002426820,   0.002394310,   0.002361545,   0.002328375,   0.002294695,   0.002260335,   0.002225015,
            0.002188440,   0.002150315,   0.002110310,   0.002068045,   0.002023160,   0.001975300,   0.001924315,   0.001870220,
            0.001813000,   0.001752700,   0.001689670,   0.001624425,   0.001557430,   0.001489245,   0.001420610,   0.001352290,
            0.001285065,   0.001219335,   0.001155025,   0.001091995,   0.001030115,   0.000968830,   0.000907300,   0.000844690,
            0.000780250,   0.000713505,   0.000644150,   0.000571825,   0.000496485,   0.000418760,   0.000339420,   0.000259225,
            0.000178800,   0.000098600,   0.000019065,  -0.000059425,  -0.000136875,  -0.000213590,  -0.000289875,  -0.000366020,
           -0.000442265,  -0.000518835,  -0.000595960,  -0.000673735,  -0.000752055,  -0.000830755,  -0.000909660,  -0.000988615,
           -0.001067465,  -0.001146050,  -0.001224245,  -0.001302075,  -0.001379640,  -0.001457050,  -0.001534395,  -0.001611660,
           -0.001688795,  -0.001765725,  -0.001842350,  -0.001918610,  -0.001994460,  -0.002069860,  -0.002144835,  -0.002219445,
           -0.002293745,  -0.002367855,  -0.002441830,  -0.002515685,  -0.002589435,  -0.002663050,  -0.002736510,  -0.002809825,
           -0.002882990,  -0.002955995,  -0.003028830,  -0.003101500,  -0.003174005,  -0.003246365,  -0.003318635,  -0.003390850,
           -0.003463085,  -0.003535420,  -0.003607915,  -0.003680645,  -0.003753675,  -0.003827075,  -0.003900920,  -0.003975295,
           -0.004050290,  -0.004125975,  -0.004202435,  -0.004279750,  -0.004358035,  -0.004437400,  -0.004517980,  -0.004599890,
           -0.004683250,  -0.004768175,  -0.004854655,  -0.004942105,  -0.005029580,  -0.005116040,  -0.005200650,  -0.005283135,
           -0.005363390,  -0.005441295,  -0.005516740,  -0.005589665,  -0.005660020,  -0.005727760,  -0.005792865,  -0.005855325,
           -0.005915125,  -0.005972270,  -0.006026760,  -0.006078610,  -0.006127860,  -0.006174555,  -0.006218745,  -0.006260510,
           -0.006299925,  -0.006337095,  -0.006372185,  -0.006405390,  -0.006436895,  -0.006466750,  -0.006494860,  -0.006521120,
           -0.006545430,  -0.006567780,  -0.006588220,  -0.006606785,  -0.006623535,  -0.006638485,  -0.006651670,  -0.006663110,
           -0.006672850,  -0.006680970,  -0.006687550,  -0.006692690,  -0.006696380,  -0.006698540,  -0.006699080,  -0.006697920,
           -0.006695070,  -0.006690580,  -0.006684515,  -0.006676910,  -0.006667725,  -0.006656905,  -0.006644380,  -0.006630165,
           -0.006614400,  -0.006597285,  -0.006579030,  -0.006559840,  -0.006539935,  -0.006519530,  -0.006498845,  -0.006478115,
           -0.006541035,  -0.006520765,  -0.006499010,  -0.006475775,  -0.006451075,  -0.006424900,  -0.006397250,  -0.006368125,
           -0.006337505,  -0.006305385,  -0.006271735,  -0.006236530,  -0.006199750,  -0.006161385,  -0.006121520,  -0.006080275,
           -0.006037770,  -0.005994065,  -0.005949145,  -0.005902950,  -0.005855450,  -0.005806675,  -0.005756760,  -0.005705835,
           -0.005654035,  -0.005601445,  -0.005548130,  -0.005494150,  -0.005439580,  -0.005384490,  -0.005328965,  -0.005273090,
           -0.005216900,  -0.005160340,  -0.005103350,  -0.005045855,  -0.004987925,  -0.004929795,  -0.004871690,  -0.004813825,
           -0.004756365,  -0.004699440,  -0.004643170,  -0.004587670,  -0.004533020,  -0.004479300,  -0.004426565,  -0.004374885,
           -0.004324310,  -0.004274895,  -0.004226685,  -0.004179695,  -0.004133925,  -0.004089360,  -0.004045975,  -0.004003725,
           -0.003962530,  -0.003922345,  -0.003882940,  -0.003843475,  -0.003802840,  -0.003760020,  -0.003714375,  -0.003665930,
           -0.003614880,  -0.003561395,  -0.003505650,  -0.003447795,  -0.003387975,  -0.003326345,  -0.003263050,  -0.003198245,
           -0.003132085,  -0.003064715,  -0.002996260,  -0.002926840,  -0.002856575,  -0.002785575,  -0.002713960,  -0.002641835,
           -0.002569320,  -0.002496505,  -0.002423465,  -0.002350270,  -0.002276975,  -0.002203665,  -0.002130430,  -0.002057355,
           -0.001984520,  -0.001912020,  -0.001839955,  -0.001768420,  -0.001697510,  -0.001627360,  -0.001558090,  -0.001489835,
           -0.001422655,  -0.001356535,  -0.001291450,  -0.001227375,  -0.001164300,  -0.001102235,  -0.001041180,  -0.000981165,
           -0.000922250,  -0.000864530,  -0.000808100,  -0.000753015,  -0.000699260,  -0.000646790,  -0.000595560,  -0.000545575,
           -0.000496875,  -0.000449510,  -0.000403525,  -0.000358980,  -0.000315925,  -0.000274430,  -0.000234520,  -0.000196155,
           -0.000159225,  -0.000123640,  -0.000089300,  -0.000056080,  -0.000023855,   0.000007500,   0.000038000,   0.000067505,
            0.000095880,   0.000122975,   0.000148600,   0.000172520,   0.000194510,   0.000214405,   0.000232280,   0.000248310,
            0.000262670,   0.000275570,   0.000287295,   0.000298145,   0.000308420,   0.000318300,   0.000327840,   0.000337085,
            0.000346065,   0.000354675,   0.000362725,   0.000370025,   0.000376415,   0.000381780,   0.000386045,   0.000389140,
            0.000391025,   0.000391750,   0.000391375,   0.000389960,   0.000387600,   0.000384420,   0.000380540,   0.000376090,
            0.000371160,   0.000365850,   0.000360240,   0.000354405,   0.000348400,   0.000342250,   0.000336005,   0.000329670,
            0.000323235,   0.000316675,   0.000309970,   0.000303105,   0.000296055,   0.000288815,   0.000281370,   0.000273715,
            0.000265845,   0.000257765,   0.000249485,   0.000241030,   0.000232435,   0.000223740,   0.000214980,   0.000206205,
            0.000197460,   0.000188795,   0.000180245,   0.000171855,   0.000163660,   0.000155685,   0.000147935,   0.000140395,
            0.000133060,   0.000125915,   0.000118945,   0.000112140,   0.000105485,   0.000098985,   0.000092650,   0.000086485,
            0.000080500,   0.000074710,   0.000069135,   0.000063785,   0.000058680,   0.000053820,   0.000049205,   0.000044845,
            0.000040725,   0.000036845,   0.000033205,   0.000029790,   0.000026600,   0.000023625,   0.000020855,   0.000018295,
            0.000015930,   0.000013760,   0.000011785,   0.000009995,   0.000008395,   0.000006960,   0.000005700,   0.000004590,
            0.000003630,   0.000002810,   0.000002120,   0.000001545,   0.000001085,   0.000000715,   0.000000440,   0.000000240,
            NO_UF(0.000000100),  NO_UF(0.000000020),  NO_UF(-0.000000020), NO_UF(-0.000000030), NO_UF(-0.000000020), NO_UF(0.000000010),  NO_UF(0.000000010),  NO_UF(0.000000010),
            NO_UF(0.000000010),  NO_UF(0.000000010),  NO_UF(0.000000010),  NO_UF(-0.000000020), NO_UF(-0.000000025), NO_UF(-0.000000020), NO_UF(0.000000020),  NO_UF(0.000000095),
            0.000000225,   0.000000415,   0.000000670,   0.000001005,   0.000001425,   0.000001935,   0.000002550,   0.000003270,
            0.000004105,   0.000005055,   0.000006135,   0.000007340,   0.000008675,   0.000010150,   0.000011760,   0.000013510,
            0.000015400,   0.000017430,   0.000019590,   0.000021895,   0.000024330,   0.000026910,   0.000029620,   0.000032475,
            0.000035465,   0.000038595,   0.000041865,   0.000045265,   0.000048790,   0.000052440,   0.000056200,   0.000060050,
            0.000063980,   0.000067980,   0.000072030,   0.000076130,   0.000080265,   0.000084430,   0.000088625,   0.000092855,
            0.000097120,   0.000101430,   0.000105780,   0.000110185,   0.000114640,   0.000119125,   0.000123620,   0.000128105,
            0.000132545,   0.000136925,   0.000141205,   0.000145360,   0.000149370,   0.000153215,   0.000156870,   0.000160325,
            0.000163575,   0.000166625,   0.000169475,   0.000172125,   0.000174585,   0.000176870,   0.000178980,   0.000180935,
            0.000182745,   0.000184415,   0.000185970,   0.000187395,   0.000188680,   0.000189815,   0.000190770,   0.000191530,
            0.000192055,   0.000192310,   0.000192265,   0.000191865,   0.000191065,   0.000189825,   0.000188105,   0.000185895,
            0.000183180,   0.000179945,   0.000176220,   0.000172035,   0.000167440,   0.000162485,   0.000157245,   0.000151805,
            0.000146260,   0.000140665,   0.000135015,   0.000129310,   0.000123530,   0.000117620,   0.000111485,   0.000105020,
            0.000098130,   0.000090750,   0.000082830,   0.000074320,   0.000065205,   0.000055560,   0.000045480,   0.000035070,
            0.000024420,   0.000013590,   0.000002650,  -0.000008335,  -0.000019355,  -0.000030450,  -0.000041655,  -0.000053000,
           -0.000064510,  -0.000076220,  -0.000088155,  -0.000100325,  -0.000112705,  -0.000125260,  -0.000137970,  -0.000150795,
           -0.000163700,  -0.000176660,  -0.000189640,  -0.000202635,  -0.000215655,  -0.000228705,  -0.000241785,  -0.000254890,
           -0.000267995,  -0.000281085,  -0.000294135,  -0.000307115,  -0.000320010,  -0.000332810,  -0.000345500,  -0.000358080,
           -0.000370550,  -0.000382920,  -0.000395180,  -0.000407325,  -0.000419345,  -0.000431225,  -0.000442950,  -0.000454505,
           -0.000465880,  -0.000477065,  -0.000488040,  -0.000498790,  -0.000509310,  -0.000519590,  -0.000529620,  -0.000539395,
           -0.000548915,  -0.000558175,  -0.000567170,  -0.000575905,  -0.000584365,  -0.000592550,  -0.000600455,  -0.000608075,
           -0.000615410,  -0.000622450,  -0.000629190,  -0.000635625,  -0.000641750,  -0.000647555,  -0.000653050,  -0.000658215,
           -0.000663050,  -0.000667545,  -0.000671670,  -0.000675345,  -0.000678555,  -0.000681360,  -0.000683840,  -0.000686125,
           -0.000688245,  -0.000690210,  -0.000692020,  -0.000693685,  -0.000695205,  -0.000696585,  -0.000697825,  -0.000698925,
           -0.000699880,  -0.000700685,  -0.000701335,  -0.000701830,  -0.000702160,  -0.000702320,  -0.000702305,  -0.000702115,
           -0.000701735,  -0.000701175,  -0.000700420,  -0.000699470,  -0.000698320,  -0.000696940,  -0.000695325,  -0.000693470,
           -0.000691390,  -0.000689090,  -0.000686585,  -0.000683860,  -0.000680925,  -0.000677780,  -0.000674420,  -0.000670850,
           -0.000667075,  -0.000663095,  -0.000658920,  -0.000654540,  -0.000649955,  -0.000645155,  -0.000640155,  -0.000634950,
           -0.000629560,  -0.000623985,  -0.000618225,  -0.000612290,  -0.000606165,  -0.000599860,  -0.000593380,  -0.000586735,
           -0.000579940,  -0.000573025,  -0.000566000,  -0.000558890,  -0.000551715,  -0.000544490,  -0.000537240,  -0.000529975;

         // First quadrant of sin(2*k*pi/N), k = [0..N-1], N = 240
         // Reading it in different directions (and changing the sign) we can
         // generate all four quadrants of sin(2*k*pi/N) and cos(2*k*pi/N).
         //    |===========================|===========|==========|==========|==========|
         //    |Quadrant                   |Q1         |Q2        |Q3        |Q4        |
         //    |===========================|===========|==========|==========|==========|
         //    |sin        direction/sign  |  -->/+    |  <--/+   |  -->/-   |  <--/-   |
         //    |===========================|===========|==========|==========|==========|
         //    |cos        direction/sign  |  <--/+    |  -->/-   |  <--/-   |  -->/+   |
         //    |===========================|===========|==========|==========|==========|
         .VAR/DM twiddle_tab[$aacdec.TWIDDLE_TABLE_SIZE] =
            0.000000000000000,  0.026176948307873,  0.052335956242944,  0.078459095727845,
            0.104528463267653,  0.130526192220052,  0.156434465040231,  0.182235525492147,
            0.207911690817759,  0.233445363855905,  0.258819045102521,  0.284015344703923,
            0.309016994374947,  0.333806859233771,  0.358367949545300,  0.382683432365090,
            0.406736643075800,  0.430511096808295,  0.453990499739547,  0.477158760259608,
            0.500000000000000,  0.522498564715949,  0.544639035015027,  0.566406236924833,
            0.587785252292473,  0.608761429008721,  0.629320391049838,  0.649448048330184,
            0.669130606358858,  0.688354575693754,  0.707106781186547,  0.725374371012288,
            0.743144825477394,  0.760405965600031,  0.777145961456971,  0.793353340291235,
            0.809016994374947,  0.824126188622016,  0.838670567945424,  0.852640164354092,
            0.866025403784439,  0.878817112661965,  0.891006524188368,  0.902585284349861,
            0.913545457642601,  0.923879532511287,  0.933580426497202,  0.942641491092178,
            0.951056516295154,  0.958819734868193,  0.965925826289068,  0.972369920397677,
            0.978147600733806,  0.983254907563955,  0.987688340595138,  0.991444861373810,
            0.994521895368273,  0.996917333733128,  0.998629534754574,  0.999657324975557,
            0.999999999999999;

      #endif //AACDEC_ELD_ADDITIONS

   // overlap add static variables
   #ifdef AAC_LOWRAM
      #ifdef AACDEC_ELD_ADDITIONS
         .VAR/DM overlap_add_left[1536];
         .VAR/DM overlap_add_right[1536];
      #else
     #ifndef AAC_USE_EXTERNAL_MEMORY
         .VAR/DM overlap_add_left[576];
         .VAR/DM overlap_add_right[576];
      #else 
         .VAR overlap_add_left_ptr;
         .VAR overlap_add_right_ptr;
     #endif //AAC_USE_EXTERNAL_MEMORY
      #endif // AACDEC_ELD_ADDITIONS
   #else
      #ifdef AACDEC_ELD_ADDITIONS
         .VAR/DM2 overlap_add_left[1536];
         .VAR/DM2 overlap_add_right[1536];
      #else
         
     #ifndef AAC_USE_EXTERNAL_MEMORY
         .VAR/DM2 overlap_add_left[576];
         .VAR/DM2 overlap_add_right[576];
     #else 
         .VAR overlap_add_left_ptr;
         .VAR overlap_add_right_ptr;
     #endif //AAC_USE_EXTERNAL_MEMORY
      #endif // AACDEC_ELD_ADDITIONS
   #endif


   // spec must be scaled up by factor 2 either in tns_encdec or in overlap_add.
   // spec_blksigndet holds the amount of headroom in the spec variable
   // (calculated using BLKSIGNDET) and whether the scaling has been done yet.
   // spec_blksigndet = [blksigndet, upscaled]
   .VAR left_spec_blksigndet[2] = 0,0;
   .VAR right_spec_blksigndet[2] = 0,0;
   .VAR current_spec_blksigndet_ptr;


   // set links to supported file types
   .VAR read_frame_func_table[] =
   #ifdef AACDEC_MP4_FILE_TYPE_SUPPORTED
       &$aacdec.mp4_read_frame,
   #else
       &$error,
   #endif
   #ifdef AACDEC_ADTS_FILE_TYPE_SUPPORTED
       &$aacdec.adts_read_frame,
   #else
       &$error,
   #endif
   #ifdef AACDEC_LATM_FILE_TYPE_SUPPORTED
       &$aacdec.latm_read_frame;
   #else
       &$error;
   #endif

   // flag shows whether only one byte of the last word in the input buffer is valid
   .VAR write_bytepos;

.ENDMODULE;