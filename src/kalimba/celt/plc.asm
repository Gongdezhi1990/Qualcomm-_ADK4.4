// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifndef CELT_PLC_INCLUDED
#define CELT_PLC_INCLUDED
#include "stack.h"
#include "celt.h"
// *****************************************************************************
// MODULE:
//    $celt.fill_plc_buffers
//
// DESCRIPTION:
//   fills plc history buffers to be used when a packet is lost
// INPUTS:
//   - none
//   
// OUTPUTS:
//   - none
//   
// TRASHED REGISTERS:
// 
// ***************************************************************************** 
.MODULE $M.celt.fill_plc_buffers;
   .CODESEGMENT CELT_FILL_PLC_BUFFERS_PM;
   .DATASEGMENT DM;
   $celt.fill_plc_buffers:
   $push_rLink_macro;
   r10 = M[r5 + $celt.dec.MODE_AUDIO_FRAME_SIZE_FIELD];
   // get pointer to newly synthesise audio
#ifdef BASE_REGISTER_MODE
   r0 = M[$celt.dec.left_obuf_start_addr];
   push r0;
   pop B5;
#endif
   r0 = M[$celt.dec.left_obuf_addr];
   r1 = M[$celt.dec.left_obuf_len];
   I5 = r0;                                                // left buffer
   L5 = r1;

   r8 = M[r5 + $celt.dec.PLC_HIST_LEFT_BUFFER_FIELD];
   M0 = r10;
   r0 = M[r5 + $celt.dec.CELT_CHANNELS_FIELD];
   M1 = r0 + 1;
   chan_loop:
      // remove older samples in hist buffer
      r0 = r8;
#ifdef BASE_REGISTER_MODE
      call $cbuffer.get_read_address_and_size_and_start_address;
      push r2;
      pop  B0;
#else
      call $cbuffer.get_read_address_and_size;
#endif
      I0 = r0;
      L0 = r1;
      r0 = M[I0, M0];
      r0 = r8;
      r1 = I0;
      call $cbuffer.set_read_address;

      // insert new samples into hist buffer
      r0 = r8;
      call $cbuffer.get_write_address_and_size;
      I0 = r0;
      r10 = M0 - 1;
      r0 = M[I5, 1];
      do copy_loop;
         r0 = M[I5, 1], M[I0, 1] = r0;
      copy_loop:
      M[I0, 1] = r0;
      r0 = r8;
      r1 = I0;
      call $cbuffer.set_write_address;

      // repeat for right channel if exists
#ifdef BASE_REGISTER_MODE
      r0 = M[$celt.dec.right_obuf_start_addr];
      push r0;
      pop B5;
#endif
      r0 = M[$celt.dec.right_obuf_addr];
      r1 = M[$celt.dec.right_obuf_len];
      I5 = r0;                                              
      L5 = r1;
      r8 = M[r5 + $celt.dec.PLC_HIST_RIGHT_BUFFER_FIELD];
      M1 = M1 - 1;
   if NZ jump chan_loop;
   L0 = 0;
   L5 = 0;
#ifdef BASE_REGISTER_MODE
      push Null;
      pop B0;
      push Null;
      pop  B5;
#endif  
   jump $pop_rLink_and_rts;
  .ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.run_plc
//
// DESCRIPTION:
//   runs packet loss concealmet procedure
// INPUTS:
//   - none
//   
// OUTPUTS:
//   - none
// TRASHED REGISTERS:
//   - assume everything except r5
// 
// NOTE:
//  - only mono at the moment!
// ***************************************************************************** 
.MODULE $M.celt.run_plc;
   .CODESEGMENT CELT_RUN_PLC_PM;
   .DATASEGMENT DM;
   $celt.run_plc:
   $push_rLink_macro;
   .VAR fade;

   // -- Pitch estimate if its first lost frame
   r0 = M[r5 + $celt.dec.PLC_COUNTER_FIELD];
   if NZ jump not_first_lost_packet;
      // -- Downsample hist by M=2
      r8 = $celt.PLC_BUFFER_SIZE;
      r0 = M[r5 + $celt.dec.PLC_HIST_LEFT_BUFFER_FIELD];
#ifdef BASE_REGISTER_MODE
      call $cbuffer.get_read_address_and_size_and_start_address;
      push r2;
      pop  B5;
#endif
      call $cbuffer.get_read_address_and_size;
      I5 = r0;
      L5 = r1;
      r0 = M[r5 + $celt.dec.PLC_PITCH_BUF_FIELD];
      I1 = r0;
      I2 = I1;
      call $celt.pitch_downsample;
      L5 = 0;
