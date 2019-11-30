// *****************************************************************************
// Copyright (c) 2003 - 2015 Qualcomm Technologies International, Ltd.
// Part of Stereo-Headset-SDK Q3-2007
//
// *****************************************************************************

#include "stream_relay_library.h"
#include "codec_library.h"
#include "core_library.h"

// *****************************************************************************
// MODULE:
//    $relay.copy_data
//
// DESCRIPTION:
//    Copies encoded data to relay frame.  
//
// INPUTS:
//   
//    - r5 = pointer to relay structure
//
// OUTPUTS:
//    - none
// *****************************************************************************
.MODULE $M.relay.copy_data;
   .CODESEGMENT PM;
   .DATASEGMENT DM;
                                      
   .VAR $relay_frame_size = 0;
   .VAR $start_of_encoded_data_bit_pos = 16;  // 
   .VAR $granule_flag=0;
   .VAR $debug_latency=0;
  
   $relay.copy_data:
   
   $push_rLink_macro;  
   
    M[$debug_latency] = r8;
   
   M[$granule_flag]=0;
   // get pointer position before decoder ran
   r0 = M[r5 + $relay.INPUT_CBUFFER_FIELD];
   call $cbuffer.get_read_address_and_size; 
   I0 = r0;
   L0 = r1;
 
   // get pointer position after decoder ran
   r0 = M[r5 + $relay.INTERNAL_CBUFFER_PTR_FIELD];
   call $cbuffer.get_read_address_and_size;   
   I1 = r0;

      
   // Make sure there is new data to relay.
   // There won't be if we're decoding an mp3 granule channel.
   // If this is the case we need to insert a header telling
   // the slave when to play this granule.
   r1 =1;
   r10 = r0 - I0;  
  
   if NZ r1 = 0;
   M[$granule_flag] = r1;     
   Null = M[$granule_flag];
   if NZ jump calc_header_space;   

   // get the bitpos that corresponds to the beginning of the frame
   r0 = M[$start_of_encoded_data_bit_pos];
   M[$stream_relay.get_bitpos] = r0;

   // get current bitpos, corresponding to the end of frame
   r1 = M[r5 + $relay.CODEC_GET_BITPOS];
   r1 = M[r1];
   M[$start_of_encoded_data_bit_pos] = r1; 
   
   // calc the amount of bytes needed to copy
   r10 = I1 - I0;
   if LE r10 = r10 + L0;   
   r10 = r10 ASHIFT 1;

   // calc bitpos before decoder ran - bitpos after decoder ran
   r1 = r0 - r1;     //
   r1 = r1 ASHIFT -3;//
   r10 = r10 + r1;
   
calc_header_space:

   // get sync frame length in bytes
   // Need to check the sync structure for size of header
   // to check and see if this frame will fit....
   r3 = 0;
   r0 = M[r5 + $relay.TWS_HEADER_FIELD];
   if Z jump no_header;

   r3 = M[r0];  //SIZE_OF_HEADER_IN_WORDS should be the first entry in the Header prototype
   r3 = r3*3 (int);
   
   .VAR $header_size =0;
   M[$header_size] = r3;
 
no_header: 
   // compute total number of bytes to relay
   r4 = r3 + r10;
    
   // see if data will fit in relay buffer
   r0 = M[r5 + $relay.RELAY_CBUFFER_FIELD];
   call $cbuffer.calc_amount_space;
   r0 = r0 ASHIFT 1;
  
   Null = r0 - r4;
   if NEG jump not_enough_space_for_relay_data;  

   // get write pointer for relaying data
   r0 = M[r5 + $relay.RELAY_CBUFFER_FIELD];
   call $cbuffer.get_write_address_and_size;
   I4 = r0; 
   L4 = r1;
   Null = M[$granule_flag];
   if NZ jump insert_header;
  
