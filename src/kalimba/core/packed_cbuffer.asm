// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
// Packed buffer library
//
//   A packed cbuffer differs from a regular cbuffer in that data is byte-aligned, 
//    rather than word aligned like a cbuffer. This requires the addition of 
//    read/write byte positions fields in order to track the byte position of the 
//    associated with the read/write address
//
//   This setup allows both compact (packed) storage of non-native sized words, 
//    and non word aligned storage of native-sized words. When word sizes larger 
//    than a byte are used, they are ordered in big-endian format.
//   
//   This library provides functions to:
//      -Create packed cbuffers 
//      -put and get words of non-native size (8bit or 16bit) into/from packed buffers.
//      -Calculate how many words are stored in packed buffers
//      
//   The figure below demonstrates storage of some 16-bit words in a K24 packed cbuffer. 
//
//  word |    
//  addr v    2       1       0      -1 <--byte_pos 
//  0x000000  |[x0_hi]| x0_lo | x1_hi | <-------read address=0, [read_bytepos=2]
//  0x000001  | x1_lo | x2_hi | x2_lo |
//  0x000002  | x3_hi | x3_lo | x4_hi |
//  0x000003  | x4_lo | x5_hi | x5_lo |
//  0x000004  | x6_hi | x6_lo | x7_hi |
//  0x000005  | x7_lo | x8_hi | x8_lo | 
//  0x000006  | x9_hi | x9_lo |(xxxxx)| <-------write address=6, (write_bytepos=0)
//       ...  |---8b--|---8b--|--8b---|
//            |----------24b----------|
//
//  The same data stored in non-packed buffer:
//
//  word |
//  addr v
//  0x000000  | xxxxx | x0_hi | x0_lo | <-------read address=0
//  0x000001  | xxxxx | x1_hi | x1_lo |
//  0x000002  | xxxxx | x2_hi | x2_lo |
//  0x000003  | xxxxx | x3_hi | x3_lo |
//  0x000004  | xxxxx | x4_hi | x4_lo |
//  0x000005  | xxxxx | x5_hi | x5_lo |
//  0x000006  | xxxxx | x6_hi | x6_lo |
//  0x000007  | xxxxx | x7_hi | x7_lo |
//  0x000008  | xxxxx | x8_hi | x8_lo |
//  0x000009  | xxxxx | x9_hi | x9_lo |
//  0x00000A  | xxxxx | xxxxx | xxxxx | <-------write address=10
//       ...  |---8b--|---8b--|--8b---|
//            |----------24b----------|
//
// xxxx = dont't care
//
// A packed cbuffer object contains the following fields:
//    $cbuffer.SIZE_FIELD (0)                   // inherited from cbuffer object
//      $cbuffer.READ_ADDR_FIELD (1)              // inherited from cbuffer object
//      $cbuffer.WRITE_ADDR_FIELD(2)              // inherited from cbuffer object
//      $cbuffer.START_ADDR_FIELD (3)             // inherited from cbuffer object (base register mode)
//    $packed_cbuffer.READ_BYTEPOS_FIELD (cbuffer.size+1)    // current read byte position (0-2 for K24)
//    $packed_cbuffer.WRITE_BYTEPOS_FIELDS (cbuffer.size+2)  // current write byte position (0-2 for K24)
//
//      Note that the beginning of the object is identical to a regular cbuffer. This means that a packed
//      cbuffer can be passed to cbuffer functions like calc_amount_data, etc
//
//    -Buffer updates: Relations below describe how READ_BYTEPOS and WRITE_BYTEPOS are updated, and how
//         data and space in the buffer are calculated...
//
//          N = number of bytes transferred to/from packed bufffer
//          sz = packed buffer size in 24-bit words
//          wo = write pointer increment (add to write pointer)
//          ro = read pointer increment (add to read pointer)
//          wb = write byte position (initialize to 2)
//          rb = read byte position (initialize to 2)
//
//       -write update (for put operation)
//          wb = (wb-N)%3           // new write bytepos
//          wo = (2-wb+N)/3         // increment for write pointer(24-bit words), how much to increment cbuffer writer_poitner field
//       -read update (for get operation)
//          rb = (rb-N)%3           // new read bytepos
//          ro = (2-rb+N)/3         // increment for read pointer(24-bit words), how much to increment cbuffer read_poitner field
//       -amount_data_bytes
//          = write_byte_pointer - read_byte_pointer
//          = (3*wo+2-wb) - (3*ro+2-rb)
//          = 3*(amount_data_w) + (rb-wb)    // amount_data_w comes from $cbuffer.calc_amount_data
//       -amount_space_bytes
//          = sz - (write_byte_pointer - read_byte_pointer)
//          = 3*(sz_w - (wo-ro)-1) + (wb-rb)
//          = 3*(amount_space_w) + (wb-rb)   // amount_space_w comes from $cbuffer.calc_amount_space


