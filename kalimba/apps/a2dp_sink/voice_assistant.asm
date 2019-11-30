
// ENABLE_VA_BACK_CHANNEL (defined in the project properties) enables the Voice
// Assistant stream, which does:
// ADC (mono @ 16 kHz) -> SBC encoder (compression ratio of 4) -> VM.
// The VM adds appropriate headers and sends the byte stream to a phone
// application for communication with Amazon Alexa.

// Note that the main music stream cannot use ADC or SPDIF when VA is enabled
// because there would be a port conflict with read port 1.  VA is only valid
// when using A2DP input on the main music channel.

// Also note that the VM controls the SBC encoder parameters.  The design 
// currently uses a bitpool of 28 to obtain 64 kbps per second.  If the VM
// were to change this, companion changes might be required in this DSP
// application; for example, the VA buffer sizes might need to be increased.

#include "core_library.h"
#include "cbops_library.h"
#include "codec_library.h"
#include "sbc_library.h"
#include "frame_sync_stream_macros.h"

#ifdef ENABLE_VA_BACK_CHANNEL

.MODULE $M.voice_assistant;
   .DATASEGMENT DM;
   .CODESEGMENT PM;
   
   .VAR enabled = 0;

   .CONST $VA_INPUT_PORT          ($cbuffer.READ_PORT_MASK  + 1);
   .CONST $VA_OUTPUT_PORT         ($cbuffer.WRITE_PORT_MASK + 0);

   // ** allocate memory for VA input (ADC input) copy routine **
   .VAR/DM1 $va_input_copy_struc[] =
      $va_input_copy_op,                  // Start of operator chain
      1,                                  // 1 input
      $VA_INPUT_PORT,                     // input
      1,                                  // 1 output
      &$va_audio_in_struc;                // output

   .BLOCK $va_input_copy_op;
      .VAR $va_input_copy_op.next = $cbops.NO_MORE_OPERATORS;
      .VAR $va_input_copy_op.func = &$cbops.shift;
      .VAR $va_input_copy_op.param[$cbops.shift.STRUC_SIZE] =
         0,                               // Input index
         1,                               // Output index
         8;
   .ENDBLOCK;
   
   // ** allocate memory for VA output (SBC encoded) copy routine **
   .VAR/DM1 $va_output_copy_struc[] =
      &$va_output_copy_op,                // Start of operator chain
      1,                                  // 1 input
      $va_codec_out_cbuffer_struc,        // input
      1,                                  // 1 output
      $VA_OUTPUT_PORT;                    // output

   .BLOCK $va_output_copy_op;
      .VAR $va_output_copy_op.next = $cbops.NO_MORE_OPERATORS;
      .VAR $va_output_copy_op.func = &$cbops.copy_op;
      .VAR $va_output_copy_op.param[$cbops.copy_op.STRUC_SIZE] =
         0,                               // Input index
         1;                               // Output index
   .ENDBLOCK;

 // These scratch "registers" are used by various libraries (e.g. SBC)
   .VAR $scratch.s0;
   .VAR $scratch.s1;
   .VAR $scratch.s2;

// ** allocate memory for av encoder structure **
   .VAR/DM1 $av_encoder_codec_stream_struc[$codec.av_encode.STRUC_SIZE] =
      &$sbcenc.frame_encode,                    // frame_encode function
      &$sbcenc.reset_encoder,                   // reset_encoder function
      $va_codec_out_cbuffer_struc,
      &$va_audio_in_struc,                      // in left cbuffer
      0,                                        // in right cbuffer
      0 ...;                                    // will also contain new pointer to data object field

   DeclareCBuffer($va_audio_in_struc,$va_audio_in, 512);
   DeclareCBuffer($va_codec_out_cbuffer_struc, $va_codec_out, 128); 
.ENDMODULE;


// *****************************************************************************
// MODULE:
//    $M.va.init
//
// DESCRIPTION:
//    Initialise Voice Assistant Processing
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
// *****************************************************************************
.MODULE $M.va.init;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

   $va.init:

   $push_rLink_macro;

   // Initialise the codec library. Stream codec structure has codec structure nested
   // inside it, so can pass start of codec structure to init, where data object pointer
   // is also set.
   r5 = &$av_encoder_codec_stream_struc + $codec.av_encode.ENCODER_STRUC_FIELD;
   call $sbcenc.init_static_encoder;

   jump $pop_rLink_and_rts;

.ENDMODULE;


//**************************************************************
// MODULE $M.va.sbc_encoder
//
// DESCRIPTION:
//       Encodes audio into SBC packets
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
// *****************************************************************************

.MODULE  $M.va.sbc_encoder;
   .CODESEGMENT   PM;
   .DATASEGMENT   DM;

$va.sbc_encoder:

$push_rLink_macro;

   r0 = $VA_INPUT_PORT;
   call $cbuffer.is_it_enabled;
   if Z jump va_not_enabled;
   
   r0 = $VA_OUTPUT_PORT;
   call $cbuffer.is_it_enabled;
   if Z jump va_not_enabled;

   // running reset function if required
   Null = M[$M.voice_assistant.enabled];
   if NZ jump no_codec_reset_needed;
      r5 = &$av_encoder_codec_stream_struc;
      r0 = M[r5 + $codec.stream_encode.RESET_ADDR_FIELD];
      //r5 has to be encoder data structure pointer, rather than stream encoder struct ptr
      r5 = r5 + $codec.av_encode.ENCODER_STRUC_FIELD;
      call r0;
      r0 = 1;
      M[$M.voice_assistant.enabled] = r0;

no_codec_reset_needed:
   // encode a frame
   r5 = &$av_encoder_codec_stream_struc;
   call $codec.av_encode;

   jump $pop_rLink_and_rts;

va_not_enabled:
   M[$M.voice_assistant.enabled] = Null;
   jump $pop_rLink_and_rts;

.ENDMODULE;

#endif // ENABLE_VA_BACK_CHANNEL