relay_data:

   M[$relay_frame_size] = r10;

   // r10 is the size of the frame
   // TODO: doing this without getbits and puts bits would be more efficient
   do copy_data_loop;      
   
      // read a byte      
      r0 = 8;
      call $stream_relay.getbits; 
      
      // write a byte      
      call $stream_relay.putbits;   
 
  copy_data_loop:
  
insert_header:
   r0 = M[r5 + $relay.TWS_HEADER_FIELD];
   if Z jump skip_header_insert;
   I1 =r0;
   r0 = M[I1,1]; //
   r10 = r0;
     do copy_header_loop;      
      // // read a byte      
      r0 = 8;
      r4 = M[I1,1]; 
      r1 = r4 AND 0xff0000  ; 
      r1 = r1 LSHIFT -16;
      // write a byte      
      call $stream_relay.putbits;   
      r1 = r4 AND 0xff00; 
      r1 = r1 LSHIFT -8;
      // write a byte      
      call $stream_relay.putbits;  
      r1 = r4 AND 0xff; 
      // write a byte      
      call $stream_relay.putbits;  
    copy_header_loop:
    
    
skip_header_insert:
   // store updated cbuffer pointers for relay output stream
   r1 = I4;
   r0 = M[r5 + $relay.RELAY_CBUFFER_FIELD];
   call $cbuffer.set_write_address;  
   jump done_with_relay_data;

not_enough_space_for_relay_data:

#ifdef RELAY_DEBUG_ENABLE
   .VAR $relay.drop_encoded_relay_frame_count = 0;
   r0 = M[$relay.drop_encoded_relay_frame_count];
   r0 = r0 + 1;
   M[$relay.drop_encoded_relay_frame_count] = r0;   
#endif

done_with_relay_data:
   L4 = NULL;
   L0 = NULL;
   
   // Update blocking pointer  
   jump $pop_rLink_and_rts;

.ENDMODULE;


// *****************************************************************************
// MODULE:
//    $relay.update_codec_ptr
//
// DESCRIPTION:
//    Sets the read pointer of the  CODEC cbuffer structure to be equivalent to
//    the read ptr of the Internal CODEC cbuffer structure.  This lets the CODEC ISR 
//    know that it is safe to overwrite the input data, as the relay is done with it.
//
//    This routine also replaces the internal cbuffer pointer in av_decode with the original codec pointer
//
// INPUTS:
//    - r5 = pointer to relay structure
//
// OUTPUTS:
//    - none
// *****************************************************************************
.MODULE $M.relay.update_codec_ptr;
   .CODESEGMENT PM;
   .DATASEGMENT DM;
      
   $relay.update_codec_ptr:

   $push_rLink_macro;
   
   call $block_interrupts;
   r0 = M[r5 + $relay.INTERNAL_CBUFFER_PTR_FIELD];
   call $cbuffer.get_read_address_and_size;
   r1 = r0;
   r0 = M[r5 + $relay.INPUT_CBUFFER_FIELD];
   call $cbuffer.set_read_address;
   
   r0 = M[r5 + $relay.INPUT_CBUFFER_FIELD];
   r1 = M[r5 + $relay.AV_DECODE_STRUC_FIELD];
   M[r1 + $codec.av_decode.IN_BUFFER_FIELD]  =r0;
   
   call $unblock_interrupts;
   
   jump $pop_rLink_and_rts;

.ENDMODULE;


