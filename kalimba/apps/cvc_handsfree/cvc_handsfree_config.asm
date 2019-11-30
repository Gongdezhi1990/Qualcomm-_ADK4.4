// *****************************************************************************
// Copyright (c) 2007 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

// *****************************************************************************
// DESCRIPTION
//    CVC static configuration file that includes tables of function pointers
//    and their corresponding data objects.
//
//    Customer modification to this file is NOT SUPPORTED.
//
//    CVC configuration should be handled from within the cvc_handsfree_config.h
//    header file.
//
// *****************************************************************************

#include "stack.h"
#include "frame_codec.h"
#include "cvc_modules.h"
#include "cvc_handsfree.h"
#include "cvc_system_library.h"
#include "cbops_multirate_library.h"
#include "frame_sync_buffer.h"
#include "cbuffer.h"
#include "frame_sync_tsksched.h"
#include "frame_sync_stream_macros.h"

// SP. Needs for Sample Rate converters
#include "operators\iir_resamplev2\iir_resamplev2_header.h"

#ifndef BUILD_MULTI_KAPS   // SP. moved to dsp_core
// declare twiddle factors
#include "fft_twiddle.h"
#endif
// temporary until application linkfile can configure this segment
#define USE_FLASH_ADDR_TABLES
#ifdef USE_FLASH_ADDR_TABLES
      #define ADDR_TABLE_DM DMCONST
#else
   #define ADDR_TABLE_DM DM
#endif


   .CONST $M.CVC.AEC.Num_FFT_Window       $M.CVC.Num_FFT_Window * AEC_WINDOW_FACTOR;

// Generate build error messages if necessary.
#if uses_AEC
#if uses_SND2_NS == 0
   #error AEC cannot be enabled without OMS2
#endif // uses_SND2_NS
#if uses_SND1_NS == 0
   #error AEC cannot be enabled without OMS1
#endif // uses_SND1_NS
#else // uses_AEC
#if uses_SND1_NS
   #error OMS1 cannot be enabled without AEC
#endif // uses_SND1_NS
#if uses_NONLINEAR_PROCESSING
   #error Nonlinear processing cannot be enabled without AEC
#endif // uses_NONLINEAR_PROCESSING
#if uses_HOWLING_CONTROL
   #error Half-Duplex cannot be enabled without AEC
#endif // uses_HOWLING_CONTROL
#endif // uses_AEC

#if uses_NSVOLUME
#if uses_SND2_NS == 0
   #error NDVC cannot be enabled without OMS2
#endif
#endif

#define MAX_NUM_PEQ_STAGES             (5)

// System Configuration is saved in kap file.
.MODULE $M.CVC_MODULES_STAMP;
   .DATASEGMENT DM;
   .BLOCK ModulesStamp;
      .VAR  s1 = 0xfeeb;
      .VAR  s2 = 0xfeeb;
      .VAR  s3 = 0xfeeb;
      .VAR  CompConfig = CVC_HANDSFREE_CONFIG_FLAG;
      .VAR  s4 = 0xfeeb;
      .VAR  s5 = 0xfeeb;
      .VAR  s6 = 0xfeeb;
   .ENDBLOCK;
.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $M.CVC_VERSION_STAMP
//
// DESCRIPTION:
//    This data module is used to write the CVC algorithm ID and build version
//    into the kap file in a readable form.
// *****************************************************************************

.MODULE $M.CVC_VERSION_STAMP;
   .DATASEGMENT DM;
   .BLOCK VersionStamp;
   .VAR  h1 = 0xbeef;
   .VAR  h2 = 0xbeef;
   .VAR  h3 = 0xbeef;
   .VAR  SysID = $CVC_HANDSFREE_SYSID;
   .VAR  BuildNum = $CVC_VERSION;
   .VAR  h4 = 0xbeef;
   .VAR  h5 = 0xbeef;
   .VAR  h6 = 0xbeef;
   .ENDBLOCK;
.ENDMODULE;


.MODULE $M.CVC.data;
   .DATASEGMENT DM;

   // Temp Variable to handle disabled modules.
   .VAR  ZeroValue = 0;
   .VAR  OneValue = 1.0;

   // These lines write module and version information to the kap file.
   .VAR kap_version_stamp = &$M.CVC_VERSION_STAMP.VersionStamp;
   .VAR kap_modules_stamp = &$M.CVC_MODULES_STAMP.ModulesStamp;


   // Default Block
   .VAR/DMCONST16  DefaultParameters_wb[] =
       #include "cvc_handsfree_defaults_wb.dat"
   ;
   .VAR/DMCONST16  DefaultParameters_fe[] =
       #include "cvc_handsfree_defaults_fe.dat"
   ;
   .VAR/DMCONST16  DefaultParameters_nb[] =
       #include "cvc_handsfree_defaults_nb.dat"
   ;

   // guarantee even length
   .VAR  CurParams[2*ROUND(0.5*$M.CVC_HANDSFREE.PARAMETERS.STRUCT_SIZE)];

//  ******************  Define circular Buffers ************************

    //LN .VAR/DM2      ref_delay_buffer[Max_RefDelay_Sample];

    // SPTBD.  This buffer can be in scratch memory
    .VAR/DM2 fft_circ[FFT_BUFFER_SIZE];

    #if uses_RCV_NS
   .VAR/DM1 rcvLpX_queue[$M.oms270.QUE_LENGTH];
    #endif
    #if uses_SND1_NS
   .VAR/DM1 snd1LpX_queue[$M.oms270.QUE_LENGTH];
    #endif
    #if uses_SND2_NS
   .VAR/DM1 snd2LpX_queue[$M.oms270.QUE_LENGTH];
    #endif


//  ******************  Define Scratch/Shared Memory ************************

    // Frequency Domain Shared working buffers
    .BLOCK/DM1   FFT_DM1;
      .VAR  D_real[$M.CVC.Num_FFT_Freq_Bins];
#if (uses_AEC || uses_RCV_FREQPROC)
      .VAR  E_real[$M.CVC.ADC_DAC_Num_FFT_Freq_Bins];
#endif
        // X_real has to be immediately after E_real, so we can use it for the
        // implicit overflow present in BW Extension for NB
      .VAR  X_real[$M.CVC.Num_FFT_Freq_Bins];
   .ENDBLOCK;

   .BLOCK/DM2 FFT_DM2;
      .VAR  D_imag[$M.CVC.Num_FFT_Freq_Bins];
#if (uses_AEC || uses_RCV_FREQPROC)
      .VAR  E_imag[$M.CVC.ADC_DAC_Num_FFT_Freq_Bins]; // shared E and rcv_harm buffer[1]
#endif
        // X_imag has to be immediately after E_imag, so we can use it for the
        // implicit overflow present in BW Extension for NB
      .VAR  X_imag[$M.CVC.Num_FFT_Freq_Bins];
   .ENDBLOCK;


#ifndef BUILD_MULTI_KAPS
   .BLOCK/DM1 $scratch.s;
      .VAR    $scratch.s0;
      .VAR    $scratch.s1;
      .VAR    $scratch.s2;
      .VAR    $scratch.s3;
      .VAR    $scratch.s4;
      .VAR    $scratch.s5;
      .VAR    $scratch.s6;
      .VAR    $scratch.s7;
      .VAR    $scratch.s8;
      .VAR    $scratch.s9;
   .ENDBLOCK;

   .BLOCK/DM2 $scratch.t;
      .VAR    $scratch.t0;
      .VAR    $scratch.t1;
      .VAR    $scratch.t2;
      .VAR    $scratch.t3;
      .VAR    $scratch.t4;
      .VAR    $scratch.t5;
      .VAR    $scratch.t6;
      .VAR    $scratch.t7;
      .VAR    $scratch.t8;
      .VAR    $scratch.t9;
   .ENDBLOCK;
#endif




    .BLOCK/DM1  $M.dm1_scratch;
         // real,imag interlaced
         .VAR  W_ri[2 * $M.CVC.Num_FFT_Freq_Bins +1];
         .VAR  L_adaptR[$M.CVC.Num_FFT_Freq_Bins];
         // SP - below shared between AEC, NLP, and CNG
         .VAR  L_adaptA[$M.CVC.Num_FFT_Freq_Bins];      // AbsSQGr
    .ENDBLOCK;


    // The oms_scratch buffer reuses the AEC buffer to reduce the data memory usage.
#define oms_scratch $M.dm1_scratch
    // The following two scratch buffers for the fft_object
    // reuses the scratch buffer from the AEC module.  This allows
    // reduction in the requirement of data memory for the overall system.
    // To be noted: The same AEC scratch memory is also reused for the
    // OMS270 scratch.
#define fft_real_scratch $M.dm1_scratch
#define fft_imag_scratch $M.dm1_scratch + FFT_BUFFER_SIZE
#define fft_circ_scratch fft_circ


    // The aeq_scratch buffer reuses the AEC buffer to reduce the data memory usage.
#define aeq_scratch $M.dm1_scratch
#define vad_scratch $M.dm1_scratch


// ***************  Shared Send & Receive Side Processing **********************

   // Shared Data for CVC modules.

   // FFT data object, common to all filter_bank cases
   // The three buffers in this object are temporary to FFT and could be shared
   .VAR fft_obj[$M.filter_bank.fft.STRUC_SIZE] =
      0,
      &fft_real_scratch,
      &fft_imag_scratch,
      &fft_circ_scratch,
      BITREVERSE(&fft_circ_scratch),
      $filter_bank.config.fftsplit_table, // PTR_FFTSPLIT
#if uses_AEQ
         -1,                  // FFT_EXTRA_SCALE
         1,                   // IFFT_EXTRA_SCALE
#endif
      0 ...;

#if uses_DCBLOCK
   // DC Blocker
   .VAR dcblock_parameters_nb[] =
        1,          // NUM_STAGES_FIELD
        1,          // GAIN_EXPONENT_FIELD
        0.5,        // GAIN_MANTISA__FIELD
        // Coefficients.        Filter format: b2,b1,b0,a2,a1
        0.948607495176447/2, -1.897214990352894/2, 0.948607495176447/2,
        0.899857926182383/2, -1.894572054523406/2,
        // Scale Factor
        1;

   .VAR dcblock_parameters_wb[] =
        1,          // NUM_STAGES_FIELD
        1,          // GAIN_EXPONENT_FIELD
        0.5,        // GAIN_MANTISA__FIELD
        // Coefficients.        Filter format: b2,b1,b0,a2,a1
        0.973965227469013/2,-1.947930454938026/2,0.973965227469013/2,
        0.948608379214097/2,-1.947252530661955/2,
        // Scale Factor
        1;
#endif

#if uses_SND_AGC || uses_RCV_VAD
   // Internal Stream Buffer

   // Declare a dummy cbuffer structure, i.e., vad_peq_output_cbuffer_struc
   // It is intended for linear buffer could be used
   // by '$frmbuffer.get_buffer_with_start_address'
   // or by '$frmbuffer.get_buffer'
   // to return '0' length of a cbuffer
   .VAR vad_peq_output_cbuffer_struc[$cbuffer.STRUC_SIZE] = 0 ...;

    .VAR  vad_peq_output[$frmbuffer.STRUC_SIZE]  =
            &vad_peq_output_cbuffer_struc,
            &vad_scratch,
            0;

    .VAR    vad_peq_parameters_nb[] =
        3,          // NUM_STAGES_FIELD
        1,          // GAIN_EXPONENT_FIELD
        0.5,        // GAIN_MANTISA__FIELD
        // Coefficients.        Filter format: (b2,b1,b0,a2,a1)/2
      3658586,    -7303920,     3662890,     3363562,    -7470041,
      3874204,    -7787540,     4194304,     3702500,    -7573428,
      4101184,    -7581562,     4194304,     4082490,    -7559795,
       // Scale Factors
      1,1,1;

    .VAR    vad_peq_parameters_wb[] =
        3,          // NUM_STAGES_FIELD
        1,          // GAIN_EXPONENT_FIELD
        0.5,        // GAIN_MANTISA__FIELD
        // Coefficients.        Filter format: (b2,b1,b0,a2,a1)/2
      3597684,    -7593996,     4029366,     3454473,    -7592720,
      3621202,    -7734660,     4194304,     3639878,    -7733107,
      4126472,    -8041639,     4194304,     4107363,    -8020823,
       // Scale Factors
      1,1,1;

#endif   // uses_XXX_AGC

// ***************  Common Test Mode Control Structure **************************

   .CONST   $M.SET_MODE_GAIN.ADC_MANT                  0;
   .CONST   $M.SET_MODE_GAIN.ADC_EXP                   1;
   .CONST   $M.SET_MODE_GAIN.SCO_IN_MANT               2;
   .CONST   $M.SET_MODE_GAIN.SCO_IN_EXP                3;
   .CONST   $M.SET_MODE_GAIN.STRUC_SIZE                4;

   .VAR     ModeControl[$M.SET_MODE_GAIN.STRUC_SIZE];

   .VAR passthru_rcv_gain[$M.audio_proc.stream_gain.STRUC_SIZE] =
      &stream_map_rcvin,                           // OFFSET_INPUT_PTR
      0,                                           // OFFSET_OUTPUT_PTR  <set in passthrough & loopback>
      &ModeControl + $M.SET_MODE_GAIN.SCO_IN_MANT, // OFFSET_PTR_MANTISSA
      &ModeControl + $M.SET_MODE_GAIN.SCO_IN_EXP;  // OFFSET_PTR_EXPONENT

   .VAR/DM1 passthru_snd_gain[$M.audio_proc.stream_gain.STRUC_SIZE] =
      &stream_map_sndin,                        // OFFSET_INPUT_PTR
      0,                                        // OFFSET_OUTPUT_PTR     <set in passthrough & loopback>
      &ModeControl + $M.SET_MODE_GAIN.ADC_MANT, // OFFSET_PTR_MANTISSA
      &ModeControl + $M.SET_MODE_GAIN.ADC_EXP;  // OFFSET_PTR_EXPONENT

// ************************  Receive Side Processing   **************************

// SP.  OMS requires 3 frames for harmonicity (window is only 2 frame)
#if uses_RCV_NS
.CONST $RCV_HARMANCITY_HISTORY_EXTENSION  $M.CVC.Num_Samples_Per_Frame;
#else
.CONST $RCV_HARMANCITY_HISTORY_EXTENSION  0;
#endif

#if uses_RCV_FREQPROC

    // Analysis Filter Bank Config Block
    .VAR/DM2  bufdr_inp[$M.CVC.Num_FFT_Window + $RCV_HARMANCITY_HISTORY_EXTENSION];

   .VAR/DM1 RcvAnalysisBank[$M.filter_bank.Parameters.ONE_CHNL_BLOCK_SIZE] =
      CVC_BANK_CONFIG_RCVIN,           // OFFSET_CONFIG_OBJECT
      &stream_map_rcvin,               // CH1_PTR_FRAME
      &bufdr_inp+$RCV_HARMANCITY_HISTORY_EXTENSION, // OFFSET_CH1_PTR_HISTORY
      0,                               // CH1_BEXP
      &D_real,                         // CH1_PTR_FFTREAL
      &D_imag,                         // CH1_PTR_FFTIMAG
      0 ...;                           // No Channel Delay

   .VAR/DM2  bufdr_outp[$M.CVC.ADC_DAC_Num_SYNTHESIS_FB_HISTORY];

    // Syntheseis Filter Bank Config Block
   .VAR/DM2 RcvSynthesisBank[$M.filter_bank.Parameters.ONE_CHNL_BLOCK_SIZE] =
      CVC_BANK_CONFIG_RCVOUT,          // OFFSET_CONFIG_OBJECT
      &stream_map_rcvout,              // OFFSET_PTR_FRAME
      &bufdr_outp,                     // OFFSET_PTR_HISTORY
      &RcvAnalysisBank + $M.filter_bank.Parameters.OFFSET_BEXP,
      &E_real,                         // OFFSET_PTR_FFTREAL
      &E_imag,                         // OFFSET_PTR_FFTIMAG
      0 ...;
