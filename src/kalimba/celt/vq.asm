// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifndef CELT_VQ_INCLUDED
#define CELT_VQ_INCLUDED
#include "stack.h"
#include "celt.h"
// *****************************************************************************
// MODULE:
//    $celt.intra_fold
//
// DESCRIPTION:
//    decode current band using previous band
//
// INPUTS:
//  r5 = pointer to decoder structure
//  r2 = number of blocks
//  r1 = start bin
//  I5 = output buffer
//  I3 = buffer containing norm values for previous band
//  r3 = width of the current band
// OUTPUTS:
//
// TRASHED REGISTERS:
//    everything except r5    
// *****************************************************************************
.MODULE $M.celt.intra_fold;
   .CODESEGMENT CELT_INTRA_FOLD_PM;
   .DATASEGMENT DM;
   $celt.intra_fold:         
   $push_rLink_macro;
   
   //for this app B = 1 or 2 , //TODO: add support of 3 and 4 short blocks
   .VAR inv2[] = 1.0, 1.0/2+(1.0e-7), 1.0/3+(1.0e-7), 1.0/4+(1.0e-7), 1.0/5+(1.0e-7), 1.0/6+(1.0e-7), 1.0/7+(1.0e-7), 1.0/8+(1.0e-7);
   r0 = r2 + 1;
   r0 = r0 LSHIFT -1;
   r0 = r0 + r1;
   r4 = M[r2 + (inv2-1)];
   r0 = r0 * r4 (frac);
   r0 = r0 - 1;
   r0 = r0 * r2 (int);  
   r4 = r1 - r0;
   I6 = I5;
   r0 = r4 + r3;
   I2 = I3 + r4; //y
   Null = r0 - r1;
   if GT jump set_z;
   r10 = r3 - 1;
   
   // fold previous band into current band
   r0 = M[I2, 1];
   do fold_loop;
      r0 = M[I2, 1], M[I6, 1] = r0;
   fold_loop:
   M[I6, 1] = r0;
   jump end_fold;
   
   // zero the band
   set_z:
   r10 = r3;
   r0 = 0;
   do z_loop;
      M[I6, 1] = r0;
   z_loop: 
   end_fold:
   
   // folding is done, now renormalise to band energy
   M3 = r3;
   M0 = 1;
   r7 = 1.0;
   call $celt.renormalise_vector;
   jump $pop_rLink_and_rts;

   .ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.renormalise_vector
//
// DESCRIPTION:
//    renormalise a band to a new energy level
//
// INPUTS:
//  I5 = buffer address
//  M3 = width of the current band
//  M0 = strides (1)
//  r7 = value (1.0)
// OUTPUTS:
//
// TRASHED REGISTERS:
//    everything except r5   
// *****************************************************************************
.MODULE $M.celt.renormalise_vector;
   .CODESEGMENT CELT_RENORMALIZE_VECTOR_PM;
   .DATASEGMENT DM;
   $celt.renormalise_vector:
   $push_rLink_macro;   
   rMAC = 0;  //TODO:check if rMAC0 = 1 can be enough
   r0 = 1;
   rMAC0 = r0;
   r10 = M3 - 1;
   I2 = I5;
   r0 = M[I2, M0];
   do calc_e_lp;
      rMAC = rMAC + r0 * r0, r0 = M[I2, M0];      
   calc_e_lp:
   rMAC = rMAC + r0 * r0;
   r8 = signdet rMAC;
   r8 = r8 AND (-2);
   r8 = r8 - 2;
   r0 = rMAC ASHIFT r8;
   $celt.sqrt
   push r1;
   r4 = 1.0;
   Null = r1 - 0.2;
   if NEG jump too_small;
      rMAC = 0.125;
      Div = rMAC / r1;
      r4 = DivResult;
   too_small:
   r1 = r8 + 2;
   r0 = r1 ASHIFT -1;
   r8 = 1 - r0;
   r1 = r4 * r7 (frac);
   r10 = M3 - 1;
   I2 = I5;
   I4 = I5, r4 = M[I2, M0];
   rMAC = r4*r1;
   do re_norm_lp;
      rMAC = rMAC ASHIFT r0 (56bit), r4 = M[I2, M0];
      rMAC = r4*r1, M[I4, M0] = rMAC;
   re_norm_lp:
   rMAC = rMAC ASHIFT r0 (56bit);
   M[I4, M0] = rMAC;
   pop r1;
   r1 = r1 ASHIFT r8;
   jump $pop_rLink_and_rts;
