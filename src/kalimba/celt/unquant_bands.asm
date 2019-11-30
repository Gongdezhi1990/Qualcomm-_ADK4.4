//  *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifndef CELT_UNQUANT_BANDS_INCLUDED
#define CELT_UNQUANT_BANDS_INCLUDED
#include "stack.h"
#include "celt.h"
// *****************************************************************************
// MODULE:
//    $celt.unquant_coarse_energy
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
.MODULE $M.celt.unquant_coarse_energy;
   .CODESEGMENT CELT_UNQUANT_COARSE_ENERGY_PM;
   .DATASEGMENT DM;

   $celt.unquant_coarse_energy:
   // push rLink onto stack
   $push_rLink_macro;
   
   .VAR coef;
   .VAR beta;
   .VAR prev[2];
   .VAR ch;
   // calc budget
   r1 = M[r5 + $celt.dec.CELT_CODEC_FRAME_SIZE_FIELD];
   r1 = r1 LSHIFT 2;
   I5 = r1 - 8; // I5:budget
   
   // reset prev for both channels
   M[prev] = 0;
   M[prev +1] = 0;
   
   r1 = M[r5 + $celt.dec.MODE_PROB_ADDR_FIELD];
   I2 = r1;
   r0 = M[r5 + $celt.dec.MODE_NB_EBANDS_FIELD];
   I6 = r0;
   r0 = M[r5 + $celt.dec.MODE_E_PRED_COEF_FIELD];
   // calc coef
   Null = M[r5 + $celt.dec.INTRA_ENER_FIELD];
   if Z jump intra_end;
      r0 = I6 + I6;
      I2 = I2 + r0;
      r0 = 0;       
   intra_end:
   M[coef] = r0;
   r0 = r0 * 0.8 (frac);
   M[beta] = r0;
   r0 = M[r5 + $celt.dec.TEMP_VECT_FIELD];
   I4 = r0;
   M3 = 1;
   get_q_loop:
      r4 = 0;
      call $celt.ec_dec_tell;
      r1 = -M3, r2 = M[I2, M3];
      Null = r0 - I5, r3 = M[I2, M3];
      if LE call $celt.ec_laplace_decode_start;
      NULL = M[r5 + $celt.dec.CELT_CHANNELS_FIELD];      
      if Z jump ch_end_loop;
         I2 = I2 - 2;
         r4 = 0, M[I4, 1] = r1;
         call $celt.ec_dec_tell;
         r1 = -M3, r2 = M[I2, M3];
         Null = r0 - I5, r3 = M[I2, M3];
         if LE call $celt.ec_laplace_decode_start;
      ch_end_loop:
      I6 = I6 - M3, M[I4, M3] = r1;
   if NZ jump get_q_loop; 
   
   M2 = 0;
   I2 = &$celt.eMeans;
   r0 = M[r5 + $celt.dec.OLD_EBAND_LEFT_FIELD];
   I3 = r0; 
   I4 = &prev;
   r0 = M[r5 + $celt.dec.TEMP_VECT_FIELD];
   I5 = r0;
   r0 = M[r5 + $celt.dec.CELT_CHANNELS_FIELD];
   M3 = r0 + 1;
   M0 = 1;
   r8 = 16;
   r7 = M[coef];
   I7 = &beta;
   r0 = M[r5 + $celt.dec.CELT_CHANNELS_FIELD];
   I6 = r0;
   /* Decode at a fixed coarse resolution */
   loop_decode_coarse:
      r10 = M[r5 + $celt.dec.MODE_NB_EBANDS_FIELD];
      do coarse_loop;
         r1 = M[I5, M3], r0 = M[I2, M0];      
         r1 = r1 ASHIFT r8, r4 = M[I4, 0];                                      
         r4 = r4 + r0, r2 = M[I3, 0];              //r4 = m+ p, r2 =b
         r4 = r4 + r1;                             //r4 = m+p+q
         r3 = r2 - r0;                             //r3 = b -m
         r3 = r3 * r7 (frac);                      //r3 = (b-m)*c
         r3 = r3 + r4;                             //r3 -->b
         rMAC = r0*r7, r0 = M[I7, 0];
         rMAC = rMAC + r1*r0, M[I3, 1] = r3;       //save C-Energy
         r4 = r4 - rMAC;
         M[I4, 0] = r4;                            //save prev
      coarse_loop:         
      I6 = I6 - 1;
   if NEG  jump $pop_rLink_and_rts;
   I2 = &$celt.eMeans;
   r0 = M[r5 + $celt.dec.OLD_EBAND_LEFT_FIELD];
   I3 = r0 + $celt.MAX_BANDS; 
   I4 = &prev + 1;
   r0 = M[r5 + $celt.dec.TEMP_VECT_FIELD];
   I5 = r0 + 1;
   jump loop_decode_coarse;
.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.unquant_fine_energy
//
// DESCRIPTION:
//    decode fine energy bits
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
.MODULE $M.celt.unquant_fine_energy;
   .CODESEGMENT CELT_UNQUANT_FINE_ENERGY_PM;
   .DATASEGMENT DM;

   $celt.unquant_fine_energy:
   
   // push rLink onto stack
   $push_rLink_macro;
   
   r0 = M[r5 + $celt.dec.MODE_NB_EBANDS_FIELD];
   M3 = r0;
   r0 = M[r5 + $celt.dec.FINE_QUANT_FIELD];
   I2 = r0;
   r0 = M[r5 + $celt.dec.OLD_EBAND_LEFT_FIELD];
   I3 = r0;
   I4 = r0 + $celt.MAX_BANDS;
   M0 = 1;
   r0 = M[r5 + $celt.dec.CELT_CHANNELS_FIELD];
   I6 = r0;
   fine_unquant_loop:
      r2 = M[I2, 1];
      M[$celt.dec.ec_dec.ftb] = r2 - Null;
      if LE jump b_loop;
         call $celt.ec_dec_bits;
         r1 = r0 + r0;
         r1 = r1 + 1;
         r2 = M[$celt.dec.ec_dec.ftb];
         r2 = 15 - r2;
         r1 = r1 ASHIFT r2, r0 = M[I3, 0];
         r1 = r1 - 0x8000; 
         r0 = r0 + r1;
         Null = I6, M[I3, 0] = r0;
         if Z jump b_loop;
            call $celt.ec_dec_bits;
            r1 = r0 + r0;
            r1 = r1 + 1;
            r2 = M[$celt.dec.ec_dec.ftb];
            r2 = 15 - r2;
            r1 = r1 ASHIFT r2;
            r1 = r1 - M0, r0 = M[I4, 0];
            r1 = r1 - 0x8000; 
            r0 = r0 + r1;
            M[I4, 0] = r0;                  
      b_loop:
      M3 = M3 - M0, r0 = M[I4, 1], r1 = M[I3, 1];
   if NZ jump fine_unquant_loop;

   // pop rLink from stack
   jump $pop_rLink_and_rts;
.ENDMODULE;

