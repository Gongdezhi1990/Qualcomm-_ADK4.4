// *****************************************************************************
// Copyright (c) 2009 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

// *****************************************************************************
// DESCRIPTION
//    Static configuration file that includes tables of function pointers and
//    corresponding data objects
//
//    Build configuration for processing modules shall be handled from within
//    the music_manager_config.h header file
//
// *****************************************************************************
#include "music_example.h"
#include "music_manager_config.h"
#include "audio_proc_library.h"
#include "cbops_library.h"
#include "codec_library.h"
#include "core_library.h"
#include "frame_sync_stream_macros.h"
#include "frame_sync_buffer.h"
#include "user_eq.h"
#include "default_eq_coefs.h"

.CONST $stream_copy.INPUT_PTR_BUFFER_FIELD             0;
.CONST $stream_copy.OUTPUT_PTR_BUFFER_FIELD            1;
.CONST $stream_copy.STRUC_SIZE                         2;

#define MAX_NUM_SPKR_EQ_STAGES     (10)
#define MAX_NUM_USER_EQ_STAGES      (5)
#define MAX_NUM_SPKR_EQ_BANKS       (1)
#define MAX_NUM_USER_EQ_BANKS       (6)

#define MAX_NUM_SPKR_CTRL_PRI_EQ_BANKS      (2)
#define MAX_NUM_SPKR_CTRL_PRI_EQ_STAGES     (7)

#define MAX_NUM_SPKR_CTRL_SEC_EQ_BANKS      (2)
#define MAX_NUM_SPKR_CTRL_SEC_EQ_STAGES     (7)


#if (MAX_NUM_SPKR_EQ_BANKS != 1)
    #error Number of Speaker Eq banks is not 1 - Mulitple bank switching not supported for Speaker Eq
#endif


.MODULE $M.system_config.data;
   .DATASEGMENT DM;

   // Temp Variable to handle disabled modules.
   .VAR  ZeroValue = 0;
   .VAR  OneValue = 1.0;
   .VAR  HalfValue = 0.5;
   .VAR  config;
   .VAR  MinusOne = -1;

   .VAR/DMCONST16  DefaultParameters[] =
   #include "music_manager_defaults.dat"
   ;

// End of ParameterMap
// -----------------------------------------------------------------------------
   // guarantee even length
   .VAR  CurParams[2*ROUND(0.5*$M.MUSIC_MANAGER.PARAMETERS.STRUCT_SIZE)];
// -----------------------------------------------------------------------------
// DATA OBJECTS USED WITH PROCESSING MODULES
//
// This section would be updated if more processing modules with data objects
// were to be added to the system.

// Creating 12dB headroom for processing modules, the headroom will be
// compensated in volume module at the end of processing chain
   .VAR headroom_mant = 0.25; // 2 bits attenuation