// *****************************************************************************
// MODULE:
//    $M.packed_cbuffer.calc_amount_data;
//
// DESCRIPTION:
//    return number of bytes stored in packed buffer
//       = ( 3*(calc_amt_data_w) + rb-wb )
//
// INPUTS:
//    r0 = packed cbuffer struc
//    r2 = buffer size in 24-bit words
//
// OUTPUTS:
//    r0 = packed amount data (16-bit words)
//
// TRASH
//    r1
//
// *****************************************************************************
.MODULE $M.packed_cbuffer.calc_amount_data;
   .CODESEGMENT PACKED_CBUFFER_CALC_AMOUNT_DATA_PM;

   $packed_cbuffer.calc_amount_data_word8:
   r1 = 0;
   jump in_bytes;
   $packed_cbuffer.calc_amount_data_word16:
   r1 = 1;
in_bytes:

   push rLink;
   push r3;
   push r1;

   push r0;
   call $block_interrupts;
   pop r0;
   r3 = r0;
   call $cbuffer.calc_amount_data;
   r0 = r0*3(int);
   r1 = M[r3 + $packed_cbuffer.READ_BYTEPOS_FIELD];
   r0 = r0 + r1;
   r1 = M[r3 + $packed_cbuffer.WRITE_BYTEPOS_FIELD];
   push r0;
   call $unblock_interrupts;
   pop r0;
   r0 = r0 - r1;
   if LT r0 = 0;
   r1 = -1;
   pop r3;
   Null = r3;
   if NZ r0 = r0 ASHIFT r1; // bytes to words if r4=1
   pop r3;
   pop rLink;
   rts;
.ENDMODULE;


// *****************************************************************************
// MODULE:
//    $M.packed_cbuffer.calc_amount_space;
//
// DESCRIPTION:
//    return number of 16-bit words available in packed buffer
//       =( 3*(calc_amt_space_w) + wb-rb ) / 2
// INPUTS:
//    r0 = packed cbuffer struc
//
// OUTPUTS:
//    r0 = packed amount space (16-bit words)
//    r2 = buffer size in 24-bit words
//
// TRASH
//    r1
// *****************************************************************************
.MODULE $M.packed_cbuffer.calc_amount_space;
   .CODESEGMENT PACKED_CBUFFER_CALC_AMOUNT_SPACE_PM;

   $packed_cbuffer.calc_amount_space_word8:
   r1 = 0;
   jump in_bytes;
   $packed_cbuffer.calc_amount_space_word16:
   r1 = 1;
in_bytes:

   push rLink;
   push r3;
   push r1;
   r3 = r0;
   push r0;
   call $block_interrupts;
   pop r0;
   call $cbuffer.calc_amount_space;
   r0 = r0*3(int);
   r1 = M[r3 + $packed_cbuffer.WRITE_BYTEPOS_FIELD];
   r0 = r0 + r1;
   r1 = M[r3 + $packed_cbuffer.READ_BYTEPOS_FIELD];
   push r0;
   call $unblock_interrupts;
   pop r0;
   r0 = r0 - r1;
   r0 = r0 - 3;
   if LT r0 = 0;
   r1 = -1;
   pop r3;
   Null = r3;
   if NZ r0 = r0 ASHIFT r1; // bytes to words
   pop r3;
   pop rLink;
   rts;