// *****************************************************************************
// MODULE:
//    $relay.update_internal_ptr
//
// DESCRIPTION:
//    Sets the write pointer of the Internal CODEC cbuffer structure to be equivalent to
//    the Write ptr of the CODEC cbuffer structure.  
//
//    This routine also replaces the codec cbuffer pointer in av_decode with the internal codec pointer
//
// INPUTS:
//    - r5 = pointer to relay structure
//
// OUTPUTS:
//    - none
// *****************************************************************************
.MODULE $M.relay.update_internal_ptr;
   .CODESEGMENT PM;
   .DATASEGMENT DM;
      
   $relay.update_internal_ptr:

   $push_rLink_macro;
   
   call $block_interrupts;
   r0 = M[r5 + $relay.INPUT_CBUFFER_FIELD];
   call $cbuffer.get_write_address_and_size;
   r1 = r0;
   r0 = M[r5 + $relay.INTERNAL_CBUFFER_PTR_FIELD];
   call $cbuffer.set_write_address;

   
   r0 = M[r5 + $relay.INTERNAL_CBUFFER_PTR_FIELD];
   r1 = M[r5 + $relay.AV_DECODE_STRUC_FIELD];
   M[r1 + $codec.av_decode.IN_BUFFER_FIELD]  =r0;
 
   // Grab bit position using codec dependant variable (set in conn_init)
   r1 = M[r5 + $relay.CODEC_GET_BITPOS];
   r0 = M[r1];
   M[$start_of_encoded_data_bit_pos] = r0;
   
   call $unblock_interrupts;
   
   jump $pop_rLink_and_rts;

.ENDMODULE;




#ifdef USE_PACKED_ENCODED_DATA


// *****************************************************************************
// MODULE:
//    $relay.update_internal_ptr_packed
//
// DESCRIPTION:
//    Sets the write pointer of the Internal CODEC cbuffer structure to be equivalent to
//    the Write ptr of the CODEC cbuffer structure.  
//
//    This routine also replaces the codec cbuffer pointer in av_decode with the internal codec pointer
//
//    This _packed version of the routine works with Packed Buffers
//
// INPUTS:
//    - r5 = pointer to relay structure
//
// OUTPUTS:
//    - none
// *****************************************************************************

.MODULE $M.relay.update_internal_ptr_packed;
   .CODESEGMENT PM;
   .DATASEGMENT DM;
   
   .VAR input_buffer_read_pos;
   .VAR input_buffer_write_pos;

   $relay.update_internal_ptr_packed:
   
   $push_rLink_macro;
   
   call $block_interrupts;
   
   r0 = M[r5 + $relay.INPUT_CBUFFER_FIELD];
   r1 = M[r0 + $packed_cbuffer.WRITE_BYTEPOS_FIELD];
   M[input_buffer_write_pos] = r1;
   call $cbuffer.get_write_address_and_size;
   
   r1 = r0;
   r0 = M[r5 + $relay.INTERNAL_CBUFFER_PTR_FIELD];
   call $cbuffer.set_write_address;
   
   r1 = M[input_buffer_write_pos];
   M[r0 + $packed_cbuffer.WRITE_BYTEPOS_FIELD] = r1;
   r0 = M[r5 + $relay.INTERNAL_CBUFFER_PTR_FIELD];
   r1 = M[r5 + $relay.AV_DECODE_STRUC_FIELD];
   M[r1 + $codec.av_decode.IN_BUFFER_FIELD]  =r0;

   call $unblock_interrupts;

   jump $pop_rLink_and_rts;

.ENDMODULE;


