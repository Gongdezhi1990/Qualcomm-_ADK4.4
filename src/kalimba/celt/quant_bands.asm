// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifndef CELT_QUANT_BANDS_INCLUDED
#define CELT_QUANT_BANDS_INCLUDED
#include "stack.h"
#include "celt.h"
// *****************************************************************************
// MODULE:
//    $celt.quant_coarse_energy
//
// DESCRIPTION:
//    decode and unquantises coarse energies
//
// INPUTS:
//  r5 = pointer to decoder structure
//
// OUTPUTS:
//   none
//
// TRASHED REGISTERS:
//    everything except r5
// *****************************************************************************
.MODULE $M.celt.quant_coarse_energy;
   .CODESEGMENT CELT_QUANT_COARSE_ENERGY_PM;
   .DATASEGMENT DM;
   $celt.quant_coarse_energy:
   // push rLink onto stack
   $push_rLink_macro;
   .VAR coef;
   .VAR beta;
   .VAR prev[2];
   .VAR temp[3];
   .VAR budget;
   .VAR counter;   
   // reset prev for both channels
   M[prev] = 0;
   M[prev +1] = 0;
   r1 = M[r5 + $celt.enc.MODE_PROB_ADDR_FIELD];
   I7 = r1;
   r2 = M[r5 + $celt.enc.MODE_NB_EBANDS_FIELD];
   M[counter] = r2;
   r0 = M[r5 + $celt.enc.MODE_E_PRED_COEF_FIELD];
   // calc coef
   Null = M[r5 + $celt.enc.INTRA_ENER_FIELD];
   if Z jump intra_end;
      r0 = r2 + r2;
      I7 = I7 + r0;
      r0 = 0;       
   intra_end:
   M[coef] = r0;
   r0 = r0 * 0.8 (frac);
   M[beta] = r0;
   
   // calc budget
   r1 = M[r5 + $celt.enc.CELT_CODEC_FRAME_SIZE_FIELD];
   r1 = r1 LSHIFT 2;
   r1 = r1 - 8; // budget
   M[budget] = r1;
   I2 = &$celt.eMeans;
   r0 = M[r5 + $celt.enc.OLD_EBAND_LEFT_FIELD];
   I3 = r0; 
   I4 = &prev;
   M2 = 0;
   r0 = M[r5 + $celt.enc.LOG_BANDE_FIELD];
   I5 = r0;
   r0 = M[r5 + $celt.enc.BAND_ERROR_FIELD];
   I6 = r0;
   //I2=mean
   //I3=oldEband
   //I4=prev
   //I5=logband
   //I6=error
   //I7=prob
   r4 = 0;
   loop_encode_coarse:
      call run_ch;
      
      r0 = M[r5 + $celt.enc.CELT_CHANNELS_FIELD];
      if Z jump end_ch;
      I2 = I2 - 1;
      I3 = I3 + ($celt.MAX_BANDS-1);
      I4 = I4 + 1;
      I5 = I5 + ($celt.MAX_BANDS-1);
      I6 = I6 + ($celt.MAX_BANDS-1);
      I7 = I7 - 2;
      call run_ch;
      I3 = I3 - $celt.MAX_BANDS;
      I4 = I4 - 1;
      I5 = I5 - $celt.MAX_BANDS;
      I6 = I6 - $celt.MAX_BANDS;
      end_ch:
      r0 = M[counter];
      r0 = r0 - 1;
      M[counter] = r0;
   if NZ jump loop_encode_coarse;
 
   // pop rLink from stack
   jump $pop_rLink_and_rts;
   run_ch:
      $push_rLink_macro;
      M[temp + 1] = Null;
      call $celt.ec_enc_tell;    
      Null = r0 - M[budget];      
      if LE jump calc_q;
         r1 = -1;
         r2 = 1.0;
         jump set_error;
      calc_q:
      r0 = M[I2, 1];
      Null = I2 - (&$celt.eMeans + $celt.E_MEANS_SIZE);
      if GT r0 = r0 - r0;  //r1=eBand=x     
      M[temp + 1] = r0;
      r7 = M[coef];      
      r2 = r7*r0(frac);
      r2 = r2 - r0, r1 = M[I5, 1];        //r0 =oldBand, r2 = -mean
      r1 = r1 + r2, r0 = M[I3, 0];
      r0 = r0*r7(frac), r3 = M[I4, 0];
      r1 = r1 - r0, r2 = M[I7, 1];
      r1 = r1 - r3, r3 = M[I7, 1];
      M[temp + 0] = r1;
      r1 = r1*128(frac);
      call $celt.ec_laplace_encode_start;
      r2 = r1*(-1.0/128.0)(int);
      r2 = r2 + M[temp + 0];      
      set_error:
      M[I6, 1] = r2;
      r1 = r1 ASHIFT 16;
      r0 = M[temp + 1];
      r4 = M[I4, 0];                            //r4 = p
      r4 = r4 + r0, r2 = M[I3, 0];              //r4 = m+ p, r2 =b
      r4 = r4 + r1;                             //r4 = m+p+q
      r7 = M[coef];                             //r7 = c
      r3 = r2 - r0;                             //r3 = b -m
      r3 = r3 * r7 (frac);                      //r3 = (b-m)*c
      r3 = r3 + r4;                             //r3 -->b
      rMAC = r0*r7;
      r0 = M[beta];
      rMAC = rMAC + r1*r0, M[I3, 1] = r3;       //save C-Energy
      r4 = r4 - rMAC;
      r4 = 0, M[I4, 0] = r4;                    //save prev
      jump $pop_rLink_and_rts;