#if uses_SPKR_EQ

   .VAR/DM2 spkr_eq_left_dm2[HQ_PEQ_OBJECT_SIZE(MAX_NUM_SPKR_EQ_STAGES)] =
        &stream_map_left_in,                    // PTR_INPUT_DATA_BUFF_FIELD
        &stream_map_left_in,                    // PTR_OUTPUT_DATA_BUFF_FIELD
        MAX_NUM_SPKR_EQ_STAGES,                 // MAX_STAGES_FIELD
        &SpkrEqCoefsA,                          // PARAM_PTR_FIELD
        0 ...;

   .VAR/DM2 spkr_eq_right_dm2[HQ_PEQ_OBJECT_SIZE(MAX_NUM_SPKR_EQ_STAGES)] =
        &stream_map_right_in,                   // PTR_INPUT_DATA_BUFF_FIELD
        &stream_map_right_in,                   // PTR_OUTPUT_DATA_BUFF_FIELD
        MAX_NUM_SPKR_EQ_STAGES,                 // MAX_STAGES_FIELD
        &SpkrEqCoefsA,                          // PARAM_PTR_FIELD
        0 ...;

   // 44.1 kHz coefficients if not using coefficient calculation routines
    .VAR SpkrEqCoefsA[3+6*MAX_NUM_SPKR_EQ_STAGES] =
        $spkrEq.Fs44.NumBands,
        $spkrEq.Fs44.GainExp,
        $spkrEq.Fs44.GainMant,
        $spkrEq.Fs44.Stage1.b2,  $spkrEq.Fs44.Stage1.b1,  $spkrEq.Fs44.Stage1.b0,  $spkrEq.Fs44.Stage1.a2,  $spkrEq.Fs44.Stage1.a1,
        $spkrEq.Fs44.Stage2.b2,  $spkrEq.Fs44.Stage2.b1,  $spkrEq.Fs44.Stage2.b0,  $spkrEq.Fs44.Stage2.a2,  $spkrEq.Fs44.Stage2.a1,
        $spkrEq.Fs44.Stage3.b2,  $spkrEq.Fs44.Stage3.b1,  $spkrEq.Fs44.Stage3.b0,  $spkrEq.Fs44.Stage3.a2,  $spkrEq.Fs44.Stage3.a1,
        $spkrEq.Fs44.Stage4.b2,  $spkrEq.Fs44.Stage4.b1,  $spkrEq.Fs44.Stage4.b0,  $spkrEq.Fs44.Stage4.a2,  $spkrEq.Fs44.Stage4.a1,
        $spkrEq.Fs44.Stage5.b2,  $spkrEq.Fs44.Stage5.b1,  $spkrEq.Fs44.Stage5.b0,  $spkrEq.Fs44.Stage5.a2,  $spkrEq.Fs44.Stage5.a1,
        $spkrEq.Fs44.Stage6.b2,  $spkrEq.Fs44.Stage6.b1,  $spkrEq.Fs44.Stage6.b0,  $spkrEq.Fs44.Stage6.a2,  $spkrEq.Fs44.Stage6.a1,
        $spkrEq.Fs44.Stage7.b2,  $spkrEq.Fs44.Stage7.b1,  $spkrEq.Fs44.Stage7.b0,  $spkrEq.Fs44.Stage7.a2,  $spkrEq.Fs44.Stage7.a1,
        $spkrEq.Fs44.Stage8.b2,  $spkrEq.Fs44.Stage8.b1,  $spkrEq.Fs44.Stage8.b0,  $spkrEq.Fs44.Stage8.a2,  $spkrEq.Fs44.Stage8.a1,
        $spkrEq.Fs44.Stage9.b2,  $spkrEq.Fs44.Stage9.b1,  $spkrEq.Fs44.Stage9.b0,  $spkrEq.Fs44.Stage9.a2,  $spkrEq.Fs44.Stage9.a1,
        $spkrEq.Fs44.Stage10.b2, $spkrEq.Fs44.Stage10.b1, $spkrEq.Fs44.Stage10.b0, $spkrEq.Fs44.Stage10.a2, $spkrEq.Fs44.Stage10.a1,
      $spkrEq.Fs44.Stage1.scale, $spkrEq.Fs44.Stage2.scale, $spkrEq.Fs44.Stage3.scale, $spkrEq.Fs44.Stage4.scale, $spkrEq.Fs44.Stage5.scale,
      $spkrEq.Fs44.Stage6.scale, $spkrEq.Fs44.Stage7.scale, $spkrEq.Fs44.Stage8.scale, $spkrEq.Fs44.Stage9.scale, $spkrEq.Fs44.Stage10.scale;

   // 48 kHz coefficients if not using coefficient calculation routines
    .VAR SpkrEqCoefsB[3+6*MAX_NUM_SPKR_EQ_STAGES] =
        $spkrEq.Fs48.NumBands,
        $spkrEq.Fs48.GainExp,
        $spkrEq.Fs48.GainMant,
        $spkrEq.Fs48.Stage1.b2,  $spkrEq.Fs48.Stage1.b1,  $spkrEq.Fs48.Stage1.b0,  $spkrEq.Fs48.Stage1.a2,  $spkrEq.Fs48.Stage1.a1,
        $spkrEq.Fs48.Stage2.b2,  $spkrEq.Fs48.Stage2.b1,  $spkrEq.Fs48.Stage2.b0,  $spkrEq.Fs48.Stage2.a2,  $spkrEq.Fs48.Stage2.a1,
        $spkrEq.Fs48.Stage3.b2,  $spkrEq.Fs48.Stage3.b1,  $spkrEq.Fs48.Stage3.b0,  $spkrEq.Fs48.Stage3.a2,  $spkrEq.Fs48.Stage3.a1,
        $spkrEq.Fs48.Stage4.b2,  $spkrEq.Fs48.Stage4.b1,  $spkrEq.Fs48.Stage4.b0,  $spkrEq.Fs48.Stage4.a2,  $spkrEq.Fs48.Stage4.a1,
        $spkrEq.Fs48.Stage5.b2,  $spkrEq.Fs48.Stage5.b1,  $spkrEq.Fs48.Stage5.b0,  $spkrEq.Fs48.Stage5.a2,  $spkrEq.Fs48.Stage5.a1,
        $spkrEq.Fs48.Stage6.b2,  $spkrEq.Fs48.Stage6.b1,  $spkrEq.Fs48.Stage6.b0,  $spkrEq.Fs48.Stage6.a2,  $spkrEq.Fs48.Stage6.a1,
        $spkrEq.Fs48.Stage7.b2,  $spkrEq.Fs48.Stage7.b1,  $spkrEq.Fs48.Stage7.b0,  $spkrEq.Fs48.Stage7.a2,  $spkrEq.Fs48.Stage7.a1,
        $spkrEq.Fs48.Stage8.b2,  $spkrEq.Fs48.Stage8.b1,  $spkrEq.Fs48.Stage8.b0,  $spkrEq.Fs48.Stage8.a2,  $spkrEq.Fs48.Stage8.a1,
        $spkrEq.Fs48.Stage9.b2,  $spkrEq.Fs48.Stage9.b1,  $spkrEq.Fs48.Stage9.b0,  $spkrEq.Fs48.Stage9.a2,  $spkrEq.Fs48.Stage9.a1,
        $spkrEq.Fs48.Stage10.b2, $spkrEq.Fs48.Stage10.b1, $spkrEq.Fs48.Stage10.b0, $spkrEq.Fs48.Stage10.a2, $spkrEq.Fs48.Stage10.a1,
      $spkrEq.Fs48.Stage1.scale, $spkrEq.Fs48.Stage2.scale, $spkrEq.Fs48.Stage3.scale, $spkrEq.Fs48.Stage4.scale, $spkrEq.Fs48.Stage5.scale,
      $spkrEq.Fs48.Stage6.scale, $spkrEq.Fs48.Stage7.scale, $spkrEq.Fs48.Stage8.scale, $spkrEq.Fs48.Stage9.scale, $spkrEq.Fs48.Stage10.scale;

    .VAR SpkrEqDefnTable[$user_eq.DEFINITION_TABLE_SIZE] =
        MAX_NUM_SPKR_EQ_BANKS,
        MAX_NUM_SPKR_EQ_STAGES,
        &spkr_eq_left_dm2,
        &spkr_eq_right_dm2,
        &SpkrEqCoefsA,
        &SpkrEqCoefsB;

   // pointer to speaker eq parameters
   // if zero, use the coefficients that are in the code above
   #if USE_PRECALCULATED_SPKR_COEFS
      #ifdef ROM
         #error cannot use precalculated coefficients with ROM part
      #endif
      .var SpkrEqParams = 0;
   #else
        .var SpkrEqParams = &CurParams + $M.MUSIC_MANAGER.PARAMETERS.OFFSET_SPKR_EQ_NUM_BANDS;
   #endif  // USE_PRECALCULATED_SPKR_COEFS

#endif  // uses_SPKR_EQ

