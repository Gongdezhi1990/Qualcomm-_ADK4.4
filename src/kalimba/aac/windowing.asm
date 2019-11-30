// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.windowing
//
// DESCRIPTION:
//    Windowing
//
// INPUTS:
//    - M0  = 0 when need to update previous_window_shape (filterbank),
//         != 0 when don't want to update (ltp)
//                = -2 when called from self due to nonsense window_sequence order
//                = -1 when called from filterbank_analysis_ltp first time
//                =  1 when called from ltp_decode or from self due to nonsense window_sequence order
//                =  2 when called from filterbank_analysis_ltp second time
//    - I5  = start address of output buffer if M0 != 0
//    - r4  = buffer to second half window (if not overlap_add ie when M0=2)
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - assume all
//
// *****************************************************************************
.MODULE $M.aacdec.windowing;
   .CODESEGMENT AACDEC_WINDOWING_PM;
   .DATASEGMENT DM;

   $aacdec.windowing:

   // push rLink onto stack
   push rLink;

   // set r6 and tmp+9 to window shape (current if M0==2, previous otherwise)
   r2 = M[$aacdec.current_channel];
   r6 = M[$aacdec.previous_window_shape + r2];
   r0 = M[$aacdec.current_ics_ptr];
   r0 = M[r0 + $aacdec.ics.WINDOW_SHAPE_FIELD];
   Null = M0 - 2;
   if Z r6 = r0;
   M[$aacdec.tmp + 9] = r6;


   // store M0 for later
   r0 = M0;
   M[$aacdec.tmp + 1] = r0;

   // choose buffers depending on channel
   r5 = M[$aacdec.codec_struc];
   Null = M[$aacdec.current_channel];
   if NZ jump right_chan;
   left_chan:
  #ifndef AAC_USE_EXTERNAL_MEMORY
      I3 = &$aacdec.overlap_add_left;
  #else 
      r0 = M[$aacdec.overlap_add_left_ptr];
      I3 = r0;
  #endif //AAC_USE_EXTERNAL_MEMORY
       
      r0 = M[r5 + $codec.DECODER_OUT_LEFT_BUFFER_FIELD];
      // if no buffer connected just exit
      // (eg. only playing 1 channel of a stereo stream)
      if Z jump $pop_rLink_and_rts;
      jump chan_select_done;
   right_chan:
      
  #ifndef AAC_USE_EXTERNAL_MEMORY
      I3 = &$aacdec.overlap_add_right;
  #else 
      r0 = M[$aacdec.overlap_add_right_ptr];
      I3 = r0;
  #endif //AAC_USE_EXTERNAL_MEMORY
  #ifdef AAC_ENABLE_ROUTING_OPTIONS 
      Null = M[$aacdec.routing_mode]; 
      if NZ jump tws_mode3;
      r0 = M[r5 + $codec.DECODER_OUT_RIGHT_BUFFER_FIELD];
      jump non_tws_mode3;
tws_mode3:
      r0 = M[r5 + $codec.DECODER_OUT_LEFT_BUFFER_FIELD];