#endif

#if uses_RCV_NS
   // <start> of memory declared per instance of oms270
   .VAR rcvoms_G[$M.oms270.FFT_NUM_BIN];
   .VAR rcvoms_LpXnz[$M.oms270.FFT_NUM_BIN];
   .VAR rcvoms_state[$M.oms270.STATE_LENGTH];

   .VAR oms270rcv_obj[$M.oms270.STRUC_SIZE] =
        M_oms270_mode_object,  //$M.oms270.PTR_MODE_FIELD
        0,                      // $M.oms270.CONTROL_WORD_FIELD
        $M.CVC_HANDSFREE.CONFIG.RCVOMSBYP,
                                // $M.oms270.BYPASS_BIT_MASK_FIELD
        1,                      // $M.oms270.MIN_SEARCH_ON_FIELD
        1,                      // $M.oms270.HARM_ON_FIELD
        1,                      // $M.oms270.MMSE_LSA_ON_FIELD
        $M.CVC.Num_FFT_Window,  // $M.oms270.FFT_WINDOW_SIZE_FIELD
        &bufdr_inp,             // $M.oms270.PTR_INP_X_FIELD
        &D_real,                // $M.oms270.PTR_X_REAL_FIELD
        &D_imag,                // $M.oms270.PTR_X_IMAG_FIELD
        &RcvAnalysisBank + $M.filter_bank.Parameters.OFFSET_BEXP,
                                // $M.oms270.PTR_BEXP_X_FIELD
#if uses_AEQ
        &D_real,                // $M.oms270.PTR_Y_REAL_FIELD
        &D_imag,                // $M.oms270.PTR_Y_IMAG_FIELD
#else
        &E_real,                // $M.oms270.PTR_Y_REAL_FIELD
        &E_imag,                // $M.oms270.PTR_Y_IMAG_FIELD
#endif
        0xD00000,               // $M.oms270.INITIAL_POWER_FIELD
        &rcvLpX_queue,          // $M.oms270.LPX_QUEUE_START_FIELD
        &rcvoms_G,                 // $M.oms270.G_FIELD;
        &rcvoms_LpXnz,             // $M.oms270.LPXNZ_FIELD,
        &rcvoms_state,             // $M.oms270.PTR_STATE_FIELD
        &oms_scratch,           // $M.oms270.PTR_SCRATCH_FIELD
        0.036805582279178,       // $M.oms270.ALFANZ_FIELD  SP.  CHanged due to frame size
        0xFF13DE,               // $M.oms270.LALFAS_FIELD       SP.  Changed due to frame size
        0xFEEB01,               // $M.oms270.LALFAS1_FIELD      SP.  Changed due to frame size
        0.45,                   // $M.oms270.HARMONICITY_THRESHOLD_FIELD
        $M.oms270.NOISE_THRESHOLD,  // $M.oms270.VAD_THRESH_FIELD
        0.9,                    // $M.oms270.AGRESSIVENESS_FIELD
#if uses_AEQ                    // $M.oms270.PTR_TONE_FLAG_FIELD
        &AEQ_DataObject + $M.AdapEq.AEQ_POWER_TEST_FIELD,
#else
        0,
#endif
        0 ...;
#endif

   // wmsn: single kap for FE/BEX only
    .VAR/DM1 dac_upsample_dm1[$iir_resamplev2.OBJECT_SIZE_SNGL_STAGE] =
        &stream_map_rcvin,                     // INPUT_PTR_FIELD
        &stream_map_rcvout,                    // OUTPUT_PTR_FIELD
        &$M.iir_resamplev2.Up_2_Down_1.filter, // CONVERSION_OBJECT_PTR_FIELD
        -8,                                    // INPUT_SCALE_FIELD
        8,                                     // OUTPUT_SCALE_FIELD
        0,                                     // INTERMEDIATE_CBUF_PTR_FIELD
        0,                                     // INTERMEDIATE_CBUF_LEN_FIELD
        0 ...;


#if uses_DCBLOCK
   .VAR/DM2     sco_dc_block_dm1[PEQ_OBJECT_SIZE(1)] =  // 1 stage
      &stream_map_rcvin,               // PTR_INPUT_DATA_BUFF_FIELD
      &stream_map_rcvin,               // PTR_OUTPUT_DATA_BUFF_FIELD
      1,                               // MAX_STAGES_FIELD
      CVC_DCBLOC_PEQ_PARAM_PTR,        // PARAM_PTR_FIELD
      0 ...;
#endif

#if uses_RCV_PEQ
   .VAR/DM2 rcv_peq_dm2[PEQ_OBJECT_SIZE(MAX_NUM_PEQ_STAGES)] =
      &stream_map_rcvout,             // PTR_INPUT_DATA_BUFF_FIELD
      &stream_map_rcvout,             // PTR_OUTPUT_DATA_BUFF_FIELD
      MAX_NUM_PEQ_STAGES,             // MAX_STAGES_FIELD
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_RCV_PEQ_CONFIG,  // PARAM_PTR_FIELD
      0 ...;
#endif

   // Pre RCV AGC gain stage
   .VAR/DM1 rcvout_gain_dm2[$M.audio_proc.stream_gain.STRUC_SIZE] =
      &stream_map_rcvout,                       // OFFSET_INPUT_PTR
      &stream_map_rcvout,                       // OFFSET_OUTPUT_PTR
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_RCVGAIN_MANTISSA,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_RCVGAIN_EXPONENT;

#if uses_RCV_VAD
   .VAR/DM2 rcv_vad_peq[PEQ_OBJECT_SIZE(3)] =
      &stream_map_rcvin,                        // PTR_INPUT_DATA_BUFF_FIELD
      &vad_peq_output,                          // PTR_OUTPUT_DATA_BUFF_FIELD
      3,                                        // MAX_STAGES_FIELD
      CVC_VAD_PEQ_PARAM_PTR,                    // PARAM_PTR_FIELD
      0 ...;

   // RCV VAD
   .VAR/DM1 rcv_vad400[$M.vad400.OBJECT_SIZE_FIELD] =
      &vad_peq_output,     // INPUT_PTR_FIELD
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_RCV_VAD_ATTACK_TC, // Parameter Ptr
      0 ...;
#endif

#if uses_RCV_AGC
   // RCV AGC
   .VAR/DM rcv_agc400_dm[$M.agc400.STRUC_SIZE] =
      0,                   //OFFSET_SYS_CON_WORD_FIELD
      $M.CVC_HANDSFREE.CONFIG.RCVAGCBYP,           //OFFSET_BYPASS_BIT_MASK_FIELD
      $M.CVC_HANDSFREE.CONFIG.BYPASS_AGCPERSIST,   // OFFSET_BYPASS_PERSIST_FIELD
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_RCV_AGC_G_INITIAL, // OFFSET_PARAM_PTR_FIELD
      &stream_map_rcvout,  //OFFSET_PTR_INPUT_FIELD
      &stream_map_rcvout,  //OFFSET_PTR_OUTPUT_FIELD
      &rcv_vad400 + $M.vad400.FLAG_FIELD,
                           //OFFSET_PTR_VAD_VALUE_FIELD
      0x7FFFFF,            //OFFSET_HARD_LIMIT_FIELD
#if uses_AEQ               //OFFSET_PTR_TONE_FLAG_FIELD
      &AEQ_DataObject + $M.AdapEq.AEQ_POWER_TEST_FIELD,
#else
      0,
#endif
      0 ...;
#endif

#if uses_AEQ
   .VAR/DM aeq_band_pX[$M.AdapEq.Bands_Buffer_Length];
   .VAR/DM AEQ_DataObject[$M.AdapEq.STRUC_SIZE] =
      0,                                        // CONTROL_WORD_FIELD
      $M.CVC_HANDSFREE.CONFIG.AEQBYP,           // BYPASS_BIT_MASK_FIELD
      $M.CVC_HANDSFREE.CONFIG.BEXENA,           // BEX_BIT_MASK_FIELD
      $M.CVC.Num_FFT_Freq_Bins,                 // NUM_FREQ_BINS
      0x000000,                                 // BEX_NOISE_LVL_DISABLE
      &D_real,                                  // PTR_X_REAL_FIELD             2
      &D_imag,                                  // PTR_X_IMAG_FIELD             3
      &RcvAnalysisBank + $M.filter_bank.Parameters.OFFSET_BEXP,   // PTR_BEXP_X_FIELD             4
      &E_real,                                  // PTR_Z_REAL_FIELD             5
      &E_imag,                                  // PTR_Z_IMAG_FIELD             6
      6-1,                                      // LOW_INDEX_FIELD              7
      8,                                        // LOW_BW_FIELD                 8
      8388608/8,                                // LOW_INV_INDEX_DIF_FIELD      9
      19,                                       // MID_BW_FIELD                 10
      (8388608/19),                             // MID_INV_INDEX_DIF_FIELD      11
      24,                                       // HIGH_BW_FIELD                12
      (8388608/24),                             // HIGH_INV_INDEX_DIF_FIELD     13
      0,                                        // AEQ_EQ_COUNTER_FIELD         14
      267,                                      // AEQ_EQ_INIT_FRAME_FIELD      15
      0,                                        // AEQ_GAIN_LOW_FIELD           16
      0,                                        // AEQ_GAIN_HIGH_FIELD          17
      &rcv_vad400 + $M.vad400.FLAG_FIELD,       // VAD_AGC_FIELD                18
      0.001873243285618,                        // ALFA_A_FIELD                 19
      1.0-0.001873243285618,                    // ONE_MINUS_ALFA_A_FIELD       20
      0.001873243285618,                        // ALFA_D_FIELD                 21
      1.0-0.001873243285618,                    // ONE_MINUS_ALFA_D_FIELD       22
      0.036805582279178,                        // ALFA_ENV_FIELD               23
      1.0-0.036805582279178,                    // ONE_MINUS_ALFA_ENV_FIELD     24
      &aeq_band_pX,                             // PTR_AEQ_BAND_PX_FIELD        25
      0,                                        // STATE_FIELD                  26
#if uses_NSVOLUME
      &ndvc_dm1 + $M.NDVC_Alg1_0_0.OFFSET_CURVOLLEVEL,    // PTR_VOL_STEP_UP_FIELD        27
#else
      &$M.CVC.data.ZeroValue,
#endif
      1,                                        // VOL_STEP_UP_TH1_FIELD        28
      2,                                        // VOL_STEP_UP_TH2_FIELD        29
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_AEQ_LO_GOAL_LOW,   // PTR_GOAL_LOW_FIELD           30
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_AEQ_HI_GOAL_LOW,   // PTR_GOAL_HIGH_FIELD          31
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_BEX_TOTAL_ATT_LOW, // PTR_BEX_ATT_TOTAL_FIELD      32 wmsn: not used in WB
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_BEX_HI2_GOAL_LOW,  // PTR_BEX_GOAL_HIGH2_FIELD     33 wmsn: not used in WB
      0,                                        // BEX_PASS_LOW_FIELD           34 wmsn: not used in WB
      21771,                                    // BEX_PASS_HIGH_FIELD          35 wmsn: not used in WB
      14,                                       // MID1_INDEX_FIELD             36
      33,                                       // MID2_INDEX_FIELD             37
      57,                                       // HIGH_INDEX_FIELD             38
      98642,                                    // INV_AEQ_PASS_LOW_FIELD       39
      197283,                                   // INV_AEQ_PASS_HIGH_FIELD      40
      43541,                                    // AEQ_PASS_LOW_FIELD Q8.16     41
      21771,                                    // AEQ_PASS_HIGH_FIELD Q8.16    42
      544265,                                   // AEQ_POWER_TH_FIELD Q8.16     43
      0,                                        // AEQ_TONE_POWER_FIELD Q8.16   44
      -326559,                                  // AEQ_MIN_GAIN_TH_FIELD Q8.16  45
      326559,                                   // AEQ_MAX_GAIN_TH_FIELD Q8.16  46
      0,                                        // AEQ_POWER_TEST_FIELD         47
      &aeq_scratch;                             // PTR_SCRATCH_G_FIELD
#endif

   .VAR sco_in_pk_dtct[] =
      &stream_map_rcvin,           // PTR_INPUT_BUFFER_FIELD
      0;                           // PEAK_LEVEL

// ************************  Send Side Processing   **************************


#if !defined(AEC_HANNING_WINDOW)
.CONST $SND_HARMANCITY_HISTORY_OFFSET     $M.CVC.Num_Samples_Per_Frame;
.CONST $SND_HARMANCITY_HISTORY_EXTENSION  0;
#else // AEC_HANNING_WINDOW
.CONST $SND_HARMANCITY_HISTORY_OFFSET     0;
// SP.  OMS requires 3 frames for harmonicity (window is only 2 frame)
#if uses_SND2_NS
.CONST $SND_HARMANCITY_HISTORY_EXTENSION  $M.CVC.Num_Samples_Per_Frame;
#else
.CONST $SND_HARMANCITY_HISTORY_EXTENSION  0;
#endif
#endif // AEC_HANNING_WINDOW

   .VAR/DM1  bufd_inp[$M.CVC.AEC.Num_FFT_Window + $SND_HARMANCITY_HISTORY_EXTENSION];

   // Analysis Filter Bank Config Block
   .VAR/DM1 fba_send[$M.filter_bank.Parameters.ONE_CHNL_BLOCK_SIZE] =
      CVC_BANK_CONFIG_AEC,             // OFFSET_CONFIG_OBJECT
      &stream_map_sndin,               // CH1_PTR_FRAME
      &bufd_inp+$SND_HARMANCITY_HISTORY_EXTENSION,// OFFSET_CH1_PTR_HISTORY
      0,                               // BEXP
      &D_real,                         // CH1_PTR_FFTREAL
      &D_imag,                         // CH1_PTR_FFTIMAG
      0 ...;

   // Syntheseis Filter Bank Config Block
     .VAR/DM1  bufd_outp[($M.CVC.AEC.Num_FFT_Window + $M.CVC.Num_Samples_Per_Frame)];

   .VAR/DM2 SndSynthesisBank[$M.filter_bank.Parameters.ONE_CHNL_BLOCK_SIZE] =
      CVC_BANK_CONFIG_AEC,             // OFFSET_CONFIG_OBJECT
      &stream_map_sndout,              // OFFSET_PTR_FRAME
      &bufd_outp,                      // OFFSET_PTR_HISTORY
      &BExp_D,                         // OFFSET_PTR_BEXP
      &D_real,                         // OFFSET_PTR_FFTREAL
      &D_imag,                         // OFFSET_PTR_FFTIMAG
      0 ...;

