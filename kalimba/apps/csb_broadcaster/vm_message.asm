// *****************************************************************************
// Copyright (c) 2008 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************


#include "music_example.h"
#include "stack.h"
#include "pskey.h"
#include "message.h"
#include "cbops_library.h"

// VM Message Handlers
.MODULE $M.music_example_message;
   .DATASEGMENT DM;
   .VAR set_mode_message_struc[$message.STRUC_SIZE];
   .VAR load_params_message_struc[$message.STRUC_SIZE];
   .VAR ps_key_struc[$pskey.STRUC_SIZE];
   .VAR multi_channel_main_mute_s_message_struc[$message.STRUC_SIZE];
.ENDMODULE;


.MODULE $M.music_example_message_payload_cache;
   .DATASEGMENT DM;
   .CONST $message.PAYLOAD_CACHE_SIZE       10;                   // Enough space for the largest expected long message payload

   // Replacement message configuration message structures
   .VAR set_output_dev_type_s[$message.PAYLOAD_CACHE_SIZE];
   .VAR multi_channel_main_mute_s[$message.PAYLOAD_CACHE_SIZE];
   .VAR multi_channel_aux_mute_s[$message.PAYLOAD_CACHE_SIZE];
   .VAR multi_volume_s[$message.PAYLOAD_CACHE_SIZE];
   .VAR aux_volume_s[$message.PAYLOAD_CACHE_SIZE];

.ENDMODULE;
// *****************************************************************************
// DESCRIPTION: $MsgMusicSetMode
//       handle mode change
//  r1 = processing mode
//  r2 = eq bank state (TODO: to which modes does this apply?)
//       0 = do not advance to next EQ bank
//       1 = advance to next EQ bank
//       2 = use eq Bank that is specified in r3
//  r3 = eq bank (only used if r2 = 2)
// *****************************************************************************
.MODULE $M.music_example_message.SetMode;

   .CODESEGMENT   PM;
func:
   Null = r2; /* TODO see if the plugin is doing this initially */
   if Z jump do_not_advance_to_next_eq_bank;
      r4 = $M.MUSIC_MANAGER.CONFIG.USER_EQ_SELECT;

      // get number of EQ banks in use
      r5 = M[&$M.system_config.data.CurParams + $M.MUSIC_MANAGER.PARAMETERS.OFFSET_USER_EQ_NUM_BANKS];
      r5 = r5 and r4;

      // get the current EQ bank and advance to next
      r0 = M[&$M.system_config.data.CurParams + $M.MUSIC_MANAGER.PARAMETERS.OFFSET_CONFIG];
      r6 = r0 AND r4;
      r6 = r6 + 1;

      // use specified index if r2==2
      Null = r2 - 2;
      if Z r6 = r3;

      // If EQFLAT bit is one it means a flat curve has been added to the system.
      // The flat curve is used when bank==0;
      // If EQFLAT bit is zero AND bank==0, bank must be forced to one.
      r8 = $M.MUSIC_MANAGER.CONFIG.EQFLAT;
      r3 = 0;
      r7 = 1;
      Null = r0 AND r8;     // is zero if flat curve not allowed (i.e. Bank0 not allowed)
      if Z r3 = r7;
      NULL = r5 - r6;
      if LT r6 = r3;        // reset index to 0 or 1 depending on EQFLAT

      // If the VM sent r2=2 and r3=0, use Bank1 if a flat curve isn't included
      Null = r6 - 0;
      if Z r6 = r3;

      // update EQ bank bits of Music Manager Config Parameter
      r7 = 0xffffff XOR r4;
      r7 = r0 AND r7;
      r6 = r7 OR r6;
      M[&$M.system_config.data.CurParams + $M.MUSIC_MANAGER.PARAMETERS.OFFSET_CONFIG] = r6;

      // User has requested a new EQ bank, but shouldn't need to call
      // coefficient calculation routine here as "reinit" is requested.

   do_not_advance_to_next_eq_bank:

   // ensure mode is valid
   r3 = $M.MUSIC_MANAGER.SYSMODE.MAX_MODES;
   Null = r3 - r1;
   if NEG r1 = r3;
   r3 = $M.MUSIC_MANAGER.SYSMODE.STANDBY;
   Null = r3 - r1;
   if POS r1 = r3;
   // save mode
   M[$music_example.sys_mode] = r1;
   // Re-init because mode or EQ setting has changed
   r1 = 1;
   M[$music_example.reinit] = r1;
   rts;