non_tws_mode3:
  #else 
      r0 = M[r5 + $codec.DECODER_OUT_RIGHT_BUFFER_FIELD];
  
  #endif 
      // if no buffer connected just exit
      // (eg. only playing 1 channel of a stereo stream)
        if Z jump $pop_rLink_and_rts;
   chan_select_done:

   // set up basic modify registers
   M2 = -1;
   M3 = +1;

   // set up I5 (output) if M0 = 0
   // otherwise set up dummy input and, if M0==2 set I3 to another location
   Null = M0;
   if NZ jump dummy_input;
      M[$aacdec.tmp + 2] = r0;
      call $cbuffer.get_write_address_and_size;
      I5 = r0;
      L5 = r1;
      L4 = r1;
      jump i3_and_i5_set;
   dummy_input:
      M[$aacdec.tmp + 4] = Null;
      Null = M0 - 2;
      if Z I3 = r4;
      Null = M0;
      if POS M2 = 0;
      if POS jump i3_and_i5_set;
      M3 = 0;
      I3 = &$aacdec.tmp + 4;
   i3_and_i5_set:

   // set tmp+5 to -1, 0 or 1 depending on M0
   r0 = 0;
   r1 = 1;
   r2 = -1;
   Null = M0 + 1;
   if Z r0 = r2;
   Null = M0 - 2;
   if Z r0 = r1;
   M[$aacdec.tmp + 5] = r0;

   // set tmp+6 to beginning of tmp_mem_pool if tmp+5==0 or middle otherwise
 #ifndef AAC_USE_EXTERNAL_MEMORY  
   r1 = &$aacdec.tmp_mem_pool;
   r2 = &$aacdec.tmp_mem_pool+512;
 #else  
   r1 =  M[$aacdec.tmp_mem_pool_ptr];
   r2 = r1 + 512;
 #endif 
   Null = r0;
   if NZ r1 = r2;
   M[$aacdec.tmp + 6] = r1;

   // branch depending on window sequence
   // normal branch if M0!=2 otherwise have to branch on what last sequence was
   r4 = M[$aacdec.current_ics_ptr];
   r0 = M[r4 + $aacdec.ics.WINDOW_SEQUENCE_FIELD];
   r1 = M[$aacdec.current_channel];
   r1 = M[$aacdec.previous_window_sequence + r1];
   Null = M0 - 2;
   if NZ jump normal_choice;
      Null = r0 - $aacdec.LONG_START_SEQUENCE;
      if Z jump long_start_sequence_processing;
      jump only_long_sequence;

   normal_choice:
      Null = M[r4 + $aacdec.ics.PREV_WINDOW_SEQ_EQ_LONG_START_FIELD];
      if NZ jump long_start_sequence_processing;
      Null = r0 - $aacdec.ONLY_LONG_SEQUENCE;
      if Z jump only_long_sequence;
      Null = r0 - $aacdec.LONG_STOP_SEQUENCE;
      if Z jump long_stop_sequence;
      Null = r0 - $aacdec.EIGHT_SHORT_SEQUENCE;
      if Z jump eight_short_sequence;

   // -- LONG_START_SEQUENCE --
   long_start_sequence:
      Null = M0;
      if NZ jump only_long_sequence;
      r2 = 1;
      M[r4 + $aacdec.ics.PREV_WINDOW_SEQ_EQ_LONG_START_FIELD] = r2;
      // this frame should be processed by only_long_sequence, the next
      // frame should be processed by long_start_sequence

   // -- ONLY_LONG_SEQUENCE --
   only_long_sequence:
      Null = M0;
      if NZ jump only_long_sequence_ok;
         Null = r1 - $aacdec.ONLY_LONG_SEQUENCE;
         if Z jump only_long_sequence_ok;
         Null = r1 - $aacdec.LONG_STOP_SEQUENCE;
         if Z jump only_long_sequence_ok;
         M[r4 + $aacdec.ics.WINDOW_SEQUENCE_FIELD] = r1;
         M0 = 1;
         call $aacdec.windowing;
         r1 = $aacdec.ONLY_LONG_SEQUENCE;
         r4 = M[$aacdec.current_ics_ptr];
         M[r4 + $aacdec.ics.WINDOW_SEQUENCE_FIELD] = r1;
         M0 = -1024;
         r0 = M[I5,M0];
         M0 = -2;
         call $aacdec.windowing;
         M[$aacdec.tmp + 1] = Null;
         jump finished_windowing;
      only_long_sequence_ok:

      // set up r8 & r9
      r4 = M[$aacdec.current_spec_blksigndet_ptr];
      r1 = 1;
      r8 = 2;
      Null = M[r4 + 1];
      if NZ r8 = r1;
      r9 = 1;

      r10 = 1024;

      // write full output
      M[$aacdec.tmp + 3] = Null;

      // set I2 to input buffer or dummy input
      r0 = M[$aacdec.tmp + 6];
      r0 = r0 + 511;
      I2 = &$aacdec.tmp + 4;
      Null = M2;
      if NZ I2 = r0;
      call window;

      jump finished_windowing;

   // -- long_start_sequence_processing --
   long_start_sequence_processing:
      Null = M0;
      if NZ jump long_start_sequence_ok;
         Null = r0 - $aacdec.EIGHT_SHORT_SEQUENCE;
         if Z jump long_start_sequence_reset;
         M[$aacdec.tmp + 11] = r0;
         M0 = 1;
         call $aacdec.windowing;
         r4 = M[$aacdec.current_ics_ptr];
         M[r4 + $aacdec.ics.PREV_WINDOW_SEQ_EQ_LONG_START_FIELD] = Null;
         r1 = M[$aacdec.tmp + 11];
         M[r4 + $aacdec.ics.WINDOW_SEQUENCE_FIELD] = r1;
         M0 = -1024;
         r0 = M[I5,M0];
         M0 = -2;
         call $aacdec.windowing;
         M[$aacdec.tmp + 1] = Null;
         jump finished_windowing;
      long_start_sequence_reset:
         // if M0==0 reset variable to not jump into here next time
         r1 = r4 + $aacdec.ics.PREV_WINDOW_SEQ_EQ_LONG_START_FIELD;
         Null = M0;
         if Z M[r1] = Null;
      long_start_sequence_ok:


      // copy first buffer (or dummy) and scale
      r10 = 448;
      r9 = $aacdec.AUDIO_OUT_SCALE_AMOUNT;
      r0 = $aacdec.AUDIO_OUT_SCALE_AMOUNT/2;
      Null = M[$aacdec.sbr_present];
      if NZ r9 = r0;
      r0 = M[$aacdec.tmp + 1];
      Null = r0 + 2;
      if NZ jump normal_copy;
         do copy_start_overlap;
            r0 = M[I3,M3];
            r0 = r0 * r9 (int) (sat),
             r1 = M[I5,0];
            r0 = r0 + r1;
            M[I5,1] = r0;
         copy_start_overlap:
         jump finished_copy;

      normal_copy:
         do copy_start;
            r0 = M[I3,M3];
            r0 = r0 * r9 (int) (sat);
            M[I5,1] = r0;
         copy_start:

      finished_copy:

      // set I2 to input buffer or dummy input
      r0 = M[$aacdec.tmp + 6];
      r0 = r0 + 63;
      I2 = &$aacdec.tmp + 4;
      Null = M2;
      if NZ I2 = r0;

      // write full output
      M[$aacdec.tmp + 3] = Null;

      r10 = 128;

      // set up r8 from r9, include scale up by 2 if not done in tns
      r4 = M[$aacdec.current_spec_blksigndet_ptr];
      r8 = 2;
      r9 = 1;
      Null = M[r4 + 1];
      if NZ r8 = r9;

      call window;

      // set I3 to same buffer as I2 and amend M3 as appropriate
      I3 = I2 - 127;
      M3 = -M2;
      if Z I3 = I2;

      // now I3 is same buffer as I2, r9 must equal r8
      r9 = r8;

      // set window shape to current window shape
      r6 = M[$aacdec.current_ics_ptr];
      r6 = M[r6 + $aacdec.ics.WINDOW_SHAPE_FIELD];
      M[$aacdec.tmp + 9] = r6;

      I4 = I5;
      M0 = 384;
      r0 = M[I4,M0];
      I7 = I4;
      short_end_loop:
         // reset r10 and r6
         r10 = 128;
         r6 = M[$aacdec.tmp + 9];

         call window;

         Null = I5 - I7;
      if NZ jump short_end_loop;

      // write only first half of output
      r1 = 1;
      M[$aacdec.tmp + 3] = r1;

      // reset r10 and r6
      r10 = 128;
      r6 = M[$aacdec.tmp + 9];

      call window;

      jump finished_windowing;

   // -- LONG_STOP_SEQUENCE --
   long_stop_sequence:
      Null = M0;
      if NZ jump long_stop_sequence_ok;
         Null = r1 - $aacdec.EIGHT_SHORT_SEQUENCE;
         if Z jump long_stop_sequence_ok;
         r2 = $aacdec.ONLY_LONG_SEQUENCE;
         Null = r1 - $aacdec.LONG_STOP_SEQUENCE;
         if Z r1 = r2;
         M[r4 + $aacdec.ics.WINDOW_SEQUENCE_FIELD] = r1;
         M0 = 1;
         call $aacdec.windowing;
         r1 = $aacdec.LONG_STOP_SEQUENCE;
         r4 = M[$aacdec.current_ics_ptr];
         M[r4 + $aacdec.ics.WINDOW_SEQUENCE_FIELD] = r1;
         M0 = -1024;
         r0 = M[I5,M0];
         M0 = -2;
         call $aacdec.windowing;
         M[$aacdec.tmp + 1] = Null;
         jump finished_windowing;
      long_stop_sequence_ok:

      // set I2 to point to same buffer as I3
      // store M2 in tmp+10 and amend M2 based on M3
      I2 = I3 + 127;
      Null = M3;
      if Z I2 = I3;
      r0 = M2;
      M[$aacdec.tmp + 10] = r0;
      M2 = -M3;

      // write only second half of output
      r1 = -1;
      M[$aacdec.tmp + 3] = r1;

      // set up r8 and r9
      r9 = 1;
      r8 = r9;

      M0 = -64;
      r0 = M[I5,M0];
      I4 = I5;
      M0 = 512;
      r0 = M[I4,M0];
      I7 = I4;
      short_start_loop:
         // reset r10
         r10 = 128;

         call window;

         // reset r6
         r6 = M[$aacdec.tmp + 9];

         // write full output
         M[$aacdec.tmp + 3] = Null;

         Null = I5 - I7;
      if NZ jump short_start_loop;

      // restore I2, M2
      r0 = M[$aacdec.tmp + 6];
      r0 = r0 + 63;
      I2 = &$aacdec.tmp + 4;
      r1 = M[$aacdec.tmp + 10];
      M2 = r1;
      if NZ I2 = r0;

      // reset r10
      r10 = 128;

      // update r8 to include scale up by 2 if not done in tns
      r4 = M[$aacdec.current_spec_blksigndet_ptr];
      r8 = 2;
      Null = M[r4 + 1];
      if NZ r8 = r9;

      call window;

      // shift I2 along buffer (unless using dummy)
      r0 = I2 - 127;
      M0 = -M2;
      if NZ I2 = r0;

      M1 = 1;
      r10 = 448;

      r0 = r8 * ($aacdec.AUDIO_OUT_SCALE_AMOUNT/2) (int);
      r8 = r8 * $aacdec.AUDIO_OUT_SCALE_AMOUNT (int);
      Null = M[$aacdec.sbr_present];
      if NZ r8 = r0;

      // set r8 to 1 if M0==-1or2
      r0 = 1;
      Null = M[$aacdec.tmp + 5];
      if NZ r8 = r0;

      r0 = M[$aacdec.tmp + 1];
      Null = r0 + 2;
      if Z jump overlap_and_scale_long_stop;
         // copy end of second buffer and scale
         do copy_end;                              // optimise me
            r0 = M[I2,M0];
            r0 = r0 * r8 (int) (sat);
            M[I5,M1] = r0;
         copy_end:

         jump finished_windowing;

      overlap_and_scale_long_stop:
         // copy end of second buffer, scale and overlap
         do copy_end_overlap;                            // optimise me
            r0 = M[I2,M0];
            r0 = r0 * r8 (int) (sat),
             r1 = M[I5,0];
            r0 = r0 + r1;
            M[I5,M1] = r0;
         copy_end_overlap:

         jump finished_windowing;

   // -- EIGHT_SHORT_SEQUENCE --
   eight_short_sequence:
      Null = M0;
      if NZ jump eight_short_sequence_ok;
         Null = r1 - $aacdec.EIGHT_SHORT_SEQUENCE;
         if Z jump eight_short_sequence_ok;
         Null = r1 - $aacdec.LONG_START_SEQUENCE;
         if Z jump eight_short_sequence_ok;
         r2 = $aacdec.ONLY_LONG_SEQUENCE;
         Null = r1 - $aacdec.LONG_STOP_SEQUENCE;
         if Z r1 = r2;
         M[r4 + $aacdec.ics.WINDOW_SEQUENCE_FIELD] = r1;
         M0 = 1;
         call $aacdec.windowing;
         r1 = $aacdec.EIGHT_SHORT_SEQUENCE;
         r4 = M[$aacdec.current_ics_ptr];
         M[r4 + $aacdec.ics.WINDOW_SEQUENCE_FIELD] = r1;
         M0 = -1024;
         r0 = M[I5,M0];
         M0 = -2;
         call $aacdec.windowing;
         M[$aacdec.tmp + 1] = Null;
         jump finished_windowing;
      eight_short_sequence_ok:

      // set I2 to point to same buffer as I3
      // store M2 in tmp+10 and amend M2 based on M3
      I2 = I3 + 127;
      Null = M3;
      if Z I2 = I3;
      r0 = M2;
      M[$aacdec.tmp + 10] = r0;
      M2 = -M3;

      // write only second half of output
      r1 = -1;
      M[$aacdec.tmp + 3] = r1;

      // set first time change stuff counter thing
      M[$aacdec.tmp + 7] = Null;

      // set up r8 and r9
      r9 = 1;
      r8 = r9;

      M0 = -64;
      r0 = M[I5,M0];
      M0 = 512;
      I4 = I5;
      r0 = M[I4,M0];
      I0 = I4;
      r0 = M[I4,M0];
      I7 = I4;
      short_loop:
         // reset r10
         r10 = 128;

         call window;

         // reset r6
         r6 = M[$aacdec.tmp + 9];

         // write full output
         M[$aacdec.tmp + 3] = Null;

         Null = I5 - I0;
         if NZ jump no_change;
            // select first or second change
            r0 = M[$aacdec.tmp + 7];
            if NZ jump i3_change;
               r0 = r0 + 1;
               M[$aacdec.tmp + 7] = r0;

               // restore I2, M2
               r0 = M[$aacdec.tmp + 6];
               r0 = r0 + 63;
               I2 = &$aacdec.tmp + 4;
               r1 = M[$aacdec.tmp + 10];
               M2 = r1;
               if NZ I2 = r0;

               // update criterion for jumping into change loop
               L0 = L5;
               M0 = 128;
               r0 = M[I0,M0];
               L0 = 0;

               // update r8 to include scale up by 2 if not done in tns
               r4 = M[$aacdec.current_spec_blksigndet_ptr];
               r8 = r9 * 2 (int);
               Null = M[r4 + 1];
               if NZ r8 = r9;

               jump no_change;
            i3_change:
               // set I3 to same buffer as I2 and amend M3 as appropriate
               I3 = I2 - 127;
               M3 = -M2;
               if Z I3 = I2;
               // now I3 is same buffer as I2, r9 must equal r8
               r9 = r8;
               // set window shape to current window shape
               r6 = M[$aacdec.current_ics_ptr];
               r6 = M[r6 + $aacdec.ics.WINDOW_SHAPE_FIELD];
               M[$aacdec.tmp + 9] = r6;
         no_change:

         Null = I5 - I7;
      if NZ jump short_loop;

      // write only first half of output
      r1 = 1;
      M[$aacdec.tmp + 3] = r1;

      // reset r10
      r10 = 128;

      call window;

   finished_windowing:

   // if M0!=0 exit
   Null = M[$aacdec.tmp + 1];
   if NZ jump $pop_rLink_and_rts;