#if uses_SND2_NS
   // <start> of memory declared per instance of oms270
   .VAR snd2oms_G[$M.oms270.FFT_NUM_BIN];
   .VAR snd2oms_LpXnz[$M.oms270.FFT_NUM_BIN];
   .VAR snd2oms_state[$M.oms270.STATE_LENGTH];

   .VAR oms270snd2_obj[$M.oms270.STRUC_SIZE] =
        M_oms270_mode_object,   //$M.oms270.PTR_MODE_FIELD
        0,                      // $M.oms270.CONTROL_WORD_FIELD
        $M.CVC_HANDSFREE.CONFIG.SND2OMSBYP,
                                // $M.oms270.BYPASS_BIT_MASK_FIELD
        1,                      // $M.oms270.MIN_SEARCH_ON_FIELD
        1,                      // $M.oms270.HARM_ON_FIELD
        1,                      // $M.oms270.MMSE_LSA_ON_FIELD
        $M.CVC.AEC.Num_FFT_Window,                    // $M.oms270.FFT_WINDOW_SIZE_FIELD
        &bufd_inp + $SND_HARMANCITY_HISTORY_OFFSET,   // $M.oms270.PTR_INP_X_FIELD
        &D_real,                // $M.oms270.PTR_X_REAL_FIELD
        &D_imag,                // $M.oms270.PTR_X_IMAG_FIELD
        &BExp_D,                // $M.oms270.PTR_BEXP_X_FIELD
        &D_real,                // $M.oms270.PTR_Y_REAL_FIELD
        &D_imag,                // $M.oms270.PTR_Y_IMAG_FIELD
        0xFF0000,               // $M.oms270.INITIAL_POWER_FIELD
        &snd2LpX_queue,         // $M.oms270.LPX_QUEUE_START_FIELD
        &snd2oms_G,             // $M.oms270.G_FIELD;
        &snd2oms_LpXnz,         // $M.oms270.LPXNZ_FIELD,
        &snd2oms_state,         // $M.oms270.PTR_STATE_FIELD
        &oms_scratch,           // $M.oms270.PTR_SCRATCH_FIELD
        0.036805582279178,      // $M.oms270.ALFANZ_FIELD       SP.  Changed due to frame size
        0xFF13DE,               // $M.oms270.LALFAS_FIELD       SP.  Changed due to frame size
        0xFEEB01,               // $M.oms270.LALFAS1_FIELD      SP.  Changed due to frame size
        0.45,                   // $M.oms270.HARMONICITY_THRESHOLD_FIELD
        $M.oms270.NOISE_THRESHOLD,  // $M.oms270.VAD_THRESH_FIELD
        1.0,                    // $M.oms270.AGRESSIVENESS_FIELD
        0, 0 ...;                      // $M.oms270.PTR_TONE_FLAG_FIELD

   .VAR wnr_obj[$M.oms270.wnr.STRUC_SIZE] =
         &$M.oms270.wnr.initialize.func,  // FUNC_WNR_INIT_FIELD
         &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_WNR_AGGR, // PTR_WNR_PARAM_FIELD
         &rcv_vad400 + $M.vad400.FLAG_FIELD, // PTR_RCVVAD_FLAG_FIELD
         &snd_vad400 + $M.vad400.FLAG_FIELD, // PTR_SNDVAD_FLAG_FIELD
         0 ...;
#endif

   // wmsn: single kap for FE/BEX only
    .VAR/DM1 adc_downsample_dm1[$iir_resamplev2.OBJECT_SIZE_SNGL_STAGE] =
        &stream_map_sndin,                  // INPUT_PTR_FIELD
        &stream_map_sndin,                  // OUTPUT_PTR_FIELD
        &$M.iir_resamplev2.Up_1_Down_2.filter,     // CONVERSION_OBJECT_PTR_FIELD
        -8,                                 // INPUT_SCALE_FIELD
        8,                                  // OUTPUT_SCALE_FIELD
        0,                                  // INTERMEDIATE_CBUF_PTR_FIELD
        0,                                  // INTERMEDIATE_CBUF_LEN_FIELD
        0 ...;


    .VAR/DM1 ref_downsample_dm1[$iir_resamplev2.OBJECT_SIZE_SNGL_STAGE] =
        &stream_map_refin,                  // INPUT_PTR_FIELD
        &stream_map_refin,                  // OUTPUT_PTR_FIELD
        &$M.iir_resamplev2.Up_1_Down_2.filter,     // CONVERSION_OBJECT_PTR_FIELD
        -8,                                 // INPUT_SCALE_FIELD
        8,                                  // OUTPUT_SCALE_FIELD
        0,                                  // INTERMEDIATE_CBUF_PTR_FIELD
        0,                                  // INTERMEDIATE_CBUF_LEN_FIELD
        0 ...;


#if uses_DCBLOCK

   .VAR/DM1 adc_dc_block_dm1[PEQ_OBJECT_SIZE(1)] =     // 1 stage
      &stream_map_sndin,               // PTR_INPUT_DATA_BUFF_FIELD
      &stream_map_sndin,               // PTR_OUTPUT_DATA_BUFF_FIELD
      1,                               // MAX_STAGES_FIELD
      CVC_DCBLOC_PEQ_PARAM_PTR,        // PARAM_PTR_FIELD
      0 ...;
#endif

   .VAR/DM1 mute_cntrl_dm1[$M.MUTE_CONTROL.STRUC_SIZE] =
      &stream_map_sndout,               // OFFSET_INPUT_PTR
      &$M.CVC_SYS.CurCallState,         // OFFSET_PTR_STATE
      $M.CVC_HANDSFREE.CALLST.MUTE;     // OFFSET_MUTE_VAL

#if uses_SND_PEQ
   // Parameteric EQ
   .VAR/DM2 snd_peq_dm2[PEQ_OBJECT_SIZE(MAX_NUM_PEQ_STAGES)] =
      &stream_map_sndout,             // PTR_INPUT_DATA_BUFF_FIELD
      &stream_map_sndout,             // PTR_OUTPUT_DATA_BUFF_FIELD
      MAX_NUM_PEQ_STAGES,             // MAX_STAGES_FIELD
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_SND_PEQ_CONFIG,  // PARAM_PTR_FIELD
      0 ...;
#endif

   // SND AGC Pre-Gain stage
   .VAR/DM1 out_gain_dm1[$M.audio_proc.stream_gain.STRUC_SIZE] =
      &stream_map_sndout,              // OFFSET_INPUT_PTR
      &stream_map_sndout,              // OFFSET_OUTPUT_PTR
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_SNDGAIN_MANTISSA,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_SNDGAIN_EXPONENT;

#if uses_SND_AGC
   // SND VAD
   .VAR/DM1 snd_vad400[$M.vad400.OBJECT_SIZE_FIELD] =
      &vad_peq_output,     // INPUT_PTR_FIELD
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_SND_VAD_ATTACK_TC, // Parameter Ptr
      0 ...;

   .VAR vad_hold[$M.CVC.vad_hold.STRUC_SIZE] =
      &snd_vad400 + $M.vad400.FLAG_FIELD, // PTR_VAD_FLAG_FIELD
      &rcv_vad400 + $M.vad400.FLAG_FIELD, // PTR_ECHO_FLAG_FIELD
      0,                                  // FLAG_FIELD
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_SND_AGC_ECHO_HOLD_TIME,    // HOLD_TIME_FRAMES_FIELD
      0 ...;

#endif

#if uses_SND_AGC

   .VAR/DM snd_vad_peq[PEQ_OBJECT_SIZE(3)] =   // 3 stages
      &stream_map_sndout,                       // PTR_INPUT_DATA_BUFF_FIELD
      &vad_peq_output,                          // PTR_OUTPUT_DATA_BUFF_FIELD
      3,                                        // MAX_STAGES_FIELD
      CVC_VAD_PEQ_PARAM_PTR,                    // PARAM_PTR_FIELD
      0 ...;

   // SND AGC
   .VAR/DM snd_agc400_dm[$M.agc400.STRUC_SIZE] =
      0,                   //OFFSET_SYS_CON_WORD_FIELD
      $M.CVC_HANDSFREE.CONFIG.SNDAGCBYP,  //OFFSET_BYPASS_BIT_MASK_FIELD
      0,                                 // OFFSET_BYPASS_PERSIST_FIELD
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_SND_AGC_G_INITIAL, // OFFSET_PARAM_PTR_FIELD
      &stream_map_sndout,  //OFFSET_PTR_INPUT_FIELD
      &stream_map_sndout,  //OFFSET_PTR_OUTPUT_FIELD
      &vad_hold + $M.CVC.vad_hold.FLAG_FIELD,
                           //OFFSET_PTR_VAD_VALUE_FIELD
      0x7FFFFF,            //OFFSET_HARD_LIMIT_FIELD
      0,                   //OFFSET_PTR_TONE_FLAG_FIELD
      0 ...;
#endif

#if uses_NSVOLUME
   // NDVC - Noise Controled Volume
   .VAR/DM1 ndvc_dm1[$M.NDVC_Alg1_0_0.BLOCK_SIZE + $M.NDVC_Alg1_0_0.MAX_STEPS] =
      0,                               // OFFSET_CONTROL_WORD
      $M.CVC_HANDSFREE.CONFIG.NDVCBYP, // OFFSET_BITMASK_BYPASS
      $M.NDVC_Alg1_0_0.MAX_STEPS,      // OFFSET_MAXSTEPS
      &snd2oms_LpXnz,                  // FROM OMS_270 LPXNZ
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_NDVC_HYSTERESIS,  // OFFSET_PTR_PARAMS
      0 ...;
#endif

   .VAR mic_in_pk_dtct[] =
      &stream_map_sndin,               // PTR_INPUT_BUFFER_FIELD
      0;                               // PEAK_LEVEL_PTR

   .VAR sco_out_pk_dtct[] =
      &stream_map_sndout,              // PTR_INPUT_BUFFER_FIELD
      0;                               // PEAK_LEVEL_PTR

#if uses_SND1_NS
   // <start> of memory declared per instance of oms270
   .VAR snd1oms_G[$M.oms270.FFT_NUM_BIN];
   .VAR snd1oms_LpXnz[$M.oms270.FFT_NUM_BIN];
   .VAR snd1oms_state[$M.oms270.STATE_LENGTH];
   .VAR oms270snd1_obj[$M.oms270.STRUC_SIZE] =
        M_oms270_mode_object,  // $M.oms270.PTR_MODE_FIELD
        0,                      // $M.oms270.CONTROL_WORD_FIELD
        0,                      // $M.oms270.BYPASS_BIT_MASK_FIELD
        1,                      // $M.oms270.MIN_SEARCH_ON_FIELD
        1,                      // $M.oms270.HARM_ON_FIELD
        1,                      // $M.oms270.MMSE_LSA_ON_FIELD
        $M.CVC.AEC.Num_FFT_Window,                    // $M.oms270.FFT_WINDOW_SIZE_FIELD
        &bufd_inp + $SND_HARMANCITY_HISTORY_OFFSET,   // $M.oms270.PTR_INP_X_FIELD
        &D_real,                // $M.oms270.PTR_X_REAL_FIELD
        &D_imag,                // $M.oms270.PTR_X_IMAG_FIELD
        &BExp_D,                // $M.oms270.PTR_BEXP_X_FIELD
        &E_real,                // $M.oms270.PTR_Y_REAL_FIELD
        &E_imag,                // $M.oms270.PTR_Y_IMAG_FIELD
        0xFF0000,               // $M.oms270.INITIAL_POWER_FIELD
        &snd1LpX_queue,         // $M.oms270.LPX_QUEUE_START_FIELD
        &snd1oms_G,             // $M.oms270.G_FIELD;
        &snd1oms_LpXnz,         // $M.oms270.LPXNZ_FIELD,
        &snd1oms_state,         // $M.oms270.PTR_STATE_FIELD
        &oms_scratch,           // $M.oms270.PTR_SCRATCH_FIELD
        0.036805582279178,       // $M.oms270.ALFANZ_FIELD      SP.  Changed due to frame size
        0xFF13DE,               // $M.oms270.LALFAS_FIELD       SP.  Changed due to frame size
        0xFEEB01,               // $M.oms270.LALFAS1_FIELD      SP.  Changed due to frame size
        0.45,                   // $M.oms270.HARMONICITY_THRESHOLD_FIELD
        $M.oms270.NOISE_THRESHOLD,  // $M.oms270.VAD_THRESH_FIELD
        1.0,                    // $M.oms270.AGRESSIVENESS_FIELD
        0, 0 ...;                      // $M.oms270.PTR_TONE_FLAG_FIELD
#endif


#if uses_AEC
   #define ref_param    CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_REF_DELAY
   #define aec_param    CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_CNG_Q
   #define nlp_param    CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_HD_THRESH_GAIN
   #define vad_aec      rcv_vad400 + $M.vad400.FLAG_FIELD

   #define nlp_scratch  $M.dm2_scratch
   #define D0           oms270snd2_obj + $M.oms270.PTR_X_REAL_FIELD

   .CONST $M.CVC.AEC_RER_AGGR                0;

   #define AEC_HF_FLAG                       (1)
#ifdef TAIL_LENGTH_60ms
//Build option for Qcc300x
   .CONST $AEC_FILTER_LENGTH		1;
#else 
   .CONST $AEC_FILTER_LENGTH		2;
