// *****************************************************************************
// Copyright (c) 2009 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

// *****************************************************************************
// DESCRIPTION
// System Routines to run music manager
//
// *****************************************************************************

#include "stack.h"
#include "music_example.h"
#include "core_library.h"
#include "music_manager_config.h"
#include "cbops.h"
#include "codec_library.h"
#include "default_eq_coefs.h"


// *****************************************************************************
// MODULE:
//    $M.music_example_reinitialize
//
// DESCRIPTION:
// This routine is called by music_example_process when the algorithm needs to
// be reinitialized.
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// CPU USAGE:
//    CODE memory:    6  words
//    DATA memory:    0  words
// *****************************************************************************
.MODULE $M.music_example_reinitialize;
 .CODESEGMENT PM;

$music_example_reinitialize:
   $push_rLink_macro;

   // exit if sample rate message hasn't been received
   Null = M[$current_codec_sampling_rate];

   if Z jump $pop_rLink_and_rts; 

   // Copy current config word to codec specific config word so they're synchronized
   r0 = M[&$M.system_config.data.CurParams + $M.MUSIC_MANAGER.PARAMETERS.OFFSET_CONFIG];

   // Tell VM the current EQ Bank
   r2 = $music_example.VMMSG.CUR_EQ_BANK;
   r3 = r0 AND $M.MUSIC_MANAGER.CONFIG.USER_EQ_SELECT;
   call $message.send_short;

// Call Module Initialize Functions
   r4 = &$M.system_config.data.reinitialize_table;
   call $frame_sync.run_function_table;

// Clear Reinitialization Flag
   M[$music_example.reinit]    = NULL;
   jump $pop_rLink_and_rts;
.ENDMODULE;


// *****************************************************************************
// MODULE:
//    $M.music_example.peq.process
//
// DESCRIPTION:
//    front end for peq's. Exits if 0-stage.
//
// INPUTS:
//    - r7 = pointer to peq object
//    - r8 = pointer to bank select object
//
// OUTPUTS:
//    - none
//
//
// *****************************************************************************

.MODULE $music_example.peq;
   .CODESEGMENT PM;

.DATASEGMENT DM;

//------------------------------------------------------------------------------
initialize:
//------------------------------------------------------------------------------
// initialise parametric filter
// - if user_eq, then need to select filter bank, and adjust it depending on
//   sample rate.  If filter bank is zero, then don't update coefficients as
//   filtering is put into bypass by peq processing wrapper (below).
//   Bank 0 means flat curve, but is only valid if EQFLAT is enabled.
//   Bank 1 means use the peq 1 for 44.1 kHz or peq 7 for 48 kHz etc...
// - if not user_eq, then force filter bank to zero.  sample rate bank switch is
//   still performed.
//------------------------------------------------------------------------------
// on entry r7 = pointer to filter object
//          r8 = pointer to bank selection object
//------------------------------------------------------------------------------

    r0 = M[&$M.system_config.data.CurParams + $M.MUSIC_MANAGER.PARAMETERS.OFFSET_CONFIG];
    r5 = M[r8];     // Number of banks per sample rate

    // running user_eq so get selected bank number
    // speaker and base boost only have one bank
    r3 = r0 and $M.MUSIC_MANAGER.CONFIG.USER_EQ_SELECT;
    NULL = r5 - 1;
    if Z r3=Null;

    // Use sample rate to update bank
    r1 = M[$current_codec_sampling_rate];

    Null = r1 - 48000;
    if Z r3 = r3 + r5;

    // Access the requested Bank
    // PARAM_PTR_FIELD=Null for no Peq
    r8 = r8 + 1;
    r0 = M[r8 + r3];
    M[r7 + $audio_proc.peq.PARAM_PTR_FIELD] = r0;
    if Z rts;
    jump $audio_proc.hq_peq.initialize;


//------------------------------------------------------------------------------
process:
//------------------------------------------------------------------------------
// peq processing wrapper
// - return without processing if bypassed
// - if running user_eq (BYPASS_BIT_MASK_FIELD == USER_EQ_BYPASS)
//     then check whether user eq bank is 0
//------------------------------------------------------------------------------
// on entry r7 = pointer to filter object (used by audio_proc.hq_peq.process)
//          r8 = bypass mask
//------------------------------------------------------------------------------

    r0 = M[&$M.system_config.data.CurParams + $M.MUSIC_MANAGER.PARAMETERS.OFFSET_CONFIG];


    // check if EQ is bypassed
    null = r0 and r8;
    if NZ rts;

    // if Parameters is Null then no Peq
    Null = M[r7 + $audio_proc.peq.PARAM_PTR_FIELD];
    if Z rts;

    jump $audio_proc.hq_peq.process;