#ifdef BASE_REGISTER_MODE
      push Null;
      pop  B5;
#endif
      // -- Pitch Estimation
      #ifdef $celt.PLC_EXTRA_DOWNSAMPLE
         // -- Pitch extimation is too MIPy, we compromise the resolution to reduce the cycles
         //    by doing another downsamling by M=2
         r8 = ($celt.PLC_BUFFER_SIZE>>1);
         I1 = I2;
         I5 = I1;
         call $celt.pitch_downsample;
         
         // Pitch Serach
         r0 = M[r5 + $celt.dec.MODE_AUDIO_FRAME_SIZE_FIELD];
         r1 = M[r5 + $celt.dec.MODE_OVERLAP_FIELD];
         r8 = r0 + r1;
         r8 = r8 LSHIFT -1;
         I4 = I2;
         r1 = ($celt.PLC_BUFFER_SIZE>>1) - r8;
         r0 = r1 LSHIFT -1;
         I5 = I4 + r0;
         r1 = r1 - 50;
         M[$celt.dec.max_pitch] = r1;
         r0 = $celt.MAX_PERIOD>>3;
         M[$celt.dec.lag] = r0;
         call $celt.pitch_search;
         
         // -- double estimated pitch
         r4 = ($celt.MAX_PERIOD>>1)-r4;
         r4 = r4 - r8;
         r4 = r4 + r4;         
     #else
         // -- pitch search only
         r0 = M[r5 + $celt.dec.MODE_AUDIO_FRAME_SIZE_FIELD];
         r1 = M[r5 + $celt.dec.MODE_OVERLAP_FIELD];
         r8 = r0 + r1;
         I4 = I2;
         r1 = ($celt.PLC_BUFFER_SIZE) - r8;
         r0 = r1 LSHIFT -1;
         I5 = I4 + r0;
         r1 = r1 - 100;
         M[$celt.dec.max_pitch] = r0;
         r0 = $celt.MAX_PERIOD>>2;
         M[$celt.dec.lag] = r0;
         call $celt.pitch_search;
         r4 = $celt.MAX_PERIOD-r4;
         r4 = r4 - r8; 
     #endif
      M[r5 + $celt.dec.PLC_LAST_PITCH_INDEX_FIELD] = r4;
      r0 = 1.0;
      M[fade] = r0;
      jump lpc_process;
   not_first_lost_packet:
     // maximum lost packet
     r1 = 1.0;
     Null = r0 - $celt.PLC_MAX_LOSS_PACKETS;
     if POS r1 = 0;
     M[fade] = r1;
   lpc_process:

      // -- copy hist into excitation buffer (DM1)
      //    there is a copy of exc buffer in DM2 to avoid stall in auto-corr compute
      r8 = $celt.PLC_BUFFER_SIZE;
      r0 = M[r5 + $celt.dec.PLC_HIST_LEFT_BUFFER_FIELD];
#ifdef BASE_REGISTER_MODE
      call $cbuffer.get_read_address_and_size_and_start_address;
      push r2;
      pop  B5;
#endif
      call $cbuffer.get_read_address_and_size;
      I5 = r0;
      L5 = r1;
      r0 = M[r5 + $celt.dec.PLC_EXC_FIELD];
      I1 = r0;
      r0 = M[r5 + $celt.dec.PLC_EXC_COPY_FIELD];
      I4 = r0;
      r10 = $celt.MAX_PERIOD;
      do copy_to_exc_loop;
         r0 = M[I5, 1];
         M[I4, 1] = r0, M[I1, 1] = r0; 
      copy_to_exc_loop:
      L5 = 0;
#ifdef BASE_REGISTER_MODE
      push Null;
      pop  B5;