.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $M.packed_cbuffer.get/set_read_address_and_bytepos;
//
// DESCRIPTION:
//    Set the buffer's read address and READ_BYTEPOS. Valid values for READ_BYTEPOS 
//    are 2,1,0, and -1.
//
//    Note a bytepos value of -1 (a state set by some CODECS) is considered an abnormal 
//    state, and while calc_amount_data/space will return a valid value, buffer 
//    operations cannot take place during this condition (packked buffer manipulation 
//    functions will call the packed_buffer.normalize function to correcft it first)
//
//    When converting between bit position used by some CODECs, and BYTEPOS, use the 
//    following relation:
//       READ_BYTEPOS = (sbcdec.get_bitpos >> 3) - 1; 
//          sbc.bitpos        READ_BYTEPOS
//          24                2
//          23-16             1
//          15-8              0
//          7-0               -1
//       where:
//          sbcdec.get_bitpos = [24...0]; // bit position, 0 means 
//          READ_BYTEPOS = [2, 1, 0, -1] // see above
//
// INPUTS:
//    r0 = packed cbuffer struc
//    r1 = read address                    (set/get)
//    r2 = read_bytepos (-1, 0, 1, 2)      (set/get)
//    r3 = length                          (get)
//    r4 = start address                   (get)
//
// OUTPUTS:
//    none
//
// TRASH
//    none
// *****************************************************************************
.MODULE $M.packed_cbuffer.set_read_address_and_bytepos;
   .CODESEGMENT PM;
   $packed_cbuffer.set_read_address_and_bytepos:
   push rLink;
   push r0;
   call $block_interrupts;
   pop r0;
   M[r0 + $cbuffer.READ_ADDR_FIELD] = r1;
   M[r0 + $packed_cbuffer.READ_BYTEPOS_FIELD] = r2;
   push r0;   
   call $unblock_interrupts;
   pop r0;
   pop rLink;
   rts;

   $packed_cbuffer.get_read_address_and_bytepos:
   push rLink;
   push r0;
   call $block_interrupts;
   pop r0;
   r1 = M[r0 + $cbuffer.READ_ADDR_FIELD];
   r2 = M[r0 + $packed_cbuffer.READ_BYTEPOS_FIELD];
   r3 = M[r0 + $cbuffer.SIZE_FIELD];
#ifdef BASE_REGISTER_MODE
   r4 = M[r0 + $cbuffer.START_ADDR_FIELD];
#endif   
   push r0;
   call $unblock_interrupts;
   pop r0;
   pop rLink;
   rts;

.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $M.packed_cbuffer.get/set_write_address_and_bytepos;
//
// DESCRIPTION:
//    Set the buffer's write address and WRITE_BYTEPOS. Valid values for WRITE_BYTEPOS 
//    are 2,1,0, and -1.
//
//    Note a bytepos value of -1 (a state set by some CODECS) is considered an abnormal 
//    state, and while calc_amount_data/space will return a valid value, buffer 
//    operations cannot take place during this condition (packked buffer manipulation 
//    functions will call the packed_buffer.normalize function to correcft it first)
//
//    When converting between bit position used by some CODECs, and BYTEPOS, use the 
//    following relation:
//       WRITE_BYTEPOS = (sbcdec.set_bitpos >> 3) - 1; 
//          sbc.bitpos        WRITE_BYTEPOS
//          24                2
//          23-16             1
//          15-8              0
//          7-0               -1
//       where:
//          sbcdec.get_bitpos = [24...0]; // bit position, 0 means 
//          WRITE_BYTEPOS = [2, 1, 0, -1] // see above
//
// INPUTS:
//    r0 = packed cbuffer struc
//    r1 = write address                     (get/set)
//    r2 = write_bytepos (-1, 0, 1, 2)       (get/set)
//    r3 = length                            (get)
//    r4 = start                             (get)
//
// TRASH
//    none
// *****************************************************************************
.MODULE $M.packed_cbuffer.set_write_address_and_bytepos;
   .CODESEGMENT PM;
   $packed_cbuffer.set_write_address_and_bytepos:
   push rLink;
   push r0;
   call $block_interrupts;
   pop r0;
   M[r0 + $cbuffer.WRITE_ADDR_FIELD] = r1;
   M[r0 + $packed_cbuffer.WRITE_BYTEPOS_FIELD] = r2;
   push r0;
   call $unblock_interrupts;
   pop r0;
   pop rLink;
   rts;

   $packed_cbuffer.get_write_address_and_bytepos:
   push rLink;
   push r0;
   call $block_interrupts;
   pop r0;
   r1 = M[r0 + $cbuffer.WRITE_ADDR_FIELD];
   r2 = M[r0 + $packed_cbuffer.WRITE_BYTEPOS_FIELD];
   r3 = M[r0 + $cbuffer.SIZE_FIELD];