#if uses_USER_EQ

    // object for currently running User EQs
   .VAR/DM2 user_eq_left_dm2[HQ_PEQ_OBJECT_SIZE(MAX_NUM_USER_EQ_STAGES)] =
      &stream_map_left_in_user_eq,              // PTR_INPUT_DATA_BUFF_FIELD
      &stream_map_left_in_user_eq,              // PTR_OUTPUT_DATA_BUFF_FIELD
      MAX_NUM_USER_EQ_STAGES,           // MAX_STAGES_FIELD
      &UserEqCoefsA,                    // PARAM_PTR_FIELD
      0 ...;

    .VAR/DM2 user_eq_right_dm2[HQ_PEQ_OBJECT_SIZE(MAX_NUM_USER_EQ_STAGES)] =
      &stream_map_right_in_user_eq,             // PTR_INPUT_DATA_BUFF_FIELD
      &stream_map_right_in_user_eq,             // PTR_OUTPUT_DATA_BUFF_FIELD
      MAX_NUM_USER_EQ_STAGES,           // MAX_STAGES_FIELD
      &UserEqCoefsA,                    // PARAM_PTR_FIELD
      0 ...;

   #if USE_PRECALCULATED_USER_COEFS
        .BLOCK PrecalculatedUserEqCoefficients;
         // coefficients if not using coefficient calculation routines
            .VAR UserEqCoefsA[3+6*MAX_NUM_USER_EQ_STAGES] =             // 44 kHz bank 1
                $userEq.Fs44.Bank1.NumBands,
                $userEq.Fs44.Bank1.GainExp,
                $userEq.Fs44.Bank1.GainMant,
                $userEq.Fs44.Bank1.Stage1.b2,  $userEq.Fs44.Bank1.Stage1.b1,  $userEq.Fs44.Bank1.Stage1.b0,  $userEq.Fs44.Bank1.Stage1.a2,  $userEq.Fs44.Bank1.Stage1.a1,
                $userEq.Fs44.Bank1.Stage2.b2,  $userEq.Fs44.Bank1.Stage2.b1,  $userEq.Fs44.Bank1.Stage2.b0,  $userEq.Fs44.Bank1.Stage2.a2,  $userEq.Fs44.Bank1.Stage2.a1,
                $userEq.Fs44.Bank1.Stage3.b2,  $userEq.Fs44.Bank1.Stage3.b1,  $userEq.Fs44.Bank1.Stage3.b0,  $userEq.Fs44.Bank1.Stage3.a2,  $userEq.Fs44.Bank1.Stage3.a1,
                $userEq.Fs44.Bank1.Stage4.b2,  $userEq.Fs44.Bank1.Stage4.b1,  $userEq.Fs44.Bank1.Stage4.b0,  $userEq.Fs44.Bank1.Stage4.a2,  $userEq.Fs44.Bank1.Stage4.a1,
                $userEq.Fs44.Bank1.Stage5.b2,  $userEq.Fs44.Bank1.Stage5.b1,  $userEq.Fs44.Bank1.Stage5.b0,  $userEq.Fs44.Bank1.Stage5.a2,  $userEq.Fs44.Bank1.Stage5.a1,
                $userEq.Fs44.Bank1.Stage1.scale, $userEq.Fs44.Bank1.Stage2.scale, $userEq.Fs44.Bank1.Stage3.scale, $userEq.Fs44.Bank1.Stage4.scale, $userEq.Fs44.Bank1.Stage5.scale;
            .VAR UserEqCoefsB[3+6*MAX_NUM_USER_EQ_STAGES] =             // 44 kHz bank 2
                $userEq.Fs44.Bank2.NumBands,
                $userEq.Fs44.Bank2.GainExp,
                $userEq.Fs44.Bank2.GainMant,
                $userEq.Fs44.Bank2.Stage1.b2,  $userEq.Fs44.Bank2.Stage1.b1,  $userEq.Fs44.Bank2.Stage1.b0,  $userEq.Fs44.Bank2.Stage1.a2,  $userEq.Fs44.Bank2.Stage1.a1,
                $userEq.Fs44.Bank2.Stage2.b2,  $userEq.Fs44.Bank2.Stage2.b1,  $userEq.Fs44.Bank2.Stage2.b0,  $userEq.Fs44.Bank2.Stage2.a2,  $userEq.Fs44.Bank2.Stage2.a1,
                $userEq.Fs44.Bank2.Stage3.b2,  $userEq.Fs44.Bank2.Stage3.b1,  $userEq.Fs44.Bank2.Stage3.b0,  $userEq.Fs44.Bank2.Stage3.a2,  $userEq.Fs44.Bank2.Stage3.a1,
                $userEq.Fs44.Bank2.Stage4.b2,  $userEq.Fs44.Bank2.Stage4.b1,  $userEq.Fs44.Bank2.Stage4.b0,  $userEq.Fs44.Bank2.Stage4.a2,  $userEq.Fs44.Bank2.Stage4.a1,
                $userEq.Fs44.Bank2.Stage5.b2,  $userEq.Fs44.Bank2.Stage5.b1,  $userEq.Fs44.Bank2.Stage5.b0,  $userEq.Fs44.Bank2.Stage5.a2,  $userEq.Fs44.Bank2.Stage5.a1,
                $userEq.Fs44.Bank2.Stage1.scale, $userEq.Fs44.Bank2.Stage2.scale, $userEq.Fs44.Bank2.Stage3.scale, $userEq.Fs44.Bank2.Stage4.scale, $userEq.Fs44.Bank2.Stage5.scale;
            .VAR UserEqCoefs3[3+6*MAX_NUM_USER_EQ_STAGES] =             // 44 kHz bank 3
                $userEq.Fs44.Bank3.NumBands,
                $userEq.Fs44.Bank3.GainExp,
                $userEq.Fs44.Bank3.GainMant,
                $userEq.Fs44.Bank3.Stage1.b2,  $userEq.Fs44.Bank3.Stage1.b1,  $userEq.Fs44.Bank3.Stage1.b0,  $userEq.Fs44.Bank3.Stage1.a2,  $userEq.Fs44.Bank3.Stage1.a1,
                $userEq.Fs44.Bank3.Stage2.b2,  $userEq.Fs44.Bank3.Stage2.b1,  $userEq.Fs44.Bank3.Stage2.b0,  $userEq.Fs44.Bank3.Stage2.a2,  $userEq.Fs44.Bank3.Stage2.a1,
                $userEq.Fs44.Bank3.Stage3.b2,  $userEq.Fs44.Bank3.Stage3.b1,  $userEq.Fs44.Bank3.Stage3.b0,  $userEq.Fs44.Bank3.Stage3.a2,  $userEq.Fs44.Bank3.Stage3.a1,
                $userEq.Fs44.Bank3.Stage4.b2,  $userEq.Fs44.Bank3.Stage4.b1,  $userEq.Fs44.Bank3.Stage4.b0,  $userEq.Fs44.Bank3.Stage4.a2,  $userEq.Fs44.Bank3.Stage4.a1,
                $userEq.Fs44.Bank3.Stage5.b2,  $userEq.Fs44.Bank3.Stage5.b1,  $userEq.Fs44.Bank3.Stage5.b0,  $userEq.Fs44.Bank3.Stage5.a2,  $userEq.Fs44.Bank3.Stage5.a1,
                $userEq.Fs44.Bank3.Stage1.scale, $userEq.Fs44.Bank3.Stage2.scale, $userEq.Fs44.Bank3.Stage3.scale, $userEq.Fs44.Bank3.Stage4.scale, $userEq.Fs44.Bank3.Stage5.scale;
            .VAR UserEqCoefs4[3+6*MAX_NUM_USER_EQ_STAGES] =             // 44 kHz bank 4
                $userEq.Fs44.Bank4.NumBands,
                $userEq.Fs44.Bank4.GainExp,
                $userEq.Fs44.Bank4.GainMant,
                $userEq.Fs44.Bank4.Stage1.b2,  $userEq.Fs44.Bank4.Stage1.b1,  $userEq.Fs44.Bank4.Stage1.b0,  $userEq.Fs44.Bank4.Stage1.a2,  $userEq.Fs44.Bank4.Stage1.a1,
                $userEq.Fs44.Bank4.Stage2.b2,  $userEq.Fs44.Bank4.Stage2.b1,  $userEq.Fs44.Bank4.Stage2.b0,  $userEq.Fs44.Bank4.Stage2.a2,  $userEq.Fs44.Bank4.Stage2.a1,
                $userEq.Fs44.Bank4.Stage3.b2,  $userEq.Fs44.Bank4.Stage3.b1,  $userEq.Fs44.Bank4.Stage3.b0,  $userEq.Fs44.Bank4.Stage3.a2,  $userEq.Fs44.Bank4.Stage3.a1,
                $userEq.Fs44.Bank4.Stage4.b2,  $userEq.Fs44.Bank4.Stage4.b1,  $userEq.Fs44.Bank4.Stage4.b0,  $userEq.Fs44.Bank4.Stage4.a2,  $userEq.Fs44.Bank4.Stage4.a1,
                $userEq.Fs44.Bank4.Stage5.b2,  $userEq.Fs44.Bank4.Stage5.b1,  $userEq.Fs44.Bank4.Stage5.b0,  $userEq.Fs44.Bank4.Stage5.a2,  $userEq.Fs44.Bank4.Stage5.a1,
                $userEq.Fs44.Bank4.Stage1.scale, $userEq.Fs44.Bank4.Stage2.scale, $userEq.Fs44.Bank4.Stage3.scale, $userEq.Fs44.Bank4.Stage4.scale, $userEq.Fs44.Bank4.Stage5.scale;
            .VAR UserEqCoefs5[3+6*MAX_NUM_USER_EQ_STAGES] =             // 44 kHz bank 5
                $userEq.Fs44.Bank5.NumBands,
                $userEq.Fs44.Bank5.GainExp,
                $userEq.Fs44.Bank5.GainMant,
                $userEq.Fs44.Bank5.Stage1.b2,  $userEq.Fs44.Bank5.Stage1.b1,  $userEq.Fs44.Bank5.Stage1.b0,  $userEq.Fs44.Bank5.Stage1.a2,  $userEq.Fs44.Bank5.Stage1.a1,
                $userEq.Fs44.Bank5.Stage2.b2,  $userEq.Fs44.Bank5.Stage2.b1,  $userEq.Fs44.Bank5.Stage2.b0,  $userEq.Fs44.Bank5.Stage2.a2,  $userEq.Fs44.Bank5.Stage2.a1,
                $userEq.Fs44.Bank5.Stage3.b2,  $userEq.Fs44.Bank5.Stage3.b1,  $userEq.Fs44.Bank5.Stage3.b0,  $userEq.Fs44.Bank5.Stage3.a2,  $userEq.Fs44.Bank5.Stage3.a1,
                $userEq.Fs44.Bank5.Stage4.b2,  $userEq.Fs44.Bank5.Stage4.b1,  $userEq.Fs44.Bank5.Stage4.b0,  $userEq.Fs44.Bank5.Stage4.a2,  $userEq.Fs44.Bank5.Stage4.a1,
                $userEq.Fs44.Bank5.Stage5.b2,  $userEq.Fs44.Bank5.Stage5.b1,  $userEq.Fs44.Bank5.Stage5.b0,  $userEq.Fs44.Bank5.Stage5.a2,  $userEq.Fs44.Bank5.Stage5.a1,
                $userEq.Fs44.Bank5.Stage1.scale, $userEq.Fs44.Bank5.Stage2.scale, $userEq.Fs44.Bank5.Stage3.scale, $userEq.Fs44.Bank5.Stage4.scale, $userEq.Fs44.Bank5.Stage5.scale;
            .VAR UserEqCoefs6[3+6*MAX_NUM_USER_EQ_STAGES] =             // 44 kHz bank 6
                $userEq.Fs44.Bank6.NumBands,
                $userEq.Fs44.Bank6.GainExp,
                $userEq.Fs44.Bank6.GainMant,
                $userEq.Fs44.Bank6.Stage1.b2,  $userEq.Fs44.Bank6.Stage1.b1,  $userEq.Fs44.Bank6.Stage1.b0,  $userEq.Fs44.Bank6.Stage1.a2,  $userEq.Fs44.Bank6.Stage1.a1,
                $userEq.Fs44.Bank6.Stage2.b2,  $userEq.Fs44.Bank6.Stage2.b1,  $userEq.Fs44.Bank6.Stage2.b0,  $userEq.Fs44.Bank6.Stage2.a2,  $userEq.Fs44.Bank6.Stage2.a1,
                $userEq.Fs44.Bank6.Stage3.b2,  $userEq.Fs44.Bank6.Stage3.b1,  $userEq.Fs44.Bank6.Stage3.b0,  $userEq.Fs44.Bank6.Stage3.a2,  $userEq.Fs44.Bank6.Stage3.a1,
                $userEq.Fs44.Bank6.Stage4.b2,  $userEq.Fs44.Bank6.Stage4.b1,  $userEq.Fs44.Bank6.Stage4.b0,  $userEq.Fs44.Bank6.Stage4.a2,  $userEq.Fs44.Bank6.Stage4.a1,
                $userEq.Fs44.Bank6.Stage5.b2,  $userEq.Fs44.Bank6.Stage5.b1,  $userEq.Fs44.Bank6.Stage5.b0,  $userEq.Fs44.Bank6.Stage5.a2,  $userEq.Fs44.Bank6.Stage5.a1,
                $userEq.Fs44.Bank6.Stage1.scale, $userEq.Fs44.Bank6.Stage2.scale, $userEq.Fs44.Bank6.Stage3.scale, $userEq.Fs44.Bank6.Stage4.scale, $userEq.Fs44.Bank6.Stage5.scale;

            .VAR UserEqCoefs7[3+6*MAX_NUM_USER_EQ_STAGES] =             // 48 kHz bank 1 (7)
                $userEq.Fs48.Bank1.NumBands,
                $userEq.Fs48.Bank1.GainExp,
                $userEq.Fs48.Bank1.GainMant,
                $userEq.Fs48.Bank1.Stage1.b2,  $userEq.Fs48.Bank1.Stage1.b1,  $userEq.Fs48.Bank1.Stage1.b0,  $userEq.Fs48.Bank1.Stage1.a2,  $userEq.Fs48.Bank1.Stage1.a1,
                $userEq.Fs48.Bank1.Stage2.b2,  $userEq.Fs48.Bank1.Stage2.b1,  $userEq.Fs48.Bank1.Stage2.b0,  $userEq.Fs48.Bank1.Stage2.a2,  $userEq.Fs48.Bank1.Stage2.a1,
                $userEq.Fs48.Bank1.Stage3.b2,  $userEq.Fs48.Bank1.Stage3.b1,  $userEq.Fs48.Bank1.Stage3.b0,  $userEq.Fs48.Bank1.Stage3.a2,  $userEq.Fs48.Bank1.Stage3.a1,
                $userEq.Fs48.Bank1.Stage4.b2,  $userEq.Fs48.Bank1.Stage4.b1,  $userEq.Fs48.Bank1.Stage4.b0,  $userEq.Fs48.Bank1.Stage4.a2,  $userEq.Fs48.Bank1.Stage4.a1,
                $userEq.Fs48.Bank1.Stage5.b2,  $userEq.Fs48.Bank1.Stage5.b1,  $userEq.Fs48.Bank1.Stage5.b0,  $userEq.Fs48.Bank1.Stage5.a2,  $userEq.Fs48.Bank1.Stage5.a1,
                $userEq.Fs48.Bank1.Stage1.scale, $userEq.Fs48.Bank1.Stage2.scale, $userEq.Fs48.Bank1.Stage3.scale, $userEq.Fs48.Bank1.Stage4.scale, $userEq.Fs48.Bank1.Stage5.scale;
            .VAR SpkrEqCoefs8[3+6*MAX_NUM_USER_EQ_STAGES] =             // 48 kHz bank 2 (8)
                $userEq.Fs48.Bank2.NumBands,
                $userEq.Fs48.Bank2.GainExp,
                $userEq.Fs48.Bank2.GainMant,
                $userEq.Fs48.Bank2.Stage1.b2,  $userEq.Fs48.Bank2.Stage1.b1,  $userEq.Fs48.Bank2.Stage1.b0,  $userEq.Fs48.Bank2.Stage1.a2,  $userEq.Fs48.Bank2.Stage1.a1,
                $userEq.Fs48.Bank2.Stage2.b2,  $userEq.Fs48.Bank2.Stage2.b1,  $userEq.Fs48.Bank2.Stage2.b0,  $userEq.Fs48.Bank2.Stage2.a2,  $userEq.Fs48.Bank2.Stage2.a1,
                $userEq.Fs48.Bank2.Stage3.b2,  $userEq.Fs48.Bank2.Stage3.b1,  $userEq.Fs48.Bank2.Stage3.b0,  $userEq.Fs48.Bank2.Stage3.a2,  $userEq.Fs48.Bank2.Stage3.a1,
                $userEq.Fs48.Bank2.Stage4.b2,  $userEq.Fs48.Bank2.Stage4.b1,  $userEq.Fs48.Bank2.Stage4.b0,  $userEq.Fs48.Bank2.Stage4.a2,  $userEq.Fs48.Bank2.Stage4.a1,
                $userEq.Fs48.Bank2.Stage5.b2,  $userEq.Fs48.Bank2.Stage5.b1,  $userEq.Fs48.Bank2.Stage5.b0,  $userEq.Fs48.Bank2.Stage5.a2,  $userEq.Fs48.Bank2.Stage5.a1,
                $userEq.Fs48.Bank2.Stage1.scale, $userEq.Fs48.Bank2.Stage2.scale, $userEq.Fs48.Bank2.Stage3.scale, $userEq.Fs48.Bank2.Stage4.scale, $userEq.Fs48.Bank2.Stage5.scale;
            .VAR UserEqCoefs9[3+6*MAX_NUM_USER_EQ_STAGES] =             // 48 kHz bank 3 (9)
                $userEq.Fs48.Bank3.NumBands,
                $userEq.Fs48.Bank3.GainExp,
                $userEq.Fs48.Bank3.GainMant,
                $userEq.Fs48.Bank3.Stage1.b2,  $userEq.Fs48.Bank3.Stage1.b1,  $userEq.Fs48.Bank3.Stage1.b0,  $userEq.Fs48.Bank3.Stage1.a2,  $userEq.Fs48.Bank3.Stage1.a1,
                $userEq.Fs48.Bank3.Stage2.b2,  $userEq.Fs48.Bank3.Stage2.b1,  $userEq.Fs48.Bank3.Stage2.b0,  $userEq.Fs48.Bank3.Stage2.a2,  $userEq.Fs48.Bank3.Stage2.a1,
                $userEq.Fs48.Bank3.Stage3.b2,  $userEq.Fs48.Bank3.Stage3.b1,  $userEq.Fs48.Bank3.Stage3.b0,  $userEq.Fs48.Bank3.Stage3.a2,  $userEq.Fs48.Bank3.Stage3.a1,
                $userEq.Fs48.Bank3.Stage4.b2,  $userEq.Fs48.Bank3.Stage4.b1,  $userEq.Fs48.Bank3.Stage4.b0,  $userEq.Fs48.Bank3.Stage4.a2,  $userEq.Fs48.Bank3.Stage4.a1,
                $userEq.Fs48.Bank3.Stage5.b2,  $userEq.Fs48.Bank3.Stage5.b1,  $userEq.Fs48.Bank3.Stage5.b0,  $userEq.Fs48.Bank3.Stage5.a2,  $userEq.Fs48.Bank3.Stage5.a1,
                $userEq.Fs48.Bank3.Stage1.scale, $userEq.Fs48.Bank3.Stage2.scale, $userEq.Fs48.Bank3.Stage3.scale, $userEq.Fs48.Bank3.Stage4.scale, $userEq.Fs48.Bank3.Stage5.scale;
            .VAR UserEqCoefs10[3+6*MAX_NUM_USER_EQ_STAGES] =             // 48 kHz bank 4 (10)
                $userEq.Fs48.Bank4.NumBands,
                $userEq.Fs48.Bank4.GainExp,
                $userEq.Fs48.Bank4.GainMant,
                $userEq.Fs48.Bank4.Stage1.b2,  $userEq.Fs48.Bank4.Stage1.b1,  $userEq.Fs48.Bank4.Stage1.b0,  $userEq.Fs48.Bank4.Stage1.a2,  $userEq.Fs48.Bank4.Stage1.a1,
                $userEq.Fs48.Bank4.Stage2.b2,  $userEq.Fs48.Bank4.Stage2.b1,  $userEq.Fs48.Bank4.Stage2.b0,  $userEq.Fs48.Bank4.Stage2.a2,  $userEq.Fs48.Bank4.Stage2.a1,
                $userEq.Fs48.Bank4.Stage3.b2,  $userEq.Fs48.Bank4.Stage3.b1,  $userEq.Fs48.Bank4.Stage3.b0,  $userEq.Fs48.Bank4.Stage3.a2,  $userEq.Fs48.Bank4.Stage3.a1,
                $userEq.Fs48.Bank4.Stage4.b2,  $userEq.Fs48.Bank4.Stage4.b1,  $userEq.Fs48.Bank4.Stage4.b0,  $userEq.Fs48.Bank4.Stage4.a2,  $userEq.Fs48.Bank4.Stage4.a1,
                $userEq.Fs48.Bank4.Stage5.b2,  $userEq.Fs48.Bank4.Stage5.b1,  $userEq.Fs48.Bank4.Stage5.b0,  $userEq.Fs48.Bank4.Stage5.a2,  $userEq.Fs48.Bank4.Stage5.a1,
                $userEq.Fs48.Bank4.Stage1.scale, $userEq.Fs48.Bank4.Stage2.scale, $userEq.Fs48.Bank4.Stage3.scale, $userEq.Fs48.Bank4.Stage4.scale, $userEq.Fs48.Bank4.Stage5.scale;
            .VAR UserEqCoefs11[3+6*MAX_NUM_USER_EQ_STAGES] =             // 48 kHz bank 5 (11)
                $userEq.Fs48.Bank5.NumBands,
                $userEq.Fs48.Bank5.GainExp,
                $userEq.Fs48.Bank5.GainMant,
                $userEq.Fs48.Bank5.Stage1.b2,  $userEq.Fs48.Bank5.Stage1.b1,  $userEq.Fs48.Bank5.Stage1.b0,  $userEq.Fs48.Bank5.Stage1.a2,  $userEq.Fs48.Bank5.Stage1.a1,
                $userEq.Fs48.Bank5.Stage2.b2,  $userEq.Fs48.Bank5.Stage2.b1,  $userEq.Fs48.Bank5.Stage2.b0,  $userEq.Fs48.Bank5.Stage2.a2,  $userEq.Fs48.Bank5.Stage2.a1,
                $userEq.Fs48.Bank5.Stage3.b2,  $userEq.Fs48.Bank5.Stage3.b1,  $userEq.Fs48.Bank5.Stage3.b0,  $userEq.Fs48.Bank5.Stage3.a2,  $userEq.Fs48.Bank5.Stage3.a1,
                $userEq.Fs48.Bank5.Stage4.b2,  $userEq.Fs48.Bank5.Stage4.b1,  $userEq.Fs48.Bank5.Stage4.b0,  $userEq.Fs48.Bank5.Stage4.a2,  $userEq.Fs48.Bank5.Stage4.a1,
                $userEq.Fs48.Bank5.Stage5.b2,  $userEq.Fs48.Bank5.Stage5.b1,  $userEq.Fs48.Bank5.Stage5.b0,  $userEq.Fs48.Bank5.Stage5.a2,  $userEq.Fs48.Bank5.Stage5.a1,
                $userEq.Fs48.Bank5.Stage1.scale, $userEq.Fs48.Bank5.Stage2.scale, $userEq.Fs48.Bank5.Stage3.scale, $userEq.Fs48.Bank5.Stage4.scale, $userEq.Fs48.Bank5.Stage5.scale;
            .VAR UserEqCoefs12[3+6*MAX_NUM_USER_EQ_STAGES] =             // 48 kHz bank 6 (12)
                $userEq.Fs48.Bank6.NumBands,
                $userEq.Fs48.Bank6.GainExp,
                $userEq.Fs48.Bank6.GainMant,
                $userEq.Fs48.Bank6.Stage1.b2,  $userEq.Fs48.Bank6.Stage1.b1,  $userEq.Fs48.Bank6.Stage1.b0,  $userEq.Fs48.Bank6.Stage1.a2,  $userEq.Fs48.Bank6.Stage1.a1,
                $userEq.Fs48.Bank6.Stage2.b2,  $userEq.Fs48.Bank6.Stage2.b1,  $userEq.Fs48.Bank6.Stage2.b0,  $userEq.Fs48.Bank6.Stage2.a2,  $userEq.Fs48.Bank6.Stage2.a1,
                $userEq.Fs48.Bank6.Stage3.b2,  $userEq.Fs48.Bank6.Stage3.b1,  $userEq.Fs48.Bank6.Stage3.b0,  $userEq.Fs48.Bank6.Stage3.a2,  $userEq.Fs48.Bank6.Stage3.a1,
                $userEq.Fs48.Bank6.Stage4.b2,  $userEq.Fs48.Bank6.Stage4.b1,  $userEq.Fs48.Bank6.Stage4.b0,  $userEq.Fs48.Bank6.Stage4.a2,  $userEq.Fs48.Bank6.Stage4.a1,
                $userEq.Fs48.Bank6.Stage5.b2,  $userEq.Fs48.Bank6.Stage5.b1,  $userEq.Fs48.Bank6.Stage5.b0,  $userEq.Fs48.Bank6.Stage5.a2,  $userEq.Fs48.Bank6.Stage5.a1,
                $userEq.Fs48.Bank6.Stage1.scale, $userEq.Fs48.Bank6.Stage2.scale, $userEq.Fs48.Bank6.Stage3.scale, $userEq.Fs48.Bank6.Stage4.scale, $userEq.Fs48.Bank6.Stage5.scale;
        .ENDBLOCK;
    #else
        .VAR UserEqCoefsA[33] =
            0x000000,                                               // [0] = config (no eq bands)
            0x000001,                                               // [1] = gain exponent
            0x400000,                                               // [2] = gain mantissa
            0x000000, 0x000000, 0x400000, 0x000000, 0x000000,       // [ 3... 7] = stage 1 (b2,b1,b0,a2,a1)
            0x000000, 0x000000, 0x400000, 0x000000, 0x000000,       // [ 8...12] = stage 2
            0x000000, 0x000000, 0x400000, 0x000000, 0x000000,       // [13...17] = stage 3
            0x000000, 0x000000, 0x400000, 0x000000, 0x000000,       // [18...22] = stage 4
            0x000000, 0x000000, 0x400000, 0x000000, 0x000000,       // [23...27] = stage 5
            0x000001, 0x000001, 0x000001, 0x000001, 0x000001;       // [28...32] = scales

        .VAR UserEqCoefsB[33] =
            0x000000,                                               // [0] = config (no eq bands)
            0x000001,                                               // [1] = gain exponent
            0x400000,                                               // [2] = gain mantissa
            0x000000, 0x000000, 0x400000, 0x000000, 0x000000,       // [ 3... 7] = stage 1 (b2,b1,b0,a2,a1)
            0x000000, 0x000000, 0x400000, 0x000000, 0x000000,       // [ 8...12] = stage 2
            0x000000, 0x000000, 0x400000, 0x000000, 0x000000,       // [13...17] = stage 3
            0x000000, 0x000000, 0x400000, 0x000000, 0x000000,       // [18...22] = stage 4
            0x000000, 0x000000, 0x400000, 0x000000, 0x000000,       // [23...27] = stage 5
            0x000001, 0x000001, 0x000001, 0x000001, 0x000001;       // [28...32] = scales
   #endif // USE_PRECALCULATED_USER_COEFS

    .VAR UserEqDefnTable[$user_eq.DEFINITION_TABLE_SIZE] =
        MAX_NUM_USER_EQ_BANKS,
        MAX_NUM_USER_EQ_STAGES,
        &user_eq_left_dm2,
        &user_eq_right_dm2,
        &UserEqCoefsA,
        &UserEqCoefsB;

     // 6 configs
    .VAR/DM2 user_eq_bank_select[1 + MAX_NUM_USER_EQ_BANKS] =
        0,  // index 0 = flat response (no eq)
        &CurParams + $M.MUSIC_MANAGER.PARAMETERS.OFFSET_USER_EQ1_NUM_BANDS,
        &CurParams + $M.MUSIC_MANAGER.PARAMETERS.OFFSET_USER_EQ2_NUM_BANDS,
        &CurParams + $M.MUSIC_MANAGER.PARAMETERS.OFFSET_USER_EQ3_NUM_BANDS,
        &CurParams + $M.MUSIC_MANAGER.PARAMETERS.OFFSET_USER_EQ4_NUM_BANDS,
        &CurParams + $M.MUSIC_MANAGER.PARAMETERS.OFFSET_USER_EQ5_NUM_BANDS,
        &CurParams + $M.MUSIC_MANAGER.PARAMETERS.OFFSET_USER_EQ6_NUM_BANDS;

