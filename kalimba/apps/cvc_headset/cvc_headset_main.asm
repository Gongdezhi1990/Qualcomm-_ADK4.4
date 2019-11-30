// *****************************************************************************
// Copyright (c) 2007 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

// *****************************************************************************
// DESCRIPTION
//    This application uses the frame_sync framework (frame_sync library) to
//    copy samples across from the SCO in buffer to the DAC buffer, and from the
//    ADC buffer to the SCO out buffer.  CVC (cvc_headset library) is called to
//    process and transfer the data between buffers
//
// NOTES
//    CVC is comprised of the following processing modules:
//     - AEC (Acoustic Echo Canceller) applied to SCO output
//     - AGC (Automatic Gain Control) applied to DAC output
//     - AGC (Automatic Gain Control) applied to SCO output
//     - NS (Noise Suppression) applied to SCO output
//     - NDVC (Noise Dependent Volume Control) applied to DAC output
//     - SCO in parametric equalizer
//     - SCO out parametric equalizer
//     - SCO in and ADC in DC-Block filters
//
//    These modules can be included/excluded from the build using define the
//    define statements in cvc_headset_config.h
//
// *****************************************************************************

#include "flash.h"
#include "core_library.h"
#include "cbops_multirate_library.h"
#include "kalimba_messages.h"
#include "frame_sync_library.h"
#include "frame_codec.h"
#include "usbio.h"
#include "spi_comm_library.h"
#include "plc100_library.h"
#include "sbc_library.h"
#include "codec_library.h"

#include "cvc_modules.h"
#include "cvc_headset.h"
#include "cvc_system_library.h"
#include "frame_sync_tsksched.h"

// --------------------------------------------------------------------------
// System defines
// --------------------------------------------------------------------------

   .CONST $MESSAGE.AUDIO_CONFIG                 0x2000;

   // 1ms is chosen as the interrupt rate for the audio input/output to minimise latency:
   .CONST $TIMER_PERIOD_AUDIO_COPY_MICROS       625;

   // send the persistence block to the VM @ a 3s interval
   .CONST $TIMER_PERIOD_PBLOCK_SEND_MICROS      3000*1000; //3E6

   .CONST  $NUM_SAMPLES_4MS_16K   (64);


#ifdef BUILD_MULTI_KAPS
// *****************************************************************************
// MODULE:
//    $flash.init_dmconst
//
// DESCRIPTION:
//    On a BC7 initialises flash data to be mapped into windows 2 and 3.
//    24-bit data (corresponding to DMCONST) is mapped into window 3,
// while 16-bit data is mapped into window 2.
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    r0
//
// *****************************************************************************
.MODULE $M.flash.init_dmconst;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

   $flash.init_dmconst:

   // these variables are filled out with the address in flash of the
   // flash segment by the firmware upon a VM KalimbaLoad() call
   .VAR $flash.data16.address;
   .VAR $flash.data24.address;

   // set up the start address and 24-bit data mode for window 2
   r0 = M[$flash.data24.address];
   M[$FLASH_WINDOW2_START_ADDR] = r0;
   r0 = $FLASHWIN_CONFIG_24BIT_MASK;
   M[$FLASHWIN2_CONFIG] = r0;

   // set up the start address and 16-bit data mode for window 1
   r0 = M[$flash.data16.address];
   M[$FLASH_WINDOW1_START_ADDR] = r0;
   M[$FLASHWIN1_CONFIG] = Null;
   rts;

.ENDMODULE;
#endif


// CVC Security ID
.CONST  $CVC_ONEMIC_HEADSET_SECID     0x258C;

// *****************************************************************************
// MODULE:
//    $M.CVC.app.confic
//
// DESCRIPTION:
//
// *****************************************************************************
.MODULE $M.CVC.app.config;
   .DATASEGMENT DM;

   // ** Memory Allocation for CVC config structure
   .VAR CVC_config_struct[$M.CVC.CONFIG.STRUC_SIZE] =
      &$App.Codec.Apply,                        // CODEC_CNTL_FUNC
      &$CVC_AppHandleConfig,                    // CONFIG_FUNC
      $M.1mic.LoadPersistResp.func,             // PERSIS_FUNC
      $CVC_ONEMIC_HEADSET_SECID,                // SECURITY_ID
      $CVC_VERSION,                             // VERSION
      $M.CVC_HEADSET.SYSMODE.STANDBY,           // STANDBY_MODE
      $M.CVC_HEADSET.SYSMODE.HFK,               // HFK_MODE
      $M.CVC_HEADSET.SYSMODE.MAX_MODES,         // NUMBER of MODES
      $M.CVC_HEADSET.CALLST.MUTE,               // CALLST_MUTE
      $M.CVC_HEADSET.PARAMETERS.STRUCT_SIZE,    // NUM_PARAMS
      &$M.CVC.data.CurParams,                   // PARAMS_PTR
      CVC_DEFAULT_PARAMETERS,                   // DEF_PARAMS_PTR
      $CVC_HEADSET_SYSID,                       // SYS_ID
      CVC_SYS_FS,                               // SYS_FS
      CVC_SET_BANDWIDTH,                        // CVC_BANDWIDTH_INIT_FUNC
      &$M.CVC.data.StatisticsPtrs,              // STATUS_PTR
      &$dac_out.auxillary_mix_op.param,         // TONE_MIX_PTR
      &$M.CVC.data.CurParams + $M.CVC_HEADSET.PARAMETERS.OFFSET_INV_DAC_GAIN_TABLE; // $M.CVC.CONFIG.PTR_INV_DAC_TABLE