#ifdef BASE_REGISTER_MODE
   r4 = M[r0 + $cbuffer.START_ADDR_FIELD];
#endif   
   push r0;
   call $unblock_interrupts;
   pop r0;
   pop rLink;
   rts;


.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $M.packed_cbuffer.normalize_read_address
//
// DESCRIPTION:
//    This module corrects the condition where the READ_BYTE_POS == -1. (ie no
//    more data can be read from the current word, but the read pointer has yet 
//    to be advanced. The functions in packed_cbufffer.asm and packed buffer cbops
//    will never leave the buffer in this condition, however, some CODECS will...
//    The condition is corrected by advancing the read pointer, AND resetting 
//    READ_BYTEPOS to 2. This normalization will not results in a change to the value 
//    returned by packed_cbuffer.calc_amount_data/space, but will allow read 
//    operations to be conducted on the packed buffer.
// INPUTS:
//    r0 = packed cbuffer struc
// OUTPUTS:
//    none
// TRASH
//    none
// *****************************************************************************
.MODULE $M.packed_cbuffer.normalize_read_address;
   .CODESEGMENT PM;
   $packed_cbuffer.normalize_read_address:

   push rLink;
   push r0;
   call $block_interrupts;
   pop r0;

   Null = M[r0 + $packed_cbuffer.READ_BYTEPOS_FIELD];
   if POS jump cleanup_and_rts;

   pushm <r0,r1>;
   push I0;
   push B0;

   r1 = M[r0 + $cbuffer.READ_ADDR_FIELD];
   I0 = r1;
   r1 = M[r0 + $cbuffer.SIZE_FIELD];
   L0 = r1;
   #ifdef BASE_REGISTER_MODE
      r1 = M[r0 + $cbuffer.SIZE_FIELD];
      push r1;
      pop B0;
   #endif
   r1 = M[I0, 1]; // dummy read to advance read address
   r1 = 2;
   M[r0 + $packed_cbuffer.READ_BYTEPOS_FIELD] = r1;
   r1 = I0;
   M[r0 + $cbuffer.READ_ADDR_FIELD] = r1;
   L0 = 0;
   #ifdef BASE_REGISTER_MODE
      push Null;
      pop B0;
   #endif
   pop B0;
   pop I0;
   popm <r0,r1>;

cleanup_and_rts:
   push r0;
   call $unblock_interrupts;
   pop r0;
   pop rLink;
   rts;
.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $M.packed_cbuffer.normalize_write_address
//
// DESCRIPTION:
//    This module corrects the condition where the WRITE_BYTE_POS == -1. (ie no
//    more data can be written to the current word, but the write pointer has yet 
//    to be advanced. The functions in packed_cbufffer.asm and packed buffer cbops
//    will never leave the buffer in this condition, however, some CODECs will...
//    The condition is corrected by advancing the write pointer, AND resetting 
//    WRITE_BYTEPOS to 2. This normalization will not results in a change to the value 
//    returned by packed_cbuffer.calc_amount_data/space, but will allow write
//    operations to be conducted on the packed buffer.
// INPUTS:
//    r0 = packed cbuffer struc
// OUTPUTS:
//    none
// TRASH
//    none
// *****************************************************************************
.MODULE $M.packed_cbuffer.normalize_write_address;
   .CODESEGMENT PM;
   $packed_cbuffer.normalize_write_address:

   push rLink;
   push r0;
   call $block_interrupts;
   pop r0;
   Null = M[r0 + $packed_cbuffer.WRITE_BYTEPOS_FIELD];
   if POS jump cleanup_and_rts;
   pushm <r0,r1>;
   push I0;
   push B0;
   r1 = M[r0 + $cbuffer.WRITE_ADDR_FIELD];
   I0 = r1;
   r1 = M[r0 + $cbuffer.SIZE_FIELD];
   L0 = r1;
   #ifdef BASE_REGISTER_MODE
      r1 = M[r0 + $cbuffer.SIZE_FIELD];
      push r1;
      pop B0;
   #endif
   r1 = M[I0, 1]; // dummy write to advance write address
   r1 = 2;
   M[r0 + $packed_cbuffer.WRITE_BYTEPOS_FIELD] = r1;
   r1 = I0;
   M[r0 + $cbuffer.WRITE_ADDR_FIELD] = r1;
   L0 = 0;
   #ifdef BASE_REGISTER_MODE
      push Null;
      pop B0;
   #endif
   pop B0;
   pop I0;
   popm <r0,r1>;
   
