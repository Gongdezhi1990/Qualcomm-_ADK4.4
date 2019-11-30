// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#ifdef AACDEC_PARAMETRIC_STEREO_ADDITIONS

#include "stack.h"
#include "profiler.h"

// *****************************************************************************
// MODULE:
//    $aacdec.ps_extension
//
// DESCRIPTION:
//    -
//
// INPUTS:
//    - r7 = ps_num_ext_bits_left
//
// OUTPUTS:
//    - r7 = ps_num_ext_bits_left (updated)
//
// TRASHED REGISTERS:
//    - toupdate
//
// *****************************************************************************
.MODULE $M.aacdec.ps_extension;
   .CODESEGMENT AACDEC_PS_EXTENSION_PM;
   .DATASEGMENT DM;


   $aacdec.ps_extension:


   // push rLink onto stack
   push rLink;


  PROFILER_START(&$aacdec.profile_ps_extension)

   r0 = M[$aacdec.read_bit_count];
   M[$aacdec.ps_info + $aacdec.PS_BIT_COUNT_PRE_EXTENSION_DATA] = r0;

   // PS_ENABLE_IPDOPD = getbits(1)
   call $aacdec.get1bit;
   if Z jump end_if_enable_ipdopd;
      // save ps_num_ext_bits_left
      r6 = r7;
      r7 = 7;
#ifdef KALASM3_NO_DATA_FLASH
      I3 = &$aacdec.t_huffman_ipd;
      I4 = &$aacdec.f_huffman_ipd;
      I5 = &$aacdec.t_huffman_opd;
      I6 = &$aacdec.f_huffman_opd;
#else
      r2 = M[$flash.windowed_data16.address];
      r0 = &$aacdec.t_huffman_ipd;
      call $aacdec.sbr_allocate_and_unpack_from_flash;
      I3 = r1;

      r2 = M[$flash.windowed_data16.address];
      r0 = &$aacdec.f_huffman_ipd;
      call $aacdec.sbr_allocate_and_unpack_from_flash;
      I4 = r1;

      r2 = M[$flash.windowed_data16.address];
      r0 = &$aacdec.t_huffman_opd;
      call $aacdec.sbr_allocate_and_unpack_from_flash;
      I5 = r1;

      r2 = M[$flash.windowed_data16.address];
      r0 = &$aacdec.f_huffman_opd;
      call $aacdec.sbr_allocate_and_unpack_from_flash;
      I6 = r1;

      r0 = M[$aacdec.ps_info + $aacdec.PS_HUFFMAN_TABLES_TOTAL_SIZE];
      r0 = r0 + (7*4);
      M[$aacdec.ps_info + $aacdec.PS_HUFFMAN_TABLES_TOTAL_SIZE] = r0;
#endif
      // restore ps_num_ext_bits_left
      r7 = r6;

      // for envelope=0:PS_NUM_ENV-1
      Null = M[$aacdec.ps_info + $aacdec.PS_NUM_ENV];
      if Z jump end_if_enable_ipdopd;
      r5 = M[$aacdec.ps_info + $aacdec.PS_NR_IPDOPD_PAR];
      if Z jump end_if_enable_ipdopd;
         // for envelope=0:PS_NUM_ENV-1,
         // r6 = envelope
         r6 = 0;
         ps_extension_loop:
            I2 = I3;  // time coded IPD data
            // PS_IPD_CODING_DIRECTION[envelope] = getbits(1)
            call $aacdec.get1bit;
            r10 = r5;
            M[($aacdec.ps_info + $aacdec.PS_IPD_CODING_DIRECTION) + r6] = r1;
            if Z I2 = I4;  // frequency coded IPD data
            // for p=0:PS_NUM_IPDOPD_PAR-1,
            do ps_ipd_huffman_decode_loop;
               call $aacdec.ps_huff_dec;
            ps_ipd_huffman_decode_loop:
            I2 = I5;  // time coded OPD data
            // PS_OPD_CODING_DIRECTION[envelope] = getbits(1)
            call $aacdec.get1bit;
            r10 = r5;
            M[($aacdec.ps_info + $aacdec.PS_OPD_CODING_DIRECTION) + r6] = r1;
            if Z I2 = I6;  // frequency coded OPD data
            // for p=0:PS_NUM_IPDOPD_PAR-1,
            do ps_opd_huffman_decode_loop;
               call $aacdec.ps_huff_dec;
            ps_opd_huffman_decode_loop:
         r6 = r6 + 1;
         Null = r6 - M[$aacdec.ps_info + $aacdec.PS_NUM_ENV];
         if LT jump ps_extension_loop;
   end_if_enable_ipdopd:


   // reserved PS bit
   call $aacdec.get1bit;

   // update ps_num_ext_bits_left
   r0 = M[$aacdec.read_bit_count];
   r1 = M[$aacdec.ps_info + $aacdec.PS_BIT_COUNT_PRE_EXTENSION_DATA];
   r0 = r0 - r1;
   r7 = r7 - r0;


  PROFILER_STOP(&$aacdec.profile_ps_extension)



   // pop rLink from stack
   jump $pop_rLink_and_rts;



.ENDMODULE;

#endif
