// *****************************************************************************
// Copyright (c) 2005 - 2018 Qualcomm Technologies International, Ltd.         http://www.csr.com
// Part of ADK_CSR867x.WIN. 4.4
//
// $Change: 2210913 $  $DateTime: 2015/06/11 10:49:13 $
// *****************************************************************************

// *****************************************************************************
// NAME:
//    pack operator
//
// DESCRIPTION:
//    Copy 16-bit words from an unpacked source buffer to a packed destination buffer 
//
// *****************************************************************************


#include "cbops.h"
#include "stack.h"
#include "cbops_pack_op.h"

.MODULE $M.cbops.pack_op;
   .DATASEGMENT DM;

   // ** function vector ** - recommendation is to standardise presence of a create(), too
   .VAR $cbops.pack_op[$cbops.function_vector.STRUC_SIZE] =
      $cbops.function_vector.NO_FUNCTION,             // reset function
      &$cbops.pack_op.amount_to_use,                  // amount_to_use function
      &$cbops.pack_op.main;                           // main function

.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $cbops.pack_op.main
//
// DESCRIPTION:
//    copy r10 16-bit words from unpacked source buffer to packed destination 
//    buffer
//       K24: three 16-bit values are packed into two 24-bit words (3:2 packing ratio)
//       K32: two 16-bit values are packed into one 32-bit word (2:1 packing ratio)
//
// INPUTS:
//    - r5 = pointer to list of buffer start addresses
//    - r6 = pointer to the list of input and output buffer pointers
//    - r7 = pointer to the list of buffer lengths
//    - r8 = pointer to operator structure
//    - r10 = the number of samples to process
//
// OUTPUTS:
//    - none
//
// NOTE:
//    - output(desination) buffer cannot be an MMU port
//    - input(source) buffer *can* be an MMU port. It is assumed that word size is set to
//      16-bits.
//
// *****************************************************************************
.MODULE $M.cbops.pack_op.main;
   .CODESEGMENT CBOPS_PACK_MAIN_PM;
   .DATASEGMENT DM;

   $cbops.pack_op.main:

   Null = r10;
   if Z rts;

   push rLink;
   // this is purely to keep same footprint of the old cbop
   pushm <r3, r4, r9>;


   // setup I0/L0/B0(input), and I4/L4/B4(output)
   r0 = M[r8 + $cbops.unpack_op.PTR_PACKED_CBUFFER_STRUC_FIELD];
   call $packed_cbuffer.normalize_write_address;
   call setup_addressing;

   // 1- Copy one or two words so that we are aligned to BYTE_OFFSET=2. Then,
   //    an efficient loop will be used.
   r9 = 0; // r9 = number of packed words written before loop
   r0 = M[r8 + $cbops.pack_op.PTR_PACKED_CBUFFER_STRUC_FIELD];
   r0 = M[r0 + $packed_cbuffer.WRITE_BYTEPOS_FIELD];
   Null = r0 - 2;
   if Z jump writebytepos_2;
      r9 = 1;
      Null = r0 - 1;
      if Z jump writebytepos_1;
         // writebytepos==0 (copy two words)
         r9 = 2; // write 2 packed words
         call putat_writepos_0;
         r10 = r10 - 1; // read one unpacked word
         Null = r10;
         if Z jump cornercase_wb0_count_1; 

writebytepos_1:
   call putat_writepos_1;
   r10 = r10 - 1; // // read one unpacked word