#if defined(KAL_ARCH3) || defined(KAL_ARCH5)
// *****************************************************************************
// MODULE:
//    $celt.quant_bands
//
// DESCRIPTION:
//    decode and dequantise residual bits
//
// INPUTS:
//  r5 = pointer to decoder structure
//  r0 = 0 ->decoder
//       1 ->encoder
// OUTPUTS:
//   none
//
// TRASHED REGISTERS:
//    everything except r5   
// *****************************************************************************
.MODULE $M.celt.quant_bands;
   .CODESEGMENT CELT_QUANT_BANDS_PM;
   .DATASEGMENT DM;
   $celt.quant_bands: 
   $celt.unquant_bands:
   .CONST CUR_B      1;
   .CONST BAL        2;
   .CONST STACK_USED 3;
   
   // push rLink onto stack
   $push_rLink_macro;
   
   // save the frame pointer and reserve stack space here before the loop starts
   pushm<FP(=SP)>; 
   SP = SP + STACK_USED; 
   
   r0 = M[r5 + $celt.dec.MODE_NB_EBANDS_FIELD];
   M3 = r0;
   I7 = M3;
   //calc nr of Blocks
   r3 = M[r5 + $celt.dec.MODE_NB_SHORT_MDCTS_FIELD];
   r2 = 1;
   Null = M[r5 + $celt.dec.SHORT_BLOCKS_FIELD];
   if NZ r2 = r3; 
   //M[$curB] = r2;
   M[FP + CUR_B] = r2; 
   r1 = 0; 
   M[FP + BAL] = r1;
   
   r1 = M[r5 + $celt.dec.CELT_CODEC_FRAME_SIZE_FIELD];
   r1 = r1 LSHIFT (3+$celt.BITRES);
   I6 = r1; //total bits in the frame (fractional)
   r0 = M[r5 + $celt.dec.PULSES_FIELD];
   I3 = r0;
   r0 = M[r5 + $celt.dec.MODE_EBANDS_ADDR_FIELD];
   I2 = r0;
   quant_bands_main_loop:
      // get bit used so far
      r4 = $celt.BITRES;
      r0 = M[r5 + $celt.dec.TELL_FUNC_FIELD];
      call r0;
      //call $celt.ec_dec_tell;
      
      // update balance
      r1 = M[FP + BAL];
      r2 = I7 - M3;
      if Z r1 = r0;
      M[FP + BAL] = r1;
      r1 = r1 - r0;
      
      // update remaining bits
      I5 = I6 - r0;
      I5 = I5 - 1;
 
      //curr_balance = balance / curr_balance;
      r3 = 1;
      Null = r1;
      if NEG r3 = - r3;
      r1 = r1 * r3(int);
      Null  =   M3 - 3; //TODO:BC7OPT-max
      if NEG jump chk_2;
         r1 = r1 -1;
         r1 = r1 * (1.0/3.0)(frac);
         jump end_cur_calc;
      chk_2:
      Null = M3 - 2;
      if NZ jump end_cur_calc;
         r1 = r1 ASHIFT -1;
      end_cur_calc:
      r1 = r1 * r3(int);
      
      //calc number of pulses for this band (n)
      r0 = M[r5 + $celt.dec.PULSES_FIELD];
      r3 = r0 + I7;
      r3 = r3 - M3;
      r0 = M[FP + BAL];
      r3 = M[r3];
      push r3;
      r3 = r0 + r3; 
      M[FP + BAL] = r3;
      pop r3; 
      r1 = r1 + r3;
      call $celt.bits2pulses;
      //r0 = n
      r2 = M[r4 + r0];
      I5 = I5 - r2;
      loop_rem_bits:
         Null = I5;
         if POS jump end_loop_rem_bits;
         Null = r0 - Null;
         if LE jump end_loop_rem_bits;
            I5 = I5 + r2;
            r0 = r0 - 1;
            r2 = M[r4 + r0];
            I5 = I5 - r2;
         jump loop_rem_bits;
      end_loop_rem_bits:
     
      // save some registers into stack

      push r5; 
      pushm<I2, I5, I6, I7, M3>;
  
      r2 = M[FP + CUR_B];
      r1 = M[I2, 1];                
      r3 = M[I2, -1];
      r3 = r3 - r1;      
      r4 = M[r5 + $celt.dec.NORM_FREQ_FIELD];
      I5 = r4 + r1;//X+eBands[i]
      // I5 = start of band
      // r0 = number of pulses
      // r1 = start bin no
      // r3 = band width
      // r2 = nr of Blocks
      r4 = r0 - Null;
      if LE jump intra_act;
         //calc spread
         M0 = r2;                 
         Null = M[r5 + $celt.dec.HAS_FOLD_FIELD];
         if Z M0 = M0 - M0;      
         //call  $celt.alg_unquant;
         r0 = M[r5 + $celt.dec.ALG_QUANT_FUNC_FIELD];
         call r0;
         jump end_act;
      intra_act:
         r0 = M[r5 + $celt.dec.NORM_FIELD];
         I3 = r0;
         call $celt.intra_fold;
      end_act:
      
      // restore trashed register
       popm<I2, I5, I6, I7, M3>;
       pop r5; 
   
      // get start and end of band (again!)
      r1 = M[I2, 1];                
      r3 = M[I2, 0];
   
      // calc norm for next folded band
      // calc only when needed!
      r0 = M[r5 + $celt.dec.MODE_NB_EBANDS_FIELD];
      r0 = r0 - M3;
      r2 = M[r5 + $celt.dec.MODE_EBNADS_DIF_SQRT_ADDR_FIELD];
      r4 = M[r2 + 0]; //shift
      r2 = r2 + 1;
      r6 = M[r2 + r0]; //gain
      r10 = r3 - r1;
      r10 = r10 - 1;
      r0 = M[r5 + $celt.dec.NORM_FIELD];
      I3  = r1 + r0;
      r0 = M[r5 + $celt.dec.NORM_FREQ_FIELD];
      I4  = r0 + r1;
      r0 = M[I4, 1];
      rMAC = r0 * r6; //6 bit less than c TODO:
      do norm_loop;
         rMAC = rMAC ASHIFT r4 (56bit), r0 = M[I4, 1];
         rMAC = r0 * r6, M[I3, 1] = rMAC;      
      norm_loop:
      rMAC = rMAC ASHIFT r4 (56bit);
      M[I3, 1] = rMAC;
   
      M3 = M3 - 1;
   if NZ jump quant_bands_main_loop;
   
   // restore the stack pointer
   SP = SP - STACK_USED; 
   popm<FP>;
  
   // pop rLink from stack
   jump $pop_rLink_and_rts;
.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $celt.unquant_bands_stereo
//
// DESCRIPTION:
//    decode and dequantise residual bits
//
// INPUTS:
//  r5 = pointer to decoder structure
//  r0 = 0 ->decoder
//       1 ->encoder
// OUTPUTS:
//   none
//
// TRASHED REGISTERS:
//    everything except r5   
// NOTE:
//   this function needs to be optimised for code size
// *****************************************************************************
.MODULE $M.celt.unquant_bands_stereo;
   .CODESEGMENT CELT_QUANT_BANDS_STEREO_PM;
   .DATASEGMENT DM;
   
   // -- entry point for unquant(decoder)
   $celt.unquant_bands_stereo:
   .VAR codec;
   r0 = $celt.CELT_DECODER;
   jump set_codec;
   
   // -- entry point for quant (encoder)
   $celt.quant_bands_stereo:
   r0 = $celt.CELT_ENCODER;
   set_codec:
   M[codec] = r0;
 
   .CONST RM_BITS          1; // remaining bits
   .CONST TOTOAL_BITS      2; // total bits in the frame
   .CONST NB_EBAND         3; // NB of EBANDS 
   .CONST ADDR_EBAND       4; // address of Ebands
   .CONST NB_EBAND_RM      5; // NB of EBANDS left to process
   .CONST CODEC_STRUC      6; 
   .CONST N_BAND           7;  // number of bands
   .CONST S_BAND           8;  // start band
   .CONST QALLOC           9;
   .CONST IMID             10;
   .CONST ISIDE            11;
   .CONST DELTA            12;
   .CONST ITHETA           13;
   .CONST VB               14;
   .CONST Q1               15;
   .CONST Q2               16;
   .CONST MBITS            17;
   .CONST SBITS            18;
   .CONST CUR_B            19; 
   .CONST BAL              20;
   .CONST QB               21;
   .CONST STACK_USED       22; 
   

   // push rLink onto stack
   $push_rLink_macro;
   
   // save the frame pointer and reserve stack space here before the loop starts
   pushm<FP(=SP)>; 
   SP = SP + STACK_USED; 
   
   r0 = M[r5 + $celt.dec.MODE_NB_EBANDS_FIELD];
   M3 = r0;
   I7 = M3;

   //calc nr of Blocks
   r3 = M[r5 + $celt.dec.MODE_NB_SHORT_MDCTS_FIELD];
   r2 = 1;
   Null = M[r5 + $celt.dec.SHORT_BLOCKS_FIELD];
   if NZ r2 = r3; 
   M[FP + CUR_B] = r2;
   r1 = 0;
   M[FP + BAL] = r1;
   r1 = M[r5 + $celt.dec.CELT_CODEC_FRAME_SIZE_FIELD];
   r1 = r1 LSHIFT (3+$celt.BITRES);
   I6 = r1; //total bits in the frame (fractional)
   r0 = M[r5 + $celt.dec.PULSES_FIELD];
   I3 = r0;
   r0 = M[r5 + $celt.dec.MODE_EBANDS_ADDR_FIELD];
   I2 = r0;
   

   