#ifdef AAC_ENABLE_ROUTING_OPTIONS

    Null = M[$aacdec.num_CPEs];
    if Z jump no_copy_to_buf_left_ptr;
    
    Null = M[$aacdec.current_channel];
    if NZ jump no_copy_to_buf_left_ptr; 
    
       // move I5 pointer back 1024 (to start of the frame) before we do the copy
      M0 = -1024;
      r0 = M[I5,M0];

      // set I1/L1 to point to the right audio output buffer
    
      r0 = M[$aacdec.buf_left_ptr]; 
      I1 = r0;


      // do the copy
      r10 = 1024;
      do copy_to_buf_left_ptr_loop;
         r0 = M[I5,1];
         M[I1,1] = r0;
      copy_to_buf_left_ptr_loop:
      
no_copy_to_buf_left_ptr:
   
     r0 = M[$aacdec.routing_mode]; 
     if Z jump non_tws_mode4;
     jump dont_copy_to_right_channel;
         
non_tws_mode4:
#endif 
   // if its a mono stream and we have stereo buffers connected then copy
   // the left channel's output to the right channel
   Null = M[$aacdec.convert_mono_to_stereo];
   if Z jump dont_copy_to_right_channel;

      // move I5 pointer back 1024 (to start of the frame) before we do the copy
      M0 = -1024;
      r0 = M[I5,M0];

      // set I1/L1 to point to the right audio output buffer
      r5 = M[$aacdec.codec_struc];
      r0 = M[r5 + $codec.DECODER_OUT_RIGHT_BUFFER_FIELD];
      call $cbuffer.get_write_address_and_size;
      I1 = r0;
      L1 = r1;

      // do the copy
      r10 = 1024;
      do copy_to_right_loop;
         r0 = M[I5,1];
         M[I1,1] = r0;
      copy_to_right_loop:
      