#endif

   // multichannel volume and limit object
.BLOCK multichannel_volume_and_limit_block;

   .VAR multichannel_volume_and_limit_obj[$volume_and_limit.STRUC_SIZE] =
        0x000000,                                         //OFFSET_CONTROL_WORD_FIELD
        $M.MUSIC_MANAGER.CONFIG.VOLUME_LIMITER_BYPASS,    //OFFSET_BYPASS_BIT_FIELD
        2,                                                //NROF_CHANNELS_FIELD
        &$current_codec_sampling_rate,                      //SAMPLE_RATE_PTR_FIELD

        $music_example.MUTE_MASTER_VOLUME,                //MASTER_VOLUME_FIELD
        $music_example.LIMIT_THRESHOLD,                   //LIMIT_THRESHOLD_FIELD
        $music_example.LIMIT_THRESHOLD_LINEAR,            //LIMIT_THRESHOLD_LINEAR_FIELD
        $music_example.LIMIT_RATIO,                       //LIMIT_RATIO_FIELD_FIELD
        $music_example.RAMP_FACTOR,                       //RAMP FACTOR FIELD
        0 ...;

   .VAR left_primary_channel_vol_struc[$volume_and_limit.channel.STRUC_SIZE] =
        &stream_map_primary_left_out,                 // INPUT_PTR_FIELD
        &stream_map_primary_left_out,                 // OUTPUT_PTR_FIELD
        $music_example.DEFAULT_TRIM_VOLUME,           // TRIM_VOLUME_FIELD
        0 ...;

   .VAR right_primary_channel_vol_struc[$volume_and_limit.channel.STRUC_SIZE] =
        &stream_map_primary_right_out,                // INPUT_PTR_FIELD
        &stream_map_primary_right_out,                // OUTPUT_PTR_FIELD
        $music_example.DEFAULT_TRIM_VOLUME,           // TRIM_VOLUME_FIELD
        0 ...;
        