quant_bands_main_loop:

      // get bit used so far
      r4 = $celt.BITRES;
      r0 = M[r5 + $celt.dec.TELL_FUNC_FIELD];
      call r0; 

      // update balance
      r1 = M[FP + BAL];
      r2 = I7 - M3;
      if Z r1 = r0;
      M[FP + BAL] = r1;
      r1 = r1 - r0;

      // update remaining bits
      I5 = I6 - r0;
      I5 = I5 - 1;
 
      //curr_balance = balance / curr_balance;
      r3 = 1;
      Null = r1;
      if NEG r3 = - r3;
      r1 = r1 * r3(int);
      Null  =   M3 - 3; //TODO:BC7OPT-max
      if NEG jump chk_2;
         r1 = r1 -1;
         r1 = r1 * (1.0/3.0)(frac);
         jump end_cur_calc;
      chk_2:
      Null = M3 - 2;
      if NZ jump end_cur_calc;
         r1 = r1 ASHIFT -1;
      end_cur_calc:
      r1 = r1 * r3(int);
      
      r0 = M[I2, 1]; 
      M[FP + S_BAND] = r0;
      r3 = M[I2, 0];
      r0 = r3 - r0;
      rMAC = 0;
      rMAC0 = r0;
      M[FP + N_BAND] = r0;
            
      //calc number of pulses for this band (n)
      r0 = M[r5 + $celt.dec.PULSES_FIELD];
      r3 = r0 + I7;
      r3 = r3 - M3;
      r0 = M[FP + BAL];
      r3 = M[r3];
      r0 = r0 + r3; 
      M[FP + BAL] = r0;
      
      r8 = I5 + 1;
      r1 = r1 + r3;
      if NEG r1 = 0;
      Null = r8 - r1;
      if POS r8 = r1;
      M[FP + VB] = r8;
      
      r0 = $celt.BITRES;
      call $celt.log2_frac;
      r0 = $celt.QTHETA_OFFSET - r0;
      r1 = M[FP + N_BAND];
      r2 = r1 - 1;
      r1 = r2 + r2;
      r1 = r1 * r0(int);
      r1 = r8 - r1;
      if NEG r1 = 0;
      
      r2 = r2 LSHIFT 5;
      rMAC = 0;
      rMAC0 = r1;
      Div = rMAC / r2;
      r7 = r8 LSHIFT (-$celt.BITRES);
      r7 = r7 - 1;
      if NEG r7 = 0;
      r0 = DivResult;
      Null = r0 - r7;
      if POS r0 = r7;
      r1 = r0 - 14;
      if POS r0 = r0 - r1;
      M[FP + QB] = r0;
      r1 = 1 LSHIFT r0;
      r1 = r1 + 1;
      rMAC = 0;
      rMAC0 = r1;
      r0 = $celt.BITRES;
      call $celt.log2_frac;
      M[FP + QALLOC] = r0;

      // -- save some registers

      // to guaranteen we will always have the same push sequence for different chips, avoid using "pushm" here
      // I5, I6, I7, I2, M3, r5 
      r3 = I5;
      M[FP + RM_BITS] = r3; 
      r3 = I6;
      M[FP + TOTOAL_BITS] = r3; 
      r3 = I7;
      M[FP + NB_EBAND] = r3; 
      r3 = I2;
      M[FP + ADDR_EBAND] = r3; 
      r3 = M3;
      M[FP + NB_EBAND_RM] = r3; 
      M[FP + CODEC_STRUC] = r5; 

      // -- stereo processing required for encode
      Null = M[codec];
      if Z jump is_dec1;
      is_enc1:
         Null = M[FP + QB];
         if NZ jump end_calc_st_coeff;
         
            // -- calc mid/side coeffs
            r2 = I7 - M3;
            r2 = r2 + r2;
            r0 = M[r5 + $celt.enc.BANDE_FIELD];
            I4 = r0 + r2;
            r3 = M[I4, 1];
            r4 = M[I4, 1];
             
            I4 = I4 + ($celt.MAX_BANDS*2);
            r0 = M[I4, 1];
            r1 = M[I4, 1];
            r2 = r4 - r1;
            if POS r2 = 0;
            r1 = r1 - r4;
            if POS r1 = 0;
            r0 = r0 ASHIFT r1;
            r3 = r3 ASHIFT r2;
            push r0;
            push r3;
            rMAC = r0 * r0;
            rMAC = rMAC + r3 * r3;
            r0 = rMAC;
            $celt.sqrt
            pop r4;
            pop r2;
            r3 = r1;
            if Z jump end_calc_st_coeff;
            rMAC = r2 ASHIFT -1;
            Div = rMAC / r3;
            r0 = DivResult;
            rMAC = r4 ASHIFT -1;
            Div = rMAC / r3;
            r1 = DivResult;
            r1 = -r1;
            jump st_mix_enc;
         end_calc_st_coeff:
         r0 = -0.707106781186548;
         r1 = 0.707106781186548;
         st_mix_enc:
         
         // -- ms stereo per band
         r3 = M[FP + S_BAND];                
         r10 = M[FP + N_BAND];
         r10 = r10 - 1;
         r2 = M[r5 + $celt.dec.NORM_FREQ_FIELD];
         I3  = r3 + r2; 
         r4 = M[r5 +  $celt.dec.MODE_MDCT_SIZE_FIELD];
         I4 = I3 + r4;
         I6 = I3;
         I7 = I4;
         r2 = M[I3, 1], r3 = M[I4, 1]; 
         r0 = r0 * 0.707106781186548;
         r1 = r1 * 0.707106781186548;
         
         rMAC = r3 * r1;
         do mid_side_loop0;
            rMAC = rMAC - r2 * r0; 
            rMAC = r3 * r1, M[I6, 1] = rMAC; 
            rMAC = rMAC + r2 * r0, r2 = M[I3, 1], r3 = M[I4, 1];
            rMAC = r3 * r1, M[I7, 1] = rMAC; 
         mid_side_loop0:
         rMAC = rMAC - r2 * r0; 
         rMAC = r3 * r1, M[I6, 1] = rMAC; 
         rMAC = rMAC + r2 * r0;
         M[I7, 1] = rMAC;
        
         // -- renormalise left band
         r3= M[FP + N_BAND];
         M3 = r3;
         r1 = M[FP + S_BAND]; 
         r0 = M[r5 + $celt.dec.NORM_FREQ_FIELD];
         I5  = r1 + r0; 
         M0 = 1;
         r7 = 1.0;
         call $celt.renormalise_vector;
         push r1;
         
         // -- renormalise right band         
         r3 = M[FP + N_BAND];
         M3 = r3;
         r1 = M[FP + S_BAND]; 
         r0 = M[r5 + $celt.dec.NORM_FREQ_FIELD];
         I5  = r1 + r0; 
         r4 = M[r5 +  $celt.dec.MODE_MDCT_SIZE_FIELD];
         I5 = I5 + r4;
         M0 = 1;
         r7 = 1.0;
         call $celt.renormalise_vector;
         
         // -- calc atan(E_L/E_R)
         r6 = r1;
         pop r1;
         r0 = M[FP + QB];
         if Z jump qb_z;
         push r5;

         // some optimisation
         r5 = 0;
         NULL = r1 OR r6;
         if Z jump calc_lr_ratio;
         r5 = 0.25;
         Null = r1 - r6;
         if Z jump calc_lr_ratio;
         // now calc E_L/E_R
         r5 = r1;
         call $math.atan;
         calc_lr_ratio:
            r3 = r5 * 0.003906251396735(frac);
         pop r5;
         r0 = M[FP + QB];
         if Z jump qb_z;
         r1 = r0 - 14;
         r2 = -r1;
         r1 = 1.0 ASHIFT r1;
         r3 = r3 * r1(frac);
         r2 = r3 ASHIFT r2;
         M[FP + ITHETA] = r2;
         r0 = 1 ASHIFT r0;
         r0 = r0 + 1;         
         M[$celt.enc.ec_enc.ft + 0] = r0;
         M[$celt.enc.ec_enc.ft + 1] = Null;
         M[$celt.enc.ec_enc.fl + 0] = r3;
         M[$celt.enc.ec_enc.fl + 1] = Null;
         r2 = M[r5 + $celt.dec.EC_UINT_FUNC_FIELD];
         call r2;
         r0 = M[FP + ITHETA];
         jump test_itheta;    
      is_dec1:
      r0 = M[FP + QB];
      if NZ jump nzqb_dec;
      qb_z:
         r0 = 0;
         M[FP + ITHETA] = r0;
      is_ztheta:
         r0 = 32767;     //mid
         r1 = 0;         //side
         r2 = -10000;    //delta
      jump set_st;
      nzqb_dec:
         r0 = M[FP + QB];
         r1 = 14 - r0;
         push r1;
         r1 = 1 LSHIFT r0;
         r0 = r1 + 1;
         r1 = 0;
         r2 = M[r5 + $celt.dec.EC_UINT_FUNC_FIELD];
         call r2;
         pop r1;
         r0 = r0 LSHIFT r1;
         M[FP + ITHETA]  = r0;
         test_itheta:
         if Z jump is_ztheta;
         Null = r0 - 16384;
         if NZ jump calc_ims;
             r0 = 0;     //mid
             r1 = 32767; //side
             r2 = 10000; //delta
          set_st:
             M[FP + IMID] = r0;
             M[FP + ISIDE] = r1;
             M[FP + DELTA] = r2;
         jump end_ims;
         calc_ims:
         call $celt.bitexact_cos;
         M[FP + IMID] = r2;
         rMAC = 0;
         rMAC0 = r2;
         r0 = $celt.BITRES+2;
         call $celt.log2_frac;
         push r0;
         
         r0 = M[FP + ITHETA];
         r0 = 16384 - r0;
         call $celt.bitexact_cos;
         M[FP + ISIDE] = r2;
         rMAC = 0;
         rMAC0 = r2;
         r0 = $celt.BITRES+2;
         call $celt.log2_frac;
         pop r1;
         r0 = r0 - r1;
         r1 = M[FP + N_BAND];
         r1 = r1 - 1;
         r0 = r0*r1(int);
         r0 = r0 ASHIFT -2;
         M[FP + DELTA] = r0;           
      end_ims:
      
      // restore trashed registers
      // retrieve the values in I6, I7, M3
      r3 = M[FP + TOTOAL_BITS];
      I6 = r3;
      r3 = M[FP + NB_EBAND];
      I7 = r3;
      r3 = M[FP + NB_EBAND_RM];
      M3 = r3; 

      // -- calc pulses allocated to L and R
      r0 = M[FP + VB];
      r4 = M[FP + QALLOC];
      r3 = M[FP + DELTA];
      r2 = r0 - r4;
      r1 = r4 ASHIFT -1;
      r1 = r0 - r1;
      r1 = r1 - r3;
      r1 = r1 ASHIFT -1;
      if NEG r1 = 0;
      Null = r1 - r2;
      if POS r1 = r2;
      M[FP + MBITS] = r1;
      r2 = r2 - r1;
      M[FP + SBITS] = r2;
      r2 = I7 - M3;
      call $celt.bits2pulses;
      M[FP + Q1] = r0;
      r1 = M[FP + SBITS];
      r2 = I7 - M3;
      call $celt.bits2pulses;
      M[FP + Q2] = r0;               //q2=r0
      r2 = M[FP + Q1];               //q1=r2
      r1 = M[r4 + r0];          //curbits=r3
      // restore I5
      r3 = M[FP + RM_BITS];
      I5 = r3; 
    
      r3 = M[r4 + r2];
      r3 = r3 + r1;
      r1 = M[FP + QALLOC];
      r3 = r3 + r1;
      rem_loop_start:
      I5 = I5 - r3;
      if POS jump end_rem_loop;
         Null = r0 + r2;
         if LE jump end_rem_loop;
         I5 = I5 + r3;
         r3 = 1;
         Null = r2 - r0;  //q1-q2          
         if LE r3 = 0;    //r3 = q>q2
         r1 = r3 XOR 1;   //r1 = q1<=q2
         r2 = r2 - r3;    //q1=q1 - q1>q2
         r0 = r0 - r1;    //q2=q2 - q1<=q2
         r3 = M[r4 + r0];
         r1 = M[r4 + r2];
         r3 = r3 + r1;
         r1 = M[FP + QALLOC];
         r3 = r3 + r1;
         jump rem_loop_start;
      end_rem_loop:
      M[FP + Q2] = r0;
      r0 = r2;
      // push I5
      r3 = I5;
      M[FP + RM_BITS] = r3; 
      
      // save some registers into stack
      r2 = M[FP + CUR_B];
      r1 = M[FP + S_BAND];                
      r3 = M[FP + N_BAND];
      r4 = M[r5 + $celt.dec.NORM_FREQ_FIELD];
      I5 = r4 + r1;//X+eBands[i]
      // I5 = start of band
      // r0 = number of pulses
      // r1 = start bin no
      // r3 = band width
      // r2 = nr of Blocks
      r4 = r0 - Null;
      if LE jump intra_act;
         //calc spread
         M0 = r2;                 
         Null = M[r5 + $celt.dec.HAS_FOLD_FIELD];
         if Z M0 = M0 - M0;      
         r0 = M[r5 + $celt.dec.ALG_QUANT_FUNC_FIELD];
         call r0;
         jump end_act;
      intra_act:
         r0 = M[r5 + $celt.dec.NORM_FIELD];
         I3 = r0;
         call $celt.intra_fold;
      end_act:
      
      // restore I5, I6, I7, M3, r5
      r3 = M[FP + RM_BITS];
      I5 = r3;
      r3 = M[FP + TOTOAL_BITS];
      I6 = r3;
      r3 = M[FP + NB_EBAND];
      I7 = r3;
      r3 = M[FP + NB_EBAND_RM];
      M3 = r3;
      r5 = M[FP + CODEC_STRUC];

      second_ch:
         r0 = M[FP + Q2];
         // save I5, I6, I7, M3, r5 into stack
         r3 = I5;
         M[FP + RM_BITS] = r3;
         r3 = I6;
         M[FP + TOTOAL_BITS] = r3;
         r3 = I7;
         M[FP + NB_EBAND] = r3;
         r3 = M3;
         M[FP + NB_EBAND_RM] = r3;
         M[FP + CODEC_STRUC] = r5;
   
         r2 = M[FP + CUR_B];
         r1 = M[FP + S_BAND];                
         r3 = M[FP + N_BAND];    
         r4 = M[r5 + $celt.dec.NORM_FREQ_FIELD];
         I5 = r4 + r1;//X+eBands[i]
         r4 = M[r5 +  $celt.dec.MODE_MDCT_SIZE_FIELD];
         I5 = I5 + r4;
         // save some registers into stack
         // I5 = start of band
         // r0 = number of pulses
         // r1 = start bin no
         // r3 = band width
         // r2 = nr of Blocks
         r4 = r0 - Null;
         if LE jump zeroside;
            //calc spread
            M0 = r2;                 
            Null = M[r5 + $celt.dec.HAS_FOLD_FIELD];
            if Z M0 = M0 - M0;      
            //call  $celt.alg_unquant;
            r0 = M[r5 + $celt.dec.ALG_QUANT_FUNC_FIELD];
            call r0;
            jump end_act2;
         zeroside:
         r10 = r3;
         r0 = 0;
         do zers_loop;
            M[I5, 1] = r0;
         zers_loop:   
         
      end_act2:
      
      // restore I5, r5
      r3 = M[FP + RM_BITS];
      I5 = r3;
      r5 = M[FP + CODEC_STRUC];
    
      // get start and end of band (again!)
      r1 = M[FP + S_BAND];                
      r10 = M[FP + N_BAND];   
      // calc norm for next folded band
      r0 = M[r5 + $celt.dec.MODE_NB_EBANDS_FIELD];
      r2 = M[FP + NB_EBAND_RM];  // M3
      r0 = r0 - r2; 
      r2 = M[r5 + $celt.dec.MODE_EBNADS_DIF_SQRT_ADDR_FIELD];
      r4 = M[r2 + 0]; //shift
      r2 = r2 + 1;
      r6 = M[r2 + r0]; //gain
      r10 = r10 - 1;
      r0 = M[r5 + $celt.dec.NORM_FIELD];
      I3  = r1 + r0;
      r0 = M[r5 + $celt.dec.NORM_FREQ_FIELD];
      I4  = r0 + r1;
      r0 = M[I4, 1];
      rMAC = r0 * r6; //6 bit less than c 
      do norm_loop;
         rMAC = rMAC ASHIFT r4 (56bit), r0 = M[I4, 1];
         rMAC = r0 * r6, M[I3, 1] = rMAC;      
      norm_loop:
      rMAC = rMAC ASHIFT r4 (56bit);
      M[I3, 1] = rMAC;
      
      r1 = M[FP + S_BAND];                
      r10 = M[FP + N_BAND];
      r10 = r10 - 1;
      r0 = M[r5 + $celt.dec.NORM_FREQ_FIELD];
      I3  = r1 + r0; 
      r4 = M[r5 +  $celt.dec.MODE_MDCT_SIZE_FIELD];
      I4 = I3 + r4;
      I6 = I3;
      I7 = I4;
      r0 = M[FP + IMID];
      r1 = M[FP + ISIDE];
      r0 = r0 ASHIFT 8;
      r1 = r1 ASHIFT 8;
      r0 = r0 * 0.707106781186548 (frac);
      r1 = r1 * 0.707106781186548 (frac);
      r2 = M[I3, 1], r3 = M[I4, 1];       
      rMAC = r2 * r0;
      do mid_side_loop;
         rMAC = rMAC - r3 * r1; 
         rMAC = r3 * r1, M[I6, 1] = rMAC; 
         rMAC = rMAC + r2 * r0, r2 = M[I3, 1], r3 = M[I4, 1];
         rMAC = r2 * r0, M[I7, 1] = rMAC; 
      mid_side_loop:
      rMAC = rMAC - r3 * r1; 
      rMAC = r3 * r1, M[I6, 1] = rMAC; 
      rMAC = rMAC + r2 * r0;
      M[I7, 1] = rMAC; 
      
      //  I5 = buffer address
      //  M3 = width of the current band
      //  M0 = strides (1)
      //  r7 = value (1.0)
      r3= M[FP + N_BAND];
      M3 = r3;
      r1 = M[FP + S_BAND]; 
      r0 = M[r5 + $celt.dec.NORM_FREQ_FIELD];
      I5  = r1 + r0; 
      M0 = 1;
      r7 = 1.0;
      call $celt.renormalise_vector;
      
      //  I5 = buffer address
      //  M3 = width of the current band
      //  M0 = strides (1)
      //  r7 = value (1.0)
      r3= M[FP + N_BAND];
      M3 = r3;
      r1 = M[FP + S_BAND]; 
      r0 = M[r5 + $celt.dec.NORM_FREQ_FIELD];
      I5  = r1 + r0; 
      r4 = M[r5 +  $celt.dec.MODE_MDCT_SIZE_FIELD];
      I5 = I5 + r4;
      M0 = 1;
      r7 = 1.0;
      call $celt.renormalise_vector;
      
      // pop I6, I7, I2, M3
      r3 = M[FP + TOTOAL_BITS];
      I6 = r3;
      r3 = M[FP + NB_EBAND];
      I7 = r3;
      r3 = M[FP + ADDR_EBAND];
      I2 = r3;
      r3 = M[FP + NB_EBAND_RM];
      M3 = r3 - 1;

   if NZ jump quant_bands_main_loop;
   
   // restore the stack pointer
   SP = SP - STACK_USED; 
   popm<FP>;
  
   
   // pop rLink from stack
   jump $pop_rLink_and_rts;