#endif
   .CONST $M.CVC.AEC_Num_Primary_Taps        ($AEC_FILTER_LENGTH * $aec510_HF.Num_Primary_Taps);
   .CONST $M.CVC.AEC_Num_Auxillary_Taps      ($AEC_FILTER_LENGTH * $aec510_HF.Num_Auxillary_Taps);

   // AEC Reference
   .VAR/DM1CIRC ref_delay_buffer[Max_RefDelay_Sample + $aec510.fbc.wb.FILTER_SIZE];
   .VAR delay_cbuffer[$cbuffer.STRUC_SIZE] =
      LENGTH(ref_delay_buffer),  // size (Linear if 0)
      &ref_delay_buffer,         // read pointer
      &ref_delay_buffer;         // write pointer

   .VAR ref_delay_stream[$frmbuffer.STRUC_SIZE] =
      &delay_cbuffer,      // CBUFFER_PTR_FIELD
      &ref_delay_buffer,   // FRAME_PTR_FIELD
      0;                   // FRAME_SIZE_FIELD

   .VAR/DM2  bufx_inp[$M.CVC.AEC.Num_FFT_Window];
   .VAR/DM1 fba_ref[$aec510.filter_bank.Parameters.ONE_CHNL_BLOCK_SIZE] =
      CVC_BANK_CONFIG_AEC,             // OFFSET_CONFIG_OBJECT
      &stream_map_refin,               // PTR_FRAME
      &bufx_inp,                       // OFFSET_PTR_HISTORY
      0,                               // BEXP
      &X_real,                         // PTR_FFTREAL
      &X_imag,                         // PTR_FFTIMAG
      &ref_delay_stream,               // OFFSET_DELAY_STREAM_PTR
      &ref_param;                      // OFFSET_DELAY_PARAM_PTR

   .VAR FD_ref[] =
      &X_real,    // X real
      &X_imag,    // X image
      &BExp_X;

   // AEC scratch
   .BLOCK/DM2 $M.dm2_scratch;
      .VAR  Exp_Mts_adapt[2*$M.CVC.Num_FFT_Freq_Bins + 1];
      // L_RatSqGt - handsfree only
      .VAR  L_RatSqGt[$aec510.RER_dim];
      // DTC_decision - handsfree only
      .VAR rerdt_dtc[$M.CVC.Num_FFT_Freq_Bins];
   .ENDBLOCK;

   .VAR DTC_lin[$M.CVC.Num_FFT_Freq_Bins];
   .VAR/DM1 Dt_real[$aec510.RER_dim];
   .VAR/DM2 Dt_imag[$aec510.RER_dim];
   .VAR/DM AEC_Dt[] =  &Dt_real,  &Dt_imag,  0;

   // AEC states
   .VAR  RatFE[$aec510.RER_dim];
   .VAR  Gr_imag[$aec510.RER_dim];
   .VAR  L2absGr[$aec510.RER_dim];
   .VAR  Gr_real[$aec510.RER_dim];
   .VAR  LPwrD[$aec510.RER_dim];
   // Bin Reversed Ordering
   .VAR  SqGr[$aec510.RER_dim];

   .VAR  LPwrX0[$M.CVC.Num_FFT_Freq_Bins];
   .VAR  LpZ_nz[$M.CVC.Num_FFT_Freq_Bins];
   .VAR  LPwrX1[$M.CVC.Num_FFT_Freq_Bins];
   .VAR  Cng_Nz_Shape_Tab[$M.CVC.Num_FFT_Freq_Bins];

   // data for fnmls reference bank
   .VAR/DM1 RcvBuf_real[$M.CVC.Num_FFT_Freq_Bins * $M.CVC.AEC_Num_Primary_Taps];
   .VAR/DM2 RcvBuf_imag[$M.CVC.Num_FFT_Freq_Bins * $M.CVC.AEC_Num_Primary_Taps];
   .VAR BExp_X_buf[$M.CVC.AEC_Num_Primary_Taps+1];

   // data for 1st channel primary fnmls
   .VAR/DM2 Ga_real[$M.CVC.Num_FFT_Freq_Bins * $M.CVC.AEC_Num_Primary_Taps];
   .VAR/DM1 Ga_imag[$M.CVC.Num_FFT_Freq_Bins * $M.CVC.AEC_Num_Primary_Taps];
   .VAR BExp_Ga[$M.CVC.Num_FFT_Freq_Bins];

   // The Attenuation buffer needed to be pulled out of scratch memory,
   // since the data needed by the CNG was being corrupted by other modules.
   .VAR  AttenuationPersist[$M.CVC.Num_FFT_Freq_Bins];

   // data for auxiliary fnmls
  .VAR/DM2 Gb_real[$aec510.RER_dim * $M.CVC.AEC_Num_Auxillary_Taps];
  .VAR/DM1 Gb_imag[$aec510.RER_dim * $M.CVC.AEC_Num_Auxillary_Taps];
  .VAR BExp_Gb[$aec510.RER_dim];
  .VAR L_RatSqG[$aec510.RER_dim];

   // FBC data
   .VAR/DM2 g_a[$aec510.fbc.wb.FILTER_SIZE];
   .VAR/DM2 g_b[$aec510.fbc.wb.FILTER_SIZE];
   .VAR/DM1 cbuf_x_hi[$M.CVC.Num_Samples_Per_Frame + $aec510.fbc.wb.FILTER_SIZE];
   .VAR/DM1 cbuf_d_hi[$M.CVC.Num_Samples_Per_Frame];
   .VAR/DM1 cbuf_x_delay[$aec510.fbc.HFP_B_SZIE];
   .VAR/DM1 cbuf_d_delay[$aec510.fbc.HFP_B_SZIE];
   .BLOCK/DM fbc_hpf_streams;
      .VAR hpf.buf_d_delay[] = 
         LENGTH(cbuf_d_delay),   // size (Linear if 0)
         &cbuf_d_delay,          // base
         &cbuf_d_delay;          // entry
      .VAR hpf.buf_d_hi[] = 
         LENGTH(cbuf_d_hi),      // size (Linear if 0)
         &cbuf_d_hi,             // base
         &cbuf_d_hi;             // entry
      .VAR hpf.buf_x_delay[] = 
         LENGTH(cbuf_x_delay),   // size (Linear if 0)
         &cbuf_x_delay,          // base
         &cbuf_x_delay;          // entry
      .VAR hpf.buf_x_hi[] = 
         LENGTH(cbuf_x_hi),      // size (Linear if 0)
         &cbuf_x_hi,             // base
         &cbuf_x_hi;             // entry
   .ENDBLOCK;

   .VAR fbc0_obj[$aec510.fbc.STRUCT_SIZE] =
         &stream_map_sndin,               // STREAM_D_FIELD
         &ref_delay_stream,               // STREAM_X_FIELD
         &vad_aec,                        // PTR_VADX_FIELD
         &g_a,                            // G_A_FIELD
         &g_b,                            // G_B_FIELD
         $aec510.fbc.PERD,                // PERD_FIELD
         $aec510.fbc.NIBBLE,              // NIBBLE_FIELD
         &fbc_hpf_streams,                // HPF_STREAM_FIELD
         0 ...;

   // AEC main data object
   .VAR aec_obj[$aec510.STRUCT_SIZE] =
         // AEC configuration and control
         &aec_mode_object,                   // $aec510.MODE_FIELD
         &aec_param,                         // $aec510.PARAM_FIELD
         $M.CVC.AEC_RER_AGGR,                // $aec510.RER_AGGR_FIELD
         &snd1oms_G,                         // $aec510.OMS_G_FIELD
         // AEC reference
         &FD_ref,                            // $aec510.X_FIELD
         &RcvBuf_real,                       // $aec510.XBUF_REAL_FIELD
         &RcvBuf_imag,                       // $aec510.XBUF_IMAG_FIELD
         &BExp_X_buf,                        // $aec510.XBUF_BEXP_FIELD
         // AEC FBC (left channel)
         &fbc0_obj,                          // $aec510.PTR_FBC_OBJ_FIELD
         // AEC primary LMS (left channel)
         &D0,                                // $aec510.D_FIELD
         &Ga_real,                           // $aec510.GA_REAL_FIELD
         &Ga_imag,                           // $aec510.GA_IMAG_FIELD
         &BExp_Ga,                           // $aec510.GA_BEXP_FIELD
         // AEC (right channel)
         0,                                  // $aec510.DM_OBJ_FIELD
         // Prep
         &LPwrX0,                            // $aec510.LPWRX0_FIELD
         &LPwrX1,                            // $aec510.LPWRX1_FIELD
         // DTC
         &RatFE,                             // $aec510.RATFE_FIELD
         // RER
         &Gr_imag,                           // $aec510.RER_GR_IMAG_FIELD
         &Gr_real,                           // $aec510.RER_GR_REAL_FIELD
         &SqGr,                              // $aec510.RER_SQGR_FIELD
         &L2absGr,                           // $aec510.RER_L2ABSGR_FIELD
         &LPwrD,                             // $aec510.RER_LPWRD_FIELD
         // CNG
         &snd2oms_G,                         // $aec510.CNG_OMS_G_FIELD
         &snd1oms_LpXnz,                     // $aec510.CNG_OMS_LPDNZ_FIELD
         &LpZ_nz,                            // $aec510.CNG_LPZNZ_FIELD
         &Cng_Nz_Shape_Tab,                  // $aec510.CNG_CUR_NZ_TABLE_FIELD
         // Scratch Arrays
         &L_adaptA,                          // $aec510.SCRPTR_LADAPTA_FIELD
         &Exp_Mts_adapt,                     // $aec510.SCRPTR_EXP_MTS_ADAPT_FIELD
         &AttenuationPersist,                // $aec510.SCRPTR_ATTENUATION_FIELD
         &W_ri,                              // $aec510.SCRPTR_W_RI_FIELD
         &L_adaptR,                          // $aec510.SCRPTR_LADAPTR_FIELD
         &DTC_lin,                           // $aec510.SCRPTR_DTC_LIN_FIELD
         &AEC_Dt,                            // $aec510.SCRPTR_T_FIELD
         // RERDT
         &rerdt_dtc,                         // $aec510.SCRPTR_RERDT_DTC_FIELD
         // AEC Auxiliary LMS
         &Gb_real,                           // $aec510.GB_REAL_FIELD
         &Gb_imag,                           // $aec510.GB_IMAG_FIELD
         &BExp_Gb,                           // $aec510.GB_BEXP_FIELD
         &L_RatSqG,                          // $aec510.L_RATSQG_FIELD
         AEC_HF_FLAG,                        // $aec510.HF_FLAG_FIELD
         0 ...;

   // AEC NLP data object
   .VAR vsm_fdnlp[$aec510.nlp.STRUCT_SIZE] =
         &aec_obj,                           // AEC_OBJ_PTR
         &nlp_param,                         // OFFSET_PARAM_PTR
         &ZeroValue,                         // OFFSET_CALLSTATE_PTR
         &vad_aec,                           // OFFSET_PTR_RCV_DETECT, only used for HD/HC
         &AttenuationPersist,                // OFFSET_SCRPTR_Attenuation
      #if uses_NONLINEAR_PROCESSING
         &nlp_scratch,                       // OFFSET_SCRPTR
         $aec510.FdnlpProcess,               // FDNLP_FUNCPTR
         $aec510.VsmProcess,                 // VSM_FUNCPTR
      #endif
         0 ...;
#endif


#if uses_SSR
// for feature extraction
   .VAR/DM fbankCoeffs[$M.SSR.NUM_FILTERS];
   .VAR/DM mfcCoeffs[$M.SSR.MFCC_ORDER+1];               // 1 extra for c0

// Viterbi decoder storage
   .VAR/DM obs[$M.SSR.OBS_SIZE];
   .VAR/DM obs_regress[$M.SSR.NPARAMS*$M.SSR.REGRESS_COLS];     // NPARAMS x (2*DELTAWIN+1) : TODO if no deltas, should not allocate regress
   .VAR/DM partial_like[$M.SSR.NMODELS*$M.SSR.NSTATES];         // NMODELS x NSTATES        : current frame (prev for the purpose of computing the patial scores)
   .VAR/DM partial_like_next[$M.SSR.NMODELS*$M.SSR.NSTATES];    // NMODELS x NSTATES        : next frame (current for the purpose of computing outputProb)
   .VAR/DM nr_best_frames[$M.SSR.NMODELS-1];

   // Private instance structure for ASR Viterbi decoder
   .VAR asr_decoder[$M.SSR.DECODER_STRUCT.BLOCK_SIZE ] =
         0,                         // HMM_SET_OFFSET
         0,                         // FINISH_OFFSET
         0,                         // RESET_OFFSET
         0,                         // BEST_WORD_OFFSET
         0,                         // BEST_SCORE_OFFSET
         0,                         // BEST_STATE_OFFSET
         &obs,                      // OBS_OFFSET
         &obs_regress,              // OBS_REGRESS_OFFSET
         0,                         // LOG_ENERGY_OFFSET
         0,                         // CONFIDENCE_SCORE_OFFSET
         &nr_best_frames,           // NR_BEST_FRAMES_OFFSET
         0,                         // SUCC_STA_CNT_OFFSET
         0,                         // NR_MAIN_STATE_OFFSET
         0,                         // FINISH_CNT_OFFSET
         0,                         // RELIABILITY_OFFSET
         0,                         // DECODER_STARTED_OFFSET
         0,                         // FRAME_COUNTER_OFFSET
         0,                         // VOICE_GONE_CNT_OFFSET
         0,                         // AFTER_RESET_CNT_OFFSET
         0,                         // SCORE_OFFSET
         0,                         // SUM_RELI_OFFSET
         0,                         // NOISE_ESTIMATE_OFFSET
         0,                         // NOISE_FRAME_COUNTER_OFFSET
         0,                         // INITIALIZED_OFFSET
         &fbankCoeffs,              // FBANK_COEFFS_OFFSET
         &mfcCoeffs,                // MFC_COEFFS_OFFSET
         &partial_like,             // PARTIAL_LIKE_OFFSET
         &partial_like_next;        // PARTIAL_LIKE_NEXT_OFFSET

   // Private pre-processing instance - input cbuffer, multi-bank FFT buffers, OMS exported variables
   // ASR public structure
   .VAR asr_obj[$M.SSR.SSR_STRUC.BLOCK_SIZE] =
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         0,
         &asr_decoder,
         &D_real,                                                 // FFT_REAL_OFFSET
         &D_imag,                                                 // FFT_IMAG_OFFSET
         &BExp_D,                                                 // SCALE_FACTOR_OFFSET
         &oms270ssr_obj + $M.oms270.VOICED_FIELD,                 // VOICED_OFFSET
         &snd2oms_G,                                               // GAIN_OFFSET
         &oms270ssr_obj + $M.oms270.LIKE_MEAN_FIELD,              // LIKE_MEAN_OFFSET
         &snd2oms_LpXnz;                                           // LPX_NZ_OFFSET

   .VAR oms270ssr_obj[$M.oms270.STRUC_SIZE] =
        M_oms270_mode_object,  //$M.oms270.PTR_MODE_FIELD
        0,                      // $M.oms270.CONTROL_WORD_FIELD
        $M.CVC_HANDSFREE.CONFIG.SND2OMSBYP,
                                // $M.oms270.BYPASS_BIT_MASK_FIELD
        1,                      // $M.oms270.MIN_SEARCH_ON_FIELD
        1,                      // $M.oms270.HARM_ON_FIELD
        1,                      // $M.oms270.MMSE_LSA_ON_FIELD
        $M.CVC.AEC.Num_FFT_Window,                    // $M.oms270.FFT_WINDOW_SIZE_FIELD
        &bufd_inp + $SND_HARMANCITY_HISTORY_OFFSET,   // $M.oms270.PTR_INP_X_FIELD
        &D_real,                // $M.oms270.PTR_X_REAL_FIELD
        &D_imag,                // $M.oms270.PTR_X_IMAG_FIELD
        &BExp_D,                // $M.oms270.PTR_BEXP_X_FIELD
        &E_real,                // $M.oms270.PTR_Y_REAL_FIELD
        &E_imag,                // $M.oms270.PTR_Y_IMAG_FIELD
        0xFF0000,               // $M.oms270.INITIAL_POWER_FIELD
        &snd2LpX_queue,          // $M.oms270.LPX_QUEUE_START_FIELD
        &snd2oms_G,             // $M.oms270.G_FIELD;
        &snd2oms_LpXnz,         // $M.oms270.LPXNZ_FIELD,
        &snd2oms_state,         // $M.oms270.PTR_STATE_FIELD
        &oms_scratch,           // $M.oms270.PTR_SCRATCH_FIELD
        0.036805582279178,      // $M.oms270.ALFANZ_FIELD       SP.  Changed due to frame size
        0xFF13DE,               // $M.oms270.LALFAS_FIELD       SP.  Changed due to frame size
        0xFEEB01,               // $M.oms270.LALFAS1_FIELD      SP.  Changed due to frame size
        0.45,                   // $M.oms270.HARMONICITY_THRESHOLD_FIELD
        $M.oms270.NOISE_THRESHOLD,  // $M.oms270.VAD_THRESH_FIELD
        1.0,                    // $M.oms270.AGRESSIVENESS_FIELD
        0,                      // $M.oms270.PTR_TONE_FLAG_FIELD
        &rcv_vad400 + $M.vad400.FLAG_FIELD, // $M.oms270.PTR_RCVVAD_FLAG_FIELD
        &snd_vad400 + $M.vad400.FLAG_FIELD, // $M.oms270.PTR_SNDVAD_FLAG_FIELD
        0 ...;

   .VAR/DM1 ssr_muted=$M.CVC_HANDSFREE.CALLST.MUTE;

   .VAR/DM1 mute_ssr_dm1[$M.MUTE_CONTROL.STRUC_SIZE] =
      &stream_map_sndout,               // OFFSET_INPUT_PTR
      &ssr_muted,                       // OFFSET_PTR_STATE
      $M.CVC_HANDSFREE.CALLST.MUTE;       // OFFSET_MUTE_VAL
#endif


   // This gain is used in ASR mode when PEQ and AGC does not get called.
   .VAR/DM1 out_gain_asr[$M.audio_proc.stream_gain.STRUC_SIZE] =
      &stream_map_sndout,              // OFFSET_INPUT_PTR
      &stream_map_sndout,              // OFFSET_OUTPUT_PTR
      &OneValue,                       // OFFSET_PTR_MANTISSA
      &ZeroValue;                      // OFFSET_PTR_EXPONENT
   // -----------------------------------------------------------------------------

   // Parameter to Module Map
   .VAR/ADDR_TABLE_DM   ParameterMap[] =

#if uses_SND2_NS
   #if uses_SSR
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_HFK_CONFIG,      &oms270ssr_obj + $M.oms270.CONTROL_WORD_FIELD,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_OMS_HARMONICITY, &oms270ssr_obj + $M.oms270.HARM_ON_FIELD,
   #endif
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_HFK_CONFIG,      &oms270snd2_obj + $M.oms270.CONTROL_WORD_FIELD,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_OMS_HARMONICITY, &oms270snd2_obj + $M.oms270.HARM_ON_FIELD,
#endif

#if uses_RCV_NS
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_HFK_CONFIG,      &oms270rcv_obj + $M.oms270.CONTROL_WORD_FIELD,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_RCV_OMS_HFK_AGGR,&oms270rcv_obj + $M.oms270.AGRESSIVENESS_FIELD,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_OMS_HI_RES_MODE, &oms270rcv_obj + $M.oms270.HARM_ON_FIELD,
#endif

#if uses_RCV_AGC
      // RCV AGC parameters
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_HFK_CONFIG,         &rcv_agc400_dm + $M.agc400.OFFSET_SYS_CON_WORD_FIELD,
#endif

#if uses_NSVOLUME
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_HFK_CONFIG,           &ndvc_dm1 + $M.NDVC_Alg1_0_0.OFFSET_CONTROL_WORD,
#endif

