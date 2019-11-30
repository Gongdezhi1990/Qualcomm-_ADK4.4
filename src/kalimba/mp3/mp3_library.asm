// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "mp3_library.h"
#include "profiler.h"

#if !defined(KALASM3)
// These will map the PM_DYNAMIC_x and _SCRATCH segments to "normal" groups
// link scratch memory segments to DMxGroups (for lib build only)
//          Name                 CIRCULAR?   Link Order  Group list
.DEFSEGMENT DM_SCRATCH                       5           DM1Group  DM2Group;
.DEFSEGMENT DM1_SCRATCH                      3           DM1Group;
.DEFSEGMENT DM2_SCRATCH                      3           DM2Group;
.DEFSEGMENT DMCIRC_SCRATCH       CIRCULAR    4           DM1Group  DM2Group;
.DEFSEGMENT DM1CIRC_SCRATCH      CIRCULAR    2           DM1Group;
.DEFSEGMENT DM2CIRC_SCRATCH      CIRCULAR    2           DM2Group;

// link dynamic program memory segments to CODEGroup (for lib build only)
//          Name                             Link Order  Group list
.DEFSEGMENT PM_DYNAMIC_1                     4           CODEGroup;
.DEFSEGMENT PM_DYNAMIC_2                     4           CODEGroup;
.DEFSEGMENT PM_DYNAMIC_3                     4           CODEGroup;
.DEFSEGMENT PM_DYNAMIC_4                     4           CODEGroup;
#ifndef MP3DEC_USE_FLASH_FOR_CODE
.DEFSEGMENT PM_DYNAMIC_5                     4           CODEGroup;
.DEFSEGMENT PM_DYNAMIC_6                     4           CODEGroup;
.DEFSEGMENT PM_DYNAMIC_7                     4           CODEGroup;
.DEFSEGMENT PM_DYNAMIC_8                     4           CODEGroup;
.DEFSEGMENT PM_DYNAMIC_9                     4           CODEGroup;
#else
.DEFSEGMENT PM_DYNAMIC_5                     4           CODEFLASHGroup;
.DEFSEGMENT PM_DYNAMIC_6                     4           CODEFLASHGroup;
.DEFSEGMENT PM_DYNAMIC_7                     4           CODEFLASHGroup;
.DEFSEGMENT PM_DYNAMIC_8                     4           CODEFLASHGroup;
.DEFSEGMENT PM_DYNAMIC_9                     4           CODEFLASHGroup;
#endif

// This segment is not overlayed
.DEFSEGMENT DM_STATIC                        5           DM1Group  DM2Group;

// Modules
#define MP3DEC_HUFF_GETVALREGION_PM                 PM_DYNAMIC_1
#define MP3DEC_SYNTHESIS_FILTERBANK_PM              PM_DYNAMIC_1
#define MP3DEC_COMPENSATION_FOR_FREQ_INVERSION_PM   PM_DYNAMIC_2
#define MP3DEC_GETBITRESBITS_PM                     PM_DYNAMIC_2
#define MP3DEC_GETBITS_PM                           PM_DYNAMIC_2
#define MP3DEC_READ_HUFFMAN_PM                      PM_DYNAMIC_2
#define MP3DEC_REQUANTISE_SUBBAND_PM                PM_DYNAMIC_2
#define MP3DEC_SUBBAND_RECONSTRUCTION_PM            PM_DYNAMIC_2
#define MP3DEC_ALIAS_REDUCTION_PM                   PM_DYNAMIC_3
#define MP3DEC_FILLBITRES_PM                        PM_DYNAMIC_3
#define MP3DEC_HUFF_GETVALQUAD_PM                   PM_DYNAMIC_3
#define MP3DEC_READ_SCALEFACTORS_PM                 PM_DYNAMIC_3
#define MP3DEC_IMDCT_WINDOWING_OVERLAPADD_PM        PM_DYNAMIC_4
#define MP3DEC_FRAME_DECODE_PM                      PM_DYNAMIC_5
#define MP3DEC_FAST_MS_DECODE_PM                    PM_DYNAMIC_6
#define MP3DEC_READ_SIDEINFO_PM                     PM_DYNAMIC_6
#define MP3DEC_REORDER_SPECTRUM_PM                  PM_DYNAMIC_7
#define MP3DEC_READ_HEADER_PM                       PM_DYNAMIC_8
#define MP3DEC_CRC_CHECK_PM                         PM_DYNAMIC_9
#define MP3DEC_GETBITS_AND_CRC_PM                   PM_DYNAMIC_9
#define MP3DEC_INIT_DECODER_PM                      PM_DYNAMIC_9
#define MP3DEC_JOINTSTEREO_PROCESSING_PM            PM_DYNAMIC_9
#define MP3DEC_INTENSITY_PROCESSOR_PM               PM_DYNAMIC_9
#define MP3DEC_RESET_DECODER_PM                     PM_DYNAMIC_9
#define MP3DEC_SILENCE_DECODER_PM                   PM_DYNAMIC_9
#define MP3DEC_RESTORE_BOUNDARY_SNAPSHOT_PM         PM_DYNAMIC_9
#define MP3DEC_STORE_BOUNDARY_SNAPSHOT_PM           PM_DYNAMIC_9
#define MP3DEC_DEINIT_DECODER_PM                    PM_DYNAMIC_9
#define MP3DEC_SKIP_THROUGH_FILE_PM                 PM_DYNAMIC_9

#define MP3DEC_FF_REW_PM                            PM_DYNAMIC_9
#define MP3DEC_MAIN_PM                              PM_DYNAMIC_9

#endif

// includes
#include "core_library.h"
#include "mp3.h"
#include "global_variables.asm"
#include "init_decoder.asm"
#include "reset_decoder.asm"
#include "silence_decoder.asm"
#include "getbits.asm"
#include "read_header.asm"
#include "crc_check.asm"
#include "read_sideinfo.asm"
#include "fillbitres.asm"
#include "getbitresbits.asm"
#include "read_scalefactors.asm"
#include "read_huffman.asm"
#include "requantise_subband.asm"
#include "subband_reconstruction.asm"
#include "jointstereo_processing.asm"
#include "reorder_spectrum.asm"
#include "alias_reduction.asm"
#include "imdct_windowing_overlapadd.asm"
#include "compensation_for_freq_inversion.asm"
#include "synthesis_filterbank.asm"
#include "frame_decode.asm"
#include "decoder_state.asm"
#include "mp3_ff_rew.asm"
#include "mp3dec_api.asm"
#ifdef BUILD_WITH_C_SUPPORT
   #include "mp3_library_c_stubs.asm"
#endif