.ENDMODULE;

     // Scheduleing Task.   COUNT_FIELD counts modulous 12 (0-11) in 625 usec intervals

     // SCO Send on COUNT_FIELD=0, SCO Xmit on COUNT_FIELD=3,
     // SCO Good Receive on COUNT_FIELD=2, with Posibility of Re-Xmits
     // Need to accept 1 packet of latency due to re-Xmit
     //     The rcv_in jitter needs to be one sco packet

     // Send processing should be scheduled based on the peaks SEND_MIPS_FIELD (0-8000).
     //     Trigger equals 11 - round[11*(SEND_MIPS_FIELD/8000)]

.MODULE $M.CVC.app.scheduler;
   .DATASEGMENT DM;

   // ** Memory Allocation for CVC config structure
    .VAR    tasks[]=
        0,                      //    COUNT_FIELD
        12,                     //    MAX_COUNT_FIELD
        (Length(tasks) - $FRM_SCHEDULER.TASKS_FIELD)/2, // NUM_TASKS_FIELD
        0,                      //    TOTAL_MIPS_FIELD
        0,                      //    SEND_MIPS_FIELD
        0,                      //    TOTALTM_FIELD
        0,                      //    TOTALSND_FIELD
        0,                      //    TIMER_FIELD
        0,                      //    TRIGGER_FIELD
        // Task List (highest to lowest priority) - Limit 23 tasks (Modulous 12)
        $main_send,              CVC_SND_PROCESS_TRIGGER,
        $main_receive,           0,
        $main_housekeeping,      1;


.ENDMODULE;


// *****************************************************************************
// MODULE:
//    $M.Main
//
// DESCRIPTION:
//    This is the main routine.  It initializes the libraries and then loops
//    "forever" in the processing loop.
//
// *****************************************************************************
#ifndef BUILD_MULTI_KAPS
.MODULE $M.main;
   .CODESEGMENT MAIN_PM;

$main:
   // initialise the stack library
   call $stack.initialise;
   // initialise DM_flash
   call $flash.init_dmconst;
   // initialise the interrupt library
   call $interrupt.initialise;
   // initialise the message library
   call $message.initialise;
   // initialise the pskey library
   call $pskey.initialise;
   // initialise the cbuffer library
   call $cbuffer.initialise;
   // initialise licensing subsystem
   call $Security.Initialize;
   // intialize SPI communications library
   call $spi_comm.initialize;
   // initialise audio config handler
   call $audio_config.initialise;

   // Initialize Synchronized Timing for SCO   (Requires wall clock)
   call $wall_clock.initialise;
   r8 = $sco_data.object;
   call $sco_timing.initialize;

   // initialize CVC library
   r8 = &$M.CVC.app.config.CVC_config_struct;
   call $CVC.PowerUpReset;

#if uses_SSR
   // initialize the ASR library
   r7 = $M.CVC.data.asr_obj;
   call $M.wrapper.ssr.reset;
#endif

   // send message saying we're up and running!
   r2 = $MESSAGE_KALIMBA_READY;
   call $message.send_short;
#else
.MODULE $M.cvc_main;
   .CODESEGMENT PM_ENTRYPT;

   .VAR/DMCONST16 cvc_modules_path[]= string("cvc_share_com/cvc_share_com.kap");    // /pack16
   .VAR/DMCONST16 intial_patch[]= string("patches/initial_patch.kap");    
   .VAR/DMCONST16 onemic_hs_patch[]= string("patches/1mic_hs_patch.kap");   
   
$app_main:

   // initialise DM_flash
   call $flash.init_dmconst;

   // Load cvc_modules sub-app
   // r4 - length of string
   // r5 - file path (text string)
   r4 = LENGTH(cvc_modules_path);
   r5 = &cvc_modules_path;
   call $KapLoader.Load_Kap_By_File_Path;

   // initialize Patch Libary
#if PSKEY_PATCH
   R1 = 0x2258;  // PSKEY_ID.  PsKey Holding first patch � may not exist.  0x2258 = PSKEY_DSP_0.
   r2 = &$cbops.scratch.mem1;  // just need a temporary buffer, which is at least 128 words in size.
   r3 = 1;        //Pass application specific number   
   call $KapLoader.LoadPatch;
#else
   r4 = LENGTH(intial_patch);
   r5 = &intial_patch;
   r3 = 1;        //Pass application specific number     
   call $KapLoaderFS.LoadPatch;
   Null = &onemic_hs_patch;
#endif

   // initialise audio config handler
   call $audio_config.initialise;

   // Initialize Synchronized Timing for SCO   (Requires wall clock)
   call $wall_clock.initialise;
   r8 = $sco_data.object;
   call $sco_timing.initialize;

   // initialize CVC library
   r8 = &$M.CVC.app.config.CVC_config_struct;
   call $CVC.PowerUpReset;

#if uses_SSR
   // initialize the ASR library
   r7 = $M.CVC.data.asr_obj;
   call $M.wrapper.ssr.reset;
#endif

#endif

#ifdef MIPS_MESSAGE
   // register cvc_status VM message
   r1 = &$M.CVC.Status.cvc_status_message_struc;
   r2 = $M.CVC.VMMSG.STATUS_REQUEST;
   r3 = &$cvc_status_request_func;
   call $message.register_handler;
#endif

   // Activate CVC system
   call $CVC.Start;

   // Wait multiples of 10ms till sending load persist request
   // Several loadpersist requests trigger response messages from the
   // VM causing DSP/FW message queue to fill up
   M[$pblock_send_timer_struc + $timer.ID_FIELD] = NULL;
   call $restart_persist_timer;

   // --------------------------------------------------------------------------
   // Main loop: filtering the data
   // --------------------------------------------------------------------------