.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.normalise_residual
//
// DESCRIPTION:
//    applies normaling gain to each band
//
// INPUTS:
//  I5 = output buffer address
//  r3 = width of the current band
//  I3 = output buffer address
//  rMAC = sum(inp^2) 
// OUTPUTS:
//
// TRASHED REGISTERS:
//    everything except r5    
// *****************************************************************************
.MODULE $M.celt.normalise_residual;
   .CODESEGMENT CELT_NORMALISE_RESIDUAL_PM;
   .DATASEGMENT DM;
   $celt.normalise_residual:
   $push_rLink_macro;
    
   .VAR temp;
   M[temp] = r3;
   r8 = signdet rMAC;
   r8 = r8 AND 0xFE;
   r8 = r8 - 2;
   r0 = rMAC ASHIFT r8;
   $celt.sqrt
   r0 = 1.0;
   Null = r1 - 0.2;
   if NEG jump too_small;
      rMAC = 0.125;
      Div = rMAC / r1;
      r0 = DivResult;
   too_small:
   r8 = r8 + 2;
   r8 = r8 ASHIFT -1;
   // r8 = shift
   // r0 = gain
   r3 = M[temp];
   r10 = r3 -1;
   I3 = I7;
   r1 = M[I3, 1];
   rMAC = r1 * r0;
   do normalise_residual_loop;
      rMAC = rMAC ASHIFT r8 (56bit),  r1 = M[I3, M0];     
      rMAC = r1 * r0, M[I5, 1] = rMAC;
   normalise_residual_loop:
   rMAC = rMAC ASHIFT r8 (56bit);
   M[I5, 1] = rMAC;     
   jump $pop_rLink_and_rts;
.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $celt.exp_rotation
//
// DESCRIPTION:
//    exp rotation for spreaded bands
//
// INPUTS:
//  I5 = input/output buffer address
//  r3 = width of the current band
//  r6 = amount of stride
//  r7 = dir (1 or -1)
//  r4 = number of pulses
// OUTPUTS:
//
// TRASHED REGISTERS:
//    everything except r5   
// *****************************************************************************
.MODULE $M.celt.exp_rotation;
   .CODESEGMENT CELT_EXP_ROTATION_PM;
   .DATASEGMENT DM;
   $celt.exp_rotation:
   //TODO: can devision, sin and cos calling be opimised?
   .VAR temp[3];
   $push_rLink_macro;
   M[temp + 0] = r3;

   r0 = r6 LSHIFT 3;
   Null = r3 - r0;
   if LE jump no_strike_update;
      rMAC = 0;
      rMAC0 = r3;
      Div = rMAC / r0;
      r0 = DivResult;
      r6 = r6 * r0 (int);
   no_strike_update:
   // calc gain
   rMAC = r3;           
   r0 = r4 * 6 (int);   
   r0 = r0 + r3;       
   r0 = r0 + 3;         
   r0 = r0 + r0;        
   Div = rMAC/r0;       
   r0 = DivResult;      
   r0 = r0 * r0 (frac); 
   r0 = r0 * 0.25(frac); 
   r0 = 0.5 - r0;       
   push I0;
   push L0;
   L0 = 0;
#ifdef BASE_REGISTER_MODE
   push B0;
   push Null;
   pop B0;
#endif
   call $math.sin;
   r8 = r1;            
   r0 = 0.5 - r0;
   call $math.sin;
   //r8 = sin
   //r1 = cos
#ifdef BASE_REGISTER_MODE
   pop B0;