#ifdef AACDEC_SBR_ADDITIONS
      Null = M[$aacdec.sbr_present];
      if NZ jump dont_set_write_ptr_mono_to_stereo;
#endif
         // store updated cbuffer pointer for the right channel
         r0 = M[r5 + $codec.DECODER_OUT_RIGHT_BUFFER_FIELD];
         r1 = I1;
         call $cbuffer.set_write_address;
      dont_set_write_ptr_mono_to_stereo:
      L1 = 0;
   dont_copy_to_right_channel:
   
#ifdef AAC_ENABLE_ROUTING_OPTIONS
     
     Null = M[$aacdec.num_CPEs];
     if Z jump non_tws_1;
    
      r0 =  M[$aacdec.routing_mode]; 
      if Z jump non_tws_1;
      
      r1 =  M[$aacdec.routing_mode]; 
      r1 = r1 - 3;
      if NZ jump non_tws_1;
      
      r0 = M[$aacdec.current_channel]; // if current channel is left and asked mode is Lr/2 dont set write 
      if Z jump dont_set_write_ptr;

      
         // move I5 pointer back 1024 (to start of the frame) before we do the copy
      M0 = -1024;
      r0 = M[I5,M0];

      // set I1/L1 to point to the right audio output buffer
    
      r0 = M[$aacdec.buf_left_ptr]; 
      I1 = r0;

      r2 = -1.0;
      // do the copy
      r10 = 1024;
      do LRby2_loop;
         r0 = M[I5,0],r1 = M[I1,1];
         rMAC = r0 * 0.5 ; 
         r1 = r1 * 0.5;
         rMAC = rMAC - r1 * r2;
         M[I5,1] =  rMAC;
      LRby2_loop:
      

 non_tws_1:     