writebytepos_2:

   // 2- Pack N*3 16-bit input words into N*2 24-output words
   //    where N = r10/3, using an a streamlined loop to save cycles
   rMAC = 0;
   rMAC0 = r10;
   r0 = 3;
   div = rMAC / r0;
   r10 = divResult;
   r7 = divRemainder;
   // efficient loop to handle the copying
   push r10;
   push r7;
   call do_3_in_16_to_2_out_24;


   // 3- Take care of leftovers from above (either 0, 1 or 2 words)
   //
   r3 = 2;  // r3 = new WRITE_BYTEPOS, assume 2
   r4 = 0;  // r4 = number of write pointer advances due to leftover data, assume none
   pop r10; // r10 is number of leftover words to copy
   Null = r10;
   if Z jump done;

      // leftover=1, writepos=0
      r3 = 0;
      call putat_writepos_2;
 
      Null = r10 - 1;
      if Z jump done;
         // leftover=2 writepos=1
         r3 = 1;
         r4 = 1;
         call putat_writepos_0;

     
done:
   r0 = M[r8 + $cbops.unpack_op.PTR_PACKED_CBUFFER_STRUC_FIELD];
   M[r0 + $packed_cbuffer.WRITE_BYTEPOS_FIELD] = r3;

   // calculate amount of outputs written, which will adjust write pointer
   pop r10;
   r0 = r10 * 2(int); // set by 3x16_to_2x24 loop 
   r0 = r0 + r4;  // set by leftovers after loop
   r0 = r0 + r9; // from before the loop
   M[$cbops.amount_written] = r0; 


   // zero the length registers and write the last sample
   L0 = 0;
   L4 = 0;

   #ifdef BASE_REGISTER_MODE
      // Zero the base registers
      push Null;
      B4 = M[SP-1];
      pop B0;
   #endif

   popm <r3, r4, r9>;
   pop rLink;
   rts;


   // Sub-functions
   //


   // INPUT: I0=INPUT, I4=OUTPUT
   // OUTPUT: I0=INPUT++
   // PRESERVE: r10, r3
   putat_writepos_2: // |BH|BL|XX|
      r0 = M[I0, 1], r1 = M[I4, 0];
      r0 = r0 LSHIFT 8;
      r1 = r1 AND 0x0000FF;
      r0 = r0 OR r1;
      M[I4, 0] = r0;
      rts;

   // INPUT: I0=INPUT, I4=OUTPUT
   // OUTPUT: I0=INPUT++, I4=OUTPUT++
   // PRESERVE: r10, r3
   putat_writepos_0: // |XX|XX|BH|
                 // |BL|XX|XX|
      r0 = M[I0, 1], r1 = M[I4, 0];
      r2 = r0 LSHIFT -8;
      r2 = r2 AND 0x0000FF;
      r1 = r1 AND 0xFFFF00;
      r2 = r2 OR r1;
      M[I4, 1] = r2;
      r1 = M[I4, 0];
      r0 = r0 LSHIFT 16;
      r1 = r1 AND 0x00FFFF;
      r0 = r0 OR r1;
      M[I4, 0] = r0;
      rts;
      
   // INPUT: I0=INPUT, I4=OUTPUT
   // OUTPUT++: I0=INPUT++
   // PRESERVE: r10, r3
   putat_writepos_1: // |XX|BH|BL|
      r0 = M[I0, 1], r1 = M[I4, 0];
      r1 = r1 AND 0xFF0000;
      r0 = r0 OR r1;
      M[I4, 1] = r0;
      rts;


   // INPUT: r10=number of blocks of 3x16 bit inputs, I0=INPUT, I4=OUTPUT
   // OUTPUT: I0=INPUT++, I4=OUTPUT++
   // PRESERVE: r10, r3
   do_3_in_16_to_2_out_24:  // |B2H|B2L|B1H|
                            // |B1L|B0H|B0L|
                            // ...
      r4 = 8;
      r7 = -8;
      r5 = 0x0000FF;
      r6 = 16;
      do loop_3_in_16_to_2_out_24;
         r0 = M[I0, 1];
         r0 = r0 LSHIFT r4, r1 = M[I0, 1];
         r2 = r1 LSHIFT r7;
         r2 = r2 AND r5;
         r0 = r0 OR r2;
         r1 = r1 LSHIFT r6, M[I4, 1] = r0, r0 = M[I0, 1];
         r0 = r0 AND 0x00FFFF;
         r0 = r0 OR r1;
         M[i4, 1] = r0;
      loop_3_in_16_to_2_out_24:
      rts;


   // INPUT: r8= data object
   // OUTPUT: I0/L0/B0, I4/L4/B4
   // PRESERVE: r8
   setup_addressing:

      // get the offset to the read buffer to use
      r0 = M[r8 + $cbops.pack_op.INPUT_START_INDEX_FIELD];
      // get the input buffer read address
      r1 = M[r6 + r0];
      // store the value in I0
      I0 = r1;
      // get the input buffer length
      r1 = M[r7 + r0];
      // store the value in L0
      L0 = r1;
      #ifdef BASE_REGISTER_MODE
         // get the start address
         r1 = M[r5 + r0];
         push r1;
         pop B0;
      #endif
   
      // get the offset to the write buffer to use
      r0 = M[r8 + $cbops.pack_op.OUTPUT_START_INDEX_FIELD];
      // get the output buffer write address
      r1 = M[r6 + r0];
      // store the value in I4
      I4 = r1;
      // get the output buffer length
      r1 = M[r7 + r0];
      // store the value in L4
      L4 = r1;
      #ifdef BASE_REGISTER_MODE
         // get the start address
         r1 = M[r5 + r0];
         push r1;
         pop B4;
      #endif
      rts;

   // corner case: amt=1, pos=0
   cornercase_wb0_count_1:
      r3 = 1;  // new write_bytepos = 1
      r4 = 0;  // +amount_written post loop
      r9 = 1;  // +amount_written for pre-loop
      r10 = 0;
      push r10;
      jump done;