#endif     
      // -- plc is computed only for first lost frame
      Null = M[r5 + $celt.dec.PLC_COUNTER_FIELD];
      if NZ jump end_lpc_calc;
         // compute auto corr for limited number of lags
         // increasing lpc order will increase MIPS!
         r6 = $celt.PLC_LPC_ORDER;
         r8 = $celt.MAX_PERIOD;
         r0 = M[r5 + $celt.dec.PLC_AC_FIELD];
         I4 = r0;
         r0 = M[r5 + $celt.dec.PLC_EXC_FIELD];
         I0 = r0;
         r0 = M[r5 + $celt.dec.PLC_EXC_COPY_FIELD];
         I5 = r0;
         call $celt.autocorr;
         // -- fixing after auto-corr compute
         //    this is to avoid instability in lpc filter
         r0 = M[r5 + $celt.dec.PLC_AC_FIELD];
         I4 = r0;
         rMAC = M[I4, 0];
         r0 = 0.00001;
         rMAC = rMAC + rMAC*r0;
         M[I4, 1] = rMAC;
         r10 = $celt.PLC_LPC_ORDER;
         r4 = 0.008;
         r1 = r4;
         do lag_window_loop;
            rMAC = M[I4, 0];
            r0 = r4 * r4 (frac); 
            rMAC = rMAC - rMAC*r0;
            r4 = r4 + r1, M[I4, 1] = rMAC;              
         lag_window_loop:
         
         // -- compute LPC coeffs
         M3 = $celt.PLC_LPC_ORDER;
         r0 = M[r5 + $celt.dec.PLC_AC_FIELD];
         I4 = r0;
         r0 = M[r5 + $celt.dec.PLC_LPC_COEFSS_FIELD];
         I0 = r0;
         call $celt.calculate_lpc;
   end_lpc_calc:
   
   // -- reset LPC filter history
   r10 = $celt.PLC_LPC_ORDER;
   r0 = 0;
   r1 = M[r5 + $celt.dec.PLC_MEM_LPC_FIELD];
   I0 = r1;
   do zero_mem_lpc_loop;
      M[I0, 1] = r0;
   zero_mem_lpc_loop:
   
   // -- lpc analysis filter
   I0 = r1;
   L0 = $celt.PLC_LPC_ORDER;
   r0 = M[r5 + $celt.dec.PLC_EXC_FIELD];
   I4 = r0;
   I5 = r0;
   M3 = $celt.MAX_PERIOD;
   r8 = $celt.PLC_LPC_ORDER;
   r0 = M[r5 + $celt.dec.PLC_LPC_COEFSS_FIELD];
   I7 = r0;
   r7 = $celt.PLC_LPC_SHIFT;
   call $celt.fir;
   
  
   // -- apply decay

   .VAR decay_rate[3]= 0.9998,  0.9989, 0.9975;
   r2 = 1.0;   
   r4 = M[r5 + $celt.dec.LAST_DECAY_FIELD];
   r0 = M[r5 + $celt.dec.PLC_COUNTER_FIELD];
   if Z r4 = r2;
   M[r5 + $celt.dec.LAST_DECAY_FIELD] = r4;
   r2 = M[decay_rate + r0];
   Null = r0 - 3;
   if POS r2 = 0;
  
   r0 = M[r5 + $celt.dec.MODE_AUDIO_FRAME_SIZE_FIELD];
   r1 = M[r5 + $celt.dec.MODE_OVERLAP_FIELD];
   r8 = r0 + r1;
   r8 = r8 + r1;
   
   r7 = M[r5 + $celt.dec.PLC_LAST_PITCH_INDEX_FIELD];
   r0 = M[r5 + $celt.dec.PLC_EXC_FIELD];
   I3 = r0 + $celt.MAX_PERIOD;
   I2 = I3 - r7;              
   I1 = I2;                   
   r10 = r8;
   r0 = M[r5 + $celt.dec.PLC_E_FIELD];
   I4 = r0;
   do copy_exc_loop;
      Null = I1 - I3;
      if POS I1 = I2;
      r4 = r4 * r2(frac),  r0 = M[I1, 1];
      r0 = r0 * r4(frac);
      M[I4, 1] = r0;      
   copy_exc_loop:
   M[r5 + $celt.dec.LAST_DECAY_FIELD] = r4;
   
   // -- lpc synthesis
   r0 = M[r5 + $celt.dec.PLC_E_FIELD];
   I4 =  r0;
   I5 =  r0;
   M3 = r8;
   r8 = $celt.PLC_LPC_ORDER;
   r0 = M[r5 + $celt.dec.PLC_LPC_COEFSS_FIELD];
   I7 = r0;
   r7 = $celt.PLC_LPC_SHIFT;
   call $celt.iir;
   L0 = 0;
#ifdef BASE_REGISTER_MODE
   push Null;
   pop  B0;
   
   r0 = M[$celt.dec.left_obuf_start_addr];
   push r0;
   pop B0;