.ENDMODULE;

#else

// *****************************************************************************
// MODULE:
//    $celt.quant_bands
//
// DESCRIPTION:
//    decode and dequantise residual bits
//
// INPUTS:
//  r5 = pointer to decoder structure
//  r0 = 0 ->decoder
//       1 ->encoder
// OUTPUTS:
//   none
//
// TRASHED REGISTERS:
//    everything except r5   
// *****************************************************************************
.MODULE $M.celt.quant_bands;
   .CODESEGMENT CELT_QUANT_BANDS_PM;
   .DATASEGMENT DM;
   $celt.quant_bands: 
   $celt.unquant_bands:
   .VAR curB;
   .VAR balance;
   .VAR temp_stk[7];
   // push rLink onto stack
   $push_rLink_macro;
   r0 = M[r5 + $celt.dec.MODE_NB_EBANDS_FIELD];
   M3 = r0;
   I7 = M3;
   //calc nr of Blocks
   r3 = M[r5 + $celt.dec.MODE_NB_SHORT_MDCTS_FIELD];
   r2 = 1;
   Null = M[r5 + $celt.dec.SHORT_BLOCKS_FIELD];
   if NZ r2 = r3; 
   M[curB] = r2;
   
   M[balance] = 0;
   r1 = M[r5 + $celt.dec.CELT_CODEC_FRAME_SIZE_FIELD];
   r1 = r1 LSHIFT (3+$celt.BITRES);
   I6 = r1; //total bits in the frame (fractional)
   r0 = M[r5 + $celt.dec.PULSES_FIELD];
   I3 = r0;
   r0 = M[r5 + $celt.dec.MODE_EBANDS_ADDR_FIELD];
   I2 = r0;
   quant_bands_main_loop:
      // get bit used so far
      r4 = $celt.BITRES;
      r0 = M[r5 + $celt.dec.TELL_FUNC_FIELD];
      call r0;
      //call $celt.ec_dec_tell;
      
      // update balance
      r1 = M[balance];
      r2 = I7 - M3;
      if Z r1 = r0;
      M[balance] = r1;
      r1 = r1 - r0;
      
      // update remaining bits
      I5 = I6 - r0;
      I5 = I5 - 1;
 
      //curr_balance = balance / curr_balance;
      r3 = 1;
      Null = r1;
      if NEG r3 = - r3;
      r1 = r1 * r3(int);
      Null  =   M3 - 3; //TODO:BC7OPT-max
      if NEG jump chk_2;
         r1 = r1 -1;
         r1 = r1 * (1.0/3.0)(frac);
         jump end_cur_calc;
      chk_2:
      Null = M3 - 2;
      if NZ jump end_cur_calc;
         r1 = r1 ASHIFT -1;
      end_cur_calc:
      r1 = r1 * r3(int);
      
      //calc number of pulses for this band (n)
      r0 = M[r5 + $celt.dec.PULSES_FIELD];
      r3 = r0 + I7;
      r3 = r3 - M3;
      r0 = M[balance];
      r3 = M[r3];
      M[balance] = r0 + r3;
      r1 = r1 + r3;
      call $celt.bits2pulses;
      //r0 = n
      r2 = M[r4 + r0];
      I5 = I5 - r2;
      loop_rem_bits:
         Null = I5;
         if POS jump end_loop_rem_bits;
         Null = r0 - Null;
         if LE jump end_loop_rem_bits;
            I5 = I5 + r2;
            r0 = r0 - 1;
            r2 = M[r4 + r0];
            I5 = I5 - r2;
         jump loop_rem_bits;
      end_loop_rem_bits:
     
      // save some registers into stack
      r3 = I5;
      M[temp_stk + 0] = r3;
      r3 = I6;
      M[temp_stk + 1] = r3;
      r3 = I7; 
      M[temp_stk + 2] = r3;
      r3 = I2;
      M[temp_stk + 3] = r3;
      r3 = M3;
      M[temp_stk + 4] = r3;
      M[temp_stk + 5] = r5;
 
      r2 = M[curB];
      r1 = M[I2, 1];                
      r3 = M[I2, -1];
      r3 = r3 - r1;      
      r4 = M[r5 + $celt.dec.NORM_FREQ_FIELD];
      I5 = r4 + r1;//X+eBands[i]
      // I5 = start of band
      // r0 = number of pulses
      // r1 = start bin no
      // r3 = band width
      // r2 = nr of Blocks
      r4 = r0 - Null;
      if LE jump intra_act;
         //calc spread
         M0 = r2;                 
         Null = M[r5 + $celt.dec.HAS_FOLD_FIELD];
         if Z M0 = M0 - M0;      
         //call  $celt.alg_unquant;
         r0 = M[r5 + $celt.dec.ALG_QUANT_FUNC_FIELD];
         call r0;
         jump end_act;
      intra_act:
         r0 = M[r5 + $celt.dec.NORM_FIELD];
         I3 = r0;
         call $celt.intra_fold;
      end_act:
      
      // restore trashed register
      r3 = M[temp_stk + 0];
      I5 =  r3;
      r3 =  M[temp_stk + 1];
      I6 = r3; 
      r3 = M[temp_stk + 2];
      I7 =  r3;
      r3 =  M[temp_stk + 3];
      I2 =  r3;
      r3 =  M[temp_stk + 4];
      M3 = r3;
      r5 = M[temp_stk + 5];
   
      // get start and end of band (again!)
      r1 = M[I2, 1];                
      r3 = M[I2, 0];
   
      // calc norm for next folded band
      r0 = M[r5 + $celt.dec.MODE_NB_EBANDS_FIELD];
      r0 = r0 - M3;
      r2 = M[r5 + $celt.dec.MODE_EBNADS_DIF_SQRT_ADDR_FIELD];
      r4 = M[r2 + 0]; //shift
      r2 = r2 + 1;
      r6 = M[r2 + r0]; //gain
      r10 = r3 - r1;
      r10 = r10 - 1;
      r0 = M[r5 + $celt.dec.NORM_FIELD];
      I3  = r1 + r0;
      r0 = M[r5 + $celt.dec.NORM_FREQ_FIELD];
      I4  = r0 + r1;
      r0 = M[I4, 1];
      rMAC = r0 * r6; //6 bit less than c TODO:
      do norm_loop;
         rMAC = rMAC ASHIFT r4 (56bit), r0 = M[I4, 1];
         rMAC = r0 * r6, M[I3, 1] = rMAC;      
      norm_loop:
      rMAC = rMAC ASHIFT r4 (56bit);
      M[I3, 1] = rMAC;
   
      M3 = M3 - 1;
   if NZ jump quant_bands_main_loop;
   // pop rLink from stack
   jump $pop_rLink_and_rts;