main_loop:
    // Check for System Initialization
    NULL = M[$M.audio_config.SysReConfigure];
    if NZ call $ConfigureSystem;

    // Check for Algorithm Initialization
    Null = M[$M.CVC_SYS.AlgReInit];
    if NZ call $M.CVC_HEADSET.SystemReInitialize.func;

    r8 = &$M.CVC.app.scheduler.tasks;
    call $frame_sync.task_scheduler_run;
    jump main_loop;

     // ******* Houskeeping Event ********************
$main_housekeeping:
      $push_rLink_macro;

    // Check Communication
    call $spi_comm.polled_service_routine;

    // Update Count for Ping
    r3 = M[$M.CVC_SYS.FrameCounter];
    r3 = r3 + 1;
    M[$M.CVC_SYS.FrameCounter] = r3;

    // Save Connection Status
    //    pack connection stat values into 24-bit statistic like:
    //       --------------------------------------------------
    //       |     8 bits    |      8 bits     |    8 bits    |
    //       |--------------_|-----------------|--------------|
    //       | packet_length | encoding_config | encodng_mode |
    //       --------------------------------------------------
    r3 = M[$far_end.in.usb_copy_struc + $frame_sync.USB_IN_MONO_COPY_PACKET_LENGTH_FIELD];
    r2 = M[&$sco_data.object + $sco_pkt_handler.PACKET_IN_LEN_FIELD];
    null = M[$M.BackEnd.sco_streaming];
    if Z r2 = r3;
    r1 = M[$M.audio_config.encoding_config];
    r3 = -1;
    r0 = M[$M.audio_config.encoding_mode];
    if Z r2 = r2 LSHIFT r3;
    r1 = r1 LSHIFT 8;
    r0 = r0 OR r1;
    r1 = r2 LSHIFT 16;
    r0 = r0 OR r1;
    M[$M.CVC_SYS.ConnectStatus] = r0;

    // NDVC - Update
#if uses_NSVOLUME
    r6 = M[&$M.CVC.data.ndvc_dm1 + $M.NDVC_Alg1_0_0.OFFSET_CURVOLLEVEL];
    call $CVC.VolumeControl.Set_DAC_Adjustment;
#endif


    // Update Side Tone Filter.   Disable if not HFK or Low-Volume Mode
    r7 = M[&$M.CVC.data.CurParams + $M.CVC_HEADSET.PARAMETERS.OFFSET_HFK_CONFIG];
    r8 = &$adc_in.sidetone_copy_op.param;
    r1 = M[$M.CVC_SYS.cur_mode];
    NULL = r1 - $M.CVC_HEADSET.SYSMODE.HFK;
    if Z jump jp_sidetone_enabled;
        NULL = r1 - $M.CVC_HEADSET.SYSMODE.LOWVOLUME;
        if NZ r7 = Null;
jp_sidetone_enabled:
    M[r8 + $cbops.sidetone_filter_op.OFFSET_ST_CONFIG_FIELD]=r7;
    call $cbops.sidetone_filter_op.SetMode;

    jump $pop_rLink_and_rts;


     // ********  Receive Processing ************
$main_receive:
      $push_rLink_macro;

      // Run PLC and Decoder
      r7 = &$sco_data.object;
      null = M[$M.BackEnd.sco_streaming];
      if NZ call $frame_sync.sco_decode;

      // Run CVC (receive)
      r2 = &$M.CVC.data.ModeProcTableRcv;
      call $Security.ProcessFrame;

      jump $pop_rLink_and_rts;

      // ***************  Send Processing **********************
$main_send:
      $push_rLink_macro;

      // SP. Track time in process
      r0 = M[$TIMER_TIME];
      push r0;

      // LowVol Mode switch logic: if (sysmode == SYSMODE.HFK) curmode = VolState
      // SP.  This must be done here to timing (jitter) in mode value.
      //      Security.ProcessFrame may alter current mode based on security fail
      //      or UFE override
      r1 = M[$M.CVC_SYS.SysMode];
      r2 = M[$M.CVC_SYS.VolState];
      Null = r1 - $M.CVC_HEADSET.SYSMODE.HFK;
      if Z r1 = r2;
      M[$M.CVC_SYS.cur_mode] = r1;

      // Run CVC (send)
      r2 = &$M.CVC.data.ModeProcTableSnd;
      call $Security.ProcessFrame;

      // Run selected codecs
      r9 = M[&$sco_data.object + $sco_pkt_handler.DECODER_PTR];
      r9 = M[r9 + $sco_decoder.DATA_PTR];
      r0 = M[$M.BackEnd.wbs_sco_encode_func];
      if NZ call r0;

      // SP.  Track Time in Process
      pop r0;
      r0 = r0 - M[$TIMER_TIME];
      r1 = M[$M.CVC.app.scheduler.tasks + $FRM_SCHEDULER.TOTALSND_FIELD];
      r1 = r1 - r0;
      M[$M.CVC.app.scheduler.tasks + $FRM_SCHEDULER.TOTALSND_FIELD]=r1;

      jump $pop_rLink_and_rts;

.ENDMODULE;


// *****************************************************************************
// MODULE:
//    $M.audio_config
//
// DESCRIPTION:
//    Set up audio routing for SCO data type
//
// INPUTS:
//    r1 - Encoding mode (0=cvsd, 1=reserved, 2=wbs, 3=usb)
//    r2 - reserved
// *****************************************************************************
// VM Messages
#define VM_ADCDAC_RATE_MESSAGE_ID               0x1070
#define VM_SET_TONE_RATE_MESSAGE_ID             0x1072
#define UNSUPPORTED_SAMPLING_RATES_MSG          0x1090