cleanup_and_rts:
   push r0;
   call $unblock_interrupts;
   pop r0;
   pop rLink;
   rts;
.ENDMODULE;


// *****************************************************************************
// MODULE:
//    $M.packed_cbuffer.put_word8;
//
// DESCRIPTION:
//    insert a byte into a packed cbuffer. This module is inneficient and not
// intended to be used for streaming data, but for inserting a single byte into a packed
// packed buffer.
//
// INPUTS:
//    r0 = packed_cbuffer pointer
//    r1 = word to insert to buffer
//
// OUTPUTS:
//    none
//
// TRASH:
//    r1-r4,I0/L0/B0
//
// *****************************************************************************
.MODULE $M.packed_cbuffer.put_word8;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

   .VAR/DM1CIRC nextpos[3] = &pos_0, &pos_1, &pos_2;

$packed_cbuffer.put_word8:
   push rLink;

   call $packed_cbuffer.normalize_write_address;
   push r1;
   call $packed_cbuffer.get_write_address_and_bytepos;
   I0 = r1;
   L0 = r3;
#ifdef BASE_REGISTER_MODE
   push r4;
   pop B0;
#endif
   pop r1;

#ifdef DEBUG_ON
   call $packed_cbuffer.check_byte_ptr;
#endif
   r3 = M[&nextpos + r2];
   call r3;
   r1 = I0;
   call $packed_cbuffer.set_write_address_and_bytepos;
   L0 = 0;

#ifdef BASE_REGISTER_MODE
   push Null;
   pop B0;
#endif
   pop rLink;
   rts;

pos_2:
   r1 = r1 LSHIFT 16;
   r2 = M[I0, 0];
   r2 = r2 AND 0x00FFFF;
   r2 = r2 OR r1;
   M[I0, 0] = r2;
   r2 = 1;
   rts;   
pos_1:
   r1 = r1 LSHIFT 8;
   r1 = r1 AND 0x00FF00;
   r2 = M[I0, 0];
   r2 = r2 AND 0xFF00FF;
   r2 = r2 OR r1;
   M[I0, 0] = r2;
   r2 = 0;
   rts;   
pos_0:
   r1 = r1 AND 0x0000FF;
   r2 = M[I0, 0];
   r2 = r2 AND 0xFFFF00;
   r2 = r2 OR r1;
   M[I0, 1] = r2;
   r2 = 2;
   rts;   

.ENDMODULE;   
   


// *****************************************************************************
// MODULE:
//    $M.packed_cbuffer.get_word8;
//
// DESCRIPTION:
//    retrieve an 8-bit word from a packed cbuffer. This module is inneficient and not
// intended to be used for streaming data, but for reading a single byte from a packed
//  buffer.
//
// INPUTS:
//    r0 = packed_cbuffer pointer
//    
//
// OUTPUTS:
//    r1 = word read from buffer
//
// TRASH:
//    r1-r4,I0/L0/B0
//
// *****************************************************************************
.MODULE $M.packed_cbuffer.get_word8;
   .CODESEGMENT PM;
   .DATASEGMENT DM;

   .VAR/DM1CIRC nextpos[3] = &pos_0, &pos_1, &pos_2;

$packed_cbuffer.get_word8:
   push rLink;
   call $packed_cbuffer.normalize_read_address;

   push r1;
   call $packed_cbuffer.get_read_address_and_bytepos;
   I0 = r1;
   L0 = r3;
#ifdef BASE_REGISTER_MODE
   push r4;
   pop B0;
#endif
   pop r1;   

#ifdef DEBUG_ON
   call $packed_cbuffer.check_byte_ptr;
#endif
   r3 = M[&nextpos + r2];
   call r3;
   
   push r1;
   r1 = I0;
   call $packed_cbuffer.set_read_address_and_bytepos;
   L0 = 0;
   pop r1;

