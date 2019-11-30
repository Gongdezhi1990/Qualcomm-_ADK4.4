// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#ifdef AACDEC_SBR_ADDITIONS

#include "stack.h"

// *****************************************************************************
// MODULE:
//    $aacdec.sbr_limiter_frequency_table
//
// DESCRIPTION:
//    Calculate fTableLim which contains the frequency borders used by the limiter
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0-r8, r10, rMAC
//    - I0-I6
//    - M0-M3
//    - first element in $aacdec.tmp
//
// *****************************************************************************
.MODULE $M.aacdec.sbr_limiter_frequency_table;
   .CODESEGMENT AACDEC_SBR_LIMITER_FREQUENCY_TABLE_PM;
   .DATASEGMENT DM;

   $aacdec.sbr_limiter_frequency_table:

   // push rLink onto stack
   push rLink;

   // allocate temporary buffers (Ftable_lim deallocated in later function)
   r0 = M[$aacdec.sbr_info + $aacdec.SBR_Nlow];
   r0 = r0 + 5;
   I6 = r0 - 1;
   r0 = r0 * 4 (int);
   call $aacdec.frame_mem_pool_allocate;
   M[$aacdec.tmp_mem_pool + $aacdec.SBR_F_table_lim_base_ptr] = r1;
   I3 = r1;

   r0 = $aacdec.SBR_LIM_TABLE_SIZE;
   call $aacdec.frame_mem_pool_allocate;
   M[&$aacdec.sbr_lim_table_base_ptr] = r1;
   M1 = r1;

   r0 = $aacdec.SBR_PATCH_BORDERS_SIZE;
   call $aacdec.frame_mem_pool_allocate;
   if NEG jump $aacdec.corruption;
   M[&$aacdec.sbr_patch_borders_base_ptr] = r1;
   M2 = r1;

   // sbr.Ftable_lim(1, 1) = sbr.F_TableLow(1) - sbr.Kx;
   // sbr.Ftable_lim(1, 2) = sbr.F_TableLow(sbr.Nlow+1) - sbr.Kx;
   // sbr.N_L(1) = 1;
   r1 = -M[$aacdec.sbr_info + $aacdec.SBR_kx];
   M0 = -r1;
   r3 = M[$aacdec.sbr_info + $aacdec.SBR_F_table_low] + r1;

   I5 = &$aacdec.tmp_mem_pool + $aacdec.SBR_N_L;
   rMAC = 1;

   r4 = M[$aacdec.sbr_info + $aacdec.SBR_Nlow];
   r0 = M[($aacdec.sbr_info + $aacdec.SBR_F_table_low) + r4];
   r0 = r0 + r1,
    M[I3, 1] = r3,
    M[I5, 1] = rMAC;

   M3 = I6;
   r1 = 0,
    M[I3, M3] = r0;

   r0 = M[$aacdec.tmp_mem_pool + $aacdec.SBR_num_patches];
   M3 = r0;

   main_loop:

      // store loop number
      M[$aacdec.tmp] = r1;

      // patchBorders(1:64) = 0;
      // patchBorders(1) = sbr.Kx;
      //
      // for k=1:sbr.noPatches,
      //    patchBorders(k+1) = patchBorders(k) + sbr.patchNoSubbands(k);
      // end;

      I0 = M1;
      I1 = M2;

      r10 = M3;
      r8 = $aacdec.SBR_PATCH_BORDERS_SIZE - r10;
      r0 = M0;
      M[I1, 0] = r0;
      I4 = &$aacdec.tmp_mem_pool + $aacdec.SBR_patch_num_subbands;
      do patch_borders_loop;
         r0 = M[I1, 1],
          r1 = M[I4, 1];
         r0 = r0 + r1;
         M[I1, 0] = r0;
      patch_borders_loop:

      r10 = r8;
      r0 = 0;
      I1 = I1 + 1;
      do pb_zero_loop;
         M[I1, 1] = r0;
      pb_zero_loop:


      // limTable(1:100) = 0;
      // for k=0:sbr.Nlow,
      //    limTable(k+1) = sbr.F_TableLow(k+1);
      // end;
      //
      // for k=1:sbr.noPatches-1,
      //    limTable(k + sbr.Nlow + 1) = patchBorders(k+1);
      // end;

      r10 = r4 + 1;
      r6 = ($aacdec.SBR_LIM_TABLE_SIZE + 1) - r10;
      I4 = &$aacdec.sbr_info + $aacdec.SBR_F_table_low;
      do lim_table_loop_1;
         r0 = M[I4, 1];
         M[I0, 1] = r0;
      lim_table_loop_1:

      r10 = M3;
      r8 = r10 + r4;
      I4 = I1 - $aacdec.SBR_PATCH_BORDERS_SIZE;

      r6 = r6 - r10,
       r0 = M[I4, 1];

      r10 = r10 - 1;
      do lim_table_loop_2;
         M[I0, 1] = r0,
          r0 = M[I4, 1];
      lim_table_loop_2:

      r10 = r6;
      r0 = 0;
      do lt_zero_loop;
         M[I0, 1] = r0;
      lt_zero_loop:



      // nrLim = sbr.noPatches + sbr.Nlow - 1;
      // limTable(1:100) = sbr_bubble_sort(limTable, (sbr.noPatches + sbr.Nlow) );
      // k = 0;
      //
      // if (nrLim < 0)
      //    return;
      // end;

      r0 = r8;
      r1 = M1;
      call $aacdec.sbr_bubble_sort;

      r5 = r1;                                           // r5 = &lim_table[k]     k = 0
      r8 = r8 - 1;                                       // r8 = nrLim
      if NEG jump escape;



      /*///////////////////////////////////////////////////////////////////////////////////////////////////////////////
                        [inc_k]        <-------------------------------------------------------------------------------
                           k = k + 1                                                                                  |
                              |                                                                                       |
                             \|/                                                                                      |
                        [top]                                                                                         |
      --------------->  if k > nrLim                                                                                  |
      |                       |                                                                                       |
      |         |-----------T---F--------------------------------|                                                    |
      |    N_L(s+1) = nrLim                                  [small_k]                                                |
      |    for k = 0:nrLim  [writeback_loop]                 if LT(k+1) = LT(k)                                       |
      |       Ftable_lim(s+1, k+1) = LT(k+1) - Kx                       |                                             |
      |    end                                                          |                                             |
      |         |                              |----------------------T---F-----------------------------|             |
      |         |                              |                         if log2(LT(k+1)) - log2(LT(k)) < 0.49/Q(s)   |
      |         |                              |                                         OR     LT(k+1) = 0           |
      |        \|/                             |                                         OR       LT(k) = 0           |
      |    [escape]                            |                                    Q = [1.2, 2, 3]     |             |
      |        OUT                             |                                                        |             |
      |                                        |                                                        |             |
      |                                        |                     |--------------------------------T---F---------->|
      |                                        |           [search_pb]                                               /|\
      |                                        |              if LT(k+1) is in                                        |
      |                                        |                patchBorders                                          |
      |                                        |                     |           [found_inpb]                         |
      |                                        |<------------------F---T---------------------------|                  |
      |                                        |                                           [search_pb]                |
      |                                        |                                              if LT(k) is in          |
      |                                        |                                               patchBorders           |
      |                                        |                                                   |                  |
      |                                        |<------------------------------------------------F---T----------------|
      |                                        |                                                         [found_inpb]
      |                                       \|/
      |                              [rem_kth]
      |                                 if come from LT(k) in patchBorders
      |                                    n = k
      |                                    length = noPatches + Nlow
      |                                 else
      |                                    n = k + 1
      |                                    length = nrLim
      |                                 end
      |                                 LT(n) = F_TableLow(Nlow+1)
      |                                 Bubblesort(LT, length)
      |                                 nrLim = nrLim - 1
      |                                       |
      |----------------------------------------

      labels in square brackets
      LT = limTable
      *////////////////////////////////////////////////////////////////////////////////////////////////////////////////


      inc_k:
         r5 = r5 + 1;                                    // r5 = &lim_table[k]     k = k+1;

      top:
         r0 = M1 - r5;
         Null = r0 + r8;
         if GE jump small_k;
            r1 = r8;
            M[I5, 1] = r1;
            r10 = r8 + 1;
            I1 = M1;
            do writeback_loop;
               r0 = M[I1, 1];
               r0 = r0 - M0;
               M[I3, 1] = r0;
            writeback_loop:
            r0 = r8 - I6;
            I3 = I3 - r0;
            jump escape;

         small_k:
            r2 = M[r5];

            r3 = M[r5 + (-1)];

            r6 = r5;
            Null = r2 - r3;
            if Z jump rem_kth;
               r6 = r3;
               if Z jump search_pb_start;
               r7 = r2;
               if Z jump search_pb_start;
               #ifdef AACDEC_SBR_LOG2_TABLE_IN_FLASH
                  r0 = r6 + (&$aacdec.sbr_log_base2_table - 1);
                  r2 = M[$flash.windowed_data16.address];
                  call $aacdec.sbr_read_one_word_from_flash;
                  r10 = r0 LSHIFT 8;

                  r0 = r7 + (&$aacdec.sbr_log_base2_table - 1);
                  r2 = M[$flash.windowed_data16.address];
                  call $aacdec.sbr_read_one_word_from_flash;
                  r0 = r0 LSHIFT 8;
               #else
                  r10 = M[(&$aacdec.sbr_log_base2_table - 1) + r6];
                  r0 = M[(&$aacdec.sbr_log_base2_table - 1) + r7];
               #endif

               r0 = r0 - r10;
               r1 = M[$aacdec.tmp];
               r1 = M[$aacdec.sbr_limiter_bands_compare + r1];
               Null = r0 - r1;
               if GE jump inc_k;

               search_pb_start:
               r1 = -1;
               search_pb_repeat:

               r10 = M3 + 1;
               I0 = M2;
               do search_pb;
                  r0 = M[I0, 1];
                  Null = r7 - r0;
                  if LE jump found_inpb;    // jump out if found r7 in patch_borders or gone past
               search_pb:                   // point where would be stored
               r6 = r5 - 1;
               Null = r1;
               if NEG r6 = r5;

            rem_kth:
               r2 = M[($aacdec.sbr_info + $aacdec.SBR_F_table_low) + r4];
               M[r6] = r2;
               r0 = M3 + r4;
               Null = r1;
               if NEG r0 = r8;
               r1 = M1;
               call $aacdec.sbr_bubble_sort;
               r8 = r8 - 1;
               jump top;

                  found_inpb:
                     if NZ jump search_pb;   // if not found jump back
                     r7 = r6;
                     r1 = r1 + 1;
                     if Z jump search_pb_repeat;
                     jump inc_k;


   escape:
   // retrieve loop number. loop 3 times
   r1 = M[$aacdec.tmp];
   r1 = r1 + 1;
   Null = r1 - 3;
   if LT jump main_loop;


   // deallocate temporary buffers
   r0 = $aacdec.SBR_PATCH_BORDERS_SIZE + $aacdec.SBR_LIM_TABLE_SIZE;
   call $aacdec.frame_mem_pool_free;


   // pop rLink from stack
   jump $pop_rLink_and_rts;


.ENDMODULE;

#endif
