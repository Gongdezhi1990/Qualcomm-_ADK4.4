// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.mp4_sequence
//
// DESCRIPTION:
//    Run through the 'atoms' in an mp4 file and extract the relavant information
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//   - r0-r8, M0, M1
//
// *****************************************************************************
.MODULE $M.aacdec.mp4_sequence;
   .CODESEGMENT AACDEC_MP4_SEQUENCE_PM;
   .DATASEGMENT DM;

   $aacdec.mp4_sequence:

   .VAR moov_size_lo;
   .VAR moov_size_hi;

   // push rLink onto stack
   push rLink;

   // default is no faults detected
   M[$aacdec.frame_corrupt] = Null;

   // re-enter mp4_moov_routine if previously entered and ran out of data
   Null = M[$aacdec.mp4_in_moov];
   if NZ jump moov_atom;

   // re-enter mp4_discard_remainder_of_sub_atom if previously entered and ran out of data
   Null = M[$aacdec.mp4_in_discard_atom_data];
   if NZ call $aacdec.mp4_discard_atom_data;
   Null = M[$aacdec.possible_frame_corruption];
   if NZ jump possible_corruption;


   Null = M[$aacdec.mp4_sequence_flags_initialised];
   if NZ jump flags_already_initialised;
      r0 = 1;
      M[$aacdec.mp4_sequence_flags_initialised] = r0;
      // found_first_mdat = 0;
      M[$aacdec.found_first_mdat] = Null;
      // found_moov = 0;
      M[$aacdec.found_moov] = Null;
   flags_already_initialised:


   // find moov atom and extract sampling frequency amd no. of channels from it
   // then find first mdat atom and exit
   mp4_sequence_outer_loop:

   error_no_skip_function:
   // TO DO

      // check if enough data available to parse next atom
      r0 = M[$aacdec.num_bytes_available];
      Null = r0 - $aacdec.MP4_ATOM_NAME_AND_SIZE_BYTES;
      if POS jump data_available;
         r0 = 1;
         M[$aacdec.frame_underflow] = r0;
         // return back to mp4_parse_header
         jump $pop_rLink_and_rts;
      data_available:

      r0 = M[$aacdec.num_bytes_available];
      r0 = r0 - $aacdec.MP4_ATOM_NAME_AND_SIZE_BYTES;
      M[$aacdec.num_bytes_available] = r0;

      //    - r4 = most significant bytes of atom_size
      //    - r5 = least significant 3 bytes of atom_size
      //    - r6 = least significant 2 bytes of atom_name
      //    - r7 = most significant 2 bytes of atom_name
      call $aacdec.mp4_read_atom_header;

      // switch( atom_name )

      // case ( mdat )
      Null = r7 - $aacdec.MP4_MDAT_TAG_MS_WORD;
      if NZ jump not_mdat_atom;
         Null = r6 - $aacdec.MP4_MDAT_TAG_LS_WORD;
         if NZ jump not_mdat_atom;

            r1 = M[$aacdec.mp4_file_offset + 1];
            r2 = M[$aacdec.mp4_file_offset];
            r1 = r1 + $aacdec.MP4_ATOM_NAME_AND_SIZE_BYTES;
            r2 = r2 + Carry;

            r3 = M[$aacdec.mdat_offset + 1];
            r4 = M[$aacdec.mdat_offset];
            Null = r3 OR r4;
            if Z jump mdat_offset_unknown;
            r1 = r1 - r3;
            r2 = r2 - r4 - Borrow;
            Null = r1 + r2;
            if NZ jump incorrect_mdat;

         mdat_offset_unknown:
            // if(found_moov==1)
            Null = M[$aacdec.found_moov];
            if NZ jump break_from_loop;

            r0 = 1;
            M[$aacdec.found_first_mdat] = r0;   // found_mdat_first = 1;
         incorrect_mdat:
            r0 = r5;
            r1 = r4;
            call $aacdec.update_mp4_file_offset;
            r6 = M[$aacdec.skip_function];
            if NZ jump do_skip;
               // throw away rest of this atom
               r5 = r5 - $aacdec.MP4_ATOM_NAME_AND_SIZE_BYTES;
               r4 = r4 - Borrow;
               call $aacdec.mp4_discard_atom_data;
               Null = M[$aacdec.possible_frame_corruption];
               if NZ jump possible_corruption;
               jump error_no_skip_function;
            do_skip:
               r3 = r5 - $aacdec.MP4_ATOM_NAME_AND_SIZE_BYTES;
               r4 = r4 - Borrow;
               call $aacdec.skip_through_file;
               jump mp4_sequence_outer_loop;

      // case ( moov )
      not_mdat_atom:

      r0 = r7 - $aacdec.MP4_MOOV_TAG_MS_WORD;
      if NZ jump not_moov_atom;
         r0 = r6 - $aacdec.MP4_MOOV_TAG_LS_WORD;
         if NZ jump not_moov_atom;
            M[moov_size_lo] = r5;
            M[moov_size_hi] = r4;
            r0 = 1;
            M[$aacdec.found_moov] = r0;   // found_moov = 1;

            moov_atom:

            // extract sampling frequency and no. of channels from moov atom
            call $aacdec.mp4_moov_routine;
            Null = M[$aacdec.possible_frame_corruption];
            if NZ jump possible_corruption;
            Null = M[$aacdec.frame_underflow];
            if NZ jump $pop_rLink_and_rts;

            r0 = M[moov_size_lo];
            r1 = M[moov_size_hi];
            call $aacdec.update_mp4_file_offset;

            // if(found_mdat_first==1)
            Null = M[$aacdec.found_first_mdat];
            if Z jump mp4_sequence_outer_loop;
               r6 = M[$aacdec.skip_function];
               if Z jump error_no_skip_function;

               r1 = M[$aacdec.mp4_file_offset + 1];
               r2 = M[$aacdec.mp4_file_offset];
               r1 = r1 + 8;
               r2 = r2 + Carry;
               r3 = M[$aacdec.mdat_offset + 1];
               r4 = M[$aacdec.mdat_offset];
               r3 = r3 - r1;
               r4 = r4 - r2 - Borrow;
               call $aacdec.skip_through_file;

               r0 = M[$aacdec.mdat_offset + 1];
               r1 = M[$aacdec.mdat_offset];
               r0 = r0 - $aacdec.MP4_ATOM_NAME_AND_SIZE_BYTES;
               r1 = r1 - Borrow;
               M[$aacdec.mp4_file_offset + 1] = r0;
               M[$aacdec.mp4_file_offset] = r1;

               jump mp4_sequence_outer_loop;

      // case ( otherwise )
      not_moov_atom:
      r0 = r5;
      r1 = r4;
      call $aacdec.update_mp4_file_offset;

      // throw away rest of this atom
      r5 = r5 - $aacdec.MP4_ATOM_NAME_AND_SIZE_BYTES;
      r4 = r4 - Borrow;
      call $aacdec.mp4_discard_atom_data;
      Null = M[$aacdec.possible_frame_corruption];
      if NZ jump possible_corruption;


      jump mp4_sequence_outer_loop;
   break_from_loop:

   r0 = M[&$aacdec.mp4_file_offset + 1];
   r1 = M[$aacdec.mp4_file_offset];
   r0 = r0 + $aacdec.MP4_ATOM_NAME_AND_SIZE_BYTES;
   M[$aacdec.mp4_file_offset] = r1 + Carry;
   M[$aacdec.mp4_file_offset + 1] = r0 ;

   // set flag to indicate mp4 header parsing is complete
   r0 = 1;
   r0 = r0 AND 0x1;
   M[$aacdec.mp4_header_parsed] = r0;


   possible_corruption:

   jump $pop_rLink_and_rts;