#if uses_SND_PEQ
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_SND_PEQ_CONFIG,       &snd_peq_dm2 + $audio_proc.peq.NUM_STAGES_FIELD,
#endif

#if uses_RCV_PEQ
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_RCV_PEQ_CONFIG,       &rcv_peq_dm2 + $audio_proc.peq.NUM_STAGES_FIELD,
#endif

#if uses_SND_AGC
      // SND AGC parameters
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_HFK_CONFIG,         &snd_agc400_dm + $M.agc400.OFFSET_SYS_CON_WORD_FIELD,
#endif

#if uses_AEQ
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_HFK_CONFIG,             &AEQ_DataObject + $M.AdapEq.CONTROL_WORD_FIELD,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_BEX_NOISE_LVL_FLAGS,    &AEQ_DataObject + $M.AdapEq.BEX_NOISE_LVL_FLAGS,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_AEQ_ATK_TC,             &AEQ_DataObject + $M.AdapEq.ALFA_A_FIELD,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_AEQ_ATK_1MTC,           &AEQ_DataObject + $M.AdapEq.ONE_MINUS_ALFA_A_FIELD,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_AEQ_DEC_TC,             &AEQ_DataObject + $M.AdapEq.ALFA_D_FIELD,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_AEQ_DEC_1MTC,           &AEQ_DataObject + $M.AdapEq.ONE_MINUS_ALFA_D_FIELD,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_BEX_LOW_STEP,           &AEQ_DataObject + $M.AdapEq.BEX_PASS_LOW_FIELD,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_BEX_HIGH_STEP,          &AEQ_DataObject + $M.AdapEq.BEX_PASS_HIGH_FIELD,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_AEQ_POWER_TH,           &AEQ_DataObject + $M.AdapEq.AEQ_POWER_TH_FIELD,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_AEQ_MIN_GAIN,           &AEQ_DataObject + $M.AdapEq.AEQ_MIN_GAIN_TH_FIELD,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_AEQ_MAX_GAIN,           &AEQ_DataObject + $M.AdapEq.AEQ_MAX_GAIN_TH_FIELD,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_AEQ_VOL_STEP_UP_TH1,    &AEQ_DataObject + $M.AdapEq.VOL_STEP_UP_TH1_FIELD,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_AEQ_VOL_STEP_UP_TH2,    &AEQ_DataObject + $M.AdapEq.VOL_STEP_UP_TH2_FIELD,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_AEQ_LOW_STEP,           &AEQ_DataObject + $M.AdapEq.AEQ_PASS_LOW_FIELD,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_AEQ_LOW_STEP_INV,       &AEQ_DataObject + $M.AdapEq.INV_AEQ_PASS_LOW_FIELD,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_AEQ_HIGH_STEP,          &AEQ_DataObject + $M.AdapEq.AEQ_PASS_HIGH_FIELD,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_AEQ_HIGH_STEP_INV,      &AEQ_DataObject + $M.AdapEq.INV_AEQ_PASS_HIGH_FIELD,

      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_AEQ_LOW_BAND_INDEX,     &AEQ_DataObject + $M.AdapEq.LOW_INDEX_FIELD,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_AEQ_LOW_BANDWIDTH,      &AEQ_DataObject + $M.AdapEq.LOW_BW_FIELD,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_AEQ_LOG2_LOW_BANDWIDTH, &AEQ_DataObject + $M.AdapEq.LOG2_LOW_INDEX_DIF_FIELD,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_AEQ_MID_BANDWIDTH,      &AEQ_DataObject + $M.AdapEq.MID_BW_FIELD,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_AEQ_LOG2_MID_BANDWIDTH, &AEQ_DataObject + $M.AdapEq.LOG2_MID_INDEX_DIF_FIELD,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_AEQ_HIGH_BANDWIDTH,     &AEQ_DataObject + $M.AdapEq.HIGH_BW_FIELD,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_AEQ_LOG2_HIGH_BANDWIDTH,&AEQ_DataObject + $M.AdapEq.LOG2_HIGH_INDEX_DIF_FIELD,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_AEQ_MID1_BAND_INDEX,    &AEQ_DataObject + $M.AdapEq.MID1_INDEX_FIELD,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_AEQ_MID2_BAND_INDEX,    &AEQ_DataObject + $M.AdapEq.MID2_INDEX_FIELD,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_AEQ_HIGH_BAND_INDEX,    &AEQ_DataObject + $M.AdapEq.HIGH_INDEX_FIELD,
#endif

#if uses_PLC
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_PLC_STAT_INTERVAL,      &$sco_data.object + $sco_pkt_handler.STAT_LIMIT_FIELD,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_HFK_CONFIG,             &$sco_data.object + $sco_pkt_handler.CONFIG_FIELD,
#endif

      // Auxillary Audio Settings
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_CLIP_POINT,           &$dac_out.auxillary_mix_op.param + $cbops.aux_audio_mix_op.CLIP_POINT_FIELD,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_BOOST_CLIP_POINT,     &$dac_out.auxillary_mix_op.param + $cbops.aux_audio_mix_op.BOOST_CLIP_POINT_FIELD,
     &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_BOOST,                &$dac_out.auxillary_mix_op.param + $cbops.aux_audio_mix_op.BOOST_FIELD,
#ifndef FILEIO
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_SCO_STREAM_MIX,       &$dac_out.auxillary_mix_op.param + $cbops.aux_audio_mix_op.PRIM_GAIN_FIELD,
      &CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_AUX_STREAM_MIX,       &$dac_out.auxillary_mix_op.param + $cbops.aux_audio_mix_op.AUX_GAIN_FIELD,
#endif
      // End of Parameter Map
      0;

   // Statistics from Modules sent via SPI
   // ------------------------------------------------------------------------
   .VAR/ADDR_TABLE_DM StatisticsPtrs[]= //[$M.CVC_HANDSFREE.STATUS.BLOCK_SIZE+2] =
      $M.CVC_HANDSFREE.STATUS.BLOCK_SIZE,
      &StatisticsClrPtrs,
      &$M.CVC_SYS.cur_mode,
      &$M.CVC_SYS.CurCallState,
      &$M.CVC_SYS.SysControl,
      &$M.CVC_SYS.CurDAC,
      &$M.CVC_SYS.Last_PsKey,
      &$M.CVC_SYS.SecStatus,
      &$dac_out.spkr_out_pk_dtct,
      &mic_in_pk_dtct   + $M.audio_proc.peak_monitor.PEAK_LEVEL,
      &sco_in_pk_dtct   + $M.audio_proc.peak_monitor.PEAK_LEVEL,
      &sco_out_pk_dtct  + $M.audio_proc.peak_monitor.PEAK_LEVEL,
      &$M.CVC.app.scheduler.tasks+$FRM_SCHEDULER.TOTAL_MIPS_FIELD,

#if uses_NSVOLUME
      &ndvc_dm1 + $M.NDVC_Alg1_0_0.OFFSET_FILTSUMLPDNZ,
      &ndvc_dm1 + $M.NDVC_Alg1_0_0.OFFSET_CURVOLLEVEL,
#else
      &ZeroValue,&ZeroValue,
#endif
      $dac_out.auxillary_mix_op.param + $cbops.aux_audio_mix_op.PEAK_AUXVAL_FIELD,
      &$M.CVC_MODULES_STAMP.CompConfig,
      &$M.CVC_SYS.Volume,
      &$M.CVC_SYS.ConnectStatus,                           // $M.CVC_HEADSET.STATUS.CONNSTAT
#if uses_PLC
      &$sco_data.object + $sco_pkt_handler.PACKET_LOSS_FIELD,    // PLC Loss Rate
#else
      &ZeroValue,
#endif
#if uses_AEQ
      &AEQ_DataObject + $M.AdapEq.AEQ_GAIN_LOW_FIELD,          // AEQ Gain Low
      &AEQ_DataObject + $M.AdapEq.AEQ_GAIN_HIGH_FIELD,         // AEQ Gain High
      &AEQ_DataObject + $M.AdapEq.STATE_FIELD,                 // AEQ State
      &AEQ_DataObject + $M.AdapEq.AEQ_POWER_TEST_FIELD,        // AEQ Tone Detection
      &AEQ_DataObject + $M.AdapEq.AEQ_TONE_POWER_FIELD,        // AEQ Tone Power
#else
      &ZeroValue,&ZeroValue,&ZeroValue,&ZeroValue,&ZeroValue,
#endif
#if uses_AEC
      &vsm_fdnlp + $aec510.nlp.OFFSET_HC_TIER_STATE,
      &aec_obj + $aec510.OFFSET_AEC_COUPLING,
      &fbc0_obj + $aec510.fbc.L2P_PWR_DIFFERENCE_FIELD,
#else
      &ZeroValue,&ZeroValue,
#endif
#if uses_RCV_VAD
      &rcv_vad400 + $M.vad400.FLAG_FIELD,
#else
      &ZeroValue,
#endif
#if uses_SND_AGC
      &snd_agc400_dm + $M.agc400.OFFSET_INPUT_LEVEL_FIELD,   // AGC SPeach Power Level
      &snd_agc400_dm + $M.agc400.OFFSET_G_REAL_FIELD,        // AGC Applied Gain
#else
      &OneValue,&OneValue,
#endif

#if uses_RCV_AGC
      &rcv_agc400_dm + $M.agc400.OFFSET_INPUT_LEVEL_FIELD,   // AGC SPeach Power Level (Q8.16 log2 power)
      &rcv_agc400_dm + $M.agc400.OFFSET_G_REAL_FIELD,        // AGC Applied Gain (Q6.17 linear gain [0 - 64.0])
#else
      &OneValue,&OneValue,
#endif

#if uses_SND2_NS
    &wnr_obj + $M.oms270.wnr.POWER_LEVEL_FIELD,         // WNR Power Level (Q8.16 log2 power)
    &oms270snd2_obj + $M.oms270.WIND_FIELD,  // WIND FLAG 
#else
    &OneValue, 
    &ZeroValue,
#endif
    // Resampler related stats - SPTBD - add to XML
    $M.audio_config.audio_if_mode,
    $M.audio_config.adc_sampling_rate,
    $M.audio_config.dac_sampling_rate,
    $M.FrontEnd.frame_adc_sampling_rate,
    &$M.CVC_SYS.dsp_volume_flag,
    &$M.CVC_SYS.dsp_volume_stat;

// Clear These statistics
.VAR/ADDR_TABLE_DM StatisticsClrPtrs[] =
      &$dac_out.spkr_out_pk_dtct,
      &mic_in_pk_dtct   + $M.audio_proc.peak_monitor.PEAK_LEVEL,
      &sco_in_pk_dtct   + $M.audio_proc.peak_monitor.PEAK_LEVEL,
      &sco_out_pk_dtct  + $M.audio_proc.peak_monitor.PEAK_LEVEL,
      $dac_out.auxillary_mix_op.param + $cbops.aux_audio_mix_op.PEAK_AUXVAL_FIELD,
      0;

   // Processing Tables
   // ----------------------------------------------------------------------------
   .VAR/DM ReInitializeTable[] =

      // Function                                           r7                 r8
      // only for FE/BEX
      $frame.iir_resamplev2.Initialize,                  &adc_downsample_dm1, 0 ,
      $frame.iir_resamplev2.Initialize,                  &ref_downsample_dm1,   0 ,
      $frame.iir_resamplev2.Initialize,                  &dac_upsample_dm1,   0 ,

      $filter_bank.one_channel.analysis.initialize,  &fft_obj,         &fba_send,
      $filter_bank.one_channel.synthesis.initialize, &fft_obj,         &SndSynthesisBank,

#if uses_RCV_FREQPROC
      $filter_bank.one_channel.analysis.initialize,  &fft_obj,         &RcvAnalysisBank,
      $filter_bank.one_channel.synthesis.initialize, &fft_obj,     &RcvSynthesisBank,
#if uses_RCV_NS
      $M.oms270.initialize.func,           &oms270rcv_obj,           0,
#endif
#if uses_AEQ
     $M.AdapEq.initialize.func,                0,                 &AEQ_DataObject,
#endif
#endif

#if uses_SND1_NS
      $M.oms270.initialize.func,                &oms270snd1_obj,     0,
#endif

#if uses_SND2_NS
      $M.oms270.initialize.func,                &oms270snd2_obj,     &wnr_obj,
#endif

#if uses_AEC
      $aec510.filter_bank.analysis.initialize,  &fft_obj,   &fba_ref,
      $aec510.initialize,                 $cvc.init.aec510,       &aec_obj,
      $aec510.nlp.initialize,             $cvc.init.vsm_fdnlp,    &vsm_fdnlp,
      $cvc.reset_cbuffer,                 &stream_map_rcvin,      0,
      $cvc.reset_cbuffer,                 &stream_map_rcvout,     0,
      $cvc.reset_cbuffer,                 &stream_map_refin,      0,
      $cvc.reset_cbuffer,                 &stream_map_sndin,      0,
      $cvc.reset_cbuffer,                 &stream_map_sndout,     0,
#endif

#if uses_SSR
   $M.oms270.initialize.func,             &oms270ssr_obj,               0,
   $M.wrapper.ssr.initialize,             &asr_obj,                     0,
   $purge_cbuffer,                        &$dac_out.cbuffer_struc,      0,
#endif

#if uses_DCBLOCK
      $audio_proc.peq.initialize,          &adc_dc_block_dm1,        0,
      $audio_proc.peq.initialize,          &sco_dc_block_dm1,        0,
#endif

#if uses_SND_PEQ
      $audio_proc.peq.initialize,     &snd_peq_dm2,                  0,
#endif

#if uses_RCV_PEQ
      $audio_proc.peq.initialize,     &rcv_peq_dm2,                 0,
#endif


#if uses_RCV_VAD
      $audio_proc.peq.initialize,          &rcv_vad_peq,             0,
      $M.vad400.initialize.func,           &rcv_vad400,          0,
#endif
#if uses_RCV_AGC
      $M.agc400.initialize.func,           0,                        &rcv_agc400_dm,
#endif

#if uses_NSVOLUME
      $M.NDVC_alg1_0_0.Initialize.func,   &ndvc_dm1,                    0,
#endif

#if uses_SND_AGC
      $audio_proc.peq.initialize,         &snd_vad_peq,                 0,
      $M.vad400.initialize.func,          &snd_vad400,                  0,
      $M.agc400.initialize.func,                0,                 &snd_agc400_dm,
#endif

      0;                                    // END OF TABLE


   .VAR/DM FilterResetTable[] =

      // Function                           r7                          r8

#if uses_DCBLOCK
      $audio_proc.peq.zero_delay_data,      &adc_dc_block_dm1,          0,
      $audio_proc.peq.zero_delay_data,      &sco_dc_block_dm1,          0,
#endif

#if uses_SND_PEQ
      $audio_proc.peq.zero_delay_data,      &snd_peq_dm2,               0,
#endif

#if uses_RCV_PEQ
      $audio_proc.peq.zero_delay_data,      &rcv_peq_dm2,               0,
#endif

#if uses_RCV_VAD
      $audio_proc.peq.zero_delay_data,      &rcv_vad_peq,               0,
#endif

#if uses_SND_AGC
      $audio_proc.peq.zero_delay_data,      &snd_vad_peq,               0,
#endif

      0;                                    // END OF TABLE


   // -------------------------------------------------------------------------------
   // Table of functions for current mode
   .VAR ModeProcTableSnd[$M.CVC_HANDSFREE.SYSMODE.MAX_MODES] =
      &copy_proc_funcsSnd,              // undefined state
      &hfk_proc_funcsSnd,               // hfk mode
#if uses_SSR
      &ssr_proc_funcsSnd,               // ssr mode
#else
      &copy_proc_funcsSnd,              // undefined mode