.ENDMODULE;



// *****************************************************************************
// MODULE:
//    $M.music_example.send_ready_msg
//
// DESCRIPTION:
//    This function sends a ready message to the VM application signifying that
//    it is okay for the VM application to connect streams to the kalimba.  The
//    application needs to call this function just prior to scheduling the audio
//    interrupt handler.
//
// INPUTS:
//    none
//
// OUTPUTS:
//    none
//
// CPU USAGE:
//    cycles =
//    CODE memory:    5  words
//    DATA memory:    4  words
// *****************************************************************************
.MODULE $M.music_example.power_up_reset;
 .DATASEGMENT    DM;
 .CODESEGMENT    PM;

// Entries can be added to this table to suit the system being developed.
   .VAR  message_handlers[] =
// Message Struc Ptr  Message ID  Message Handler  Registration Function
   &$M.music_example_message.set_mode_message_struc,       $music_example.VMMSG.SETMODE,                 &$M.music_example_message.SetMode.func,      $message.register_handler,
   &$M.music_example_message.load_params_message_struc,    $music_example.VMMSG.LOADPARAMS,              &$M.music_example.LoadParams.func,           $message.register_handler,
   &$M.music_example_message.multi_channel_main_mute_s_message_struc,   $M.music_example.VMMSG.MULTI_CHANNEL_MAIN_MUTE_S,  &$M.music_example_message.MultiChannelMainMute_s.func,   $message.register_handler,
   &$M.music_example_message.multi_volume_s_message_struc,              $M.music_example.VMMSG.VOLUME_S,                   &$M.music_example_message.MainVolume_s.func,             $message.register_handler,
   0;

$music_example.power_up_reset:
   $push_rLink_macro;

   // Copy default parameters into current parameters
   call $M.music_example.load_default_params.func;

   r4 = &message_handlers;
   call $frame_sync.register_handlers;
   jump $pop_rLink_and_rts;
.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $M.music_example.load_default_params
//
// DESCRIPTION:
//    This function copies the (packed) default parameter values into the current
//    parameters block...
//
//    Packing format should be three 16-bit words to two 24-bit words
//    eg: 1234 5678 9abc def0 to 123456,789abc
//
//    Throughput is 2 outputs/8 cycles
//
// INPUTS:
//    NONE
//
// OUTPUTS:
//    loads Default parameter values into CurParams block.
//
// TRASHED REGISTERS:
//    r0,r2,r3,r4,L0,I0,I1,I4,r10,Loop
//
// CPU USAGE:
//    cycles =
//    CODE memory:     18 words
//    DATA memory:     5 words
//
// Note:
//    LENGTH($M.system_config.data.CurParams) must be even
//
// *****************************************************************************
.MODULE $M.music_example.load_default_params;


   .CODESEGMENT PM;
   .DATASEGMENT DM;
   .VAR/DM1CIRC operatorvals[] = 8,0x00ff00,-8,0x00ffff,16;

func:
   L0 = LENGTH(operatorvals);
   I0 = &operatorvals;
   I4 = &$M.system_config.data.DefaultParameters;
   I1 = &$M.system_config.data.CurParams;
   r10 = LENGTH($M.system_config.data.CurParams);
#if 1 // compiler bug: should divide above by two @ compile time
   r10 = r10 ASHIFT -1;
#endif
   r4 = M[I0, 1], r0 = M[I4, 1];  // load 8, load 0x1234
   do three16_to_two24_loop;
      r0 = r0 LSHIFT r4, r4 = M[I0, 1], r2 = M[I4, 0]; // load 0x5678,load mask
      r2 = r2 AND r4, r4 = M[I0, 1];    // mask sign bits, load -8
      r2 = r2 LSHIFT r4, r4 = M[I0, 1], r3 = M[I4, 1]; // load mask, load 0x5678
      r0 = r0 OR r2,               r2 = M[I4, 1]; // load 0x9abc, word1 done
      r2 = r2 AND r4, r4 = M[I0, 1];      // clear upper bits of word2, load 16
      r3 = r3 LSHIFT r4, M[I1, 1] = r0;   // store word1
      r3 = r3 OR r2,     r4 = M[I0, 1], r0 = M[I4, 1]; // load 8, load 0xdef0
      M[I1, 1] = r3;  // word2 done, store word2
   three16_to_two24_loop:
   L0 = 0;
   rts;