.MODULE $M.audio_config;
   .CODESEGMENT AUDIO_CONFIG_PM;
   .DATASEGMENT DM;

   // For routing config message
   .VAR  set_port_type_message_struc[$message.STRUC_SIZE];
   .VAR  set_adcdac_rate_from_vm_message_struc[$message.STRUC_SIZE];
   .VAR  set_tone_rate_from_vm_message_struc[$message.STRUC_SIZE]; // Message structure for VM_SET_TONE_RATE_MESSAGE_ID message

   // ** allocate memory for timer structures **
   .VAR  $audio_copy_timer_struc[$timer.STRUC_SIZE];

   // Routing Control
   .VAR  encoding_mode   = $FAR_END.AUDIO.DEFAULT_CODING;
   .VAR  encoding_config = 0;

   // Flag to show interface type (analogue, I2S etc)
   .VAR audio_if_mode = 0;
   .VAR audio_rate_matching = 0;

   // Sampling Rate
   .VAR adc_sampling_rate=0;
   .VAR dac_sampling_rate=0;

   // CVC Variant
   .VAR SysReConfigure=1;

$audio_config.initialise:
   $push_rLink_macro;

   // set up message handler for SCO routing message
   r1 = &set_port_type_message_struc;
   r2 = $MESSAGE.AUDIO_CONFIG;
   r3 = &$set_backend_from_vm;
   call $message.register_handler;

   // Set up message handler for VM_ADCDAC_RATE_MESSAGE_ID message
   r1 = &set_adcdac_rate_from_vm_message_struc;
   r2 = VM_ADCDAC_RATE_MESSAGE_ID;
   r3 = &$set_front_end_from_vm;
   call $message.register_handler;

   // set up message handler for VM_SET_TONE_RATE_MESSAGE_ID message
   r1 = &set_tone_rate_from_vm_message_struc;
   r2 = VM_SET_TONE_RATE_MESSAGE_ID;
   r3 = &$set_tone_rate_from_vm;
   call $message.register_handler;

   // start timer that copies audio samples
   r1 = &$audio_copy_timer_struc;
   r2 = $TIMER_PERIOD_AUDIO_COPY_MICROS;
   r3 = &$audio_copy_handler;
   call $timer.schedule_event_in;

   // use default cvc_bandwidth
   r0 = $M.CVC.BANDWIDTH.DEFAULT;
   M[$M.CVC_SYS.cvc_bandwidth] = r0;

   // Force Initial System Configuration
   call $ConfigureSystem;
   jump $pop_rLink_and_rts;


// *****************************************************************************
// MODULE:
//    $audio_config_handler
//
// DESCRIPTION:
//    Message handler for receiving SCO/USB select from VM
//
// INPUTS:
//    r1 = encoding_mode
//    r2 = encoding_config
//
// OUTPUTS:
//    none
// *****************************************************************************
$set_backend_from_vm:
   // Save encoding mode/config
   M[encoding_mode]   = r1;
   M[encoding_config] = r2;
   // Signal System ReConfigure
   jump Signal_system_reconfig;

// *****************************************************************************
// MODULE:
//    $set_front_end_from_vm
//
// DESCRIPTION:
//    Message handler for receiving ADCDAC rate from VM
//
// INPUTS:
//    r1 = dac sampling rate/10 (e.g. 44100Hz is given by r1=4410)
//    r2 = rate match enable mask (bit1==1 enables S/W RM, bit0==1 enables H/W RM
//         (e.g.S/W RM r2=0x0002, H/W RM r2=0x0001, no RM r2=0x0000)
//    r3 = interface mode (0:ADC+DAC, 1:I2S, etc)
//    r4 = adc sampling rate
//
// OUTPUTS:
//    none
// *****************************************************************************
$set_front_end_from_vm:
   // Mask sign extension.  Scale to get DAC sampling rate in Hz
   r1 = r1 AND 0xffff;
   r1 = r1 * 10 (int);
   M[dac_sampling_rate]=r1;

   // S/W RM r2=0x0002, H/W RM r2=0x0001, no RM r2=0x0000
   r2 = r2 AND $SW_RATE_MATCH_MASK;
   M[audio_rate_matching] = r2;

   // ADC+DAC r3=0x00, I2S r3=0x01, etc)
   r3 = r3 AND $AUDIO_IF_MASK;
   M[audio_if_mode] = r3;

   // ADC sampling rate
   r4 = r4 AND 0xffff;
   r4 = r4 * 10 (int);
   M[adc_sampling_rate]=r4;

   // Signal System ReConfigure
   jump Signal_system_reconfig;

// *****************************************************************************
// MODULE:
//    $set_variant_from_vm
//
// DESCRIPTION:
//    Message handler for receiving the variant from the VM
//    This is the LOAD_PARAMS message
//
// INPUTS:
//    none
//
// OUTPUTS:
//    none
// *****************************************************************************
$set_variant_from_vm:
   // Set the default Parameters
   r6 = &$M.CVC.data.DefaultParameters_nb;
   r5 = &$M.CVC.data.DefaultParameters_fe;
   r4 = &$M.CVC.data.DefaultParameters_wb;
   r9 = M[$M.CVC_SYS.cvc_bandwidth];
   Null = r9 - $M.CVC.BANDWIDTH.FE;
   if Z r6 = r5;
   Null = r9 - $M.CVC.BANDWIDTH.WB;
   if Z r6 = r4;
   M[&$M.CVC.app.config.CVC_config_struct + $M.CVC.CONFIG.DEF_PARAMS_PTR] = r6;

Signal_system_reconfig:
    r3 = 1;
    M[$M.audio_config.SysReConfigure]=r3;
    M[$M.CVC_SYS.AlgReInit]=r3;
    rts;

// *****************************************************************************
// MODULE:
//    $CVC_AppHandleConfig
//
// DESCRIPTION:
//    Set Config Flag in statistic
//
$CVC_AppHandleConfig:
   // set mic-config bits
   r1 = M[$M.CVC_MODULES_STAMP.CompConfig];
   r1 = r1 AND (~(flag_uses_DIGITAL_MIC));
   r0 = r4 LSHIFT ( round(log2(flag_uses_DIGITAL_MIC)) - 1);
   r0 = r0 AND flag_uses_DIGITAL_MIC;
   r1 = r1 OR r0;
   M[$M.CVC_MODULES_STAMP.CompConfig] = r1;
   rts;