#endif
      &copy_proc_funcsSnd,             // pass-thru mode
      &copy_proc_funcsLpbk,             // loop-back mode
      &copy_proc_funcsSnd;              // standby-mode

   .VAR ModeProcTableRcv[$M.CVC_HANDSFREE.SYSMODE.MAX_MODES] =
      &copy_proc_funcsRcv,              // undefined state
      &hfk_proc_funcsRcv,               // hfk mode
      &hfk_proc_funcsRcv,               // ns mode
      &copy_proc_funcsRcv,              // pass-thru mode
      0,                                // loop-back mode       // SP. Loopback does all processing in Send
      &copy_proc_funcsRcv;              // standby-mode


   // -----------------------------------------------------------------------------
   .VAR/DM hfk_proc_funcsRcv[] =
      // Function                               r7                   r8

      $frame_sync.distribute_streams_ind,      &rcv_process_streams,  0,

#if uses_DCBLOCK
      $audio_proc.peq.process,                  &sco_dc_block_dm1,      0,
#endif

      $M.audio_proc.peak_monitor.Process.func,  &sco_in_pk_dtct,        0,

#if uses_RCV_VAD
      $audio_proc.peq.process,                  &rcv_vad_peq,           0,
      $M.vad400.process.func,                   &rcv_vad400,        0,
#endif

#if uses_RCV_FREQPROC
      $filter_bank.one_channel.analysis.process, &fft_obj,   &RcvAnalysisBank,

#if uses_AEQ
      $M.AdapEq.process.tone_detect,            0,                   &AEQ_DataObject,
#endif

#if uses_RCV_NS
      $M.oms270.process.func,                   &oms270rcv_obj,         0,
      $M.oms270.apply_gain.func,                &oms270rcv_obj,         0,
#endif

#if uses_AEQ
      $M.AdapEq.process.func,                   0,                   &AEQ_DataObject,
#endif

      // wmsn: for NB/WB only, not for FE/BEX
      $cvc.non_fe.Zero_DC_Nyquist,              &E_real,              &E_imag,

      $filter_bank.one_channel.synthesis.process, &fft_obj,   &RcvSynthesisBank,
#else
      // SP.  No Freq domain processing, need explicit upsampling to 16 kHz
      // wmsn: only for FE/BEX
      $cvc.fe.frame_resample_process,         &dac_upsample_dm1, 0 ,
#endif

#if uses_RCV_PEQ
      // wmsn: for NB/FE only (not WB)
      $cvc.rcv_peq.process,                     &rcv_peq_dm2,           0,
#endif

      $M.audio_proc.stream_gain.Process.func,   &rcvout_gain_dm2,       0,

#if uses_RCV_AGC
      $M.agc400.process.func,                       0,              &rcv_agc400_dm,
#endif

#if uses_RCV_PEQ
      // wmsn: for WB only
      $cvc.rcv_peq.process_wb,                  &rcv_peq_dm2,           0,
#endif

      $frame_sync.update_streams_ind,            &rcv_process_streams, 0,

      0;                                     // END OF TABLE
   // -----------------------------------------------------------------------------

 .VAR/DM hfk_proc_funcsSnd[] =
      // Function                               r7                   r8
      $frame_sync.distribute_streams_ind,      &snd_process_streams,  0,

      // only for FE/BEX
      $cvc.fe.frame_resample_process,         &adc_downsample_dm1, 0 ,
      $cvc.fe.frame_resample_process,         &ref_downsample_dm1, 0 ,

#if uses_DCBLOCK
      $audio_proc.peq.process,                  &adc_dc_block_dm1,      0,
#endif

      $M.audio_proc.peak_monitor.Process.func,  &mic_in_pk_dtct,        0,

#if uses_AEC
      $cvc.aec_ref.filter_bank.analysis,        &fft_obj,            &fba_ref,
      $aec510.fbc.process,                      0,                   &aec_obj,
#endif

      $filter_bank.one_channel.analysis.process, &fft_obj,           &fba_send,

#if uses_SND1_NS
      $M.oms270.process.func,                   &oms270snd1_obj,     0,
#endif

#if uses_AEC
      $aec510.process,                          $cvc.mc.aec510,      &aec_obj,
#endif

#if uses_SND2_NS
      $M.oms270.process.func,                   &oms270snd2_obj,     0,
      $M.oms270.apply_gain.func,                &oms270snd2_obj,     0,
#endif

#if uses_AEC
   #if (uses_HOWLING_CONTROL || uses_NONLINEAR_PROCESSING)
      $aec510.nlp.process,                      $cvc.mc.aec510,      &vsm_fdnlp,
   #endif
      $aec510.cng.process,                      $cvc.mc.aec510,      &aec_obj,
#endif

      $M.CVC.Zero_DC_Nyquist.func,              &D_real,             &D_imag,
      $filter_bank.one_channel.synthesis.process, &fft_obj,   &SndSynthesisBank,

#if uses_NSVOLUME
      $M.NDVC_alg1_0_0.Process.func,            &ndvc_dm1,                  0,
#endif

#if uses_SND_PEQ
      $audio_proc.peq.process,                  &snd_peq_dm2,               0,
#endif

      $M.audio_proc.stream_gain.Process.func,   &out_gain_dm1,              0,

#if uses_SND_AGC
      $audio_proc.peq.process,                  &snd_vad_peq,               0,
      $M.vad400.process.func,                   &snd_vad400,                0,
      $M.vad_hold.process.func,                 &vad_hold,                 0,
      $M.agc400.process.func,                   0,                   &snd_agc400_dm,
#endif

      $M.MUTE_CONTROL.Process.func,             &mute_cntrl_dm1,            0,

      $M.audio_proc.peak_monitor.Process.func,  &sco_out_pk_dtct,        0,

      $frame_sync.update_streams_ind,            &snd_process_streams, 0,

      0;                                     // END OF TABLE

   // ----------------------------------------------------------------------------
#if uses_SSR // Simple Speech Recognition
   .VAR/DM ssr_proc_funcsSnd[] =
      // Function                               r7                      r8
      $frame_sync.distribute_streams_ind,       &snd_process_streams,   0,

      // only for FE/BEX
      $cvc.fe.frame_resample_process,         &adc_downsample_dm1, 0 ,
      $cvc.fe.frame_resample_process,         &ref_downsample_dm1, 0 ,

#if uses_DCBLOCK
      $audio_proc.peq.process,                  &adc_dc_block_dm1,      0,
#endif

      $M.audio_proc.peak_monitor.Process.func,  &mic_in_pk_dtct,        0,

      $filter_bank.one_channel.analysis.process, &fft_obj,              &fba_send,

#if uses_SND2_NS
      $M.oms270.process.func,                   &oms270ssr_obj,         0,
#endif

      // SP.  ASR uses oms data object
      $M.wrapper.ssr.process,                   &asr_obj,                 0,

      $M.MUTE_CONTROL.Process.func,             &mute_ssr_dm1,            0,

      $M.audio_proc.peak_monitor.Process.func,  &sco_out_pk_dtct,        0,

      $frame_sync.update_streams_ind,            &snd_process_streams,    0,
      0;                                     // END OF TABLE

#endif

   // -----------------------------------------------------------------------------
   .VAR/DM copy_proc_funcsSnd[] =
      // Function                               r7                   r8
      $frame_sync.distribute_streams_ind,        &snd_process_streams,  0,

      $cvc_Set_PassThroughGains,                &ModeControl,         0,

      // only for FE/BEX
      $cvc.fe.frame_resample_process,         &adc_downsample_dm1, 0 ,

      $M.audio_proc.peak_monitor.Process.func,  &mic_in_pk_dtct,      0,
      $M.audio_proc.stream_gain.Process.func,   &passthru_snd_gain,   0,
      $M.audio_proc.peak_monitor.Process.func,  &sco_out_pk_dtct,     0,

      $frame_sync.update_streams_ind,           &snd_process_streams,  0,
      0;                                     // END OF TABLE

   .VAR/DM copy_proc_funcsRcv[] =
      // Function                               r7                   r8
      $frame_sync.distribute_streams_ind,       &rcv_process_streams,  0,

      $cvc_Set_PassThroughGains,                &ModeControl,         0,

      $M.audio_proc.peak_monitor.Process.func,  &sco_in_pk_dtct,      0,
      $M.audio_proc.stream_gain.Process.func,   &passthru_rcv_gain,   0,

      // SP.  passthru_rcv_gain must be before passthru_snd_gain for loopback.
      // passthru_snd_gain overwrites rcv_in. upsample is from rcv_in to rcv_out
      // wmsn: only executed when FE/BEX
      $cvc.fe.frame_resample_process,         &dac_upsample_dm1, 0 ,

      $frame_sync.update_streams_ind,           &rcv_process_streams,  0,
      0;                                     // END OF TABLE

// -----------------------------------------------------------------------------
   .VAR/DM copy_proc_funcsLpbk[] =
      // Function                               r7                   r8
      $frame_sync.distribute_streams_ind,        &lpbk_process_streams,  0,

      $cvc_Set_LoopBackGains,                   &ModeControl,         0,

      $M.audio_proc.peak_monitor.Process.func,  &mic_in_pk_dtct,      0,
      $M.audio_proc.peak_monitor.Process.func,  &sco_in_pk_dtct,      0,
      $M.audio_proc.stream_gain.Process.func,   &passthru_snd_gain,   0,    // si --> ro
      $M.audio_proc.stream_gain.Process.func,   &passthru_rcv_gain,   0,    // ri --> so
      $M.audio_proc.peak_monitor.Process.func,  &sco_out_pk_dtct,     0,

      $frame_sync.update_streams_ind,           &lpbk_process_streams,  0,
      0;                                     // END OF TABLE

// ***************  Stream Definitions  ************************/
   // reference stream map
   .VAR  stream_map_refin[$framesync_ind.ENTRY_SIZE_FIELD] =
      $dac_out.reference_cbuffer_struc,         // $framesync_ind.CBUFFER_PTR_FIELD
      0,                                        // $framesync_ind.FRAME_PTR_FIELD
      0,                                        // $framesync_ind.CUR_FRAME_SIZE_FIELD
      $M.CVC.ADC_DAC_Num_Samples_Per_Frame,     // $framesync_ind.FRAME_SIZE_FIELD
      0,                                        // $framesync_ind.JITTER_FIELD     [--CONFIG--]
      $frame_sync.distribute_input_stream_ind,  // Distribute Function
      $frame_sync.update_input_streams_ind,     // Update Function
      0 ...;
    // SP.  Constant links.  Set in data objects
    //     &ref_downsample_dm1 + $iir_resamplev2.INPUT_1_START_INDEX_FIELD,
    //     &ref_downsample_dm1 + $iir_resamplev2.OUTPUT_1_START_INDEX_FIELD,


    //  &fba_ref + $M.filter_bank.Parameters.OFFSET_PTR_FRAME,




   // sndin stream map
   .VAR  stream_map_sndin[$framesync_ind.ENTRY_SIZE_FIELD] =
      $adc_in.cbuffer_struc,                    // $framesync_ind.CBUFFER_PTR_FIELD
      0,                                        // $framesync_ind.FRAME_PTR_FIELD
      0,                                        // $framesync_ind.CUR_FRAME_SIZE_FIELD
      $M.CVC.ADC_DAC_Num_Samples_Per_Frame,     // $framesync_ind.FRAME_SIZE_FIELD
      3,                                        // $framesync_ind.JITTER_FIELD
      $frame_sync.distribute_input_stream_ind,  // Distribute Function
      $frame_sync.update_input_streams_ind,     // Update Function
      0 ...;
    // SP.  Constant links.  Set in data objects
    //  &adc_downsample_dm1 + $iir_resamplev2.INPUT_1_START_INDEX_FIELD,
    //  &adc_downsample_dm1 + $iir_resamplev2.OUTPUT_1_START_INDEX_FIELD,
    //  &passthru_snd_gain + $M.audio_proc.stream_gain.OFFSET_INPUT_PTR,
    //  &adc_dc_block_dm1 + $audio_proc.peq.INPUT_ADDR_FIELD,
    //  &adc_dc_block_dm1 + $audio_proc.peq.OUTPUT_ADDR_FIELD,
    //  &fba_send + $M.filter_bank.Parameters.OFFSET_PTR_FRAME,
    //  &mic_in_pk_dtct + $M.audio_proc.peak_monitor.PTR_INPUT_BUFFER_FIELD,


    // sndout stream map.
   .VAR  stream_map_sndout[$framesync_ind.ENTRY_SIZE_FIELD] =
      0,                                        // $framesync_ind.CBUFFER_PTR_FIELD     [---CONFIG---]
      0,                                        // $framesync_ind.FRAME_PTR_FIELD
      0,                                        // $framesync_ind.CUR_FRAME_SIZE_FIELD
      $M.CVC.Num_Samples_Per_Frame,             // $framesync_ind.FRAME_SIZE_FIELD
      0,                                        // $framesync_ind.JITTER_FIELD
      $frame_sync.distribute_output_stream_ind, // Distribute Function
      $frame_sync.update_output_streams_ind,    // Update Function
      0 ...;
    // SP.  Constant links.  Set in data objects
    //  &passthru_snd_gain + $M.audio_proc.stream_gain.OFFSET_OUTPUT_PTR,
    //  &passthru_snd_gain + $M.audio_proc.stream_gain.OFFSET_OUTPUT_LEN,
    //  &SndSynthesisBank + $M.filter_bank.Parameters.OFFSET_PTR_FRAME,
    //  &out_gain_asr + $M.audio_proc.stream_gain.OFFSET_INPUT_PTR,
    //  &out_gain_asr + $M.audio_proc.stream_gain.OFFSET_OUTPUT_PTR,
    //  &out_gain_dm1 + $M.audio_proc.stream_gain.OFFSET_INPUT_PTR,
    //  &out_gain_dm1 + $M.audio_proc.stream_gain.OFFSET_OUTPUT_PTR,
    //  &snd_vad_peq + $audio_proc.peq.INPUT_ADDR_FIELD,
    //  &snd_agc400_dm + $M.agc400.OFFSET_PTR_INPUT_FIELD,
    //  &snd_agc400_dm + $M.agc400.OFFSET_PTR_OUTPUT_FIELD,
    //  &snd_peq_dm2 + $audio_proc.peq.OUTPUT_ADDR_FIELD,
    //  &snd_peq_dm2 + $audio_proc.peq.INPUT_ADDR_FIELD,
    //  &mute_cntrl_dm1 + $M.MUTE_CONTROL.OFFSET_INPUT_PTR,
    //  &sco_out_pk_dtct + $M.audio_proc.peak_monitor.PTR_INPUT_BUFFER_FIELD,

  // rcvin stream map
   .VAR  stream_map_rcvin[$framesync_ind.ENTRY_SIZE_FIELD] =
      &$far_end.in.output.cbuffer_struc,        // $framesync_ind.CBUFFER_PTR_FIELD
      0,                                        // $framesync_ind.FRAME_PTR_FIELD
      0,                                        // $framesync_ind.CUR_FRAME_SIZE_FIELD
      $M.CVC.Num_Samples_Per_Frame,             // $framesync_ind.FRAME_SIZE_FIELD
      0,                                        // $framesync_ind.JITTER_FIELD
      $frame_sync.distribute_input_stream_ind,  // Distribute Function
      $frame_sync.update_input_streams_ind,     // Update Function
      0 ...;
    // SP.  Constant links.  Set in data objects
    //  &sco_dc_block_dm1 + $audio_proc.peq.INPUT_ADDR_FIELD,
    //  &sco_dc_block_dm1 + $audio_proc.peq.OUTPUT_ADDR_FIELD,
    //  &rcv_vad_peq + $audio_proc.peq.INPUT_ADDR_FIELD,
    //  &RcvAnalysisBank + $M.filter_bank.Parameters.OFFSET_PTR_FRAME,
    //  &passthru_rcv_gain + $M.audio_proc.stream_gain.OFFSET_INPUT_PTR,
    //  &passthru_rcv_gain + $M.audio_proc.stream_gain.OFFSET_OUTPUT_PTR,
    //  &dac_upsample_dm1 + $iir_resamplev2.INPUT_1_START_INDEX_FIELD,
    //  &sco_in_pk_dtct + $M.audio_proc.peak_monitor.PTR_INPUT_BUFFER_FIELD,

    // rcvout stream map
   .VAR  stream_map_rcvout[$framesync_ind.ENTRY_SIZE_FIELD] =
      &$dac_out.cbuffer_struc,                  // $framesync_ind.CBUFFER_PTR_FIELD
      0,                                        // $framesync_ind.FRAME_PTR_FIELD
      0,                                        // $framesync_ind.CUR_FRAME_SIZE_FIELD
      $M.CVC.ADC_DAC_Num_Samples_Per_Frame,     // $framesync_ind.FRAME_SIZE_FIELD
      3,                                        // $framesync_ind.JITTER_FIELD
      $frame_sync.distribute_output_stream_ind,   // Distribute Function
      $frame_sync.update_output_streams_ind,      // Update Function
      0 ...;
    // SP.  Constant links.  Set in data objects
    //  &RcvSynthesisBank + $M.filter_bank.Parameters.OFFSET_PTR_FRAME,
    //  &rcvout_gain_dm2 + $M.audio_proc.stream_gain.OFFSET_INPUT_PTR,
    //  &rcvout_gain_dm2 + $M.audio_proc.stream_gain.OFFSET_OUTPUT_PTR,
    //  &rcv_peq_dm2 + $audio_proc.peq.INPUT_ADDR_FIELD,
    //  &rcv_peq_dm2 + $audio_proc.peq.OUTPUT_ADDR_FIELD,
    //  &rcv_agc400_dm + $M.agc400.OFFSET_PTR_INPUT_FIELD,
    //  &rcv_agc400_dm + $M.agc400.OFFSET_PTR_OUTPUT_FIELD,
    //  &dac_upsample_dm1 + $iir_resamplev2.OUTPUT_1_START_INDEX_FIELD,
    //  &passthru_rcv_gain + $M.audio_proc.stream_gain.OFFSET_OUTPUT_PTR,

   // -----------------------------------------------------------------------------