.ENDMODULE;

// *****************************************************************************
// MODULE:
//   $M.cbops.pack_op.amount_to_use
//
// DESCRIPTION:
//
// INPUTS:
//    - r5 = the minimum of the number of input samples available and the
//      amount of output space available
//    - r6 = the number of input samples available
//    - r7 = the amount of output space available
//    - r8 = pointer to operator structure
//
// OUTPUTS:
//    - r5 = the number of samples to process
//
//
// *****************************************************************************
.MODULE $M.cbops.pack_op.amount_to_use;
   .CODESEGMENT CBOPS_PACK_AMOUNT_TO_USE_PM;
   .DATASEGMENT DM;
   $cbops.pack_op.amount_to_use:

   // recompute space based on packing ratio
   push rLink;
   r0 = r7;
   call $cbops.pack_op.adjust_amount_space; // returns r0
   r5 = r6;
   r5 = MIN r0;   // calc amount to use based on adjusted buffer space

   pop rLink;
   rts;

.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $M.cbops.unpack_op.adjust_amount_data;
//
// DESCRIPTION:
//    return amount of space in packed buffer
//       = ( 3*(calc_amt_space_w) + wb-rb ) / 2
//
// INPUTS:
//    r0 = amount of space in buffer, from $cbuffer.calc_amount_space (24-bit words)
//
// OUTPUTS:
//    r0 = packed amount space (16-bit words)
//
// TRASH
//    r0-r3
//
// *****************************************************************************
.MODULE $M.cbops.pack_op.adjust_amount_space;
   .CODESEGMENT CBOPS_PACK_PM;
   .DATASEGMENT DM;

   $cbops.pack_op.adjust_amount_space:

   r3 = M[r8 + $cbops.unpack_op.PTR_PACKED_CBUFFER_STRUC_FIELD];
   r0 = r0*3(int);
   r1 = M[r3 + $packed_cbuffer.WRITE_BYTEPOS_FIELD];
   r0 = r0 + r1;
   r1 = M[r3 + $packed_cbuffer.READ_BYTEPOS_FIELD];
   r0 = r0 - r1;
   r0 = r0 - 3;
   if LT r0 = 0;
   r0 = r0 ASHIFT -1; // bytes to words
   rts;
.ENDMODULE;