#endif   
    
   r0 = M[$celt.dec.left_obuf_addr];
   r1 = M[$celt.dec.left_obuf_len];
   I0 = r0;
   L0 = r1;
   
   // -- write into output buffer
   // -- we dont know if next frame is lost or not,
   //   to avoid aliasing when overlap-add, the history is windowed for next frame
   r8 = M[r5 +  $celt.dec.MODE_AUDIO_FRAME_SIZE_FIELD];
   r6 = M[r5 + $celt.dec.MODE_OVERLAP_FIELD];
   r10 = r6 LSHIFT -1;
   r7 = r6 - 1;
   M0 = r7;
   I1 = I0;
   L1 = L0;
#ifdef BASE_REGISTER_MODE
   push B0;
   pop  B1;
#endif
   r0 = M[I1, M0];

   r0 = M[r5 + $celt.dec.MODE_WINDOW_ADDR_FIELD]; 
   I2 = r0;
   I3 = I2 + r7;
   r0 =  M[r5 + $celt.dec.PLC_E_FIELD];
   I4 =  r0;
   I5 =  r0 + r7;//$celt.e + r7;

   r0 = M[r5 + $celt.dec.HIST_OLA_LEFT_FIELD];   
   I6 = r0;
   I7 = I6 + r7;
   M2 = r8;
   // I2 = w1 +
   // I3 = w2 -
   // I4 = e1 + e3+
   // I5 = e2 - e4-
   // I4 + M2 -> e3
   // I5 + M2 -> e4
   // I6 = hist1
   // I7 = hist2
   // I0 = mem1
   // I1 = mem2
   // r7 = fade
   r7 = M[fade];
   M0 = 1;
   M3 = 1 - M2;
   M1 = (-1) - M2;
   r0 = M[I2, M0], r1 = M[I4, M2];                                //r0 = w1  r1 = e1          w1+1   e1+ov
   r2 = M[I3, -1];                                                //r2 = w2                   w2-1 
   
   do plc_tdac_loop;
      rMAC = r0 * r1, r1 = M[I5, M2];                             // w1*e1  r1=e2             e2+ov
      rMAC = rMAC - r1 * r2, r1 = M[I4, M3];                      //w1*e1-w2*e2, r1 = e3      e1+ov-(ov-1)
      r8 = rMAC * r7(frac);                                       //r8 = temp1
      rMAC = r2*r1, r1 = M[I5, M1];                               //w2*e3, r1 = e4            e2+ov-(ov-1)
      rMAC = rMAC + r1*r0;                                        //w2*e3+e4*w1             
      r4 = rMAC * r7(frac);
      rMAC = M[I6, 0];                                           //r6 = temp2*fade, rMAC = h1    h1=h1+0
      rMAC = rMAC + r8*r0, r1 = M[I4, M2];                       //h1 + tmp1*w1
      r3 = r4*r2(frac), M[I0, M0] = rMAC;
      rMAC = M[I7, 0];                                           //r3=temp2*w2,    mem0 = h1+w1*tmp1, rMAC = h2(+0)
      rMAC = rMAC - r8*r2, M[I6, 1] = r3, r2 = M[I3, -1];        //h1(+1) = tmp2*w2; h2-tmp1*w2
      r4 = r4*r0(frac), M[I1, -1] = rMAC;
      M[I7, -1] = r4, r0 = M[I2, 1];
   plc_tdac_loop:
   r0 = r6 LSHIFT -1;
   M1 = r0;
   r0 = M[I0, M1];   
   r10 = M2 - r6;
   r0 = M[r5+ $celt.dec.PLC_E_FIELD];
   I4 = r6 + r0;
   r10 = r10 - M0, r0 = M[I4, M0];
   rMAC = r0*r7, r0 = M[I4, M0];
   do flat_win_loop;
      rMAC = r0*r7, M[I0, M0] = rMAC, r0 = M[I4, M0];
   flat_win_loop:
   M[I0, M0] = rMAC;
   L0 = 0;
   L1 = 0;  
#ifdef BASE_REGISTER_MODE
   push Null;
   pop  B0;
   push Null; 
   pop B1; 
#endif
   r0 = M[r5 + $celt.dec.PLC_COUNTER_FIELD];
   r0 = r0 + 1;
   M[r5 + $celt.dec.PLC_COUNTER_FIELD] = r0;
   jump $pop_rLink_and_rts;