.ENDMODULE;


// *****************************************************************************
// DESCRIPTION: $LoadParams
// r1 = PsKey Address containing Music Example parameters
// *****************************************************************************
.MODULE $M.music_example.LoadParams;

   .CODESEGMENT PM;
   .DATASEGMENT DM;
   .VAR paramoffset = 0;
   .VAR Pskey_fetch_flg = 1;
   .VAR Last_PsKey;
#if defined(SELECTED_MULTI_DECODER)
   .VAR $codec_config = $INVALID_CONFIG; 
#elif defined(SELECTED_DECODER_AAC)
   .VAR $codec_config = $music_example.AAC_CODEC_CONFIG; 
#elif defined(SELECTED_DECODER_SBC)
   .VAR $codec_config = $music_example.SBC_CODEC_CONFIG; 
#endif

func:
   $push_rLink_macro;
   // Set Mode to standby
   r8 = $M.MUSIC_MANAGER.SYSMODE.STANDBY;
   M[$music_example.sys_mode] = r8;
   push r1; // save key
   // Copy default parameters into current parameters
   call $M.music_example.load_default_params.func;
   // Save for SPI Status
   M[paramoffset] = 0; // needed if loadparams is called more than once
   pop r2;
   M[Last_PsKey] = r2;
TestPsKey:
   if Z jump done;
      // r2 = key;
      //  &$friendly_name_pskey_struc;
      r1 = &$M.music_example_message.ps_key_struc;
      // &$DEVICE_NAME_pskey_handler;
      r3 = &$M.music_example.PsKeyReadHandler.func;
      call $pskey.read_key;
      jump $pop_rLink_and_rts;
done:

   // copy codec config word to current config word  
   r0 = M[$codec_config];
#ifdef DEBUG_ON
   if NEG call $error;
#endif 
   r0 = M[&$M.system_config.data.CurParams + r0];

   // Set the current codec config word
   M[&$M.system_config.data.CurParams + $M.MUSIC_MANAGER.PARAMETERS.OFFSET_CONFIG] = r0;
   
   r8 = 1;
   M[$music_example.reinit] = r8;

   // Tell VM is can send other messages
   r2 = $music_example.VMMSG.PARAMS_LOADED;
   call $message.send_short;

   jump $pop_rLink_and_rts;
.ENDMODULE;



// *****************************************************************************
// DESCRIPTION: $PsKeyReadHandler
//  INPUTS:
//    Standard (short) message mode:
//    r1 = Key ID
//    r2 = Buffer Length; $pskey.FAILED_READ_LENGTH on failure
//    r3 = Payload.  Key ID Plus data
// *****************************************************************************
.MODULE $M.music_example.PsKeyReadHandler;

   .CODESEGMENT PM;

func:
   $push_rLink_macro;

   // error checking - check if read failed
   // if so, DSP default values will be used instead of PsKey values.
   Null = r2 - $pskey.FAILED_READ_LENGTH;
   if NZ jump No_Retry;
   //Retry requesting for the PSKEY once.
   r0 = M[$M.music_example.LoadParams.Pskey_fetch_flg];  //If Z we have retried once already
   if Z jump No_2nd_Retry;
   M[$M.music_example.LoadParams.Pskey_fetch_flg] = 0;
   r2 = M[$M.music_example.LoadParams.Last_PsKey];
   jump $M.music_example.LoadParams.TestPsKey;
No_2nd_Retry:
   //Reset flag for next time and keep the default parameters
   r0 = 1;
   M[$M.music_example.LoadParams.Pskey_fetch_flg] = r0;
   jump $M.music_example.LoadParams.done;
No_Retry:
   // Adjust for Key Value in payload?
   I0 = r3 + 1;
   r10 = r2 - 1;
   // Clear sign bits
   // I2=copy of address
   I2 = I0;
   // r3=mask to clear sign extension
   r3 = 0x00ffff;
   do loop1;
      r0 = M[I2,0];
      r0 = r0 AND r3;
      M[I2,1] = r0;