.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $celt.unquant_bands_stereo
//
// DESCRIPTION:
//    decode and dequantise residual bits
//
// INPUTS:
//  r5 = pointer to decoder structure
//  r0 = 0 ->decoder
//       1 ->encoder
// OUTPUTS:
//   none
//
// TRASHED REGISTERS:
//    everything except r5   
// NOTE:
//   this function needs to be optimised for code size
// *****************************************************************************
.MODULE $M.celt.unquant_bands_stereo;
   .CODESEGMENT CELT_QUANT_BANDS_STEREO_PM;
   .DATASEGMENT DM;
   
   // -- entry point for unquant(decoder)
   $celt.unquant_bands_stereo:
   .VAR codec;
   r0 = $celt.CELT_DECODER;
   jump set_codec;
   
   // -- entry point for quant (encoder)
   $celt.quant_bands_stereo:
   r0 = $celt.CELT_ENCODER;
   set_codec:
   M[codec] = r0;
   
   .VAR curB;
   .VAR balance;
   .VAR temp_stk[7];
   .VAR n_bands; //number of bands
   .VAR s_band;  //start band
   .VAR qb;
   .VAR qalloc;
   .VAR imid;
   .VAR iside;
   .VAR delta;
   .VAR itheta;
   .VAR vb;
   .VAR q1;
   .VAR q2;
   .VAR mbits;
   .VAR sbits;
   
   // push rLink onto stack
   $push_rLink_macro;
   r0 = M[r5 + $celt.dec.MODE_NB_EBANDS_FIELD];
   M3 = r0;
   I7 = M3;

   //calc nr of Blocks
   r3 = M[r5 + $celt.dec.MODE_NB_SHORT_MDCTS_FIELD];
   r2 = 1;
   Null = M[r5 + $celt.dec.SHORT_BLOCKS_FIELD];
   if NZ r2 = r3; 
   M[curB] = r2;
   
   M[balance] = 0;
   r1 = M[r5 + $celt.dec.CELT_CODEC_FRAME_SIZE_FIELD];
   r1 = r1 LSHIFT (3+$celt.BITRES);
   I6 = r1; //total bits in the frame (fractional)
   r0 = M[r5 + $celt.dec.PULSES_FIELD];
   I3 = r0;
   r0 = M[r5 + $celt.dec.MODE_EBANDS_ADDR_FIELD];
   I2 = r0;
   quant_bands_main_loop:
   
      // get bit used so far
      r4 = $celt.BITRES;
      r0 = M[r5 + $celt.dec.TELL_FUNC_FIELD];
      call r0;
      
      // update balance
      r1 = M[balance];
      r2 = I7 - M3;
      if Z r1 = r0;
      M[balance] = r1;
      r1 = r1 - r0;
      
      // update remaining bits
      I5 = I6 - r0;
      I5 = I5 - 1;
 
      //curr_balance = balance / curr_balance;
      r3 = 1;
      Null = r1;
      if NEG r3 = - r3;
      r1 = r1 * r3(int);
      Null  =   M3 - 3; //TODO:BC7OPT-max
      if NEG jump chk_2;
         r1 = r1 -1;
         r1 = r1 * (1.0/3.0)(frac);
         jump end_cur_calc;
      chk_2:
      Null = M3 - 2;
      if NZ jump end_cur_calc;
         r1 = r1 ASHIFT -1;
      end_cur_calc:
      r1 = r1 * r3(int);
      
      r0 = M[I2, 1]; 
      M[s_band] = r0;
      r3 = M[I2, 0];
      r0 = r3 - r0;
      rMAC = 0;
      rMAC0 = r0;
      M[n_bands] = r0;
            
      //calc number of pulses for this band (n)
      r0 = M[r5 + $celt.dec.PULSES_FIELD];
      r3 = r0 + I7;
      r3 = r3 - M3;
      r0 = M[balance];
      r3 = M[r3];
      M[balance] = r0 + r3;
      
      r8 = I5 + 1;
      r1 = r1 + r3;
      if NEG r1 = 0;
      Null = r8 - r1;
      if POS r8 = r1;
      M[vb] = r8;
      
      r0 = $celt.BITRES;
      call $celt.log2_frac;
      r0 = $celt.QTHETA_OFFSET - r0;
      r1 = M[n_bands];
      r2 = r1 - 1;
      r1 = r2 + r2;
      r1 = r1 * r0(int);
      r1 = r8 - r1;
      if NEG r1 = 0;
      
      r2 = r2 LSHIFT 5;
      rMAC = 0;
      rMAC0 = r1;
      Div = rMAC / r2;
      r7 = r8 LSHIFT (-$celt.BITRES);
      r7 = r7 - 1;
      if NEG r7 = 0;
      r0 = DivResult;
      Null = r0 - r7;
      if POS r0 = r7;
      r1 = r0 - 14;
      if POS r0 = r0 - r1;
      M[qb] = r0;
      r1 = 1 LSHIFT r0;
      r1 = r1 + 1;
      rMAC = 0;
      rMAC0 = r1;
      r0 = $celt.BITRES;
      call $celt.log2_frac;
      M[qalloc] = r0;

      // -- save some registers
      r3 = I6;
      M[temp_stk + 1] = r3;
      r3 = I7; 
      M[temp_stk + 2] = r3;
      r3 = I2;
      M[temp_stk + 3] = r3;
      r3 = M3;
      M[temp_stk + 4] = r3;
      M[temp_stk + 5] = r5;
      r3 = I5;
      M[temp_stk + 0] = r3;

      // -- stereo processing required for encode
      Null = M[codec];
      if Z jump is_dec1;
      is_enc1:
         Null = M[qb];
         if NZ jump end_calc_st_coeff;
         
            // -- calc mid/side coeffs
            r2 = I7 - M3;
            r2 = r2 + r2;
            r0 = M[r5 + $celt.enc.BANDE_FIELD];
            I4 = r0 + r2;
            r3 = M[I4, 1];
            r4 = M[I4, 1];
             
            I4 = I4 + ($celt.MAX_BANDS*2);
            r0 = M[I4, 1];
            r1 = M[I4, 1];
            r2 = r4 - r1;
            if POS r2 = 0;
            r1 = r1 - r4;
            if POS r1 = 0;
            r0 = r0 ASHIFT r1;
            r3 = r3 ASHIFT r2;
            push r0;
            push r3;
            rMAC = r0 * r0;
            rMAC = rMAC + r3 * r3;
            r0 = rMAC;
            $celt.sqrt
            pop r4;
            pop r2;
            r3 = r1;
            if Z jump end_calc_st_coeff;
            rMAC = r2 ASHIFT -1;
            Div = rMAC / r3;
            r0 = DivResult;
            rMAC = r4 ASHIFT -1;
            Div = rMAC / r3;
            r1 = DivResult;
            r1 = -r1;
            jump st_mix_enc;
         end_calc_st_coeff:
         r0 = -0.707106781186548;
         r1 = 0.707106781186548;
         st_mix_enc:
         
         // -- ms stereo per band
         r3 = M[s_band];                
         r10 = M[n_bands];
         r10 = r10 - 1;
         r2 = M[r5 + $celt.dec.NORM_FREQ_FIELD];
         I3  = r3 + r2; 
         r4 = M[r5 +  $celt.dec.MODE_MDCT_SIZE_FIELD];
         I4 = I3 + r4;
         I6 = I3;
         I7 = I4;
         r2 = M[I3, 1], r3 = M[I4, 1];       
         rMAC = r3 * r1;
         do mid_side_loop0;
            rMAC = rMAC - r2 * r0; 
            rMAC = r3 * r1, M[I6, 1] = rMAC; 
            rMAC = rMAC + r2 * r0, r2 = M[I3, 1], r3 = M[I4, 1];
            rMAC = r3 * r1, M[I7, 1] = rMAC; 
         mid_side_loop0:
         rMAC = rMAC - r2 * r0; 
         rMAC = r3 * r1, M[I6, 1] = rMAC; 
         rMAC = rMAC + r2 * r0;
         M[I7, 1] = rMAC;
        
         // -- renormalise left band
         r3= M[n_bands];
         M3 = r3;
         r1 = M[s_band]; 
         r0 = M[r5 + $celt.dec.NORM_FREQ_FIELD];
         I5  = r1 + r0; 
         M0 = 1;
         r7 = 1.0;
         call $celt.renormalise_vector;
         push r1;
         
         // -- renormalise right band         
         r3 = M[n_bands];
         M3 = r3;
         r1 = M[s_band]; 
         r0 = M[r5 + $celt.dec.NORM_FREQ_FIELD];
         I5  = r1 + r0; 
         r4 = M[r5 +  $celt.dec.MODE_MDCT_SIZE_FIELD];
         I5 = I5 + r4;
         M0 = 1;
         r7 = 1.0;
         call $celt.renormalise_vector;
         
         // -- calc atan(E_L/E_R)
         r6 = r1;
         pop r1;
         r0 = M[qb];
         if Z jump qb_z;
         push r5;
         r5 = r1;
         call $math.atan;
         r3 = r5 * 0.003906251396735(frac);
         pop r5;
         r0 = M[qb];
         if Z jump qb_z;
         r1 = r0 - 14;
         r2 = -r1;
         r1 = 1.0 ASHIFT r1;
         r3 = r3 * r1(frac);
         r2 = r3 ASHIFT r2;
         M[itheta] = r2;
         r0 = 1 ASHIFT r0;
         r0 = r0 + 1;         
         M[$celt.enc.ec_enc.ft + 0] = r0;
         M[$celt.enc.ec_enc.ft + 1] = Null;
         M[$celt.enc.ec_enc.fl + 0] = r3;
         M[$celt.enc.ec_enc.fl + 1] = Null;
         r2 = M[r5 + $celt.dec.EC_UINT_FUNC_FIELD];
         call r2;
         r0 = M[itheta];
         jump test_itheta;    
      is_dec1:
      r0 = M[qb];
      if NZ jump nzqb_dec;
         qb_z:
         M[itheta] = 0;
         is_ztheta:
         r0 = 32767;     //mid
         r1 = 0;         //side
         r2 = -10000;    //delta
      jump set_st;
      nzqb_dec:
         r0 = M[qb];
         r1 = 14 - r0;
         push r1;
         r1 = 1 LSHIFT r0;
         r0 = r1 + 1;
         r1 = 0;
         r2 = M[r5 + $celt.dec.EC_UINT_FUNC_FIELD];
         call r2;
         pop r1;
         r0 = r0 LSHIFT r1;
         M[itheta]  = r0;
         test_itheta:
         if Z jump is_ztheta;
         Null = r0 - 16384;
         if NZ jump calc_ims;
             r0 = 0;     //mid
             r1 = 32767; //side
             r2 = 10000; //delta
             set_st:
             M[imid] = r0;
             M[iside] = r1;
             M[delta] = r2;
         jump end_ims;
         calc_ims:
         call $celt.bitexact_cos;
         M[imid] = r2;
         rMAC = 0;
         rMAC0 = r2;
         r0 = $celt.BITRES+2;
         call $celt.log2_frac;
         push r0;
         
         r0 = M[itheta];
         r0 = 16384 - r0;
         call $celt.bitexact_cos;
         M[iside] = r2;
         rMAC = 0;
         rMAC0 = r2;
         r0 = $celt.BITRES+2;
         call $celt.log2_frac;
         pop r1;
         r0 = r0 - r1;
         r1 = M[n_bands];
         r1 = r1 - 1;
         r0 = r0*r1(int);
         r0 = r0 ASHIFT -2;
         M[delta] = r0;           
      end_ims:
      
      // restore trashed registers
      r3 =  M[temp_stk + 1];
      I6 = r3; 
      r3 = M[temp_stk + 2];
      I7 =  r3;
      r3 =  M[temp_stk + 4];
      M3 = r3;
      
      // -- calc pulses allocated to L and R
      r0 = M[vb];
      r4 = M[qalloc];
      r3 = M[delta];
      r2 = r0 - r4;
      r1 = r4 ASHIFT -1;
      r1 = r0 - r1;
      r1 = r1 - r3;
      r1 = r1 ASHIFT -1;
      if NEG r1 = 0;
      Null = r1 - r2;
      if POS r1 = r2;
      M[mbits] = r1;
      M[sbits] = r2 - r1;
      r2 = I7 - M3;
      call $celt.bits2pulses;
      M[q1] = r0;
      r1 = M[sbits];
      r2 = I7 - M3;
      call $celt.bits2pulses;
      M[q2] = r0;               //q2=r0
      r2 = M[q1];               //q1=r2
      r1 = M[r4 + r0];          //curbits=r3
      r3 = M[temp_stk + 0];
      I5 = r3;      
      r3 = M[r4 + r2];
      r3 = r3 + r1;
      r3 = r3 + M[qalloc];
      rem_loop_start:
      I5 = I5 - r3;
      if POS jump end_rem_loop;
         Null = r0 + r2;
         if LE jump end_rem_loop;
         I5 = I5 + r3;
         r3 = 1;
         Null = r2 - r0;  //q1-q2          
         if LE r3 = 0;    //r3 = q>q2
         r1 = r3 XOR 1;   //r1 = q1<=q2
         r2 = r2 - r3;    //q1=q1 - q1>q2
         r0 = r0 - r1;    //q2=q2 - q1<=q2
         r3 = M[r4 + r0];
         r1 = M[r4 + r2];
         r3 = r3 + r1;
         r3 = r3 + M[qalloc];
         jump rem_loop_start;
      end_rem_loop:
      M[q2] = r0;
      r0 = r2;
      r3 = I5;
      M[temp_stk + 0] = r3;
      // save some registers into stack
      r2 = M[curB];
      r1 = M[s_band];                
      r3 = M[n_bands];
      r4 = M[r5 + $celt.dec.NORM_FREQ_FIELD];
      I5 = r4 + r1;//X+eBands[i]
      // I5 = start of band
      // r0 = number of pulses
      // r1 = start bin no
      // r3 = band width
      // r2 = nr of Blocks
      r4 = r0 - Null;
      if LE jump intra_act;
         //calc spread
         M0 = r2;                 
         Null = M[r5 + $celt.dec.HAS_FOLD_FIELD];
         if Z M0 = M0 - M0;      
         r0 = M[r5 + $celt.dec.ALG_QUANT_FUNC_FIELD];
         call r0;
         jump end_act;
      intra_act:
         r0 = M[r5 + $celt.dec.NORM_FIELD];
         I3 = r0;
         call $celt.intra_fold;
      end_act:
      
      // restore trashed register
      r3 = M[temp_stk + 0];
      I5 =  r3;
      r3 =  M[temp_stk + 1];
      I6 = r3; 
      r3 = M[temp_stk + 2];
      I7 =  r3;
      r3 =  M[temp_stk + 4];
      M3 = r3;
      r5 = M[temp_stk + 5];
      second_ch:
         r0 = M[q2];
         // save some registers into stack
         r3 = I5;
         M[temp_stk + 0] = r3;
         r3 = I6;
         M[temp_stk + 1] = r3;
         r3 = I7; 
         M[temp_stk + 2] = r3;
         r3 = M3;
         M[temp_stk + 4] = r3;
         M[temp_stk + 5] = r5;
 
         r2 = M[curB];
         r1 = M[s_band];                
         r3 = M[n_bands];    
         r4 = M[r5 + $celt.dec.NORM_FREQ_FIELD];
         I5 = r4 + r1;//X+eBands[i]
         r4 = M[r5 +  $celt.dec.MODE_MDCT_SIZE_FIELD];
         I5 = I5 + r4;
         // save some registers into stack
         // I5 = start of band
         // r0 = number of pulses
         // r1 = start bin no
         // r3 = band width
         // r2 = nr of Blocks
         r4 = r0 - Null;
         if LE jump zeroside;
            //calc spread
            M0 = r2;                 
            Null = M[r5 + $celt.dec.HAS_FOLD_FIELD];
            if Z M0 = M0 - M0;      
            //call  $celt.alg_unquant;
            r0 = M[r5 + $celt.dec.ALG_QUANT_FUNC_FIELD];
            call r0;
            jump end_act2;
         zeroside:
         r10 = r3;
         r0 = 0;
         do zers_loop;
            M[I5, 1] = r0;
         zers_loop:   
         
      end_act2:
      
      // restore trashed register
      r3 = M[temp_stk + 0];
      I5 =  r3;
      r5 = M[temp_stk + 5];
   
      // get start and end of band (again!)
      r1 = M[s_band];                
      r10 = M[n_bands];   
      // calc norm for next folded band
      // calc only when needed!
      r0 = M[r5 + $celt.dec.MODE_NB_EBANDS_FIELD];
      r0 = r0 - M[temp_stk + 4];
      r2 = M[r5 + $celt.dec.MODE_EBNADS_DIF_SQRT_ADDR_FIELD];
      r4 = M[r2 + 0]; //shift
      r2 = r2 + 1;
      r6 = M[r2 + r0]; //gain
      r10 = r10 - 1;
      r0 = M[r5 + $celt.dec.NORM_FIELD];
      I3  = r1 + r0;
      r0 = M[r5 + $celt.dec.NORM_FREQ_FIELD];
      I4  = r0 + r1;
      r0 = M[I4, 1];
      rMAC = r0 * r6; //6 bit less than c TODO:
      do norm_loop;
         rMAC = rMAC ASHIFT r4 (56bit), r0 = M[I4, 1];
         rMAC = r0 * r6, M[I3, 1] = rMAC;      
      norm_loop:
      rMAC = rMAC ASHIFT r4 (56bit);
      M[I3, 1] = rMAC;
      
      r1 = M[s_band];                
      r10 = M[n_bands];
      r10 = r10 - 1;
      r0 = M[r5 + $celt.dec.NORM_FREQ_FIELD];
      I3  = r1 + r0; 
      r4 = M[r5 +  $celt.dec.MODE_MDCT_SIZE_FIELD];
      I4 = I3 + r4;
      I6 = I3;
      I7 = I4;
      r0 = M[imid];
      r1 = M[iside];
      r0 = r0 ASHIFT 8;
      r1 = r1 ASHIFT 8;
      r0 = r0 * 0.707106781186548 (frac);
      r1 = r1 * 0.707106781186548 (frac);
      r2 = M[I3, 1], r3 = M[I4, 1];       
      rMAC = r2 * r0;
      do mid_side_loop;
         rMAC = rMAC - r3 * r1; 
         rMAC = r3 * r1, M[I6, 1] = rMAC; 
         rMAC = rMAC + r2 * r0, r2 = M[I3, 1], r3 = M[I4, 1];
         rMAC = r2 * r0, M[I7, 1] = rMAC; 
      mid_side_loop:
      rMAC = rMAC - r3 * r1; 
      rMAC = r3 * r1, M[I6, 1] = rMAC; 
      rMAC = rMAC + r2 * r0;
      M[I7, 1] = rMAC; 
      
      //  I5 = buffer address
      //  M3 = width of the current band
      //  M0 = strides (1)
      //  r7 = value (1.0)
      r3= M[n_bands];
      M3 = r3;
      r1 = M[s_band]; 
      r0 = M[r5 + $celt.dec.NORM_FREQ_FIELD];
      I5  = r1 + r0; 
      M0 = 1;
      r7 = 1.0;
      call $celt.renormalise_vector;
      
      //  I5 = buffer address
      //  M3 = width of the current band
      //  M0 = strides (1)
      //  r7 = value (1.0)
      r3= M[n_bands];
      M3 = r3;
      r1 = M[s_band]; 
      r0 = M[r5 + $celt.dec.NORM_FREQ_FIELD];
      I5  = r1 + r0; 
      r4 = M[r5 +  $celt.dec.MODE_MDCT_SIZE_FIELD];
      I5 = I5 + r4;
      M0 = 1;
      r7 = 1.0;
      call $celt.renormalise_vector;
      
      r3 =  M[temp_stk + 1];
      I6 = r3; 
      r3 = M[temp_stk + 2];
      I7 =  r3;
      r3 =  M[temp_stk + 3];
      I2 =  r3;
      r3 =  M[temp_stk + 4];
      M3 = r3 - 1;
   if NZ jump quant_bands_main_loop;
   // pop rLink from stack
   jump $pop_rLink_and_rts;