.ENDMODULE;


// *****************************************************************************
// MODULE:
//    $M.music_example
//
// DESCRIPTION:
//    music_example data object.
//
// *****************************************************************************
.MODULE $M.MUSIC_EXAMPLE_VERSION_STAMP;
   .DATASEGMENT DM;
   .BLOCK VersionStamp;
   .VAR  h1 = 0xbeef;
   .VAR  h2 = 0xbeef;
   .VAR  h3 = 0xbeef;
   .VAR  SysID = $MUSIC_MANAGER_SYSID;
   .VAR  BuildVersion = MUSIC_EXAMPLE_VERSION;
   .VAR  h4 = 0xbeef;
   .VAR  h5 = 0xbeef;
   .VAR  h6 = 0xbeef;
   .ENDBLOCK;
.ENDMODULE;

#define MUSIC_MANAGER_CONFIG_FLAG_RAW                                   \
    ( (flag_uses_SPEAKER_CROSSOVER * uses_SPEAKER_CROSSOVER)            \
    + (flag_uses_SPKR_EQ * uses_SPKR_EQ)                                \
    + (flag_uses_BASS_BOOST * uses_BASS_BOOST)                          \
    + (flag_uses_BASS_PLUS * uses_BASS_PLUS)                            \
    + (flag_uses_USER_EQ * uses_USER_EQ)                                \
    + (flag_uses_STEREO_ENHANCEMENT * uses_STEREO_ENHANCEMENT)          \
    + (flag_uses_3DV * uses_3DV)                                        \
    + (flag_uses_DITHER * uses_DITHER)                                  \
    + (flag_uses_COMPANDER * uses_COMPANDER)                            \
    + (flag_uses_VOLUME_CONTROL * uses_VOLUME_CONTROL)                  \
    + (flag_uses_SIGNAL_DETECTION * uses_SIGNAL_DETECTION)              \
    + (flag_uses_WIRED_SUB_EQ * uses_WIRED_SUB_EQ)                      \
    + (flag_uses_WIRED_SUB_COMPANDER * uses_WIRED_SUB_COMPANDER)        \
    + (flag_uses_SPKR_EQ_RAW_COEFS * USE_PRECALCULATED_SPKR_COEFS)      \
    + (flag_uses_BASS_BOOST_RAW_COEFS * USE_PRECALCULATED_BOOST_COEFS)  \
    + (flag_uses_USER_EQ_RAW_COEFS * USE_PRECALCULATED_USER_COEFS) )

// System Configuration is saved in kap file.
.MODULE $M.MUSIC_EXAMPLE_MODULES_STAMP;
   .DATASEGMENT DM;
   .BLOCK ModulesStamp;
      .VAR  s1 = 0xfeeb;
      .VAR  s2 = 0xfeeb;
      .VAR  s3 = 0xfeeb;
      .VAR  CompConfig = MUSIC_MANAGER_CONFIG_FLAG_RAW;
      .VAR  s4 = 0xfeeb;
      .VAR  s5 = 0xfeeb;
      .VAR  s6 = 0xfeeb;
   .ENDBLOCK;
.ENDMODULE;

.MODULE $music_example;
 .DATASEGMENT DM;
   .VAR  Version    = MUSIC_EXAMPLE_VERSION;
   .VAR  sys_mode   = $M.MUSIC_MANAGER.SYSMODE.FULLPROC;
   .VAR  reinit     = $music_example.REINITIALIZE;
   .VAR  frame_processing_size = $music_example.NUM_SAMPLES_PER_FRAME;
   .VAR  config_raw = MUSIC_MANAGER_CONFIG_FLAG_RAW;
   .VAR  config_anc = (MUSIC_MANAGER_CONFIG_FLAG_RAW + (flag_uses_ANC_EQ * uses_ANC_EQ));