.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $aacdec.skip_through_file
//
// DESCRIPTION:
//    wrapper function to call the skip function
//
// INPUTS:
//    - r4 = MS byte of skip size
//    - r3 = LS 3 bytes of skip size
//    - r6 = external skip function pointer
//
// OUTPUTS:
//
// TRASHED REGISTERS:
// assume everything
//
// *****************************************************************************
.MODULE $M.aacdec.skip_through_file;
   .CODESEGMENT AACDEC_MP4_SEQUENCE_PM;
   .DATASEGMENT DM;

   $aacdec.skip_through_file:

   // push rLink onto stack
   push rLink;

   // seeking is relative to read pointer, so move the read pointer
   // to the current word
   r5 = M[$aacdec.codec_struc];
   r0 = M[r5 + $codec.DECODER_IN_BUFFER_FIELD];
   r1 = I0;
   call $cbuffer.set_read_address;

   // fix bitpos if needed
   // seek_value   bitpos      fix
   // ----------------------------------------------------------------
   // even          x          not required
   // odd           >7         bitpos-=8, seek_value-=1
   // odd           <8         bitpos+=8, seek_value+=1
   Null = r3 AND 1;
   if Z jump no_fix_needed;
      r0 = M[$aacdec.get_bitpos];
      r0 = r0 - 8;
      if POS jump fix_finished;
         r3 = r3 + 1;
         r4 = r4 + carry;
         r0 = r0 + 16;
      fix_finished:
      M[$aacdec.get_bitpos] = r0;
      r3 = r3 AND 0xFFFFFE;
   no_fix_needed:

   // decide whether seek is required
   Null = r4;
   if NZ jump seek_required;         // seek if negative or too big
   r0 = M[r5 + $codec.DECODER_IN_BUFFER_FIELD];
   call $cbuffer.calc_amount_data;
   r1 = r3 LSHIFT -1;
   Null = r0 - r1;
   if LE jump seek_required;         // seek if not enough data
      // just skip words in the input buffer
      M0 = r1;
      r0 = M[I0, M0];
      r0 = M[r5 + $codec.DECODER_IN_BUFFER_FIELD];
      r1 = I0;
      call $cbuffer.set_read_address;
      jump seek_done;
   // call external seek function
   seek_required:
   call r6;

   // update to the new state
   r5 = M[$aacdec.codec_struc];
   r0 = M[r5 + $codec.DECODER_IN_BUFFER_FIELD];
   call $cbuffer.get_read_address_and_size;
   I0 = r0;
   L0 = r1;
   seek_done:
   r0 = M[r5 + $codec.DECODER_IN_BUFFER_FIELD];
   call $cbuffer.calc_amount_data;
   r0 = r0 + r0;
   // adjust by the number of bits we've currently read
   r1 = M[$aacdec.get_bitpos];
   r1 = r1 ASHIFT -3;
   r0 = r0 + r1;
   r0 = r0 - 2;
   if NEG r0 = 0;
   M[$aacdec.read_bit_count] = Null;
   r1 = r0 ASHIFT 3;
   M[$aacdec.frame_num_bits_avail] = r1;
   M[$aacdec.num_bytes_available] = r0;
   jump $pop_rLink_and_rts;
.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $aacdec.update_mp4_file_offset
//
// DESCRIPTION:
//    function to update the file offset
//
// INPUTS:
//    - r0 = File offset increment LSW
//    - r1 = File offset increment MSW
//
// OUTPUTS:
//
// TRASHED REGISTERS:
//  r2, r3
//
// *****************************************************************************
.MODULE $M.aacdec.update_mp4_file_offset;
   .CODESEGMENT AACDEC_MP4_SEQUENCE_PM;
   .DATASEGMENT DM;

   $aacdec.update_mp4_file_offset:

   push rLink;

   r3 = M[$aacdec.mp4_file_offset + 1];
   r2 = M[$aacdec.mp4_file_offset];
   r3 = r0 + r3;
   r2 = r1 + r2 + Carry;
   M[$aacdec.mp4_file_offset + 1] = r3;
   M[$aacdec.mp4_file_offset] = r2;

   jump $pop_rLink_and_rts;

.ENDMODULE;