.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $M.audio_copy_handler
//
// DESCRIPTION:
//    This routine copies data between firmware MMU buffers and dsp processing
//    buffers.  It is called every 625 usec.  SPTBD - check effect on USB IN/OUT operation
//
// *****************************************************************************
.MODULE $M.audio_copy_handler;
   .CODESEGMENT AUDIO_COPY_HANDLER_PM;
   .DATASEGMENT DM;

$audio_copy_handler:
   $push_rLink_macro;

   // Call operators
   r8 = &$adc_in.copy_struc;
   call $cbops_multirate.copy;

   // Set up DAC operation
   call $DAC_CheckConnectivity;

   r8 = &$dac_out.copy_struc;
   call $cbops_multirate.copy;

   r0 = M[&$tone_in.cbuffer_struc + $cbuffer.WRITE_ADDR_FIELD];
   M[&$M.detect_end_of_aux_stream.last_write_address] = r0;

   r8 = &$tone_in.copy_struc;
   call $cbops_multirate.copy;

   // Check for Volume Change due to Auxillary Audio Play
   call $CVC.VolumeControl.Check_Aux_Volume;

   // detect end of tone/prompt stream
   call $detect_end_of_aux_stream;

   null = M[$M.BackEnd.sco_streaming];
   if NZ jump irq_sco;
irq_usb:
        // usb routing
        r8 = &$far_end.in.usb_copy_struc;
        call $frame_sync.usb_in_mono_audio_copy;

        r8 = &$far_end.in.copy_struc;
        call $cbops_multirate.copy;

        r8 = &$far_end.out.copy_struc;
        call $cbops_multirate.copy;

        r8 = &$far_end.out.usb_copy_struc;
        call $frame_sync.usb_out_mono_copy;

        r8 = &$M.CVC.app.scheduler.tasks;
        call $frame_sync.task_scheduler_isr;

        // post another timer event
        r1 = &$audio_copy_timer_struc;
        r2 = $TIMER_PERIOD_AUDIO_COPY_MICROS;
        r3 = &$audio_copy_handler;
        call $timer.schedule_event_in_period;
        jump $pop_rLink_and_rts;

irq_sco:
        // SP - SCO synchronization may reset frame counter
        r7 = &$M.CVC.app.scheduler.tasks + $FRM_SCHEDULER.COUNT_FIELD;
        r1 = &$audio_copy_timer_struc;
        r3 = &$audio_copy_handler;
        call $sco_timing.SyncClock;

        r8 = &$M.CVC.app.scheduler.tasks;
        call $frame_sync.task_scheduler_isr;

        jump $pop_rLink_and_rts;

.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $M.App.Codec.Apply
//
// DESCRIPTION:
//    This function sends ADC and DAC gain to the VM plugin.  It also updates
//    the volume operator and sets the SCO leveling timer.
//
// INPUTS:
//    r3 - DAC Gain
//    r4 - DSP volume
//    r5 - SCO leveling timer used by auxillary mix operator
//    r7 - Volume to compare against OFFSET_LVMODE_THRES
//
// OUTPUTS:
//    sends a CODEC message to the VM application
//
// REGISTER RESTRICTIONS:
//
// CPU USAGE:
//    cycles =
//    CODE memory:
//    DATA memory:    0  words
//
// *****************************************************************************
.MODULE $M.App.Codec.Apply;
   .CODESEGMENT CODEC_APPLY_PM;
   .DATASEGMENT DM;

$App.Codec.Apply:
   $push_rLink_macro;

   // Set DSP volume
   M[$dac_out.audio_out_volume.param + $cbops.volume.FINAL_VALUE_FIELD]= r4;
   // Set the auxillary mix operators hold timer
   M[$dac_out.auxillary_mix_op.param + $cbops.aux_audio_mix_op.TIMER_HOLD_FIELD] = r5;

// Low volume mode switching logic
   // r3 = CurDac
   // if (curdac <= LVMODE_THRS)
   //    volstate = SYSMODE.LOWV
   // else
   //    volstate = SYSMODE.HFK;
   // end
   r0 = $M.CVC_HEADSET.SYSMODE.HFK;
   r6 = $M.CVC_HEADSET.SYSMODE.LOWVOLUME;
   r2 = M[$M.CVC.data.CurParams + $M.CVC_HEADSET.PARAMETERS.OFFSET_LVMODE_THRES];
   Null = r2 - r7;
   if POS r0 = r6;
   M[&$M.CVC_SYS.VolState] = r0;

   // Select ADC gain based on Mode
   r4 = M[$M.CVC.data.CurParams + $M.CVC_HEADSET.PARAMETERS.OFFSET_ADCGAIN];
   r0 = M[$M.CVC.data.CurParams + $M.CVC_HEADSET.PARAMETERS.OFFSET_ADCGAIN_SSR];
   r7 = M[$M.CVC_SYS.cur_mode];
   r7 = r7 - $M.CVC_HEADSET.SYSMODE.SSR;
   if Z r4 = r0;

//    r3 - DAC Gain
//    r4 - ADC Gain
//
//    The DAC Gain is in a form suitable for the VM function CodecSetOutputGainNow.
//    The ADC Gain is the form described by T_mic_gain in csr_cvc_common_if.h

   // r3=DAC gain r4=ADC gain left  r5=ADC Gain Right
   r2 = $M.CVC.VMMSG.CODEC;
   call $message.send_short;
   jump $pop_rLink_and_rts;
.ENDMODULE;