.ENDMODULE;
// *****************************************************************************
// MODULE:
//    $celt.autocorr
//
// DESCRIPTION:
//   auto correlation
// INPUTS:
//   r6 = number of lags
//   I0 = input in DM1
//   I5 = same input in DM2
//   I4 = output
//   r8 = length of input
// OUTPUTS:
//  - none 
// TRASHED REGISTERS:
// r0-r4, r6-r8, r10, I0-I7
// NOTE: 
//   The results are normalized, r2 shows the shift value
// ***************************************************************************** 
.MODULE $M.celt.autocorr;
   .CODESEGMENT CELT_AUTOCORR_PM;
   .DATASEGMENT DM;
   $celt.autocorr:
   r4 = -10;          
   r3 = r4 + 24;
   r2 = 30;
   r7 = r8 - 1;
   M0 = -1;
   I4 = I4 + r6;
   I7 = I4 + r6;
   I7 = I7 + 1;
   M1 = r6;
   auto_cor_loop:
      I1 = I0 + r6;
      I6 = I5;
      r10 = r7 - r6;
      rMAC = 0, r0 = M[I1, 1], r1 = M[I6, 1];
      do calc_ac_loop;
         rMAC = rMAC + r0*r1, r0 = M[I1, 1], r1 = M[I6, 1];
      calc_ac_loop:
      rMAC = rMAC + r0*r1;
      r0 = rMAC ASHIFT r4;
      r1 = rMAC LSHIFT r3;
      // double precison is saved
      r2 = blksigndet rMAC, M[I4, M0] = r0;
      r6 = r6 + M0, M[I7, M0] = r1;
  if POS jump auto_cor_loop;
  
  // Normalise autocorr double precision vector to single precision
  r2 = r2 + 9; 
  r10 = M1;
  r0 = M[I4, 1];
  r1 = M[I7, 1];
  I1 = I4;
  rMAC = M[I1, 1];
  r1 = M[I7, 1];
  do acor_shift_loop;
     rMAC0 = r1;
     rMAC = rMAC ASHIFT r2 (56bit), r1 = M[I7, 1];
     M[I4, 1] = rMAC, rMAC = M[I1, 1];
  acor_shift_loop:
  rMAC0 = r1;
  rMAC = rMAC ASHIFT r2 (56bit);
  M[I4, 1] = rMAC;
  rts; 
  .ENDMODULE;

// *****************************************************************************
// MODULE:
//    $celt.calculate_lpc
//
// DESCRIPTION:
//    Calultaing Linear Prediction Ceoefficient (Levinson-Durbin)
//
// INPUTS:
//   I0 = output coeffs
//   I4 = input auto-corr 
//   M3 = LPC order
// OUTPUTS:
//   -none
// TRASHED REGISTERS:
// 
// NOTE: need optimization
// ***************************************************************************** 
.MODULE $M.celt.calculate_lpc;
   .CODESEGMENT CELT_CALCULATE_LPC_PM;
   .DATASEGMENT DM;
   
   $celt.calculate_lpc:
   
   // see if first lag auto-corr is not zero
   r0 = M[I4 , 0];
   Null = r0;
   if NZ jump calc_lpc;
   
   // Set all coeffs to zero
   r10 = M3;
   do zero_lpc_loop;
     M[I0, 1] = r0;
   zero_lpc_loop:
   rts;
   
   // calculate coeffs loop
   calc_lpc:    
   r7 = 0;
   r8 = I4 + 1;
   r6 = r0;
   r4 = r6 LSHIFT -12;
   I7 = I0;
   r3 = 1.0;
   calc_lpc_loop:
      I5 = r8 + r7;
      I1 = I0;
      r10 = r7;
      r1 = r3 ASHIFT (-$celt.PLC_LPC_SHIFT);
     
      // sum up reflection coeffs up to this index
      rMAC = 0, r0 = M[I5, -1];
      do sum_ref_cf_lp;
         rMAC = rMAC - r0 * r1, r1 = M[I1, 1], r0 = M[I5, -1];
      sum_ref_cf_lp:
      r10 = 1;
      rMAC = rMAC - r0 * r1;
     
      // next step is divison, negate if result is negative
      // TODO:OPTBC7
      if POS jump is_pos;
         r0 = rMAC0;
         r1 = rMAC1;
         r0 = Null - r0;
         r1 = Null - r1 - Borrow;
         rMAC = r1;
         rMAC0 = r0;
         r10 = -1;
      is_pos:
     
      // PLC coeffs are scaled to supput maximum (1.0<<PLC_LPC_SHIFT)
      // more than that is saturated
      r0 = rMAC LSHIFT ($celt.PLC_LPC_SHIFT+23);
      rMAC = rMAC ASHIFT ($celt.PLC_LPC_SHIFT-1);
      rMAC0 = r0;
      Div = rMAC / r6;
      r0 = DivResult;
      // apply sign
      r0 = r0*r10(int);
     
      // save next coeff
      r1= r0 ASHIFT (-$celt.PLC_LPC_SHIFT);
      M[I7, 1] = r1;
     
      // update coeffs
      r10 = r7 + 1;
      r10 = r10 LSHIFT -1;
      I2 = I0;
      I3 = I0 + r7;
      I3 = I3 - 1;    
      r1 = M[I2, 0];
      do cross_lpc_loop;
         rMAC = r1 * r3, r2 = M[I3, 0];
         rMAC = rMAC + r2 * r0;
         rMAC = r0*r1, M[I2, 1] = rMAC;
         rMAC = rMAC + r3*r2, r1 = M[I2, 0];
         M[I3, -1] = rMAC;
      cross_lpc_loop:
     
      // update error
      r7 = r7 + 1;
      r0 = r0 * r0(frac);
      r0 = r3 - r0;
      r6 = r0*r6(frac);
      // if error is too small -> return
      //Null = r6 - r4;
      //if NEG rts;                          
      M3 = M3 - 1;
   if NZ jump calc_lpc_loop;
   rts; 