#endif
   pop L0;
   pop I0;
   Null = r7;
   if NEG r8 = -r8;
 
   // 1st rotation loop
   r10 = M[temp + 0];
   r10 = r10 - r6;
   if LE jump end_rot_loop1;
   I3 = I5;       
   I6 = I3 + r6;   
   do exp_rot_lp1;
      r2 = M[I6, 0]; 
      rMAC = r2*r1, r0 = M[I3, 0];
      rMAC = rMAC + r0*r8;
      rMAC = r0*r1, M[I6, 1] = rMAC; 
      rMAC = rMAC - r8*r2;
      M[I3, 1] = rMAC;//, r2 = M[I6, 0];
   exp_rot_lp1:
   end_rot_loop1:
   
   // 2nd rotation loop
   r0 = M[temp + 0];
   r2 = r6 + r6;
   r10 = r0 - r2;
   if LE jump end_rot_loop2;
   r3 = r10 - 1; 
   I3 = I5 + r3;
   I6 = I3 + r6;
   do exp_rot_lp2;
      r2 = M[I6, 0];
      rMAC = r2*r1, r0 = M[I3, 0];
      rMAC = rMAC + r0*r8;
      rMAC = r0*r1, M[I6, -1] = rMAC;
      rMAC = rMAC - r8*r2;
      M[I3, -1] = rMAC;//, r2 = M[I6, 0];
   exp_rot_lp2:
   end_rot_loop2:
   jump $pop_rLink_and_rts;