#ifdef BASE_REGISTER_MODE
   push Null;
   pop B0;
#endif
   pop rLink;
   rts;


pos_2:
   r2 = M[I0, 0];
   r1 = r2 AND 0xFF0000;
   r1 = r1 LSHIFT -16;
   r2 = 1;
   rts;   
pos_1:
   r2 = M[I0, 0];
   r1 = r2 AND 0x00FF00;
   r1 = r1 LSHIFT -8;
   r2 = 0;
   rts;   
pos_0:
   r2 = M[I0, 0];
   r1 = r2 AND 0x0000FF;
   r2 = M[I0, 1];
   r2 = 2;
   rts;   

.ENDMODULE;   


// *****************************************************************************
// MODULE:
//    $M.packed_cbuffer.get_word16;
//
// DESCRIPTION:
//    This module contains functions to retrieve a 16-bit word from a packed cbuffer. The following functions
//    are supported:
//
//    $packed_cbuffer.retrieve_16:
//       Function to unpack a word. Not setup or initialization is required. This funciton is 
//       relatively inneficient but easy to use
//
//    $packed_cbuffer.retrieve_16_initialize:
//       Initialize system for repeatedly unpacking words. After calling thisi function, call r4
//       repaeatedly to efficiently read values from the packed buffer
//
//    $packed_cbuffer.retrieve_16_finalize:
//       Call this function when finished reading packed data from the buffer
//
//    get_pos0/1/2
//       Function to get data from various byte positions. These should not be called directly
//
//    Example of using above functions to read packed data
//       For a more efficient way of reading packed words, rather than calling thiis function,
//       use the following procedure:
//
//          // initialize
//          call $packed_cbuffer.get_word16_initialize;
// 
//          // call r4 repeatedly to extract four words out of a packed cbuffer (and store them):
//          // preserve r6, I1/L1, I5/L5/B5
//          call r4;
//          call r4, M[I0, M1] = r0;
//          call r4, M[I0, M1] = r0;
//          call r4, M[I0, M1] = r0;
//          M[I0, M1] = r0;
// 
//          // finish
//          $packed_cbuffer.get_word16_finalize
//
// *****************************************************************************
.MODULE $M.packed_cbuffer.get_word16;
   .CODESEGMENT PM;
   .DATASEGMENT DM;
   
   .VAR/DM1CIRC getpos_jump_table_nextpos[3] = &get_pos1, &get_pos2, &get_pos0;


// DESCRIPTION:
//    Function to unpack a word. No setup or initialization is required. This funciton is 
//    relatively inneficient but easy to use
//
// INPUTS:
//    r0 = packed_cbuffer pointer
//
// OUTPUTS:
//    r0 = output value
//
// TRASH
//    none
//
// CYCLES
//    38 or 41
$packed_cbuffer.get_word16:

   push rLink;
   pushm<r4,r6,r8>;
   pushm<I1, I5, L1, L5>;
   
   r8 = r0;
   call $packed_cbuffer.get_word16_initialize;
   call r4;
   push r0;
   r0 = r8;
   call $packed_cbuffer.get_word16_finalize;
   pop r0;

   popm<I1, I5, L1, L5>;
   popm<r4,r6,r8>;
   pop rlink;
   rts;
   
// DESCRIPTION:   
//    Initialize system for repeatedly unpacking words. After calling thisi function, call r4
//    repaeatedly to efficiently read values from the packed buffer
// INPUT: 
//    r0 = packed_cbuffer pointer
// OUTPUT: 
//    r4=address of read function to call, r6/I1/L1, I5/L5/B5=read address
// TRASH
//    none
$packed_cbuffer.get_word16_initialize:
   push rLink;
   pushm <r1,r2,r3>;
   call $packed_cbuffer.normalize_read_address;

   call $packed_cbuffer.get_read_address_and_bytepos;
   I5 = r1;
   L5 = r3;
#ifdef BASE_REGISTER_MODE
   push r4;
   pop B5;
#endif
#ifdef DEBUG_ON
   call $packed_cbuffer.check_byte_ptr;
#endif
   r4 = r2;
   I1 = r4 + &getpos_jump_table_nextpos;
   L1 = 3;
   push I1;
   r4 = M[I1, -1]; // table has next address, but we
   r4 = M[I1, -1]; // want current address, so decrement
   pop I1;
   r6 = 8;
   popm <r1,r2,r3>;
   pop rLink;
   rts;