// *****************************************************************************
// MODULE:
//    $M.cvc.wbs_utility
//
// DESCRIPTION:
//    WBS utility functions
//
// *****************************************************************************
.MODULE $M.cvc.wbs_utility;
   .CODESEGMENT CVC_BANDWIDTH_PM;
   .DATASEGMENT DM;



$cvc.wb.wbs_initialize:
   $push_rLink_macro;

   // new merged SBC library needs full initialisation
   // prepare R5 pointer to encoder/decoder data structs

   r5 = M[&$sco_data.object + $sco_pkt_handler.DECODER_PTR];
   push r5;

   r5 = r5 + ($sco_decoder.DATA_PTR - $codec.ENCODER_DATA_OBJECT_FIELD);
   call $sbcenc.init_static_encoder;  // will also reset it

   pop r5;

   r5 = r5 + ($sco_decoder.DATA_PTR - $codec.DECODER_DATA_OBJECT_FIELD);
   call $sbcdec.init_static_decoder;  // also resets and silences

   jump $pop_rLink_and_rts;

$cvc.wb.wbs_sco_encode:
   jump $frame_sync.sco_encode;

.ENDMODULE;


// *****************************************************************************
// MODULE:
//    $M.App.cvc_bandwidth
//
// DESCRIPTION:
//    Loading default parameters for selected CVC bandwidth
//
// INPUTS:
//
// OUTPUTS:
//
// REGISTER RESTRICTIONS:
//
// CPU USAGE:
//
// NOTE:
//    This function is called by $M.cvc_message.LoadParams.func VM message
// *****************************************************************************

.MODULE $M.ConfigureSystem;
   .CODESEGMENT CVC_BANDWIDTH_PM;
   .DATASEGMENT DM;

   .VAR $cvc_fftbins = $M.CVC.Num_FFT_Freq_Bins;
   .VAR $fe_frame_resample_process = 0;
   .VAR $pblock_key = ($CVC_HEADSET_SYSID >> 8) | (CVC_SYS_FS / 2000); // unique key

   .VAR Variant = $M.CVC.BANDWIDTH.DEFAULT;

   .VAR cvc_bandwidth_param_nb[] =
            $M.CVC.BANDWIDTH.NB_FS,             // SYS_FS
            60,                                 // Num_Samples_Per_Frame
            65,                                 // Num_FFT_Freq_Bins
            120,                                // Num_FFT_Window
            SND_PROCESS_TRIGGER_NB,             // SND_PROCESS_TRIGGER
            &$M.oms270.mode.narrow_band.object,          // OMS_MODE_OBJECT
            &$M.AEC_500_NB.LPwrX_margin.overflow_bits,   // AEC_LPWRX_MARGIN_OVFL
            &$M.AEC_500_NB.LPwrX_margin.scale_factor,    // AEC_LPWRX_MARGIN_SCL
            &$M.AEC_500.nb_constants.nzShapeTables,      // AEC_PTR_NZ_TABLES
#if uses_SND_AGC || uses_RCV_VAD
            &$M.CVC.data.vad_peq_parameters_nb,          // VAD_PEQ_PARAM_PTR
#else
            0,
#endif
#if uses_DCBLOCK
            &$M.CVC.data.dcblock_parameters_nb,          // DCBLOC_PEQ_PARAM_PTR
#else
            0,
#endif
            CVC_BANK_CONFIG_HANNING_NB,                  // FB_CONFIG_RCV_ANALYSIS
            CVC_BANK_CONFIG_HANNING_NB,                  // FB_CONFIG_RCV_SYNTHESIS
            CVC_BANK_CONFIG_HANNING_NB,                  // FB_CONFIG_AEC
            $M.CVC.BANDWIDTH.NB_FS/2000,                 // BANDWIDTH_ID
            0;

   .VAR cvc_bandwidth_param_fe[] =
            $M.CVC.BANDWIDTH.FE_FS,             // SYS_FS
            60,                                 // Num_Samples_Per_Frame
            65,                                 // Num_FFT_Freq_Bins
            120,                                // Num_FFT_Window
            SND_PROCESS_TRIGGER_FE,             // SND_PROCESS_TRIGGER
            &$M.oms270.mode.narrow_band.object,          // OMS_MODE_OBJECT
            &$M.AEC_500_NB.LPwrX_margin.overflow_bits,   // AEC_LPWRX_MARGIN_OVFL
            &$M.AEC_500_NB.LPwrX_margin.scale_factor,    // AEC_LPWRX_MARGIN_SCL
            &$M.AEC_500.nb_constants.nzShapeTables,      // AEC_PTR_NZ_TABLES
#if uses_SND_AGC || uses_RCV_VAD
            &$M.CVC.data.vad_peq_parameters_nb,          // VAD_PEQ_PARAM_PTR
#else
            0,
#endif
#if uses_DCBLOCK
            &$M.CVC.data.dcblock_parameters_nb,          // DCBLOC_PEQ_PARAM_PTR
#else
            0,
#endif
            CVC_BANK_CONFIG_HANNING_NB,                  // FB_CONFIG_RCV_ANALYSIS
            CVC_BANK_CONFIG_HANNING_WB,                  // FB_CONFIG_RCV_SYNTHESIS
            CVC_BANK_CONFIG_HANNING_NB,                  // FB_CONFIG_AEC
            $M.CVC.BANDWIDTH.FE_FS/2000,                 // BANDWIDTH_ID
            0;

   .VAR cvc_bandwidth_param_wb[] =
            $M.CVC.BANDWIDTH.WB_FS,             // SYS_FS
            120,                                // Num_Samples_Per_Frame
            129,                                // Num_FFT_Freq_Bins
            240,                                // Num_FFT_Window
            SND_PROCESS_TRIGGER_WB,             // SND_PROCESS_TRIGGER
            &$M.oms270.mode.wide_band.object,            // OMS_MODE_OBJECT
            &$M.AEC_500_WB.LPwrX_margin.overflow_bits,   // AEC_LPWRX_MARGIN_OVFL
            &$M.AEC_500_WB.LPwrX_margin.scale_factor,    // AEC_LPWRX_MARGIN_SCL
            &$M.AEC_500.wb_constants.nzShapeTables,      // AEC_PTR_NZ_TABLES