.ENDMODULE;

#endif //#if defined(KAL_ARCH3) || defined(KAL_ARCH5)

// *****************************************************************************
// MODULE:
//    $celt.bits2pulses
//
// DESCRIPTION:
//    returns number of pulses for the bans
//
// INPUTS:
//  r5 = pointer to decoder structure
//  r1 = number of bits for the band
//  r2 = bit vector index
// OUTPUTS:
//   r0 = number of pulses
//
// TRASHED REGISTERS:
//    everything except r5   
// *****************************************************************************
.MODULE $M.celt.bits2pulses;
   .CODESEGMENT CELT_BIT2PULSES_PM;
   .DATASEGMENT DM;
   $celt.bits2pulses: 
   r4 = M[r5 + $celt.dec.MODE_BITS_VECTORS_ADDR_FIELD];
   r0 = M[r4 + r2];
   r4 = r4 + r0;   
   r10 = $celt.MAX_PSEUDOLOG;
   r6 = 0; //lo
   r7 = $celt.MAX_PSEUDO - 1;
   do find_lo_hi;
      r0 = r6 + r7;
      r0 = r0 LSHIFT -1;
      r2 = M[r4 + r0];
      Null = r2 - r1;
      if POS r7 = r0;
      Null = r2 - r1;
      if NEG r6 = r0;         
   find_lo_hi:
   
   r2 = M[r4+r6];
   r0 = M[r4+r7];
   r2 = r2+r0;
   r2 = r2 - r1;
   r0 = r6;
   r2 = r2 - r1;
   if NEG r0 = r7;
   rts;