.ENDBLOCK;


// -----------------------------------------------------------------------------
// STREAM MAPS - Stream definitions
//
// A static stream object is created for each stream. Current system has:
// 3 input stream maps in L,R and optional LFE
// 7 output stream maps out primary L,R, out secondary L,R, out aux L,R, out sub
//
// Stream maps populate processing module data objects with input and output
// pointers so processing modules know where to get and write their data.
// -----------------------------------------------------------------------------

// left input stream map
   .VAR   stream_map_left_in[$framesync_ind.ENTRY_SIZE_FIELD] =
          &$M.audio_processing.audio_in_l_cbuffer_struc,                 // $framesync_ind.CBUFFER_PTR_FIELD
          0,                                        // $framesync_ind.FRAME_PTR_FIELD
          0,                                        // $framesync_ind.CUR_FRAME_SIZE_FIELD
          512,                                      // $framesync_ind.FRAME_SIZE_FIELD
          $music_example.JITTER,                    // $framesync_ind.JITTER_FIELD
          $frame_sync.distribute_input_stream_ind,  // Distribute Function
          $frame_sync.update_input_streams_ind,     // Update Function
          0 ...;

// right input stream map
    .VAR  stream_map_right_in[$framesync_ind.ENTRY_SIZE_FIELD] =
          &$M.audio_processing.audio_in_r_cbuffer_struc,                 // $framesync_ind.CBUFFER_PTR_FIELD
          0,                                        // $framesync_ind.FRAME_PTR_FIELD
          0,                                        // $framesync_ind.CUR_FRAME_SIZE_FIELD
          512,                                      // $framesync_ind.FRAME_SIZE_FIELD
          $music_example.JITTER,                    // $framesync_ind.JITTER_FIELD
          $frame_sync.distribute_input_stream_ind,  // Distribute Function
          $frame_sync.update_input_streams_ind,     // Update Function
          0 ...;