#if uses_SND_AGC || uses_RCV_VAD
            &$M.CVC.data.vad_peq_parameters_wb,          // VAD_PEQ_PARAM_PTR
#else
            0,
#endif
#if uses_DCBLOCK
            &$M.CVC.data.dcblock_parameters_wb,          // DCBLOC_PEQ_PARAM_PTR
#else
            0,
#endif
            CVC_BANK_CONFIG_HANNING_WB,                  // FB_CONFIG_RCV_ANALYSIS
            CVC_BANK_CONFIG_HANNING_WB,                  // FB_CONFIG_RCV_SYNTHESIS
            CVC_BANK_CONFIG_HANNING_WB,                  // FB_CONFIG_AEC
            $M.CVC.BANDWIDTH.WB_FS/2000,                 // BANDWIDTH_ID
            0;

// *****************************************************************************
// MODULE:
//    $ConfigureSystem
//
// DESCRIPTION:
//    Set up the system including Front End, Back End, and Algorithmm Variant
//
// INPUTS:
//    none
// OUTPUTS:
//    none
// *****************************************************************************
$ConfigureSystem:
   $push_rLink_macro;

   M[$M.audio_config.SysReConfigure]=NULL;

   call $block_interrupts;
   call $ConfigureFrontEnd;
   r1 = M[$M.audio_config.encoding_mode];
   call $ConfigureBackEnd;
   call $unblock_interrupts;

   // select parameter set based on cvc bandwidth
   r6 = &cvc_bandwidth_param_nb;
   r5 = &cvc_bandwidth_param_fe;
   r4 = &cvc_bandwidth_param_wb;
   r9 = M[$M.CVC_SYS.cvc_bandwidth];
   M[Variant] = r9;
   Null = r9 - $M.CVC.BANDWIDTH.FE;
   if Z r6 = r5;
   Null = r9 - $M.CVC.BANDWIDTH.WB;
   if Z r6 = r4;

   // Save the Variant for the UFE (SPI) GetVersion
   r0 = M[r6 + $CVC.BW.PARAM.SYS_FS];
   M[&$M.CVC.app.config.CVC_config_struct + $M.CVC.CONFIG.SYS_FS] = r0;

   // Set SCO/USB Frame Size
   r1 = M[r6 + $CVC.BW.PARAM.Num_Samples_Per_Frame];
#if uses_SND_NS
   r2 = M[$M.CVC.data.AecAnalysisBank + $M.filter_bank.Parameters.OFFSET_CH1_PTR_HISTORY];
   r2 = r2 - r1;
   M[$M.CVC.data.oms270snd_obj + $M.oms270.PTR_INP_X_FIELD] = r2;
#endif
#if uses_SSR
   r2 = M[$M.CVC.data.AecAnalysisBank + $M.filter_bank.Parameters.OFFSET_CH1_PTR_HISTORY];
   r2 = r2 - r1;
   M[$M.CVC.data.oms270ssr_obj + $M.oms270.PTR_INP_X_FIELD] = r2;
#endif
#if uses_RCV_NS
   r2 = M[$M.CVC.data.RcvAnalysisBank + $M.filter_bank.Parameters.OFFSET_PTR_HISTORY];
   r2 = r2 - r1;
   M[$M.CVC.data.oms270rcv_obj + $M.oms270.PTR_INP_X_FIELD] = r2;
#endif

   r0 = M[r6 + $CVC.BW.PARAM.Num_FFT_Freq_Bins];
   M[$cvc_fftbins] = r0;
#if uses_AEQ
   M[&$M.CVC.data.AEQ_DataObject + $M.AdapEq.NUM_FREQ_BINS] = r0;
#endif
#if uses_AEC
   M[&$M.CVC.data.aec_dm1 + $M.AEC_500.OFFSET_NUM_FREQ_BINS] = r0;
   M[&$M.CVC.data.vsm_fdnlp_dm1 + $M.AEC_500_HF.OFFSET_NUM_FREQ_BINS] = r0;
#endif
   r0 = M[r6 + $CVC.BW.PARAM.Num_FFT_Window];
#if uses_RCV_NS
   M[&$M.CVC.data.oms270rcv_obj + $M.oms270.FFT_WINDOW_SIZE_FIELD] = r0;
#endif
#if uses_SND_NS
   M[&$M.CVC.data.oms270snd_obj + $M.oms270.FFT_WINDOW_SIZE_FIELD] = r0;
#endif
#if uses_SSR
   M[&$M.CVC.data.oms270ssr_obj + $M.oms270.FFT_WINDOW_SIZE_FIELD] = r0;
#endif

   r0 = M[r6 + $CVC.BW.PARAM.SND_PROCESS_TRIGGER];
   M[$M.CVC.app.scheduler.tasks + $FRM_SCHEDULER.TASKS_FIELD + $CVC.TASK.OFFSET_SND_PROCESS_TRIGGER]=r0;

   r0 = M[r6 + $CVC.BW.PARAM.OMS_MODE_OBJECT];
#if uses_RCV_NS
   M[&$M.CVC.data.oms270rcv_obj + $M.oms270.PTR_MODE_FIELD] = r0;
#endif
#if uses_SND_NS
   M[&$M.CVC.data.oms270snd_obj + $M.oms270.PTR_MODE_FIELD] = r0;