.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.alg_quant
//
// DESCRIPTION:
//
// INPUTS:
//  r5 = pointer to encoder structure
//  I5 = input buffer
//  r4 = nrof pulses
//  r3 = nr of inputs
//  M0 = spread flag
// OUTPUTS:
//
// TRASHED REGISTERS:
//    everything except r5   
// *****************************************************************************
.MODULE $M.celt.alg_quant;
   .CODESEGMENT CELT_EXP_ROTATION_PM;
   .DATASEGMENT DM;
   $celt.alg_quant:
   $push_rLink_macro;  

   .VAR temp[10];
   // 0 -> nrof pulses
   // 1 -> input buffer
   // 2 -> spread
   // 3 -> nrof inputs
   // 4 -> 1/N
   $celt.get_pulses(r4, r1, get_pulses_lbl1)
   
   rMAC = 1;
   r0 = r3 LSHIFT 15;
   Div = rMAC /r0;
   
   // rotation if required
   M[temp + 0] = r4;
   r0 = I5;
   M[temp + 1] = r0;
   r6 = M0;
   M[temp + 3] = r3;
   r7 = 1;
   r0 = DivResult;
   M[temp + 4] = r0;
   M[temp + 2] = r6;
   if NZ call $celt.exp_rotation;
   r2 = M[r5 + $celt.enc.ALG_QUANT_ST_FIELD];
   I6 = r2;
   r2 = 0;
   M0 = 1;
   r0 = M[temp + 1];
   r10 = M[temp + 3];
   I3 = r0;
   r10 = r10 - M0, r0 = M[I3, M0];
   r3 = 16384;//??4096; //0.00390625;
   r1 = M[r5 + $celt.enc.ABS_NORM_FIELD]; 
   I2 = r1;
   r1 = r0*r3(frac);
   do abs_norm_loop;
      if NEG r1 = -r1, r0 = M[I3, M0];
      r1 = r0*r3(frac), M[I2, M0] = r1;      
      M[I6, M0] = r2;
   abs_norm_loop:
   if NEG r1 = -r1;
   M[I2, M0] = r1;      
   M[I6, M0] = r2;
   
   r0 = M[temp + 0];
   M2 = r0;
   r10 = M[temp + 3];
   M3 = r10;

   r7 = 0;
   r8 = 0;
   r2 = r10 LSHIFT -1;
   Null = r0 - r2;
   if LE jump end_presearch;
      r3 = M[r5 + $celt.enc.ABS_NORM_FIELD];
      I6 = r3;
      r10 = r10 - M0, r1 = M[I6, M0];
      r4 = M[temp + 0];
      r0 = 0;
      do calc_sum_lp;
         r0 = r0 + r1, r1 = M[I6, M0];
      calc_sum_lp:
      I6 = r3;
      r0 = r0 + r1;
      NULL = r0 - M3;
      if POS jump calc_inv;
          // empty or nearly empty band
          r0 = 1<<20;
          r1 = 0, M[I6, M0] = r0;
          r10 = M3 - 1;
          do force_clear_band;
             M[I6, M0] = r1;
          force_clear_band:
          I6 = r3;
      calc_inv:
      r2 = r4 - 1;
      //rMAC = r2 LSHIFT 6;
      rMAC = r2 LSHIFT 5;//??3;
      Div = rMAC /r0;
      r10 = M3;

      r0 = M[r5 + $celt.enc.ALG_QUANT_ST_FIELD];
      I3 = r0;      
      r6 = DivResult;
      do rcp_loop;
         r0 = M[I6, M0];
         r1 = r0 * r6 (frac);
         r1 = r1 LSHIFT -6;//??-4;//r1 = r1 LSHIFT -7;
         r2 = r1 * r1 (int), M[I3, M0] = r1;
         r7 = r7 + r2;
         r2 = r1 * r0(int)(sat);
         r8 = r8 + r2;
         M2 = M2 - r1;
      rcp_loop:
   end_presearch:
   // M2 = pulsesLeft 
   // M3 = N
   // r7 = yy
   // r8 = xy
   // r3 = Rxy
   // r2 = Ryy
   // r6 = best_num
   // r4 = best_den
   // M0 = 1;
   // M1 = best_id
   fine_loop:
      r0 = M2;
      if LE jump end_fine_loop;
      
      r4 = 0;
      r6 = -1.0;
   
      r1 = M[temp + 4];
      r1 = r1 * r0 (int);
      r1 = r1 LSHIFT -9;
      if Z r1 = M0;
      M1 = 0;
      r10 = M3;
      r0 = M[r5 + $celt.enc.ABS_NORM_FIELD];
      I6 = r0;
      r0 = M[r5 + $celt.enc.ALG_QUANT_ST_FIELD];
      I3 = r0; 
      r0 = r1 * r1 (int);
      r7 = r7 + r0, r0 = M[I6, M0];
      do search_fine_loop;
         r0 = r0 * r1(int);
         r3 = r8 + r0, r0 = M[I3, M0];
         r0 = r0 * r1(int);
         r2 = r7 + r0;
         r2 = r2 + r0;
         rMAC = r3 * r3;
         r3 = rMAC ASHIFT 6;
         rMAC = r3*r4;
         rMAC = rMAC - r6 * r2;
         if LE jump b_loop;
            r4 = r2;
            r6 = r3;
            M1 = M3 - r10;
         b_loop:
         r0 = M[I6, M0];
      search_fine_loop:
      r0 = M1;

      r2 = M[r5 + $celt.enc.ABS_NORM_FIELD];
      r3 = M[r0 + r2];
      r3 = r1 * r3 (int);
      r8 = r8 + r3;      
      r2 = M[r5 + $celt.enc.ALG_QUANT_ST_FIELD];
      r3 = M[r0 + r2];
      rMAC = r1 * r3 (int);
      r7 = r7 + rMAC;
      r7 = r7 + rMAC;
      r3 = r3 + r1;
      M[r0 + r2] = r3;
            
   M2 = M2 - r1;
   jump fine_loop;  
   end_fine_loop:
   M[temp + 6] = r7 + r7;
   r0 = M[temp + 1];
   I5 = r0;
   I6 = I5;
   r0 = M[r5 + $celt.enc.ALG_QUANT_ST_FIELD];
   I2 = r0;
   I3 = I2;
   r10 = M3 - M0;
   r10 = r10 - M0, r0 = M[I6, M0];
   r0 = r0, r1 = M[I2, M0];
   if NEG r1 = -r1;
   r0 = M[I6, M0];
   do ap_sign_loop;
      r2 = r1, r1 = M[I2, M0];
      r0 = r0 + Null;
      if NEG r1 = -r1, M[I3, M0] = r2;      
       r0 = M[I6, M0];
   ap_sign_loop:
   r2 = r1, r1 = M[I2, M0];
   r0 = r0 + Null;
   if NEG r1 = -r1, M[I3, M0] = r2; 
   M[I3, M0] = r1;
   r0 = M[r5 + $celt.enc.ALG_QUANT_ST_FIELD];
   I7 = r0;
   r3 = M[temp + 3];
   r4 = M[temp + 0];
   call $celt.encode_pulses;
   
   // normalise residual
   r0 = M[temp + 6];
   rMAC = 0;
   rMAC0 = r0;
   r0 = M[temp + 1];
   I5 = r0;
   r0 = M[r5 + $celt.enc.ALG_QUANT_ST_FIELD];
   I7 = r0;
   r3 = M[temp + 3];
   call $celt.normalise_residual;
   Null = M[temp + 0];
   if Z jump $pop_rLink_and_rts;
   
   // rotation if required
   r6 = M[temp + 2];
   r0 = M[temp + 1];
   I5 = r0;
   r3 = M[temp + 3];
   r4 = M[temp + 0];
   r7 = -1;
   call $celt.exp_rotation;
 
   jump $pop_rLink_and_rts;
.ENDMODULE;
#endif