loop1:
   r10 = 256;

   // End of buffer pointer (last valid location)
   I2 = I2 - 1;

   // error checking - make sure first value is the Pskey address.
   // if not, DSP default values will be used instead of PsKey values.
   r0 = M[I0,1];
   Null = r1 - r0;
   if NZ jump $M.music_example.LoadParams.done;

   // get next Pskey address
   // r5 = address of next PsKey
   r5 = M[I0,1];
   r0 = M[I0,1];
   // r4 = NumParams (last parameter + 1)
   r4 = r0 AND 0xff;
   if Z r4 = r10;
   // r0 = firstParam (zero-based index into
   //      paramBlock)
   r0 = r0 LSHIFT -8;

   // initial mask value
   r8 = Null;

start_loop:
      r8 = r8 LSHIFT -1;
      if NZ jump withinGroup;

      // Check for past end of buffer
      null = I2 - I0;
      if NEG jump endOfBuffer;

      // group
      r3 = M[I0,1];

      // mask value
      r8 = 0x8000;
      // used for odd variable
      r7 = Null;
withinGroup:
      Null = r3 AND r8;
      if Z jump dontOverwriteCurrentValue;
         // overwrite current parameter
         r7 = r7 XOR 0xffffff;
         if Z jump SomeWhere;
         // MSB for next two parameters
         r2 = M[I0,1];
         // MSB for param1
         r6 = r2 LSHIFT -8;
         jump SomeWhereElse;
SomeWhere:
         // MSB for param2
         r6 = r2 AND 0xff;
SomeWhereElse:
         // LSW
         r1 = M[I0,1];
         r6 = r6 LSHIFT 16;
         // Combine MSW and LSW
         r1 = r1 OR r6;
         r6 = r0 + M[$M.music_example.LoadParams.paramoffset];
         M[$M.system_config.data.CurParams + r6] = r1;
dontOverwriteCurrentValue:
      r0 = r0 + 1;
      Null = r0 - r4;
   if NEG jump start_loop;

endOfBuffer:
   // inc offset if lastkey=0
   r2 = M[$M.music_example.LoadParams.paramoffset];
   Null = r4 - r10;
   if Z r2 = r2 + r10;
   M[$M.music_example.LoadParams.paramoffset] = r2;
   // PS Key Being requested
   r2 = r5;
   jump $M.music_example.LoadParams.TestPsKey;

.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $M.music_example_message.MainVolume_s
//
// DESCRIPTION:
//    Handler for the replacement short multi-channel configuration message.
//    (this uses the original corresponding long configuration message handler)
//    Message from VM->DSP to specify the mute status of all main wired outputs
//    (Note 1: all main wired multi-channel outputs are specified)
//    (Note 2: r1 selects the parameters being set by the message
//     Parameters are cached until a message with r1 = 0 is received
//     this sets all the parameters atomically from the cache.)
//
// INPUTS:
//
//    r1 = volume select = 0                       <=  This must be sent to synchronise
//    r2 = system volume index (i.e. DAC index)        other main volume changes
//    r3 = master volume (dB)*60
//    r4 = tone volume (dB)*60

//    r1 = volume select = 1
//    r2 = Left primary trim volume (dB)*60
//    r3 = Right primary trim volume (dB)*60
//    r4 = <not used>

//    r1 = volume select = 2
//    r2 = Left secondary trim volume (dB)*60
//    r3 = Right secondary trim volume (dB)*60
//    r4 = Wired subwoofer trim (dB)*60

// OUTPUTS:
//    none
//
// TRASHED REGISTERS:
//    r0, r1, r2, r3, r4, r5, r8, I0
//
// *****************************************************************************
.MODULE $M.music_example_message.MainVolume_s;

   .CODESEGMENT PM;

func:

   // Point the temporary message payload cache
   r5 = $M.music_example_message_payload_cache.multi_volume_s;
   I0 = r5;

   null = r1;                          // Test the select
   if NZ jump skip_select0;

      // Load parameters into cache then process all the volume parameters from the cache
      M[I0,1] = r2;                    // System volume index
      M[I0,1] = r3;                    // Master volume (dB)*60
      M[I0,1] = r4;                    // Tone volume (dB)*60

      // Point at the payload cache
      r3 = r5;

      // Execute the original long message handler (input: r3 points at the payload cache)
      jump $M.music_example_message.MainVolume.func;

   skip_select0:

   null = r1 - 1;                      // Test the select
   if NZ jump skip_select1;

      // Load parameters into cache then exit without processing
      M0 = 3;
      r0 = M[I0,M0];                   // Dummy read to skip other parameters in cache
      M[I0,1] = r2;                    // Left primary trim volume (dB)*60
      M[I0,1] = r3;                    // Right primary trim volume (dB)*60

      jump exit;                       // Exit without processing
   skip_select1:

   null = r1 - 2;                      // Test the select
   if NZ jump skip_select2;