// -----------------------------------------------------------------------------
// left primary output stream map
    .VAR  stream_map_primary_left_out[$framesync_ind.ENTRY_SIZE_FIELD] =
          &$M.audio_processing.eq_out_left_cbuffer_struc,
          0,                                        // $framesync_ind.FRAME_PTR_FIELD
          0,                                        // $framesync_ind.CUR_FRAME_SIZE_FIELD
          512,                                      // $framesync_ind.FRAME_SIZE_FIELD
          $music_example.JITTER,                    // $framesync_ind.JITTER_FIELD
          $frame_sync.distribute_output_stream_ind, // Distribute Function
          $frame_sync.update_output_streams_ind,    // Update Function
          0 ...;

// right primary output stream map
    .VAR  stream_map_primary_right_out[$framesync_ind.ENTRY_SIZE_FIELD] =
          &$M.audio_processing.eq_out_right_cbuffer_struc,

          0,                                        // $framesync_ind.FRAME_PTR_FIELD
          0,                                        // $framesync_ind.CUR_FRAME_SIZE_FIELD
          512,                                      // $framesync_ind.FRAME_SIZE_FIELD
          $music_example.JITTER,                    // $framesync_ind.JITTER_FIELD
          $frame_sync.distribute_output_stream_ind, // Distribute Function
          $frame_sync.update_output_streams_ind,    // Update Function
          0 ...;