.ENDMODULE;  
// *****************************************************************************
// MODULE:
//    $celt.fir
//
// DESCRIPTION:
//  FIR filter for lpc analysis
// INPUTS:
//    I0/L0 = lpc filter history  
//    I4 = input  
//    I5 = output
//    I7 = lpc coeffs
//    r8 = lpc filter order
//    M3 = input length
//    r7 = scaling shift value
// OUTPUTS:
//   
// TRASHED REGISTERS:
// 
// NOTE: 
// 
// ***************************************************************************** 
.MODULE $M.celt.fir;
   .CODESEGMENT CELT_FIR_PM;
   .DATASEGMENT DM;
   $celt.fir:
   M0 = 1;
   r4 = r8 - 1;
   M2 = -r8;
   M1 = -1;
   r2 = M[I4, 1];
   r0 = Null - r7;
   r3 = 0x7FFFFF ASHIFT r0;
   r0 = M[I0, 0];
   
   outer_fir_loop:
      r10 = r4;
      rMAC = r2*r3, r1 = M[I7, 1], r0 = M[I0, 1];
      do fir_loop;
         rMAC = rMAC + r0*r1, r0 = M[I0, 1], r1 = M[I7, 1];
      fir_loop:
      rMAC = rMAC + r0*r1, r0 = M[I0, M1],r1 = M[I7, M2];
      rMAC = rMAC ASHIFT r7 (56bit), r2 = M[I4, 1], M[I0, 0] = r2;
      M3 = M3 - M0, M[I5, M0] = rMAC;      
   if NZ jump outer_fir_loop;
   rts;
.ENDMODULE;  
// *****************************************************************************
// MODULE:
//    $celt.iir
//
// DESCRIPTION:
//    IIR filter for lpc synthesis
//
// INPUTS:
//    I0/L0 = lpc filter history  
//    I4 = input  
//    I5 = output
//    I7 = lpc coeffs
//    r8 = lpc filter order
//    M3 = input length
//    r7 = scaling shift value  
// OUTPUTS:
//   
// TRASHED REGISTERS:
// 
// NOTE:
// ***************************************************************************** 
.MODULE $M.celt.iir;
   .CODESEGMENT CELT_IIR_PM;
   .DATASEGMENT DM;
   $celt.iir:
   M0 = 1;
   r4 = r8 - 1;
   M2 = -r8;
   M1 = 0;
   r0 = Null - r7;
   r3 = 0x7FFFFF ASHIFT r0;
   r2 = M[I4, 1];
   sample_iir_loop:
      r10 = r4;
      rMAC = r2*r3, r1 = M[I7, 1], r0 = M[I0, 1];
      do fir_loop;
         rMAC = rMAC - r0*r1, r0 = M[I0, 1], r1 = M[I7, 1];
      fir_loop:
      rMAC = rMAC - r0*r1, r0 = M[I0, -1], r2 = M[I4, 1];
      rMAC = rMAC ASHIFT r7 (56bit), r1 = M[I7, M2];
      M3 = M3 - M0, M[I5, M0] = rMAC, M[I0, M1] = rMAC;      
   if NZ jump sample_iir_loop;   
   rts;
.ENDMODULE;
#endif
