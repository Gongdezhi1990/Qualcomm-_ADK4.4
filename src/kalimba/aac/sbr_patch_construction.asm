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
//    $aacdec.sbr_patch_construction
//
// DESCRIPTION:
//    Calculate patch information required by hf_generation from bitstream information
//
// INPUTS:
//    - none
//
// OUTPUTS:
//    - none
//
// TRASHED REGISTERS:
//    - r0-3, r5-8
//    - I0-3
//    - M0
//
// *****************************************************************************
.MODULE $M.aacdec.sbr_patch_construction;
   .CODESEGMENT AACDEC_SBR_PATCH_CONSTRUCTION_PM;
   .DATASEGMENT DM;

   $aacdec.sbr_patch_construction:

   I1 = &$aacdec.tmp_mem_pool + $aacdec.SBR_patch_num_subbands;
   I2 = &$aacdec.tmp_mem_pool + $aacdec.SBR_patch_start_subband;


   // if (sbr.Nmaster == 0)
   //    sbr.noPatches = 0;
   //    sbr.patchNoSubbands(1) = 0;
   //    sbr.patchStartSubband(1) = 0;
   //    return;
   // end;
   r0 = M[$aacdec.sbr_info + $aacdec.SBR_Nmaster];
   if Z jump escape;


   // msb = k0
   // usb = kx
   r0 = M[$aacdec.sbr_info + $aacdec.SBR_k0];              // r0 = msb
   r1 = M[$aacdec.sbr_info + $aacdec.SBR_kx];              // r1 = usb


   // goalSb = goalSbTab(sbr_get_sr_index(sbr.FS_SBR) + 1);
   r2 = M[$aacdec.sf_index];
   r2 = r2 - 3;
   r6 = M[r2 + &$aacdec.sbr_goal_sb_tab];


   // sbr.numPatches = 0;
   r7 = 0;                                   // r7 = sbr.numPatches


   // if (goalSb < (sbr.Kx + sbr.M))
   //    i = 0;
   //    k = 0;
   //    while(sbr.Fmaster(i+1) < goalSb)
   //       k = i+1;
   //       i = i + 1;
   //    end;
   // else
   //    k = sbr.Nmaster;
   // end;
   r2 = M[$aacdec.sbr_info + $aacdec.SBR_M];
   r2 = r2 + r1;
   Null = r6 - r2;
   if GE jump big_goalSb;
      I0 = (&$aacdec.sbr_info + $aacdec.SBR_Fmaster);

      next_k:
         r2 = M[I0,1];
         Null = r6 - r2;
         if GT jump next_k;

      // r6 = k
      r6 = I0 - (&$aacdec.sbr_info + $aacdec.SBR_Fmaster + 1);

      jump k_set;

   big_goalSb:
      r6 = M[$aacdec.sbr_info + $aacdec.SBR_Nmaster];


   k_set:
   I0 = (&$aacdec.sbr_info + $aacdec.SBR_Fmaster);


   // while(1),
   //    j = k + 1;
   outer_loop:

     I3 = I0 + r6;


      // while(1)
      //
      //    j = j - 1;
      //
      //    sb = sbr.Fmaster(j+1);
      //    odd = (sb - 2 + sbr.k0);
      //    odd = bitand(uint8(odd), 1);
      //
      //    if(sb <= (uint8(sbr.k0) - 1 + uint8(msb) - odd))
      //       break;
      //    end;
      //
      // end;
      r8 = M[$aacdec.sbr_info + $aacdec.SBR_k0];        // r8 = k0
      inner_loop:
         r2 = M[I3, -1];                     // r2 = sb
         r3 = r2 + r8;
         r3 = r3 AND 1;
         r3 = r3 - r8;                    // r3 = odd - k0

         r5 = r0 - r3;

         Null = r2 - r5;
      if GE jump inner_loop;



      // sbr.patchNoSubbands(sbr.noPatches + 1) = max(sb - usb, 0);
      // sbr.patchStartSubband(sbr.noPatches + 1) = uint8(sbr.k0) - odd - uint8(sbr.patchNoSubbands(sbr.noPatches + 1));
      //
      // if(sbr.patchNoSubbands(sbr.noPatches + 1) > 0)
      //    usb = sb;
      //    msb = sb;
      //    sbr.noPatches = sbr.noPatches + 1;
      // else
      //    msb = sbr.Kx;
      // end;
      M0 = r7;
      r5 = M[$aacdec.sbr_info + $aacdec.SBR_kx];        // r5 = kx
      r8 = r2 - r1;                          // r8 = sbr.patchNoSubbands
      if GT jump pns_pos;
         r0 = r5;
         r8 = 0;
         jump done_pns;

      pns_pos:
         r0 = r2;
         r1 = r2;
         r7 = r7 + 1;


      done_pns:
      r3 = r3 + r8;
      r3 = -r3;
      I3 = I2 + M0;
      M[I3, 0] = r3;
      I3 = I1 + M0;
      r3 = r8;
      M[I3, 0] = r3;


      // if (sbr.Fmaster(k+1) - sb < 3)
      //    k = sbr.Nmaster;
      // end;
      r8 = M[$aacdec.sbr_info + $aacdec.SBR_Nmaster];
      r3 = M[($aacdec.sbr_info + $aacdec.SBR_Fmaster) + r6];
      r3 = r3 - r2;
      r3 = r3 - 3;
      if LT r6 = r8;


      // if(sb == (sbr.Kx + sbr.M))
      //    break;
      // end;
      r3 = M[$aacdec.sbr_info + $aacdec.SBR_M];
      r3 = r3 + r5;
      r3 = r3 - r2;
   if NZ jump outer_loop;


   // if ((sbr.patchNoSubbands(sbr.noPatches) < 3) && (sbr.noPatches > 1))
   //    sbr.noPatches = sbr.noPatches - 1;
   // end;
   r7 = r7 - 1;
   if LE jump in_if;
      I3 = I1 + r7;
      r3 = M[I3, 0];
      Null = r3 - 3;
      if LT jump out_if;
         in_if:
         r7 = r7 + 1;

   out_if:

   // sbr.noPatches = min(sbr.noPatches, 5);
   r3 = r7 - 5;
   if GT r7 = r7 - r3;
   M[$aacdec.tmp_mem_pool + $aacdec.SBR_num_patches] = r7;

   rts;



   escape:

      r0 = 0;
      M[$aacdec.tmp_mem_pool + $aacdec.SBR_num_patches] = r0;
      M[$aacdec.tmp_mem_pool + $aacdec.SBR_patch_num_subbands] = r0;
      M[$aacdec.tmp_mem_pool + $aacdec.SBR_patch_start_subband] = r0;
      rts;



.ENDMODULE;

#endif