#endif
#if uses_SSR
   M[&$M.CVC.data.oms270ssr_obj + $M.oms270.PTR_MODE_FIELD] = r0;
#endif
#if uses_AEC
   r0 = M[r6 + $CVC.BW.PARAM.AEC_LPWRX_MARGIN_OVFL];
   r1 = M[r6 + $CVC.BW.PARAM.AEC_LPWRX_MARGIN_SCL];
   r2 = M[r6 + $CVC.BW.PARAM.AEC_PTR_NZ_TABLES];
   M[&$M.CVC.data.aec_dm1 + $M.AEC_500.OFFSET_LPWRX_MARGIN_OVFL] = r0;
   M[&$M.CVC.data.aec_dm1 + $M.AEC_500.OFFSET_LPWRX_MARGIN_SCL] = r1;
   M[&$M.CVC.data.aec_dm1 + $M.AEC_500.OFFSET_PTR_NZ_TABLES] = r2;
#endif

   r0 = M[r6 + $CVC.BW.PARAM.VAD_PEQ_PARAM_PTR];
#if uses_RCV_VAD
   M[&$M.CVC.data.rcv_vad_peq + $audio_proc.peq.PARAM_PTR_FIELD] = r0;
#endif
#if uses_SND_AGC
   M[&$M.CVC.data.snd_vad_peq + $audio_proc.peq.PARAM_PTR_FIELD] = r0;
#endif
   r0 = M[r6 + $CVC.BW.PARAM.DCBLOC_PEQ_PARAM_PTR];
   M[&$M.CVC.data.sco_dc_block_dm1 + $audio_proc.peq.PARAM_PTR_FIELD] = r0;
   M[&$M.CVC.data.adc_dc_block_dm1 + $audio_proc.peq.PARAM_PTR_FIELD] = r0;

#if uses_RCV_FREQPROC
   r0 = M[r6 + $CVC.BW.PARAM.FB_CONFIG_RCV_ANALYSIS];
   M[&$M.CVC.data.RcvAnalysisBank + $M.filter_bank.Parameters.OFFSET_CONFIG_OBJECT] = r0;
#endif
#if uses_RCV_FREQPROC
   r0 = M[r6 + $CVC.BW.PARAM.FB_CONFIG_RCV_SYNTHESIS];
   M[&$M.CVC.data.RcvSynthesisBank + $M.filter_bank.Parameters.OFFSET_CONFIG_OBJECT] = r0;
#endif
   r0 = M[r6 + $CVC.BW.PARAM.FB_CONFIG_AEC];
   M[&$M.CVC.data.AecAnalysisBank + $M.filter_bank.Parameters.OFFSET_CONFIG_OBJECT] = r0;
   M[&$M.CVC.data.SndSynthesisBank + $M.filter_bank.Parameters.OFFSET_CONFIG_OBJECT] = r0;

   // request persistence
   r0 = M[r6 + $CVC.BW.PARAM.BANDWIDTH_ID];
   r3 = r0 OR ($CVC_HEADSET_SYSID >> 8);
   M[$pblock_key] = r3;
   call $restart_persist_timer;

   jump $pop_rLink_and_rts;

.ENDMODULE;

#ifdef MIPS_MESSAGE
// *****************************************************************************
// MODULE:
//    $M.CVC.Status
//
// DESCRIPTION:
//    This message handler will return a set of requested status items
//
// INPUTS:
//   r2 = message length
//   r3 = message data address : points to a list of 16-bit request ID's of 
//       the form: $M.CVC.STATUS.xxx
//
// *****************************************************************************
.MODULE $M.CVC.Status;
   .CODESEGMENT PM;
   .DATASEGMENT DM;
   // status values buffer. Format: 32 bits/status item, LSW first
   .VAR  cvc_status_message_struc[$message.STRUC_SIZE];
   .VAR/DM1 status_values[2*$M.CVC.STATUS.COUNT] = 
      $CVC_HEADSET_SYSID, 0,      // SYSID
#ifdef KAL_ARCH3
      80,0,                         // CPU_MHZ Gordon
#else
      120,0,                         // CPU_MHZ Rick
#endif
      0,0;                          // TOTAL_MIPS
   // return buffer. Format: 32 bits/status item, LSW first
   .VAR/DM2 return_buffer[2*$M.CVC.STATUS.COUNT];
$cvc_status_request_func:
   $push_rLink_macro;
   // first, refresh all status values
   r0 = M[&$M.CVC.app.scheduler.tasks+$FRM_SCHEDULER.TOTAL_MIPS_FIELD];
   r1 = r0 AND 0xffff;
   M[status_values + 2*$M.CVC.STATUS.TOTAL_MIPS] = r1; // current MIPS values (LSW)
   r1 = r0 ASHIFT -16;
   M[status_values + 2*$M.CVC.STATUS.TOTAL_MIPS+1] = r1; // current MIPS values (MSW)
   // second, gather requested status and place in return buffer
   I4 = &return_buffer;
   I0 = r3; // points to list of requested ID's
   r10 = r2;
   r0 = M[I0, 1]; // get requested ID, and use as index into "status_values"
   do get_status_loop;
      r0 = r0 LSHIFT 1;
      I1 = &status_values + r0;
      r0 = M[I1, 1]; // get LSW
      M[I4, 1] = r0, r0 = M[I1, 1]; // store LSW, get MSW
      M[I4, 1] = r0, r0 = M[I0, 1]; // store MSW, get ID
   get_status_loop:
   // send the response
   r3 = $M.CVC.VMMSG.STATUS_RESPONSE;
   r4 = r2 LSHIFT 1;
   r5 = &return_buffer;
   call $message.send_long;
   jump $pop_rLink_and_rts;
.ENDMODULE;
#endif