.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.quant_fine_energy
//
// DESCRIPTION:
//
// INPUTS:
//  r5 = pointer to decoder structure
//
// OUTPUTS:
//   none
//
// TRASHED REGISTERS:
//    everything except r5
// *****************************************************************************
.MODULE $M.celt.quant_fine_energy;
   .CODESEGMENT CELT_QUANT_FINE_ENERGY_PM;
   .DATASEGMENT DM;
   $celt.quant_fine_energy:
   // push rLink onto stack
   $push_rLink_macro;
   r0 = M[r5 + $celt.enc.MODE_NB_EBANDS_FIELD];
   M3 = r0;
   r0 = M[r5 + $celt.enc.FINE_QUANT_FIELD];
   I2 = r0;
   r0 = M[r5 + $celt.enc.OLD_EBAND_LEFT_FIELD];
   I3 = r0;
   M0 = 1;
   r0 = M[r5 + $celt.enc.CELT_CHANNELS_FIELD];
   I6 = r0;
   r0 = M[r5 + $celt.enc.BAND_ERROR_FIELD];
   I5 = r0 - 1;
   fine_quant_loop:
      r2 = M[I2, 1], r0 = M[I5, 1];
      M[$celt.enc.ec_enc.ftb] = r2 - Null;
      if LE jump b_loop;
      push r2;
      call run_ch;
      pop r2;
      r0 = M[r5 + $celt.enc.CELT_CHANNELS_FIELD];
      if Z jump end_ch;
      I3 = I3 + ($celt.MAX_BANDS);
      I5 = I5 + ($celt.MAX_BANDS);
      call run_ch;
      I3 = I3 - ($celt.MAX_BANDS);
      I5 = I5 - ($celt.MAX_BANDS);
      end_ch:         
      b_loop:
      M3 = M3 - M0, r0 = M[I3, 1];
   if NZ jump fine_quant_loop;
   
   // pop rLink from stack
   jump $pop_rLink_and_rts;
   run_ch:
   $push_rLink_macro;
   r0 = M[I5, 0];
   r0 = r0 + 0x8000; //TODO:make sure sat avoided
   r1 = r2 - 16;
   r0 = r0 ASHIFT r1;
   r1 = 1 LSHIFT r2;
   r1 = r1 - 1;
   Null = r0 - r1;
   if POS r0 = r1;
   M[$celt.enc.ec_enc.fl + 0] = r0;
   M[$celt.enc.ec_enc.fl + 1] = Null;
   r1 = r0 + r0;
   r1 = r1 + 1;
   r2 = 15 - r2;
   r1 = r1 ASHIFT r2, r0 = M[I3, 0];
   r1 = r1 - 0x8000; 
   r0 = r0 + r1, r2 = M[I5, 0];
   r2 = r2 - r1, M[I3, 0] = r0;
   M[I5, 0] = r2;
   call $celt.ec_enc_bits;
   // pop rLink from stack
   jump $pop_rLink_and_rts;  

.ENDMODULE;