#endif 

#ifdef AACDEC_SBR_ADDITIONS
   Null = M[$aacdec.sbr_present];
   if NZ jump dont_set_write_ptr;
#endif
      // store updated cbuffer pointer
      r0 = M[$aacdec.tmp + 2];
      r1 = I5;
      call $cbuffer.set_write_address;
   dont_set_write_ptr:
   L5 = 0;
   L4 = 0;

   // store updated previous_window_shape and previous_window_sequence
   r4 = M[$aacdec.current_ics_ptr];
   r8 = M[r4 + $aacdec.ics.WINDOW_SHAPE_FIELD];
   r2 = M[$aacdec.current_channel];
   M[$aacdec.previous_window_shape + r2] = r8;
   r8 = M[r4 + $aacdec.ics.WINDOW_SEQUENCE_FIELD];
   M[$aacdec.previous_window_sequence + r2] = r8;

   // pop rLink from stack
   jump $pop_rLink_and_rts;



   // DESCRIPTION: Subroutine to do sin or kaiser windowing and overlap add
   //
   // INPUTS:
   //    r6  - window type SIN_WINDOW (0) or KAISER_WINDOW (1)
   //    r8  - gain for I2 data
   //    r9  - gain for I3 data
   //    r10 - number of samples 1024/128
   //    I2  - ptr to end of data to be second half windowed
   //    I3  - ptr to start of data to be first half windowed
   //    I5  - ptr to start of output buffer
   //    M2  = -1 if I2 points to data
   //        =  0 if I2 points to dummy data
   //    M3  = +1 if I3 points to data
   //        =  0 if I3 points to dummy data
   //    $aacdec.tmp + 3  = -1 - only second half of output written
   //                     =  0 - all of output written
   //                     = +1 - only first half of output written
   //    L4  - set to length of output buffer
   //    L5  - set to length of output buffer
   //
   // OUTPUTS:
   //    r10 = 0;
   //    I5  = I5 + r10
   //    I2  = I2 + 128 (unless pointing to dummy variable, in which case I2 = I2)
   //    I3  = I3 + 128 (unless pointing to dummy variable, in which case I3 = I3)
   //
   // TRASHED:
   //    r0-r7, r10, I1, I4, I6, M0, M1