// DESCRIPTION:   
//    Call this function when finished reading packed data from the buffer
// INPUT: 
//    r0 = packed_cbuffer pointer, I1, I5=read_address
// OUTPUT: 
//    None
// TRASH:
//    none
$packed_cbuffer.get_word16_finalize:
   push rLink;
   pushm <r1,r2>;
   r1 = I5;
   r2 = I1-getpos_jump_table_nextpos;
   call $packed_cbuffer.set_read_address_and_bytepos;
   L5 = 0;
   L1 = 0;
   
#ifdef BASE_REGISTER_MODE
   push Null;
   pop B5;
#endif
   popm <r1,r2>;   
   pop rLink;
   rts;


// (applies to next three functions)
// DESCRIPTION:
//    Functions for retrieving a word from a packed buffer. Do not call these directly
// INPUT: 
//    r6, I1/L1, I5/L5/B5=read_address
// OUTPUT: 
//    r0=unpacked word, r4=next read function,I1,I5=read_address(updated)
// TRASH:
//    none
// NOTE
//    r6, I1/L1, and I5/L5/B5 must be preserved between "call r4" statements
// CYCLES
//    3 or 6
get_pos2:
   r4 = M[I1, 1], r0 = M[I5, 0];
   r0 = r0 LSHIFT -8;
   rts;

get_pos1:
   r4 = M[I1, 1], r0 = M[I5, 1];
   r0 = r0 AND 0x00FFFF;
   rts;

get_pos0:
   r0 = M[I5, 1];
   r0 = r0 LSHIFT r6, r4 = M[I5, 0];
   r0 = r0 AND 0x00FF00;
   r4 = r4 LSHIFT -16;
   r0 = r0 OR r4, r4 = M[I1, 1];
   rts;

.ENDMODULE;





// *****************************************************************************
// MODULE:
//    $M.packed_cbuffer.put_word16;
//
// DESCRIPTION:
//    This module contains functions to insert 16-bit words into a packed cbuffer. The following functions
//    are supported:
//
//    $packed_cbuffer.insert_16:
//       Function to pack a word. No setup or initialization is required. This funciton is 
//       relatively inneficient but easy to use
//
//    $packed_cbuffer.insert_16_initialize:
//       Initialize system for repeatedly packing words. After calling thisi function, call r5
//       repaeatedly to efficiently read values from the packed buffer
//
//    $packed_cbuffer.insert_16_finalize:
//       Call this function when finished reading packed data from the buffer
//
//    write_at_pos0/1/2
//       Function to get data from various byte positions. These should not be called directly
//
//    Example of using above functions to read packed data
//       For a more efficient way of reading packed words, rather than calling thiis function,
//       use the following procedure:
//
//          // initialize
//          call $packed_cbuffer.put_word16_initialize;
// 
//          // call r5 repeatedly to pack words into a packed buffer
//          // preserve r6, I0/L0/B0, I4/L4, M0,M1
//          r0 = M[I1, M1];
//          call r5, r0 = M[I1, M1];
//          call r5, r0 = M[I1, M1];
//          call r5, r0 = M[I1, M1];
// 
//          // finish
//          $packed_cbuffer.put_word16_finalize
//
// *****************************************************************************
.MODULE $M.packed_cbuffer.put_word16;
   .CODESEGMENT PM;
   .DATASEGMENT DM;
   
   .VAR/DM2CIRC getpos_jump_table_nextpos[3] = &write_at_pos1, &write_at_pos2, &write_at_pos0;


// DESCRIPTION:
//    Function to insert a word in a packed cbuffer. No setup or initialization is required. 
//     This funciton is  relatively inneficient but easy to use
//
// INPUTS:
//    r0 = packed_cbuffer pointer
//    r1 = word to insert to buffer
// OUTPUTS:
//    r0 = output value
// TRASH
//    none
// CYCLES
//    38 or 41
$packed_cbuffer.put_word16:

   push rLink;
   pushm<r1,r5,r6>;
   pushm<I0, I4, L0, L4>;
   pushm<M0,M1>;
   
   call $packed_cbuffer.put_word16_initialize;

   push r0;
   r0 = r1;
   call r5;
   pop r0;

   call $packed_cbuffer.put_word16_finalize;

   popm<M0,M1>;
   popm<I0, I4, L0, L4>;
   popm<r1,r5,r6>;
   pop rlink;
   rts;
   