// *****************************************************************************
// MODULE:
//    $celt.quant_energy_finalise
//
// DESCRIPTION:
//
// INPUTS:
//  r5 = pointer to encoder structure
// OUTPUTS:
//
// TRASHED REGISTERS:
//    everything except r5    
// *****************************************************************************
.MODULE $M.celt.quant_energy_finalise;
   .CODESEGMENT CELT_QUANT_ENERGY_FINALISE_PM;
   .DATASEGMENT DM;
   $celt.quant_energy_finalise: 
   // push rLink onto stack
   $push_rLink_macro;
   
   // work out bits left
   r4 = 0;
   call $celt.ec_enc_tell;
   r1 = M[r5 + $celt.enc.CELT_CODEC_FRAME_SIZE_FIELD];
   r1 = r1 * 8(int);
   M2 = r1 - r0;
   
   // mono/stereo 
   r0 = M[r5 + $celt.enc.CELT_CHANNELS_FIELD];
   I6 = r0;
   M3 = 1;
   prio_loop:
      r10 = M[r5 + $celt.enc.MODE_NB_EBANDS_FIELD];
      r0 = M[r5 + $celt.enc.FINE_QUANT_FIELD];
      I2 = r0;
      r0 = M[r5 + $celt.enc.OLD_EBAND_LEFT_FIELD];
      I3 = r0;
      I4 = r0 + $celt.MAX_BANDS;
      r0 = M[r5 + $celt.enc.FINE_PRIORITY_FIELD];
      I5 = r0;
      r0 = M[r5 + $celt.enc.BAND_ERROR_FIELD];
      I7 = r0;
      do finalise_loop;
         r0 = M[r5 + $celt.enc.CELT_CHANNELS_FIELD];
         Null = M2 - r0;
         if LE jump end_finalise_loop;
         r0 = M[I2, 0], r1 = M[I5, 0];
         Null = r0 - 7;
         if POS jump next_fin;
         Null = r1 - M3;
         if Z jump next_fin;
            r2 = 1;
            M[$celt.enc.ec_enc.ftb] = r2;
            r1 = M[I7, 0];
            Null = r1;
            if NEG r2 = 0;
            M[$celt.enc.ec_enc.fl + 0] = r2;
            M[$celt.enc.ec_enc.fl + 1] = Null;
            call $celt.ec_enc_bits;
            //calc offset
            r0 = M[I7, 0];
            r0 = r0 + r0, r2 = M[I2, 0];
            r0 = r0 - 1;
            r2 = 14 - r2;
            r0 = r0 ASHIFT r2, r1 = M[I3, 0];
            r0 = r0 + r1;
            M2 = M2 -1;
            Null = I6, M[I3, 0] = r0;
            if Z jump next_fin;
            I7 = I7 + $celt.MAX_BANDS;
            r1 = M[I7, 0];
            M[$celt.enc.ec_enc.fl + 0] = r1;
            M[$celt.enc.ec_enc.fl + 1] = Null;
            call $celt.ec_enc_bits;
            r0 = M[I7, 0];
            r0 = r0 + r0, r2 = M[I2, 0];
            r0 = r0 - 1;
            r2 = 14 - r2;
            r0 = r0 ASHIFT r2, r1 = M[I4, 0];
            r0 = r0 + r1;
            M[I4, 0] = r0;
            M2 = M2 -1;
            I7 = I7 - $celt.MAX_BANDS;
            next_fin:
            r0 = M[I2, 1], r1 = M[I5, 1];
            r0 = M[I3, 1], r1 = M[I7, 1];
            r1 = M[I4, 1]; 
        finalise_loop:
        end_finalise_loop:
   M3 = M3 - 1;
   if Z jump prio_loop;

   // calculate non-logarithmic bands Energies
   r0 = M[r5 + $celt.enc.OLD_EBAND_LEFT_FIELD];
   I3 = r0;
   r0 = M[r5 + $celt.enc.BANDE_FIELD];
   I2 = r0;
   I4 = I2 + $celt.MAX_BANDS;
   r0 = M[r5 + $celt.enc.CELT_CHANNELS_FIELD];
   M3 = r0 + 1;
   r8 = M[r5 + $celt.enc.CELT_MODE_OBJECT_FIELD];
   calc_ebands:
   r10 = M[r5 + $celt.enc.MODE_NB_EBANDS_FIELD];
   do comp_ebands_loop_ch;
      r0 = M[I3, 0];
      r4 = 0;
      r1 = r0 ASHIFT -16;
      if NEG jump calc_log;
         r4 = r1 + 1;
         r1 = r4 ASHIFT 16;
         r0 = r0 - r1;
      calc_log:
      call $math.pow2_table;
      r4 = r4 - 12;
      // store E in the form of a gain and a shift value
      M[I4, 1] = r4; 
      M[I2, 1] = r0;

      // minimum energy clipping
      r0 = M[I3, 0];
      r1 = r0 + 0.0546875;
      if NEG r0 = r0 - r1;
      M[I3, 1] = r0;
   comp_ebands_loop_ch:
   r0 = M[r5 + $celt.enc.OLD_EBAND_LEFT_FIELD];
   I3 = r0 + $celt.MAX_BANDS;
   r0 = M[r5 + $celt.enc.BANDE_FIELD];
   I2 = r0 + (2*$celt.MAX_BANDS);
   I4 = I2 + $celt.MAX_BANDS;
   M3 = M3 - 1;
   if NZ jump calc_ebands;
 
   // pop rLink from stack
   jump $pop_rLink_and_rts;
.ENDMODULE;

#endif