// left input stream map
   .VAR   stream_map_left_in_user_eq[$framesync_ind.ENTRY_SIZE_FIELD] =
          &$audio_in_left_cbuffer_struc,                 // $framesync_ind.CBUFFER_PTR_FIELD
          0,                                        // $framesync_ind.FRAME_PTR_FIELD
          0,                                        // $framesync_ind.CUR_FRAME_SIZE_FIELD
          512,                                      // $framesync_ind.FRAME_SIZE_FIELD
          $music_example.JITTER,                    // $framesync_ind.JITTER_FIELD
          $frame_sync.distribute_input_stream_ind,  // Distribute Function
          $frame_sync.update_input_streams_ind,     // Update Function
          0 ...;

// right input stream map
    .VAR  stream_map_right_in_user_eq[$framesync_ind.ENTRY_SIZE_FIELD] =
          &$audio_in_right_cbuffer_struc,                 // $framesync_ind.CBUFFER_PTR_FIELD
          0,                                        // $framesync_ind.FRAME_PTR_FIELD
          0,                                        // $framesync_ind.CUR_FRAME_SIZE_FIELD
          512,                                      // $framesync_ind.FRAME_SIZE_FIELD
          $music_example.JITTER,                    // $framesync_ind.JITTER_FIELD
          $frame_sync.distribute_input_stream_ind,  // Distribute Function
          $frame_sync.update_input_streams_ind,     // Update Function
          0 ...;

// -----------------------------------------------------------------------------
// REINITIALIZATION FUNCTION TABLE
// Reinitialization functions and corresponding data objects can be placed
// in this table.  Functions in this table all called every time a frame of data
// is ready to be processed and the reinitialization flag is set.
// This table must be null terminated.

   .VAR reinitialize_table[] =
    // Function                          r7                   r8
#if uses_SPKR_EQ
   $user_eq.eqInitialize,              &SpkrEqDefnTable,     &SpkrEqParams,
#endif
#if uses_USER_EQ
    $user_eq.userEqInitialize,          &UserEqDefnTable,     &user_eq_bank_select,