window:
   M0 = r10 - 1;
   I4 = I5;
   r0 = M[I4,M0];
   M0 = +1;
   M1 = -1;
   Null = r6;
   if NZ jump window_kaiser;

   window_sin:
   // select either 2048 or 256 length coefs
   I1 = &$aacdec.sin2048_coefs;
   I6 = &$aacdec.sin256_coefs;
   Null = r10 - 1024;
   if NZ I1 = I6;

   // r6 = r10 = 512 or 64
   r10 = r10 ASHIFT -1;
   r6 = r10;

   // load the init_vector and rotation_matrix into registers
   I6 = I1 + 1;
   r0 = M[I1,2],   // init_vector[0]
    r3 = M[I6,2];  // init_vector[1]
   r4 = M[I1,2],   // rotation_matrix[0][0] =  rotation_matrix[1][1]
    r5 = M[I6,2];  // rotation_matrix[1][0] = -rotation_matrix[0][1]

   // if input data isn't mirrored jump to other routine
   Null = M[$aacdec.tmp + 5];
   if NZ jump non_mirrored;

   // now r8old = r9 LSHIFT r8new
   r2 = SIGNDET r8;
   r8 = SIGNDET r9;
   r8 = r8 - r2;

   M[$aacdec.tmp + 12] = r9;

   r2 = r9 * ($aacdec.AUDIO_OUT_SCALE_AMOUNT/2) (int);
   r9 = r9 * $aacdec.AUDIO_OUT_SCALE_AMOUNT (int);
   Null = M[$aacdec.sbr_present];
   if NZ r9 = r2;

   // if only writing to half of audio buffer set up one
   // pointer to point to a dummy location and set the
   // corresponding modify register to 0
   Null = M[$aacdec.tmp + 3];
   if Z jump ok_sin;
      if NEG jump second_half_sin;
         I4 = &$aacdec.tmp;
         L4 = 0;
         M1 = 0;
         r6 = 0;
      jump ok_sin;
      second_half_sin:
         I5 = &$aacdec.tmp;
         L5 = 0;
         M0 = 0;
   ok_sin:

   r2 = M[$aacdec.tmp + 1];
   Null = r2 + 2;
   if Z jump two_passes_loop;

   do sin_loop;
      r2 = r0,
       r0 = M[I2,M2];         // read value A
      r0 = r0 LSHIFT r8,
       r1 = M[I3,M3];         // read value B
      rMAC = r1 * r3;
      rMAC = rMAC + r0 * r2;
      rMAC = rMAC * r9 (int) (sat);
      rMAC = r1 * r2,
       M[I4,M1] = rMAC;       // write walue A'
      rMAC = rMAC - r0 * r3;
      rMAC = rMAC * r9 (int) (sat);
      rMAC = r4 * r2,         // update window
       M[I5,M0] = rMAC;       // write walue B'
      rMAC = rMAC - r5 * r3;  // update window
      r0 = rMAC;
      rMAC = r5 * r2;         // update window
      rMAC = rMAC + r4 * r3;  // update window
      r3 = rMAC;
   sin_loop:
   // if I5 pointing at dummy need to use I4
   r0 = M[I4, 1];
   Null = M[$aacdec.tmp + 3];
   if POS L4 = L5;
   if NEG I5 = I4;
   L5 = L4;
   // set I2, I3, I5 to correct points
   M0 = r6;
   Null = M1;
   if Z M0 = 0;
   r0 = M[I5,M0];
   r1 = M2;
   r6 = r6 + 128;
   r0 = r1 * r6 (int);
   I2 = I2 - r0;
   r1 = M3;
   r6 = r6 - 256;
   r0 = r1 * r6 (int);
   I3 = I3 - r0;

   // restore r8, r9
   r9 = M[$aacdec.tmp + 12];
   r8 = r9 LSHIFT r8;
   rts;

   two_passes_loop:
   do second_pass_sin_loop;
      r2 = r0,
       r0 = M[I2,M2];         // read value A
      r0 = r0 LSHIFT r8,
       r1 = M[I3,M3];         // read value B
      rMAC = r1 * r3;
      rMAC = rMAC + r0 * r2;
      rMAC = rMAC * r9 (int) (sat);
      r7 = I4;
      rMAC = rMAC + M[r7];
      rMAC = r1 * r2,
       M[I4,M1] = rMAC;       // write walue A'
      rMAC = rMAC - r0 * r3;
      rMAC = rMAC * r9 (int) (sat);
      r7 = I5;
      rMAC = rMAC + M[r7];
      rMAC = r4 * r2,         // update window
       M[I5,M0] = rMAC;       // write walue B'
      rMAC = rMAC - r5 * r3;  // update window
      r0 = rMAC;
      rMAC = r5 * r2;         // update window
      rMAC = rMAC + r4 * r3;  // update window
      r3 = rMAC;
   second_pass_sin_loop:
   jump sin_loop;


   non_mirrored:
   // rMAC = 255 or 31
   rMAC = r10 ASHIFT 1;
   rMAC = rMAC - 1;

   Null = M[$aacdec.tmp + 5];
   if NEG jump first_half_type;
      // swap r3 and r0 and invert r5
      r2 = r0;
      r0 = r3;
      r3 = r2;
      r5 = -r5;
      // store I2,M2 then use I3,M3 to set up I2,M2
      r1 = I2;
      r2 = M2;
      I2 = I3 + rMAC;
      Null = M3;
      if Z I2 = I3;
      M2 = -M3;
      jump start_the_loop;
   first_half_type:
      // store I3,M3 then use I2,M2 to set up I3,M3
      r1 = I3;
      r2 = M3;
      I3 = I2 - rMAC;
      Null = M2;
      if Z I3 = I2;
      M3 = -M2;
   start_the_loop:
   M[$aacdec.tmp + 7] = r1;
   M[$aacdec.tmp + 8] = r2;
   do non_mirrored_sin_loop;
      r2 = r0,
       r0 = M[I2,M2];         // read value A
      r1 = M[I3,M3];         // read value B
      rMAC = r0 * r2;
      rMAC = r1 * r3,
       M[I4,M1] = rMAC;       // write walue A'
      rMAC = r4 * r2,         // update window
       M[I5,M0] = rMAC;       // write walue B'
      rMAC = rMAC - r5 * r3;  // update window
      r0 = rMAC;
      rMAC = r5 * r2;         // update window
      rMAC = rMAC + r4 * r3;  // update window
      r3 = rMAC;
   non_mirrored_sin_loop:
   // set I5 to correct point
   M0 = r6;
   r0 = M[I5,M0];
   r0 = M[$aacdec.tmp + 7];
   r1 = M[$aacdec.tmp + 8];
   Null = M[$aacdec.tmp + 5];
   if NEG jump first_half_type_post;
      // restore I2,M2
      I2 = r0;
      M2 = r1;
      r1 = M3;
      // set I3, to correct point
      r0 = r1 * r6 (int);
      I3 = I3 - r0;
      jump shift_i2_i3;
   first_half_type_post:
      // restore I3,M3
      I3 = r0;
      M3 = r1;
      r1 = M2;
      // set I2 to correct point
      r0 = r1 * r6 (int);
      I2 = I2 - r0;
      jump shift_i2_i3;



   window_kaiser:
   // select either 2048 or 256 length coefs
   I1 = &$aacdec.kaiser2048_coefs;
   I6 = &$aacdec.kaiser256_coefs;
   Null = r10 - 1024;
   if NZ I1 = I6;
   I6 = I1 + 18;
   // set r7 = 2^15 (if r10 = 1024)
   // set r7 = 2^18 (if r10 = 128)
   r7 = SIGNDET r10;
   r7 = 8 ASHIFT r7;

   // if input data isn't mirrored jump to other routine
   Null = M[$aacdec.tmp + 5];
   if NZ jump non_mirrored_kaiser;

   // if only writing to half of audio buffer set up one
   // pointer to point to a dummy location and set the
   // corresponding modify register to 0
   Null = M[$aacdec.tmp + 3];
   if Z jump ok_kai_1;
      if NEG jump second_half_kai_1;
         I4 = &$aacdec.tmp;
         L4 = 0;
         M1 = 0;
      jump ok_kai_1;
      second_half_kai_1:
         I5 = &$aacdec.tmp;
         L5 = 0;
         M0 = 0;
   ok_kai_1:

   r8 = -r8;

   r2 = M[$aacdec.tmp + 1];
   Null = r2 + 2;
   if NZ jump kaiser_outer_loop;
      r4 = $aacdec.AUDIO_OUT_SCALE_AMOUNT;
      r0 = $aacdec.AUDIO_OUT_SCALE_AMOUNT/2;
      Null = M[$aacdec.sbr_present];
      if NZ r4 = r0;
      M[$aacdec.tmp + 12] = r9;
      M[$aacdec.tmp + 13] = r8;
      r8 = r8 * r4 (int);
      r9 = r9 * r4 (int);
      r4 = 1;
      jump kaiser_outer_loop_2;

   kaiser_outer_loop:
      r1 = M[I1,1];  // coef for x^0
      r2 = M[I1,1];  // coef for x^1
      r3 = M[I1,1];  // coef for x^2
      r4 = M[I1,1];  // coef for x^3
      r5 = M[I1,1];  // coef for x^4
      r0 = M[I1,1];  // number of values generated with these coefs
      r10 = r0;

      r6 = 0;

      // window loop
      do kaiser_inner_loop;
         rMAC = r1;
         rMAC = rMAC + r6 * r2;
         r0 = r6 * r6 (frac);  // r6 = x^2;
         rMAC = rMAC + r0 * r3;
         r0 = r0 * r6 (frac);  // r6 = x^3;
         rMAC = rMAC + r0 * r4;
         r0 = r0 * r6 (frac);  // r6 = x^4;
         rMAC = rMAC + r0 * r5,
          r0 = M[I3,M3];
         r0 = rMAC * r0 (frac);
         r0 = r0 * r9 (int) (sat);
         r6 = r6 + r7,  // increment x;
          M[I4,M1] = r0,
          r0 = M[I2,M2];
         r0 = rMAC * r0 (frac);
         r0 = r0 * r8 (int) (sat);
         M[I5,M0] = r0;
      kaiser_inner_loop:

      Null = I1 - I6;
   if NZ jump kaiser_outer_loop;

   end_kaiser_outer_loop_1:
   // work along I2 and I3 in other direction
   r0 = I2 + 1;
   M2 = -M2;
   if NZ I2 = r0;
   r0 = I3 - 1;
   M3 = -M3;
   if NZ I3 = r0;
   I6 = I1 + 18;

   r8 = -r8;

   // if only writing to half of audio buffer set up one
   // pointer to point to a dummy location and set the
   // corresponding modify register to 0
   Null = M[$aacdec.tmp + 3];
   if Z jump ok_kai_2;
      if NEG jump second_half_kai_2;
         r0 = M[I5,-1];
         I4 = I5;
         L4 = L5;
         M1 = -M0;
         I5 = &$aacdec.tmp;
         L5 = 0;
         M0 = 0;
      jump ok_kai_2;
      second_half_kai_2:
         I5 = I4;
         L5 = L4;
         r0 = M[I5,1];
         M0 = -M1;
         I4 = &$aacdec.tmp;
         L4 = 0;
         M1 = 0;
   ok_kai_2:

   r4 = $aacdec.AUDIO_OUT_SCALE_AMOUNT;
   r0 = $aacdec.AUDIO_OUT_SCALE_AMOUNT/2;
   Null = M[$aacdec.sbr_present];
   if NZ r4 = r0;
   r0 = 1;
   r2 = M[$aacdec.tmp + 1];
   Null = r2 + 2;
   if Z r4 = r0;

   kaiser_outer_loop_2:
      r1 = M[I1,1];  // coef for x^0
      r2 = M[I1,1];  // coef for x^1
      r3 = M[I1,1];  // coef for x^2
      r5 = M[I1,2];  // coef for x^3 (re-read in inside loop)
                     // coef for x^4 (read in inside loop)
      r0 = M[I1,-1];  // number of values generated with these coefs
      r10 = r0;

      r0 = M[I1,-1];  // dummy read

      // window, scale and overlap add loop
      do kaiser_inner_loop_2;
         rMAC = r1;
         rMAC = rMAC + r6 * r2;
         r0 = r6 * r6 (frac);  // r6 = x^2;
         rMAC = rMAC + r0 * r3,
          r5 = M[I1,1];
         r0 = r0 * r6 (frac);  // r6 = x^3;
         rMAC = rMAC + r0 * r5,
          r5 = M[I1,1];
         r0 = r0 * r6 (frac);  // r6 = x^4;
         rMAC = rMAC + r0 * r5,
          r0 = M[I3,M3];
         r0 = r0 * rMAC (frac),
          r5 = M[I1,-1];  // dummy read
         r0 = r0 * r9 (int) (sat),
          r5 = M[I4,0];
         r0 = r0 + r5;
         r0 = r0 * r4 (int) (sat);
         r6 = r6 + r7,  // increment x;
          M[I4,M1] = r0,
          r0 = M[I2,M2];
         r0 = rMAC * r0 (frac);
         r0 = r0 * r8 (int) (sat),
          r5 = M[I5,0];
         r0 = r0 + r5,
          r5 = M[I1,-1];  // dummy read
         r0 = r0 * r4 (int) (sat);
         M[I5,M0] = r0;
      kaiser_inner_loop_2:

      I1 = I1 + 3;
      r6 = 0;
      Null = I1 - I6;
   if NZ jump kaiser_outer_loop_2;

   r2 = M[$aacdec.tmp + 1];
   Null = r2 + 2;
   if Z jump repeat_kaiser;
   // if I5 pointing at dummy need to use I4
   M0 = 65;
   Null = -M[$aacdec.tmp + 3];
   if POS M0 = 0;
   if POS L4 = L5;
   if NEG I5 = I4;
   L5 = L4;
   r0 = M[I5,M0];
   // reset I2,I3 to original values
   r0 = I2 + 127;
   M2 = -M2;
   if NZ I2 = r0;
   r0 = I3 + 129;
   M3 = -M3;
   if NZ I3 = r0;
   r2 = M[$aacdec.tmp + 1];
   Null = r2 + 3;
   if NZ rts;
   r9 = M[$aacdec.tmp + 12];
   r8 = M[$aacdec.tmp + 13];
   rts;


   repeat_kaiser:
   r2 = -3;
   M[$aacdec.tmp + 1] = r2;
   r6 = I1 - 1;
   r6 = M[r6];
   r6 = r7 * r6 (int);
   jump end_kaiser_outer_loop_1;


   non_mirrored_kaiser:
      r8 = r10 - 1;
      r9 = I6;
      I6 = I6 + 18;
      Null = M[$aacdec.tmp + 5];
      if POS jump second_half_windowing;
         // store I3,M3 then set up I3,M3 based on I2,M2
         r1 = I3;
         M[$aacdec.tmp + 7] = r1;
         r1 = M3;
         M[$aacdec.tmp + 8] = r1;
         I3 = I2 - r8;
         M3 = -M2;
         jump non_mirrored_kaiser_outer_loop;
      second_half_windowing:
         // work along buffers in other direction (for 2nd half windowing)
         r1 = M0;
         M0 = r8;
         r2 = M[I5, M0];
         M0 = -r1;
         I3 = I3 + r8;
         M3 = -M3;

      non_mirrored_kaiser_outer_loop:
      // don't reset r6 if half way through section
      Null = I1 - r9;
      if NZ r6 = 0;

      r1 = M[I1,1];  // coef for x^0
      r2 = M[I1,1];  // coef for x^1
      r3 = M[I1,1];  // coef for x^2
      r4 = M[I1,1];  // coef for x^3
      r5 = M[I1,1];  // coef for x^4
      r0 = M[I1,1];  // number of values generated with these coefs
      r10 = r0;

      do non_mirrored_kaiser_inner_loop;
         rMAC = r1;
         rMAC = rMAC + r6 * r2;
         r0 = r6 * r6 (frac);  // r6 = x^2;
         rMAC = rMAC + r0 * r3;
         r0 = r0 * r6 (frac);  // r6 = x^3;
         rMAC = rMAC + r0 * r4;
         r0 = r0 * r6 (frac);  // r6 = x^4;
         rMAC = rMAC + r0 * r5;
         r6 = r6 + r7,  // increment x;
          r0 = M[I3,M3];
         r0 = rMAC * r0 (frac);
         M[I5,M0] = r0;
      non_mirrored_kaiser_inner_loop:

      Null = I1 - I6;
   if NZ jump non_mirrored_kaiser_outer_loop;

   // reset 'I's and 'M's
   Null = M[$aacdec.tmp + 5];
   if POS jump restore_second_half_windowing;
   r1 = M[$aacdec.tmp + 7];
   I3 = r1;
   r1 = M[$aacdec.tmp + 8];
   M3 = r1;
   jump shift_i2_i3;

   restore_second_half_windowing:
   M0 = r8 + 1;
   r0 = M[I5, M0];
   I3 = I3 + 1;
   M3 = -M3;


   shift_i2_i3:
      r0 = I2 + 128;
      Null = M2;
      if NZ I2 = r0;
      r0 = I3 + 128;
      Null = M3;
      if NZ I3 = r0;
      rts;

.ENDMODULE;