// Stream List for Receive Processing
.VAR/ADDR_TABLE_DM    rcv_process_streams[] =
   &stream_map_rcvin,
   &stream_map_rcvout,
   0;

// Stream List for Send Processing
.VAR/ADDR_TABLE_DM    snd_process_streams[] =
   &stream_map_sndin,
   &stream_map_refin,
   &stream_map_sndout,
   0;

// Stream List for Loopback Processing
.VAR/ADDR_TABLE_DM    lpbk_process_streams[] =
   &stream_map_sndin,
   &stream_map_refin,
   &stream_map_sndout,
   &stream_map_rcvin,
   &stream_map_rcvout,
   0;

.ENDMODULE;



// *****************************************************************************
// MODULE:
//    $M.purge_cbuffer
//
// DESCRIPTION:
//    Purge cbuffers by writing zeros into the cbuffer.
//    Without this function the DAC port would continuously be fed stale data
//    from DSP cbuffers when switching from HFK to SSR mode.
//
// INPUTS:
//    - r7 = Pointer to cbuffer struc
//
// OUTPUTS:
//    - none
//
// *****************************************************************************
#if uses_SSR
.MODULE $M.purge_cbuffer;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

$purge_cbuffer:
   $push_rLink_macro;
   call $block_interrupts;
   r0 = r7;
#ifdef BASE_REGISTER_MODE
   call $cbuffer.get_write_address_and_size_and_start_address;
   push r2;
   pop  B0;
#else
   call $cbuffer.get_write_address_and_size;
#endif
   I0 = r0;
   L0 = r1;

   r10 = L0;
   r5 = Null;
   do clear_buffer;
      M[I0, 1] = r5;
   clear_buffer:

   L0 = 0;
#ifdef BASE_REGISTER_MODE
   push Null;
   pop  B0;
#endif

   call $unblock_interrupts;
   jump $pop_rLink_and_rts;
.ENDMODULE;
#endif

// Always called for a MODE change
.MODULE $M.CVC_HANDSFREE.SystemReInitialize;

   .CODESEGMENT CVC_SYSTEM_REINITIALIZE_PM;
   .DATASEGMENT DM;

 func:
   // Clear Re-Initialize Flag
   M[$M.CVC_SYS.AlgReInit]    = Null;
   M[$M.CVC_SYS.FrameCounter] = Null;

   // Transfer Parameters to Modules.
   // Assumes at least one value is copied
   M1 = 1;
   I0 = &$M.CVC.data.ParameterMap;
   // Get Source (Pre Load)
   r0 = M[I0,M1];
lp_param_copy:
      // Get Destination
      r1 = M[I0,M1];
      // Read Source,
      r0 = M[r0];
      // Write Destination,  Get Source (Next)
      M[r1] = r0, r0 = M[I0,M1];
      // Check for NULL termination
      Null = r0;
   if NZ jump lp_param_copy;

    // Configure Send OMS aggresiveness
    r0 = M[&$M.CVC.data.CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_HFK_OMS_AGGR];
#if uses_SND2_NS
    r1 = M[&$M.CVC.data.CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_SSR_OMS_AGGR];
    r2 = M[$M.CVC_SYS.cur_mode];
    NULL = r2 - $M.CVC_HANDSFREE.SYSMODE.SSR;
    if NZ r1=r0;
    M[&$M.CVC.data.oms270snd2_obj + $M.oms270.AGRESSIVENESS_FIELD] = r1;
#endif

   // Call Module Initialize Functions
   $push_rLink_macro;

   // Configure PLC and Codecs
   r7 = &$sco_data.object;
   NULL = M[$M.BackEnd.sco_streaming];
   if NZ call $frame_sync.sco_initialize;

   r0 = M[$M.BackEnd.wbs_init_func];
   if NZ call r0;

   r4 = &$M.CVC.data.FilterResetTable;
   call $frame_sync.run_function_table;

// refresh from persistence
#if uses_RCV_AGC
   // refresh from persistence
   r1 = M[$M.hf.LoadPersistResp.persistent_agc_init];    // alg re-init
   M[$M.CVC.data.rcv_agc400_dm + $M.agc400.OFFSET_PERSISTED_GAIN_FIELD] = r1;
#endif


   r4 = &$M.CVC.data.ReInitializeTable;
   call $frame_sync.run_function_table;


   // rate match persistence

   call $block_interrupts;

   // Load the rate match info previously acquired from the persistence store
   r1 = M[$M.hf.LoadPersistResp.persistent_current_alpha_index_usb];
   M[$far_end.in.sw_rate_op.param + $cbops.rate_monitor_op.CURRENT_ALPHA_INDEX_FIELD] = r1;

   r1 = M[$M.hf.LoadPersistResp.persistent_average_io_ratio_usb];
   M[$far_end.in.sw_rate_op.param + $cbops.rate_monitor_op.AVERAGE_IO_RATIO_FIELD] = r1;

   r1 = M[$M.hf.LoadPersistResp.persistent_warp_value_usb];
   M[$far_end.in.sw_rate_op.param + $cbops.rate_monitor_op.WARP_VALUE_FIELD] = r1;

   r1 = M[$M.hf.LoadPersistResp.persistent_inverse_warp_value_usb];
   M[$far_end.in.sw_rate_op.param + $cbops.rate_monitor_op.INVERSE_WARP_VALUE_FIELD] = r1;

   r1 = M[$M.hf.LoadPersistResp.persistent_sra_current_rate_usb];
   M[$far_end.in.sw_copy_op.param + $cbops.rate_adjustment_and_shift.SRA_CURRENT_RATE_FIELD] = r1;

   // Further initialisation
   M[$far_end.in.sw_rate_op.param + $cbops.rate_monitor_op.ACCUMULATOR_FIELD] = 0;

   r1 = M[$far_end.in.sw_rate_op.param + $cbops.rate_monitor_op.IDLE_PERIODS_AFTER_STALL_FIELD];
   r1 = 0 - r1;
   M[$far_end.in.sw_rate_op.param + $cbops.rate_monitor_op.COUNTER_FIELD] = r1;

   r1 = $cbops.rate_monitor_op.NO_DATA_PERIODS_FOR_STALL;
   M[$far_end.in.sw_rate_op.param + $cbops.rate_monitor_op.STALL_FIELD] = r1;

   M[$far_end.in.sw_rate_op.param + $cbops.rate_monitor_op.WARP_MSG_COUNTER_FIELD] = 0;

   call $unblock_interrupts;

   // r0 = &$M.CVC.data.CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_DSP_USER_0;
   // SP.  Add any special initialization here

   jump $pop_rLink_and_rts;
.ENDMODULE;


.MODULE  $M.CVC.Zero_DC_Nyquist;

   .codesegment CVC_ZERO_DC_NYQUIST_PM;

func:
   // Zero DC/Nyquist  -
   r0 = M[$cvc_fftbins];
   r0 = r0 - 1;
   M[r7] = Null;
   M[r8] = Null;
   M[r7 + r0] = Null;
   M[r8 + r0] = Null;
   rts;
.ENDMODULE;

// *****************************************************************************
//
// MODULE:
//    $M.set_mode_gains.func
//
// DESCRIPTION:
//    Sets input gains (ADC and SCO) based on the current mode.
//    (Note: this function should only be called from within standy,
//    loopback, and pass-through modes).
//
//    MODE              ADC GAIN        SCO GAIN
//    pass-through      user specified  user specified
//    standby           zero            zero
//    loopback          unity           unity
//
//
// INPUTS:
//    r7 - Pointer to the data structure
//
// *****************************************************************************

.MODULE $M.set_mode_gains;
    .CODESEGMENT SET_MODE_GAIN_PM;

$cvc_Set_LoopBackGains:

   // SP.  Gain si-->ro
   r0 = &$M.CVC.data.stream_map_rcvout;
   M[&$M.CVC.data.passthru_snd_gain + $M.audio_proc.stream_gain.OFFSET_OUTPUT_PTR] = r0;
   // SP.  Gain ri-->so
   r0 = &$M.CVC.data.stream_map_sndout;
   M[&$M.CVC.data.passthru_rcv_gain + $M.audio_proc.stream_gain.OFFSET_OUTPUT_PTR] = r0;

   // Unity (0 db)
   r0 = 0.5;
   r1 = 1;
   r2 = r0;
   r3 = r1;
   jump setgains;

$cvc_Set_PassThroughGains:

   // SP.   Gain si-->so
   r0 = &$M.CVC.data.stream_map_sndout;
   M[&$M.CVC.data.passthru_snd_gain + $M.audio_proc.stream_gain.OFFSET_OUTPUT_PTR] = r0;

   // SP.  Gain in-place.  Resampler is ri-->ri, for FE/BEX
   // SP.  Gain ri-->ro, for NB/WB
   r1 = &$M.CVC.data.stream_map_rcvin;
   r2 = &$M.CVC.data.stream_map_rcvout;
   r0 = M[$M.ConfigureSystem.Variant];
   Null = r0 - $M.CVC.BANDWIDTH.FE;
   if NZ r1 = r2;
   M[&$M.CVC.data.passthru_rcv_gain + $M.audio_proc.stream_gain.OFFSET_OUTPUT_PTR] = r1;

   r4 = M[$M.CVC_SYS.cur_mode];
   NULL = r4 - $M.CVC_HANDSFREE.SYSMODE.PSTHRGH;
   if Z jump passthroughgains;

   // Standby - Zero Signal
   r0 = NULL;
   r1 = 1;
   r2 = r0;
   r3 = r1;
   jump setgains;
passthroughgains:
   // PassThrough Gains set from Parameters
   r0 = M[$M.CVC.data.CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_PT_SNDGAIN_MANTISSA];
   r1 = M[$M.CVC.data.CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_PT_SNDGAIN_EXPONENT];
   r2 = M[$M.CVC.data.CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_PT_RCVGAIN_MANTISSA];
   r3 = M[$M.CVC.data.CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_PT_RCVGAIN_EXPONENT];
setgains:
   M[r7 + $M.SET_MODE_GAIN.ADC_MANT]    = r0;
   M[r7 + $M.SET_MODE_GAIN.ADC_EXP]     = r1;
   M[r7 + $M.SET_MODE_GAIN.SCO_IN_MANT] = r2;
   M[r7 + $M.SET_MODE_GAIN.SCO_IN_EXP]  = r3;
   rts;
.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $M.cvc.rcv_peq
//
// DESCRIPTION:
//    CVC receive PEQ process depending on WB/NB setting
//
// *****************************************************************************
.MODULE $M.cvc.rcv_peq;
   .CODESEGMENT CVC_BANDWIDTH_PM;
   .DATASEGMENT DM;
$cvc.rcv_peq.process_wb:
   r0 = M[$M.ConfigureSystem.Variant];
   Null = r0 - $M.CVC.BANDWIDTH.WB;
   if NZ rts;
   jump $audio_proc.peq.process;
$cvc.rcv_peq.process:
   r0 = M[$M.ConfigureSystem.Variant];
   Null = r0 - $M.CVC.BANDWIDTH.WB;
   if Z rts;
   jump $audio_proc.peq.process;
.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $M.cvc.fe_utility
//
// DESCRIPTION:
//    FE/BEX utility functions
//
// *****************************************************************************
.MODULE $M.cvc.fe_utility;
   .CODESEGMENT CVC_BANDWIDTH_PM;
   .DATASEGMENT DM;


$cvc.fe.frame_resample_process:
   r0 = M[$fe_frame_resample_process];
   if NZ jump r0;
   rts;

$cvc.non_fe.Zero_DC_Nyquist:
   r0 = M[$M.ConfigureSystem.Variant];
   Null = r0 - $M.CVC.BANDWIDTH.FE;
   if Z rts;
   jump $M.CVC.Zero_DC_Nyquist.func;

.ENDMODULE;

.CONST $CVC_HF_PERSIST_MGDC_OFFSET                                 0; // Not used in 1 mic handsfree (but want a common/compatible pblock)
.CONST $CVC_HF_PERSIST_AGC_OFFSET                                  1;

.CONST $CVC_HF_PERSIST_CURRENT_ALPHA_INDEX_OFFSET_USB              2;
.CONST $CVC_HF_PERSIST_AVERAGE_IO_RATIO_HI_OFFSET_USB              3;
.CONST $CVC_HF_PERSIST_AVERAGE_IO_RATIO_LO_OFFSET_USB              4;
.CONST $CVC_HF_PERSIST_WARP_VALUE_HI_OFFSET_USB                    5;
.CONST $CVC_HF_PERSIST_WARP_VALUE_LO_OFFSET_USB                    6;
.CONST $CVC_HF_PERSIST_INVERSE_WARP_VALUE_HI_OFFSET_USB            7;
.CONST $CVC_HF_PERSIST_INVERSE_WARP_VALUE_LO_OFFSET_USB            8;
.CONST $CVC_HF_PERSIST_SRA_CURRENT_RATE_HI_OFFSET_USB              9;
.CONST $CVC_HF_PERSIST_SRA_CURRENT_RATE_LO_OFFSET_USB              10;
.CONST $CVC_HF_PERSIST_NUM_ELEMENTS                                11; // Number of persistance elements


// *****************************************************************************
// DESCRIPTION: Response to persistence load request
// r2 = length of persistence block / zero for error[?]
// r3 = address of persistence block
// *****************************************************************************
.MODULE $M.hf.LoadPersistResp;

   .CODESEGMENT PM;
   .DATASEGMENT DM;

   // AGC persistence
   .VAR persistent_agc_init = 0x20000;

   // USB rate match persistence
   .VAR persistent_current_alpha_index_usb = 0;
   .VAR persistent_average_io_ratio_usb = 0.0;
   .VAR persistent_warp_value_usb = 0.0;
   .VAR persistent_inverse_warp_value_usb = 0.0;
   .VAR persistent_sra_current_rate_usb = 0.0;

func:

   M[$flag_load_persist] = NULL;
   Null = r2 - $CVC_HF_PERSIST_NUM_ELEMENTS;
   if NZ rts; // length must be correct

   // Re-Initialize System (this will result in a load of the persistent values)
   M[$M.CVC_SYS.AlgReInit] = r2;