// *****************************************************************************
// MODULE:
//    $relay.update_codec_ptr_packed
//
// DESCRIPTION:
//    Sets the read pointer of the  CODEC cbuffer structure to be equivalent to
//    the read ptr of the Internal CODEC cbuffer structure.  This lets the CODEC ISR 
//    know that it is safe to overwrite the input data, as the relay is done with it.
//
//    This routine also replaces the internal cbuffer pointer in av_decode with the original codec pointer
//
//    This _packed version of the routine works with Packed Buffers
//
// INPUTS:
//    - r5 = pointer to relay structure
//
// OUTPUTS:
//    - none
// *****************************************************************************
.MODULE $M.relay.update_codec_ptr_packed;
   .CODESEGMENT PM;
   .DATASEGMENT DM;
   
   .VAR internal_buffer_read_pos;
   .VAR internal_buffer_write_pos; 
   
   $relay.update_codec_ptr_packed:

   $push_rLink_macro;

   call $block_interrupts;
   
   r0 = M[r5 + $relay.INTERNAL_CBUFFER_PTR_FIELD];
   r1 = M[r0 + $packed_cbuffer.READ_BYTEPOS_FIELD];
   M[internal_buffer_read_pos] = r1;
   call $cbuffer.get_read_address_and_size;

   r1 = r0;
   r0 = M[r5 + $relay.INPUT_CBUFFER_FIELD];
   call $cbuffer.set_read_address;
   
   r1 = M[internal_buffer_read_pos];
   M[r0 + $packed_cbuffer.READ_BYTEPOS_FIELD] = r1;

   r0 = M[r5 + $relay.INPUT_CBUFFER_FIELD];
   r1 = M[r5 + $relay.AV_DECODE_STRUC_FIELD];
   M[r1 + $codec.av_decode.IN_BUFFER_FIELD]  =r0;

   call $unblock_interrupts;
   
   jump $pop_rLink_and_rts;
   
.ENDMODULE;



// *****************************************************************************
// MODULE:
//    $relay.copy_data_packed
//
// DESCRIPTION:
//    Copies encoded data to relay frame.  
//
//    This _packed version of the routine works with Packed Buffers for input and output
// INPUTS:
//   
//    - r5 = pointer to relay structure
//
// OUTPUTS:
//    - none
// *****************************************************************************
.MODULE $M.relay.copy_data_packed;
   .CODESEGMENT PM;
   .DATASEGMENT DM;
   
   .VAR $relay_frame_size_packed = 0;
   .VAR $start_of_encoded_data_bit_pos_packed = 16;  // 
   .VAR $debug_latency_packed=0;
   .VAR internal_buffer_read_pos;
   .VAR internal_buffer_write_pos;
   .VAR input_buffer_read_pos;
   .VAR input_buffer_write_pos;
   .VAR relay_struc_temp;
   
   $relay.copy_data_packed:
   
   $push_rLink_macro;  
   
   M[$debug_latency_packed] = r8;
   M[relay_struc_temp]=r5;

   call $block_interrupts;

   // get pointer position before decoder ran
   r0 = M[r5 + $relay.INPUT_CBUFFER_FIELD];  //codec_in_cbuffer
   r1 = M[r0 + $packed_cbuffer.READ_BYTEPOS_FIELD];   //Rbp
   M[input_buffer_read_pos] = r1;
   call $cbuffer.get_read_address_and_size; 
   I1 = r0; //Rp
   L1 = r1;

   // get pointer position after decoder ran
   r0 = M[r5 + $relay.INTERNAL_CBUFFER_PTR_FIELD]; //codec_in_internal_cbuffer
   r1 = M[r0 + $packed_cbuffer.READ_BYTEPOS_FIELD];   //Wbp
   M[internal_buffer_read_pos] = r1;
   call $cbuffer.get_read_address_and_size;   
   I0 = r0;//Wp

   call $unblock_interrupts;

   // calc the amount of bytes needed to copy
   r10 = I0 - I1; //Wp - Rp
   if LE r10 = r10 + L1;   
   r10 = r10*3(int); //(Wp - Rp)*3

   // calc bitpos before decoder ran - bitpos after decoder ran
   r1 = M[internal_buffer_read_pos]; //Wbp
   r10 = r10 - r1; //(Wp - Rp)*3 - Wbp

   r1 = M[input_buffer_read_pos];
   r10 = r10 + r1; //(Wp - Rp)*3 - Wbp +Rbp
   
   // get sync frame length in bytes
   // Need to check the sync structure for size of header
   // to check and see if this frame will fit....
   r3 = 0;
   r0 = M[r5 + $relay.TWS_HEADER_FIELD];
   if Z jump no_header;
   r3 = M[r0];  //SIZE_OF_HEADER_IN_WORDS should be the first entry in the Header prototype
   r3 = r3*3 (int);

   .VAR $header_size_packed =0;
   M[$header_size_packed] = r3;
   