// DESCRIPTION:   
//    Initialize system for repeatedly packing words. After calling thisi function, call r5
//    repaeatedly to efficiently read values from the packed buffer
// INPUT: 
//    r0 = packed_cbuffer pointer
// OUTPUT: 
//    r5=address of read function to call, r6, I0/L0/B0, I4/L4, M0,M1
// TRASH
//    none
$packed_cbuffer.put_word16_initialize:
   push rLink;
   pushm <r1, r2, r3, r4>;
   call $packed_cbuffer.normalize_write_address;
   call $packed_cbuffer.get_write_address_and_bytepos;
   I0 = r1;
#ifdef DEBUG_ON
   call $packed_cbuffer.check_byte_ptr;
#endif   
   r5 = r2;
   L0 = r3;
#ifdef BASE_REGISTER_MODE
   push r4;
   pop B0;
#endif

   I4 = r5 + &getpos_jump_table_nextpos;
   L4 = 3;
   push I4;
   r5 = M[I4, -1]; // table has next address, but we
   r5 = M[I4, -1]; // want current address, so decrement
   pop I4;
   M0 = 0;
   M1 = 1;
   r6 = 8;
   popm <r1, r2, r3, r4>;
   pop rLInk;
   rts;
 
// DESCRIPTION:   
//    Call this function when finished reading packed data from the buffer
// INPUT: 
//    r0 = packed_cbuffer pointer, I0=write_addr, I4=wtite_bytepos
// OUTPUT: 
//    None
// TRASH:
//    None
$packed_cbuffer.put_word16_finalize:
   push rLink;
   pushm <r1,r2>;
   r1 = I0;
   r2 = I4-getpos_jump_table_nextpos;
   call $packed_cbuffer.set_write_address_and_bytepos;
   L0 = 0;
   L4 = 0;
   
#ifdef BASE_REGISTER_MODE
   push Null;
   pop B0;
#endif
   popm<r1,r2>;
   pop rLink;
   rts;


// (applies to next three functions)
// DESCRIPTION:
//    Functions for inserting a 16-bit word into a packed buffer. Do not call these directly
// INPUT: 
//    I0/L0/B0=write_address, r0=value to write, r6,M0,M1,I4,L4
// OUTPUT: 
//    r5=next read function,I0=write_address(updated),I4(updated)
// TRASH:
//    r1
// NOTE:
//    r6, M0/M1, I0/L0/B0, and I4/L4 must be preserved between "call r5" statements
// CYCLES
//    4 or 11
write_at_pos2:
   r0 = r0 LSHIFT r6, r1 = M[I0, 0], r5 = M[I4, 1];
   r1 = r1 AND 0x0000FF;
   r0 = r0 OR r1;
   rts, M[I0, M0] = r0;
   
write_at_pos1:
   r1 = M[I0, 0], r5 = M[I4, 1];
   r1 = r1 AND 0xFF0000;
   r0 = r0 OR r1;
   rts, M[I0, M1] = r0;
   
write_at_pos0:
   push r0, r1 = M[I0, 0];
   r0 = r0 LSHIFT -8;
   r0 = r0 AND 0x0000FF;
   r1 = r1 AND 0xFFFF00;
   r0 = r0 OR r1, r5 = M[I4, 1];
   pop r0, M[I0, M1] = r0;
   r1 = M[I0, 0];
   r0 = r0 LSHIFT 16;
   r1 = r1 AND 0x00FFFF;
   r0 = r0 OR r1;
   rts, M[I0, M0] = r0;
.ENDMODULE;




// *****************************************************************************
// MODULE:
//    $M.packed_cbuffer.check_byte_ptr;
//
// INPUT:
//    r2 = read/write byteptr
// TRASH:
//    none
// *****************************************************************************
$packed_cbuffer.check_byte_ptr:
   Null = r2 - 0;
   if Z jump ok;
   Null = r2 - 1;
   if Z jump ok;
   Null = r2 - 2;
   if Z jump ok;
      // goto error, rLink contains caller of this function
      jump $error;
ok:
rts;