// SPI System Control
.BLOCK SpiSysControl;
   // Bit-wise flag for tuning control
   .VAR  SysControl = 0;
   // override System Volumes
   .VAR  OvrSystemVolume = 0x0009;
   .VAR  OvrCallState = 0;
   .VAR  OvrMode    = 0;

   // override Aux Master volumes
   .VAR  AuxOvrMasterVolumes = 0x0000;
   // override Aux Left & Right Trim volumes
   .VAR  AuxOvrTrimVolumes = 0x0000;

   // override Main Master volumes
   .VAR  MainOvrMasterVolumes = 0x0000;
   // override Primary Left & Right Trim volumes
   .VAR  PriOvrTrimVolumes = 0x0000;
   // override Secondary Left & Right Trim volumes
   .VAR  SecOvrTrimVolumes = 0x0000;
   // override Subwoofer Trim volumes
   .VAR  SubOvrTrimVolumes = 0x0000;
.ENDBLOCK;


   .VAR  SystemVolume = 11;                  // system volume (index)

   .VAR  Aux.MasterVolume = 0;               // Master volume (dB/60)
   .VAR  Aux.ToneVolume = 0;                 // Tone volume (dB/60)
   .VAR  Aux.LeftTrimVolume = 0;             // Aux Left trim volume (dB/60)
   .VAR  Aux.RightTrimVolume = 0;            // Aux Right trim volume(dB/60)


   .VAR  Main.MasterVolume = 0;              // Master volume (dB/60)
   .VAR  Main.ToneVolume = 0;                // Tone volume (dB/60)
   .VAR  Main.PrimaryLeftTrimVolume = 0;     // Primary Left trim volume (dB/60)
   .VAR  Main.PrimaryRightTrimVolume = 0;    // Primary Right trim volume(dB/60)
   .VAR  Main.SecondaryLeftTrimVolume = 0;   // Secondary Left trim volume (dB/60)
   .VAR  Main.SecondaryRightTrimVolume = 0;  // Secondary Right trim volume(dB/60)
   .VAR  Main.SubTrimVolume = 0;                 // Sub trim volume (dB/60)

   .VAR  DAC_IF_Connections = 0;
   .VAR  SPDIF_IF_Connections = 0;
   .VAR  I2S_IF_Connections = 0;
   .VAR  OTA_IF_Connections = 0;


.BLOCK Statistics;
   .VAR  CurMode            = 0;
   .VAR  PeakMipsFunc       = 0;
   .VAR  PeakMipsDecoder    = 0;
   .VAR  SamplingRate       = 0;

#ifdef FASTSTREAM_ENABLE
   .VAR  dec_sampling_freq;
   .VAR  dec_bitpool;
   .VAR  PeakMipsEncoder;
#endif
#if defined(APTX_ENABLE) || defined(APTX_ACL_SPRINT_ENABLE)
   .VAR  aptx_channel_mode;
   .VAR  aptx_security_status = 0;
   .VAR  aptx_decoder_version;
#endif
.ENDBLOCK;

.ENDMODULE;


// *****************************************************************************
// MODULE:
//    $M.music_example_message.MultiChannelMainMute_s
//
// DESCRIPTION:
//    Handler for the replacement short multi-channel configuration message.
//    (this uses the original corresponding long configuration message handler)
//    Message from VM->DSP to specify the mute status of all main wired outputs
//    (Note: all main wired multi-channel outputs are specified)
//
// INPUTS:
//    r1 = multi-channel mute enable flags
//          bit0 = Primary left mute
//          bit1 = Primary right mute
//          bit2 = Secondary left mute
//          bit3 = Secondary right mute
//          bit4 = Wired Sub mute
//          bit5 = BA All Devices mute (only used on BA Broadcaster)
//          bit6-bit15  <not used>
//
// OUTPUTS:
//    none
//
// TRASHED REGISTERS:
//    r0, r1, r2, r3, r4, r8, I0
//
// *****************************************************************************
.MODULE $M.music_example_message.MultiChannelMainMute_s;

   .CODESEGMENT PM;

func:
   $push_rLink_macro;

   // Primary left mute control
   r0 = r1 AND 0x01;
   if NZ r0 = -1;
   if Z r0 = 1;
   M[$M.post_eq.soft_mute_l.param + $cbops.soft_mute_op.MUTE_DIRECTION] = r0;

   // Primary right mute control
   r1 = r1 LSHIFT -1;
   r0 = r1 AND 0x01;
   if NZ r0 = -1;
   if Z r0 = 1;
   M[$M.post_eq.soft_mute_r.param + $cbops.soft_mute_op.MUTE_DIRECTION] = r0;

  jump $pop_rLink_and_rts;

.ENDMODULE;