no_header: 
   // compute total number of bytes to relay
   r4 = r3 + r10;
   // see if data will fit in relay buffer
   r0 = M[r5 + $relay.RELAY_CBUFFER_FIELD];
   call $packed_cbuffer.calc_amount_space_word16;
   //in bytes   
   r0 = r0  ASHIFT 1;

   Null = r0 - r4;
   if NEG jump not_enough_space_for_relay_data;  
   //Are there odd number of bytes? 
   Null = r10 AND 1;   
   if Z jump skip_odd_byte;
      //COPY ONE BYTE so we have even bytes left 
      r0 = M[r5 + $relay.INPUT_CBUFFER_FIELD];
      call $packed_cbuffer.get_word8;
      r0 = M[r5 + $relay.RELAY_CBUFFER_FIELD];
      call $packed_cbuffer.put_word8; 
skip_odd_byte:

   //in 16bit words
   r10 = r10 ASHIFT -1;
   r0 = M[r5 + $relay.INPUT_CBUFFER_FIELD];
   call $packed_cbuffer.get_word16_initialize;
   // Output of previous call    
   //    r4=address of read function to call, r6 = 8
   //    I1/L1 = address of index in getpos_jump_table_nextpos for current READ_BYTEPOS 
   //    I5/L5/B5=read address
   // get write pointer for relaying data
   
   r0 = M[r5 + $relay.RELAY_CBUFFER_FIELD];
   call $packed_cbuffer.put_word16_initialize; 
   // Output of previous call 
   // r5=address of write function to call, 
   // r6 = 8, 
   // I0/L0/B0 = write address, 
   // I4/L4 = address of index in getpos_jump_table_nextpos for current WRITE_BYTEPOS, 
   // M0 =0,M1 =1
   
   do  lp_write_word;
      call r4;
      call r5;
lp_write_word:

   r5 = M[relay_struc_temp];
   r0 = M[r5 + $relay.INPUT_CBUFFER_FIELD];
   call $packed_cbuffer.get_word16_finalize;
   
   // get write pointer for relaying data
   r0 = M[r5 + $relay.RELAY_CBUFFER_FIELD];
   call $packed_cbuffer.put_word16_finalize;

insert_header:
   r5 = M[relay_struc_temp];
   r0 = M[r5 + $relay.TWS_HEADER_FIELD];
   if Z jump done_with_relay_data;
   
   I1 =r0;
   r0 = M[I1,1]; 
   r10 = r0;
   r0 = M[r5 + $relay.RELAY_CBUFFER_FIELD];
   
   do copy_header_loop;      
      // // read a 24 bit word      
      r5 = M[I1,1]; 
      r1 = r5 AND 0xff0000  ; 
      r1 = r1 LSHIFT -16;
      // write a byte      
      call $packed_cbuffer.put_word8;   
      r1 = r5 AND 0xff00; 
      r1 = r1 LSHIFT -8;
      // write a byte      
      call $packed_cbuffer.put_word8; 
      r1 = r5 AND 0xff; 
      // write a byte      
      call $packed_cbuffer.put_word8; 
   copy_header_loop:
   
   r5 = M[relay_struc_temp];

not_enough_space_for_relay_data:

#ifdef RELAY_DEBUG_ENABLE
   .VAR $relay.drop_encoded_relay_frame_count = 0;
   r0 = M[$relay.drop_encoded_relay_frame_count];
   r0 = r0 + 1;
   M[$relay.drop_encoded_relay_frame_count] = r0;   
#endif

done_with_relay_data:

   L0 = NULL;
   L1 = NULL;
   L4 = NULL;
   L5 = NULL;
   // Update blocking pointer  
   jump $pop_rLink_and_rts;
.ENDMODULE;

#endif