#if uses_RCV_AGC
   r0 = M[r3 + $CVC_HF_PERSIST_AGC_OFFSET];
   r0 = r0 ASHIFT 8; // 16 msb, 8lsbs trucated
   M[persistent_agc_init] = r0;           // perst_load_resp :  $CVC_HF_PERSIST_AGC_OFFSET
#endif

   // rate match persistence
   // --------------------------

   // CURRENT_ALPHA_INDEX
   r0 = M[r3 + $CVC_HF_PERSIST_CURRENT_ALPHA_INDEX_OFFSET_USB];
   M[persistent_current_alpha_index_usb] = r0;

   // AVERAGE_IO_RATIO
   r0 = M[r3 + $CVC_HF_PERSIST_AVERAGE_IO_RATIO_HI_OFFSET_USB];
   r1 = M[r3 + $CVC_HF_PERSIST_AVERAGE_IO_RATIO_LO_OFFSET_USB];
   r0 = r0 LSHIFT 8;
   r1 = r1 AND 0xff;
   r0 = r0 OR r1;
   M[persistent_average_io_ratio_usb] = r0;

   // WARP_VALUE
   r0 = M[r3 + $CVC_HF_PERSIST_WARP_VALUE_HI_OFFSET_USB];
   r1 = M[r3 + $CVC_HF_PERSIST_WARP_VALUE_LO_OFFSET_USB];
   r0 = r0 LSHIFT 8;
   r1 = r1 AND 0xff;
   r0 = r0 OR r1;
   M[persistent_warp_value_usb] = r0;

   // INVERSE_WARP_VALUE
   r0 = M[r3 + $CVC_HF_PERSIST_INVERSE_WARP_VALUE_HI_OFFSET_USB];
   r1 = M[r3 + $CVC_HF_PERSIST_INVERSE_WARP_VALUE_LO_OFFSET_USB];
   r0 = r0 LSHIFT 8;
   r1 = r1 AND 0xff;
   r0 = r0 OR r1;
   M[persistent_inverse_warp_value_usb] = r0;

   // SRA_CURRENT_RATE
   r0 = M[r3 + $CVC_HF_PERSIST_SRA_CURRENT_RATE_HI_OFFSET_USB];
   r1 = M[r3 + $CVC_HF_PERSIST_SRA_CURRENT_RATE_LO_OFFSET_USB];
   r0 = r0 LSHIFT 8;
   r1 = r1 AND 0xff;
   r0 = r0 OR r1;
   M[persistent_sra_current_rate_usb] = r0;

   rts;
.ENDMODULE;


// *****************************************************************************
// MODULE:
//    $M.pblock_send_handler
//
// DESCRIPTION:
//    This module periodically sends the persistence block to HSV5 for storage
//
//
// *****************************************************************************
.MODULE $M.pblock_send_handler;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

   .CONST $CVC_HF_PERSIST_STORE_MSG_SIZE         ($CVC_HF_PERSIST_NUM_ELEMENTS + 1); // Need 1 extra for the SysID
   // SysID(1), MGDC(1), AGC(1), Alpha index(1), IO ratio(2), USB warp value(2), USB inverse warp value(2), sra current rate(2)

   .CONST $PBLOCK_RESTART_TIMER_MICRO             10000;

   // Pblock re-send timer data structure
   .VAR $pblock_send_timer_struc[$timer.STRUC_SIZE];

   // Persistence message data
   .VAR persist_data_hf[$CVC_HF_PERSIST_STORE_MSG_SIZE];                // Need 1 extra for the SysID

   .VAR $flag_load_persist = 0;

$restart_persist_timer:

   push rLink;
   // start timer for persistence block
   r1 = &$pblock_send_timer_struc;
   M[$flag_load_persist] = r1;

   r2 = M[r1 + $timer.ID_FIELD];
   if NZ call $timer.cancel_event;

   r1 = &$pblock_send_timer_struc;
   r2 = $PBLOCK_RESTART_TIMER_MICRO; // 10 msec
   r3 = &$pblock_send_handler;
   call $timer.schedule_event_in;
   jump $pop_rLink_and_rts ;

$pblock_send_handler:

   $push_rLink_macro;

   r3 = M[$pblock_key];
   M[&persist_data_hf] = r3;

   NULL = M[$flag_load_persist];
   if Z jump persist_store;

      r2 = $M.CVC.VMMSG.LOADPERSIST;
      call $message.send_short;
      jump perist_done;

persist_store:

#if uses_RCV_AGC
   r0 = M[$M.CVC.data.rcv_agc400_dm + $M.agc400.OFFSET_G_REAL_FIELD];
   M[$M.hf.LoadPersistResp.persistent_agc_init]=r0;   // Perst_store : $CVC_HF_PERSIST_AGC_OFFSET
   r0 = r0 ASHIFT -8;                                                   // to 16-bit, truncate 8 lsbs
   M[&persist_data_hf + 1 + $CVC_HF_PERSIST_AGC_OFFSET] = r0;
#endif

   // Rate match persistence
   // --------------------------

   // CURRENT_ALPHA_INDEX
   r0 = M[$far_end.in.sw_rate_op.param + $cbops.rate_monitor_op.CURRENT_ALPHA_INDEX_FIELD];
   M[&persist_data_hf + 1 + $CVC_HF_PERSIST_CURRENT_ALPHA_INDEX_OFFSET_USB] = r0;

   // --------------------------

   // AVERAGE_IO_RATIO
   r0 = M[$far_end.in.sw_rate_op.param + $cbops.rate_monitor_op.AVERAGE_IO_RATIO_FIELD];
   r1 = r0 LSHIFT -8;                                                   // Bits 23-8
   M[&persist_data_hf + 1 + $CVC_HF_PERSIST_AVERAGE_IO_RATIO_HI_OFFSET_USB] = r1;
   r1 = r0 AND 0xff;                                                    // Bits 7-0
   M[&persist_data_hf  + 1 + $CVC_HF_PERSIST_AVERAGE_IO_RATIO_LO_OFFSET_USB] = r1;

   // --------------------------

   // WARP_VALUE_FIELD
   r0 = M[$far_end.in.sw_rate_op.param + $cbops.rate_monitor_op.WARP_VALUE_FIELD];
   r1 = r0 LSHIFT -8;                                                   // Bits 23-8
   M[&persist_data_hf + 1 + $CVC_HF_PERSIST_WARP_VALUE_HI_OFFSET_USB] = r1;
   r1 = r0 AND 0xff;                                                    // Bits 7-0
   M[&persist_data_hf + 1 + $CVC_HF_PERSIST_WARP_VALUE_LO_OFFSET_USB] = r1;

   // --------------------------

   // INVERSE_WARP_VALUE_FIELD
   r0 = M[$far_end.in.sw_rate_op.param + $cbops.rate_monitor_op.INVERSE_WARP_VALUE_FIELD];
   r1 = r0 LSHIFT -8;                                                   // Bits 23-8
   M[&persist_data_hf + 1 + $CVC_HF_PERSIST_INVERSE_WARP_VALUE_HI_OFFSET_USB] = r1;
   r1 = r0 AND 0xff;                                                    // Bits 7-0
   M[&persist_data_hf + 1 + $CVC_HF_PERSIST_INVERSE_WARP_VALUE_LO_OFFSET_USB] = r1;

   // --------------------------

   // SRA_CURRENT_RATE
   r0 = M[$far_end.in.sw_copy_op.param + $cbops.rate_adjustment_and_shift.SRA_CURRENT_RATE_FIELD];
   r1 = r0 LSHIFT -8;                                                   // Bits 23-8
   M[&persist_data_hf + 1 + $CVC_HF_PERSIST_SRA_CURRENT_RATE_HI_OFFSET_USB] = r1;
   r1 = r0 AND 0xff;                                                    // Bits 7-0
   M[&persist_data_hf + 1 + $CVC_HF_PERSIST_SRA_CURRENT_RATE_LO_OFFSET_USB] = r1;

   // --------------------------

   r3 = $M.CVC.VMMSG.STOREPERSIST;
   r4 = $CVC_HF_PERSIST_STORE_MSG_SIZE;
   r5 = &persist_data_hf;
   call $message.send_long;


perist_done:

   // post another timer event
   r1 = &$pblock_send_timer_struc;
   r2 = $TIMER_PERIOD_PBLOCK_SEND_MICROS;
   r3 = &$pblock_send_handler;
   call $timer.schedule_event_in_period;

   jump $pop_rLink_and_rts;

.ENDMODULE;


// *****************************************************************************
// MODULE:
//    $M.vad_hold.process
//
// DESCRIPTION:
//    Delay VAD transition to zero after echo event. Logic:
//    if echo_flag
//        echo_hold_counter = echo_hold_time_frames
//    else
//        echo_hold_counter = MAX(--echo_hold_counter, 0)
//    end
//    VAD = VAD && (echo_hold_counter > 0)
//
// INPUTS:
//    r7 - Pointer to the data structure
//
// *****************************************************************************
.MODULE $M.vad_hold.process;
   .CODESEGMENT PM;

func:
   r0 = M[r7 + $M.CVC.vad_hold.PTR_VAD_FLAG_FIELD];
   r0 = M[r0]; // VAD status
   r1 = M[r7 + $M.CVC.vad_hold.PTR_ECHO_FLAG_FIELD];
   r1 = M[r1]; // echo status
   r2 = M[r7 + $M.CVC.vad_hold.HOLD_COUNTDOWN_FIELD]; // count
   r3 = M[r7 + $M.CVC.vad_hold.PTR_HOLD_TIME_FRAMES_FIELD];
   r3 = M[r3]; // reset value

   // update hold counter
   r2 = r2 - 1;
   if NEG r2 = 0;
   Null = r1;
   if NZ r2 = r3;
   M[r7 + $M.CVC.vad_hold.HOLD_COUNTDOWN_FIELD] = r2;
   if NZ r0 = Null; // dont allow VAD to activate until countdown competed
   M[r7 + $M.CVC.vad_hold.FLAG_FIELD] = r0;
   rts;

.ENDMODULE;


// *****************************************************************************
// MODULE:
//    $cvc.init.aec510
//
// DESCRIPTION:
//    aec510 module configuration
//
// MODIFICATIONS:
//
// INPUTS:
//    - r8 - module object (aec_obj / vsm_fdnlp)
//
// OUTPUTS:
//
// TRASHED REGISTERS:
//
// CPU USAGE:
//
// NOTE:
// *****************************************************************************
.MODULE $M.CVC_SEND.module_init.aec510;

   .CODESEGMENT PM;

$cvc.init.aec510:
   // AEC mode
   r0 = $aec510.mode.narrow_band;
   r1 = $aec510.mode.wide_band;
   r2 = M[$cvc_fftbins];
   Null = r2 - 65;
   if NZ r0 = r1;
   M[r8 + $aec510.MODE_FIELD] = r0;

   // AEC taillength selection
   r1 = 2;
   r0 = M[&$M.CVC.data.CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_AEC_FILTER_LENGTH];
  Null = r0 - 1;
  if NZ r0 = r1;
#ifdef TAIL_LENGTH_60ms
   //Qcc300x supports only 60ms of taillength
   r0 = $AEC_FILTER_LENGTH;
#endif   
   M[r8 + $aec510.HF_FLAG_FIELD] = r0;

   // RER_Aggr
   r0 = M[&$M.CVC.data.CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_RER_ADAPT];
   M[r8 + $aec510.RER_AGGR_FIELD] = r0;

   // OMS/DMS AGGR needed for CNG offset
   r0 = M[&$M.CVC.data.CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_HFK_OMS_AGGR];
   M[r8 + $aec510.OFFSET_OMS_AGGRESSIVENESS] = r0;


   // AEC sub-module on/off flags
   r2 = M[&$M.CVC.data.CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_HFK_CONFIG];

   r0 = r2 AND $M.CVC_HANDSFREE.CONFIG.BYPASS_FBC;
   M[r8 + $aec510.FLAG_BYPASS_FBC_FIELD] = r0;

   r0 = 1;
   Null = r2 AND $M.CVC_HANDSFREE.CONFIG.RERENA;
   if NZ r0 = 0;
   M[r8 + $aec510.FLAG_BYPASS_RER_FIELD] = r0;

   r0 = 1;
   Null = r2 AND $M.CVC_HANDSFREE.CONFIG.CNGENA;
   if NZ r0 = 0;
   M[r8 + $aec510.FLAG_BYPASS_CNG_FIELD] = r0;

   r0 = 1;
   Null = r2 AND $M.CVC_HANDSFREE.CONFIG.RERCBAENA;
   if NZ r0 = 0;
   M[r8 + $aec510.FLAG_BYPASS_RERCBA_FIELD] = r0;

   r0 = 1;
   M[r8 + $aec510.FLAG_BYPASS_RERDEV_FIELD] = r0;

   rts;

$cvc.init.vsm_fdnlp:
   // HD on/off flags
   r0 = 0;  // always on
   M[r8 + $aec510.nlp.FLAG_BYPASS_HD_FIELD] = r0;
   rts;

.ENDMODULE;


// *****************************************************************************
// MODULE:
//    $cvc.mc.aec510
//
// DESCRIPTION:
//    aec510 module control
//
// MODIFICATIONS:
//
// INPUTS:
//
// OUTPUTS:
//    - r0 - ~AEC_ON (bypass flag)
//
// TRASHED REGISTERS:
//
// CPU USAGE:
//
// NOTE:
// *****************************************************************************
.MODULE $M.CVC_SEND.module_control.aec510;

   .CODESEGMENT PM;

$cvc.mc.aec510:
   r0 = 1;
   r2 = M[&$M.CVC.data.CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_HFK_CONFIG];
   Null = r2 AND $M.CVC_HANDSFREE.CONFIG.AECENA;
   if NZ r0 = 0;
   rts;

.ENDMODULE;


// *****************************************************************************
// MODULE:
//    $cvc.aec_ref.filter_bank.analysis
//
// DESCRIPTION:
//    aec510 reference filter_bank analysis process
//
// MODIFICATIONS:
//
// INPUTS:
//    - r7 - fft_obj
//    - r8 - fba_ref
//
// OUTPUTS:
//
// TRASHED REGISTERS:
//
// CPU USAGE:
//
// NOTE:
// *****************************************************************************
.MODULE $M.CVC_SEND.module_control.aec_ref.filter_bank.analysis;

   .CODESEGMENT PM;

$cvc.aec_ref.filter_bank.analysis:
   // r0 -> ~(AEC_on || FBC_on)
   r2 = M[&$M.CVC.data.CurParams + $M.CVC_HANDSFREE.PARAMETERS.OFFSET_HFK_CONFIG];
   r0 = r2 AND $M.CVC_HANDSFREE.CONFIG.BYPASS_FBC;
   Null = r2 AND $M.CVC_HANDSFREE.CONFIG.AECENA;
   if NZ r0 = 0;

   Null = r0;
   if NZ rts;

   // Run reference filter_bank analysis only when AEC or FBC is enabled.
   // r7 = fft_obj, r8 = fba_ref
   jump $aec510.filter_bank.analysis.process;

.ENDMODULE;


// *****************************************************************************
// MODULE:
//    $cvc.reset_cbuffer
//
// DESCRIPTION:
//    Reset the cbuffer that is pointed to by the stream map object
//
// INPUTS:
//    - r7 - stream map object
// OUTPUTS:
//
// CPU USAGE:
//
// NOTE:
// *****************************************************************************
.MODULE $M.cvc.reset_cbuffer;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

$cvc.reset_cbuffer:
   r7 = M[r7 + $framesync_ind.CBUFFER_PTR_FIELD];
   if Z rts;

   push rLink;
   call $block_interrupts;

   r0 = r7;
#ifdef BASE_REGISTER_MODE
   call $cbuffer.get_write_address_and_size_and_start_address;
   push r2;
   pop  B0;
#else
   call $cbuffer.get_write_address_and_size;
#endif
   call $cbuffer.buffer_configure;

   call $unblock_interrupts;
   jump $pop_rLink_and_rts;

.ENDMODULE;