#if 0 // not supported in BA
      // Load parameters into cache then exit without processing
      M0 = 5;
      r0 = M[I0,M0];                   // Dummy read to skip other parameters in cache
      M[I0,1] = r2;                    // Left secondary trim volume (dB)*60
      M[I0,1] = r3;                    // Right secondary trim volume (dB)*60
      M[I0,1] = r4;                    // Wired subwoofer trim (dB)*60
#endif

   skip_select2:
   exit:
   // Exit without processing volume parameters
   rts;
.ENDMODULE;

// *****************************************************************************
// DESCRIPTION: $MsgMusicExampleSetMainVolume
//       handle call state mode
//  r3 = message pay load
//     word0 = sytem volume index
//     word1 = master_volume_dB * 60
//     word2 = tone_volume_dB * 60
//     word3 = primary_left_trim_volume_dB * 60
//     word4 = primary_right_trim_volume_dB * 60
//     word5 = secondary_left_trim_volume_dB * 60
//     word6 = secondary_right_trim_volume_dB * 60
//     word7 = sub_trim_volume_dB * 60
//
// *****************************************************************************
.MODULE $M.music_example_message.MainVolume;

.DATASEGMENT DM;

.CODESEGMENT   PM;

   .VAR $multichannel_vol_msg_echo = 0;
   .VAR temp_msg_ptr;
// ------------------------------------------
// update_volumes:
//    update the system when receiving
//    new volumes, it also sends the
//    system volume to vm
//
// ------------------------------------------
update_volumes:

   // push rLink onto stack
   $push_rLink_macro;

   // update internal volumes
   I0 = r3;
   M[temp_msg_ptr] = r3;


   r4 = M[I0,1];

   .VAR $DAC_conn_main = 1;
   null = M[$DAC_conn_main]; //TODO: find out if we need this in BA
   if Z jump no_system_vol;
   // update system volume
   r4 = r4 AND 0xF;
   M[$music_example.SystemVolume] = r4;

 no_system_vol:

   // update master volume
   r0 = M[I0,1];
   null =r0;
   if POS r0 = 0;
   M[$music_example.Main.MasterVolume] = r0;

   // convert master volume to linear
   call $M.music_example_message.vmdB2vol;
   M[$M.system_config.data.multichannel_volume_and_limit_obj + $volume_and_limit.MASTER_VOLUME_FIELD] = r0;

   // update tone volume
   r0 = M[I0,1];
   Null = r0;
   if POS r0 = 0;
   M[$music_example.Main.ToneVolume] = r0;

   // convert tone volume to linear
   call $M.music_example_message.vmdB2vol;
   r3 = r0 ASHIFT 3;  // 4-bit up for converting Q5.19 to Q1.23, 1 down for mixing
   // Input r3 = tone mixing ratio
   call $multi_chan_set_prim_tone_mix_ratio;

   // update primary left trim volume
   r0 = M[I0,1];
   r1 = r0 - $music_example.MAX_VM_TRIM_VOLUME_dB;
   if POS r0 = r0 - r1;
   r1 = r0 - $music_example.MIN_VM_TRIM_VOLUME_dB;
   if NEG r0 = r0 - r1;
   M[$music_example.Main.PrimaryLeftTrimVolume] = r0;

   // convert trim to linear
   call $M.music_example_message.vmdB2vol;
   M[$M.system_config.data.left_primary_channel_vol_struc + $volume_and_limit.channel.TRIM_VOLUME_FIELD] = r0;

   // right primary trim volume
   r0 = M[I0,1];
   r1 = r0 - $music_example.MAX_VM_TRIM_VOLUME_dB;
   if POS r0 = r0 - r1;
   r1 = r0 - $music_example.MIN_VM_TRIM_VOLUME_dB;
   if NEG r0 = r0 - r1;
   M[$music_example.Main.PrimaryRightTrimVolume] = r0;

   // convert  trim to linear
   call $M.music_example_message.vmdB2vol;
   M[$M.system_config.data.right_primary_channel_vol_struc + $volume_and_limit.channel.TRIM_VOLUME_FIELD] = r0;

   // VM expects entire volume message to be sent back
   null = M[$multichannel_vol_msg_echo];
   if Z jump done;
   r5 = M[temp_msg_ptr];
   r4 = 8; // size of main volume message
   r3 = $music_example.VMMSG.MESSAGE_MAIN_VOLUME_RESP;
   call $message.send_long;