#endif
    $volume_and_limit.initialize,      &multichannel_volume_and_limit_obj,   0,
      0;

// -----------------------------------------------------------------------------

   .VAR filter_reset_table[] =
    // Function                         r7                      r8
#if uses_SPKR_EQ
    $audio_proc.hq_peq.zero_delay_data,  &spkr_eq_left_dm2,    0,
    $audio_proc.hq_peq.zero_delay_data,  &spkr_eq_right_dm2,   0,
#endif
#if uses_USER_EQ
    $audio_proc.hq_peq.zero_delay_data,  &user_eq_left_dm2,    0,
    $audio_proc.hq_peq.zero_delay_data,  &user_eq_right_dm2,   0,
#endif
    0;

// ----------------------------------------------------------------------------

// Data object used with $stream_copy.pass_thru function
   .VAR left_pass_thru_obj[$stream_copy.STRUC_SIZE] =
    &stream_map_left_in,
    &stream_map_primary_left_out;

   .VAR right_pass_thru_obj[$stream_copy.STRUC_SIZE] =
    &stream_map_right_in,
    &stream_map_primary_right_out;

   .VAR right_pass_thru_obj_user_eq[$stream_copy.STRUC_SIZE] =
    &stream_map_right_in_user_eq,
    &stream_map_primary_right_out_user_eq;

   .VAR $spkr_eq_obj_table[] =
      &left_pass_thru_obj,     
      &right_pass_thru_obj,
      &spkr_eq_left_dm2,            
      &spkr_eq_right_dm2;            

.ENDMODULE;


.MODULE $M.stream_copy;
 .codesegment PM;
$stream_copy:

   push rLink;  
   // Get Input Buffer
   r0  = M[r7 + $stream_copy.INPUT_PTR_BUFFER_FIELD];
#ifdef BASE_REGISTER_MODE  
   call $frmbuffer.get_buffer_with_start_address;
   push r2;
   pop  B0;
#else
   call $frmbuffer.get_buffer;
#endif
   // r0 = buf ptr
   // r1 = circ buf length
   // r2 = buffer base address <base variant only>
   // r3 = frame size
   I0  = r0;
   L0  = r1;
      
   // Use input frame size
   r10 = r3;
   // Update output frame size from input
   r0 = M[r7 + $stream_copy.OUTPUT_PTR_BUFFER_FIELD];
   call $frmbuffer.set_frame_size;
   
   // Get output buffer
#ifdef BASE_REGISTER_MODE  
   call $frmbuffer.get_buffer_with_start_address;
   push r2;
   pop  B4;
#else
   call $frmbuffer.get_buffer;
#endif
   I4 = r0;
   L4 = r1;
   pop rLink;
   

// INPUT->OUTPUT
   r0=M[I0,1]; // first input
   do loop_passthru;
      M[I4,1] = r0, r0=M[I0,1]; // copy
   loop_passthru:

// Clear L registers
   L0 = 0;
   L4 = 0;
#ifdef BASE_REGISTER_MODE  
   push Null;
   B4 = M[SP-1];
   pop  B0;
#endif   
   rts;
.ENDMODULE;



.MODULE $M.EQ.Utils;
 .codesegment PM;

// input: r7: the pass_thru_obj table: each obj entry has input and output streams
//        r8: # of obj to process  
// output r8 is the framesize
// trash: rMAC, r10, I0, r7, r0~r2
                                          
$mm_stream_config_framesize:

    $push_rLink_macro;
    
    push   r8;
    r10  = r8; 
    M1   = 1;
    r8   = 10000; // start with rarndomly large number
    do lp_calc_framesize;
        r0 = M[r7];                                     // get pass_thru_obj
        I0 = r0;
        r7 = r7 + M1, r0 = M[I0, M1];                   // get input stream,  next obj
        r0 = M[r0 + $framesync_ind.CBUFFER_PTR_FIELD];  // stream cbuffer ptr
        call $cbuffer.calc_amount_data;
        r8 = min r0,  r0 = M[I0, M1];                   // get output stream
        r0 = M[r0 + $framesync_ind.CBUFFER_PTR_FIELD];  // stream cbuffer ptr
        call $cbuffer.calc_amount_space;
        r8 = min r0;
lp_calc_framesize:         

//  Null = r8; removed due to previous min in the loop
    if  NZ  jump  config_framesize;
    pop  Null;       // balance stack push r8
    jump  exit;
    
config_framesize:    

    pop  r10;       // # of obj to process    
    r7 = r7 - r10;    // root obj ptr
    
    // r10: # of objs
    // r7: root obj ptr
    // r8:  framesize      

    do lp_stream_setup;    
        r0 = M[r7];                                     // get pass_thru_obj
        I0 = r0;
        r7 = r7 + M1,    rMAC = M[I0, M1];              // input stream, next obj
        M[rMAC + $framesync_ind.CUR_FRAME_SIZE_FIELD] = r8;
        r0 = M[rMAC + $framesync_ind.CBUFFER_PTR_FIELD];
        call $cbuffer.get_read_address_and_size;
        M[rMAC + $framesync_ind.FRAME_PTR_FIELD] = r0;
        rMAC = M[I0, M1];
        M[rMAC + $framesync_ind.CUR_FRAME_SIZE_FIELD] = r8;
        r0 = M[rMAC + $framesync_ind.CBUFFER_PTR_FIELD];
        call $cbuffer.get_write_address_and_size;
        M[rMAC + $framesync_ind.FRAME_PTR_FIELD] = r0;
lp_stream_setup:
        
exit:

    M1 = Null; 
    jump $pop_rLink_and_rts;

// input: r7: obj table
// output: none
// trash: assuming all     
$mm_stream_process_chan:

    $push_rLink_macro;
       
        r9 = r7;
        
        r7 = M[r9 + $EQ_OBJ_OFFSET_FIELD]; 
        call $music_example.peq.process;
        r7 = M[r9]; 
        call $stream_copy;

        // update buffer addr
        M1 = r3;

        // r7: pass thru obj

        I1 = r7;
        r0 = M[I1, 1];      // input stream
        r0 = M[r0 + $framesync_ind.CBUFFER_PTR_FIELD];
        push r0;
        call $cbuffer.get_read_address_and_size;
        I0 = r0;
        L0 = r1;
        pop  r0,      r1 = M[I0, M1];   // restore input stream cbuffer
        r1 = I0;
        call $cbuffer.set_read_address;
        // update write address
        r0 = M[I1, 1];                 // output stream 
        r0 = M[r0 + $framesync_ind.CBUFFER_PTR_FIELD];
        push r0;                        // preserve input stream cbuffer
        call $cbuffer.get_write_address_and_size;
        I0 = r0;
        L0 = r1;
        pop  r0,      r1 = M[I0,M1];    // restore input stream cbuffer
        r1 = I0;
        call $cbuffer.set_write_address;

        L0 = Null;
        M1 = Null;

    jump  $pop_rLink_and_rts;
    
.ENDMODULE;