.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $celt.unquant_energy_finalise
//
// DESCRIPTION:
//    decoding the remaining bits in the stream and finalising band energies
//
// INPUTS:
//  r5 = pointer to decoder structure
// OUTPUTS:
//
// TRASHED REGISTERS:
//    everything except r5    
// *****************************************************************************
.MODULE $M.celt.unquant_energy_finalise;
   .CODESEGMENT CELT_UNQUANT_ENERGY_FINALISE_PM;
   .DATASEGMENT DM;
   $celt.unquant_energy_finalise: 
   // push rLink onto stack
   $push_rLink_macro;

   // work out bits left
   r4 = 0;
   call $celt.ec_dec_tell;
   r1 = M[r5 + $celt.dec.CELT_CODEC_FRAME_SIZE_FIELD];
   r1 = r1 * 8(int);
   M2 = r1 - r0;
   
   r0 = M[r5 + $celt.dec.CELT_CHANNELS_FIELD];
   I6 = r0;
   M3 = 1;
   prio_loop:
      r10 = M[r5 + $celt.dec.MODE_NB_EBANDS_FIELD];
      r0 = M[r5 + $celt.dec.FINE_QUANT_FIELD];
      I2 = r0;
      r0 = M[r5 + $celt.dec.OLD_EBAND_LEFT_FIELD];
      I3 = r0;
      I4 = r0 + $celt.MAX_BANDS;
      r0 = M[r5 + $celt.dec.FINE_PRIORITY_FIELD];
      I5 = r0;
      do finalise_loop;
         r0 = M[r5 + $celt.dec.CELT_CHANNELS_FIELD];
         Null = M2 - r0;
         if LE jump end_finalise_loop;
         r0 = M[I2, 0], r1 = M[I5, 0];
         Null = r0 - 7;
         if POS jump next_fin;
         Null = r1 - M3;
         if Z jump next_fin;
            r2 = 1;
            M[$celt.dec.ec_dec.ftb] = r2;
            call $celt.ec_dec_bits;
            //calc offset
            r0 = r0 + r0, r2 = M[I2, 0];
            r0 = r0 - 1;
            r2 = 14 - r2;
            r0 = r0 ASHIFT r2, r1 = M[I3, 0];
            r0 = r0 + r1;
            M2 = M2 -1;
            Null = I6, M[I3, 0] = r0;
            if Z jump next_fin;
            call $celt.ec_dec_bits;
            r0 = r0 + r0, r2 = M[I2, 0];
            r0 = r0 - 1;
            r2 = 14 - r2;
            r0 = r0 ASHIFT r2, r1 = M[I4, 0];
            r0 = r0 + r1;
            M[I4, 0] = r0;
            M2 = M2 -1;
            next_fin:
            r0 = M[I2, 1], r1 = M[I5, 1];
            r0 = M[I3, 1];
            r1 = M[I4, 1]; 
        finalise_loop:
        end_finalise_loop:
   M3 = M3 - 1;
   if Z jump prio_loop;

   
   // calculate non-logarithmic bans Energies
   r0 = M[r5 + $celt.dec.OLD_EBAND_LEFT_FIELD];
   I3 = r0;
   r0 = M[r5 + $celt.dec.BANDE_FIELD];
   I2 = r0;
   I4 = I2 + $celt.MAX_BANDS;
   r0 = M[r5 + $celt.dec.CELT_CHANNELS_FIELD];
   M3 = r0 + 1;
   r8 = M[r5 + $celt.dec.CELT_MODE_OBJECT_FIELD];
   I7 = &$celt.dec.max_sband;
   calc_ebands:
   I6 = -100;
   r10 = M[r5 + $celt.dec.MODE_NB_EBANDS_FIELD];
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
      Null = r4 - I6;
      if POS I6 = r4;
      // minimum energy clipping
      r0 = M[I3, 0];
      r1 = r0 + 0.0546875;
      if NEG r0 = r0 - r1;
      M[I3, 1] = r0;
   comp_ebands_loop_ch:
   r0 = I6;

   M[I7, 1] = r0;
   
   r0 = M[r5 + $celt.dec.OLD_EBAND_LEFT_FIELD];
   I3 = r0 + $celt.MAX_BANDS;
   r0 = M[r5 + $celt.dec.BANDE_FIELD];
   I2 = r0 + (2*$celt.MAX_BANDS);
   I4 = I2 + $celt.MAX_BANDS;
   M3 = M3 - 1;
   if NZ jump calc_ebands;
   
   // pop rLink from stack
   jump $pop_rLink_and_rts;