done:
   // pop rLink from stack
   jump $pop_rLink_and_rts;

func:
   // push rLink onto stack
   $push_rLink_macro;

   call update_volumes;

volume_msg_done:
   // pop rLink from stack
   jump $pop_rLink_and_rts;

.ENDMODULE;

.MODULE $M.music_example_message;
   .DATASEGMENT DM;
   .CODESEGMENT PM;
   
   .VAR multi_volume_s_message_struc[$message.STRUC_SIZE];

// ---------------------------------------
// vmdB2vol:
//    helper function to convert
//    vm volumes(dB/60.) to suitable
//    linear format for DSP (Q5.19)
//
//    input r0 = vm vol dB
//
//    output r0 = kal vol linear
// ---------------------------------------
vmdB2vol:
   // convert vmdB to log2 format
   r1 = 0.4215663554485;
   rMAC = r0 * 181 (int);
   rMAC = rMAC + r0 * r1;
   // less 24dB for Q5.19 format
   r0 = rMAC - (1<<18);
   if POS r0 = 0;
   // r0 = log2(volume/16.0)
   jump $math.pow2_taylor;

.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $multi_chan_set_prim_tone_mix_ratio
//
// DESCRIPTION:
//    Helper function to set the primary channel tone mixing ratio
//
// INPUTS:
//    r3 = primary channel tone mixing ratio
//
// OUTPUTS:
//    none
//
// TRASHED:
//    none
//
// *****************************************************************************
.MODULE $M.multi_chan_set_prim_tone_mix_ratio;
   .CODESEGMENT PM;

   $multi_chan_set_prim_tone_mix_ratio:

   // Set the primary channel tone mixing ratio
   M[$M.post_eq.tone_mixer_l.param + $cbops.auto_resample_mix.TONE_MIXING_RATIO_FIELD] = r3;
   M[$M.post_eq.tone_mixer_r.param + $cbops.auto_resample_mix.TONE_MIXING_RATIO_FIELD] = r3;
   M[$tone_mixing_data + 2] = r3;

   rts;

.ENDMODULE;


// plugin function
// VM message handlers for set_plugin, Set Codec rate, APTX-LL params
// *****************************************************************************
// MODULE:
//    $M.set_plugin
//
// FUNCTION
//    $M.set_plugin.func
//
// DESCRIPTION:
//    Handle the set plugin VM message
//    (this sets the codec type)
//
// INPUTS:
//    r1 = connection type:
//    SBC_DECODER      1
//    AAC_DECODER      3
//
//
// OUTPUTS:
//    none
//
// TRASHES: r1
//
// *****************************************************************************
#ifdef SELECTED_MULTI_DECODER
.MODULE $M.set_plugin;
   .CODESEGMENT   PM;
   .DATASEGMENT   DM;

func:
   // Allow only the first message ($codec_config is initialised to -1)
   Null = M[$codec_config];
   if   GT  rts;

   // Set the plugin type
   Null = r1 - $SBC_IO;
   if   Z   jump   configure_sbc;
   Null = r1 - $AAC_IO;  
   if   Z   jump   configure_aac;
   // Unknown codec
   call $error;
   
configure_sbc:
    r1 = $music_example.SBC_CODEC_CONFIG; 
    M[$codec_config] = r1;
   // setup for $app.rtp_input_decoder_params + 5
   r1 = $_sbc_decode_frame;
   M[$app.rtp_input_decoder_params + 5] = r1;
   // setup for $app.rtp_input_params + 6   
   r1 = $_rtp_input_process_sbc_frames;
   M[$app.rtp_input_params + 6] = r1;
   rts;
   
configure_aac:
    r1 = $music_example.AAC_CODEC_CONFIG; 
    M[$codec_config] = r1;
   // setup for $app.rtp_input_decoder_params + 5
   r1 = $_aac_decode_frame;
   M[$app.rtp_input_decoder_params + 5] = r1;
   // setup for $app.rtp_input_params + 6   
   r1 = $_rtp_input_process_aac_frames;
   M[$app.rtp_input_params + 6] = r1;
   rts;

.ENDMODULE;
#endif // SELECTED_MULTI_DECODER