.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.denormalise_bands
//
// DESCRIPTION:
//    denormalise bands
//
// INPUTS:
//  r5 = pointer to decoder structure
// OUTPUTS:
//
// TRASHED REGISTERS:
//    everything except r5   
// *****************************************************************************
.MODULE $M.celt.denormalise_bands;
   .CODESEGMENT CELT_DENORMALISE_BANDS_PM;
   .DATASEGMENT DM;
   $celt.denormalise_bands: 
   // push rLink onto stack
   $push_rLink_macro;
  
   r0 = M[r5 + $celt.dec.CELT_CHANNELS_FIELD];
   M3 = r0 + 1;
   r0 = M[r5 + $celt.dec.MODE_NB_EBANDS_FIELD];
   M0 = r0;
   r0 = M[r5 + $celt.dec.MODE_EBANDS_ADDR_FIELD];
   I2 = r0;
   r0 = M[r5 + $celt.dec.BANDE_FIELD];
   I4 = r0;
   I6 = I4 + $celt.MAX_BANDS;
   r0 = M[r5 + $celt.dec.NORM_FREQ_FIELD];
   I3 = r0;
   r0 = M[r5 + $celt.dec.FREQ_FIELD];
   I5 = r0;
   M1 = 1;
   r7 = 0x400000;
   I7 = &$celt.dec.max_sband;
   chan_denorm_loop:
      M2 = M0;
      band_denorm_loop:
         // process band
         r2 = M[I6, 1];
         r3 = M[I7, 0];
         r2 = r2 - 1;
         r2 = r2 - r3;
         r8 = (-22) - r2;
         r8 = r7 ASHIFT r8;
         r0 = M[I2, 1];
         r1 = M[I2, 0];
         r10 = r1 - r0, r0 = M[I3, M1];
         r10 = r10 - M1, r4 = M[I4, M1];
         rMAC = r4 * r0;
         rMAC = rMAC + r7*r8;
         do denorm_band_loop;
            rMAC = rMAC ASHIFT r2 (56bit), r0 = M[I3, M1];
            rMAC = r4 * r0,  M[I5, M1] = rMAC;
            rMAC = rMAC + r7*r8;
         denorm_band_loop:
         rMAC = rMAC ASHIFT r2 (56bit);
         M[I5, 1] = rMAC;
      M2 = M2 - 1;
      if NZ jump band_denorm_loop;
      // zero the rest
      r0 = M[I2, 1];
      r1 = M[I2, 0];
      r10 = r1 - r0;
      r0 = 0;
      do zero_last_band_loop;
         M[I5, 1] = r0;
      zero_last_band_loop:
      // set regs for next channel if necessary
      r0 = M[r5 + $celt.dec.BANDE_FIELD];
      I4 = r0 + (2*$celt.MAX_BANDS);
      I6 = I4 + $celt.MAX_BANDS;
      r0 = M[r5 + $celt.dec.NORM_FREQ_FIELD];
      r1 = M[r5 + $celt.dec.MODE_AUDIO_FRAME_SIZE_FIELD];
      I3 = r0 + r1;
      r0 = M[r5 + $celt.dec.FREQ2_FIELD];
      I5 = r0;
      r0 = M[r5 + $celt.dec.MODE_EBANDS_ADDR_FIELD];
      I2 = r0;
      r3 = M[I7, 1];
   M3 = M3 - 1;
   if NZ jump chan_denorm_loop;
   
   // pop rLink from stack
   jump $pop_rLink_and_rts;
.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.renormalise_bands
//
// DESCRIPTION:
//    restore full amplitude for each band
//
// INPUTS:
//  r5 = pointer to decoder structure
// OUTPUTS:
//
// TRASHED REGISTERS:
//    everything except r5   
// *****************************************************************************
.MODULE $M.celt.renormalise_bands;
   .CODESEGMENT CELT_RENORMALISE_BANDS_PM;
   .DATASEGMENT DM;
   $celt.renormalise_bands: 
   // push rLink onto stack
   $push_rLink_macro;
   
   r0 = M[r5 + $celt.dec.MODE_NB_EBANDS_FIELD];
   I7 = r0;
   r0 = M[r5 + $celt.dec.MODE_EBANDS_ADDR_FIELD];
   I3 = r0;
   r0 = M[r5 + $celt.dec.CELT_CHANNELS_FIELD];
   I6 = r0 + 1;
   M0 = 1;
   r7 = 1.0;
   r0 = M[r5 + $celt.dec.NORM_FREQ_FIELD];
   I5 = r0;
   chan_renorm_loop:
      M2 = I7;
      band_norm_loop:
         r0 = M[I3, 1];
         r1 = M[I3, 0];
         M3 = r1 - r0;
         call $celt.renormalise_vector;
         I5 = I5 + M3;
         M2 = M2 -1;
      if NZ jump band_norm_loop;
      r0 = M[r5 + $celt.dec.MODE_EBANDS_ADDR_FIELD];
      r1 = M[r5 + $celt.dec.MODE_MDCT_SIZE_FIELD];
      I3 = r0;
      r0 = M[r5 + $celt.dec.NORM_FREQ_FIELD];
      I5 = r0 + r1;
      I6 = I6 - 1;
   if NZ jump chan_renorm_loop;

   // pop rLink from stack
   jump $pop_rLink_and_rts;
 .ENDMODULE;

#endif

