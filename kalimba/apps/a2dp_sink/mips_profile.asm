// *****************************************************************************
// Copyright (c) 2005 - 2015 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

// *****************************************************************************
// MODULE:
//    $M.mips_profile
//
// INPUTS:
//    r8 - mips data block pointer
//
// OUTPUTS:
//    main_cycles :
//       num cycles used in your main function in a 100ms interval
//    int_cycles  :
//       num cycles used in your interrupt functions(s) in a 100ms interval
//    tot_cycles  :
//       total cycles used by your application in a 100ms interval
//
// TRASHED:
//    r0,r1
//
// CYCLES
//    $M.mips_profile.mainstart: 6
//    $M.mips_profile.mainend:   16
//    $M.mips_profile.intstart:  3
//    $M.mips_profile.intend:    10
//
//
// DESCRIPTION:
//    profiler. Calculate #cycles used in main and interrupt processes
//
//    MATLAB script to read MIPS:
//
//    cyc_m = kalreadval('$M.cvc_profile.main_cycles', 'uint', '24');
//    cyc_int = kalreadval('$M.cvc_profile.int_cycles', 'uint', '24');
//    cyc_tot = kalreadval('$M.cvc_profile.tot_cycles', 'uint', '24');
//
//    buf = sprintf('main MIPS\t%.2f\nint MIPS \t%.2f\ntotal MIPS\t%.2f\n',...
//       1e-5*cyc_m,1e-5*cyc_int,1e-5*cyc_tot);
//    disp(buf);
//
//
// *****************************************************************************
#include "mips_profile.h"

.MODULE $M.mips_profile;
   .CODESEGMENT MIPS_PROFILE_PM;
   .DATASEGMENT DM;

   .VAR $DecoderMips_data_block[$mips_profile.MIPS.BLOCK_SIZE] =
     0,                                 // STAT               // status(0=reset, 1=running)
     0,                                 // TMAIN              // initial cycle count
     0,                                 // SMAIN              // accumulation of main cycles, minus interrupt cycles during eval period
     0,                                 // TINT               // inital sum of interrupt cycles
     0,                                 // SINT               // accumulation of in cycles during eval period
     $IntMips_data_block,                // PTR_INT_OBJ        // pointer to interrupt profile object
     0,                                 // MAIN_CYCLES        // main cycles used during eval period, without int cycles
     0,                                 // INT_CYCLES         // int cycles used during eval period
     0,                                 // TOT_CYCLES         // total cycles used during eval period
     0;                                 // TEVAL              // main profile start time

   .VAR $FunctionMips_data_block[$mips_profile.MIPS.BLOCK_SIZE] =
     0,                                 // STAT
     0,                                 // TMAIN
     0,                                 // SMAIN
     0,                                 // TINT
     0,                                 // SINT
     $IntMips_data_block,                // PTR_INT_OBJ
     0,                                 // MAIN_CYCLES
     0,                                 // INT_CYCLES
     0,                                 // TOT_CYCLES
     0;                                 // TEVAL

// integer profiling object, shares fields with main profiling object
   .VAR $IntMips_data_block[$mips_profile.MIPS.BLOCK_SIZE] =  // integer profile object
     0,                                 // STAT               // status(0=reset, 1=running)
     0,                                 // TMAIN              // initial int cycle count
     0,                                 // SMAIN              // freerunning int cycle counter (never resets)
     0,                                 // TINT               // unused (reserved for nesting in future)
     0,                                 // SINT               // unused (reserved for nesting in future)
     0,                                 // SMAIN_INT          // initial vlaue of SMAIN
     0,                                 // MAIN_CYCLES        // total int cycles over profile period
     0,                                 // INT_CYCLES         // unused
     0,                                 // TOT_CYCLES         // unused
     0;                                 // TEVAL              // start of profile time

   .CONST $mips_profile.MIPS.PTR_INT_OBJ_OFFSET  $mips_profile.MIPS.SMAIN_INT_OFFSET;
   #define PROFILE_ADDR $NUM_RUN_CLKS_LS
   .VAR evalinterval_us = 100000;

mainstart:
   // start profiling main process

   r0 = M[PROFILE_ADDR];
   M[r8 +$mips_profile.MIPS.TMAIN_OFFSET] = r0;

   push r8;
   r8 = M[r8 + $mips_profile.MIPS.PTR_INT_OBJ_OFFSET];
   r0 = M[r8 + $mips_profile.MIPS.SMAIN_OFFSET];        // get running count from interrupt profile object
   pop r8;
   M[r8 + $mips_profile.MIPS.TINT_OFFSET] = r0;         // get current INT cycle sum
   r0 = M[r8 + $mips_profile.MIPS.STAT_OFFSET];
   if Z jump init;

   rts;


init:
   // get first us timestamp
   r0 = M[$TIMER_TIME];
   M[r8 + $mips_profile.MIPS.TEVAL_OFFSET] = r0;

   r0 = 1;
   M[r8 + $mips_profile.MIPS.STAT_OFFSET] = r0;
   M[r8 + $mips_profile.MIPS.SMAIN_OFFSET] = 0;
   M[r8 + $mips_profile.MIPS.SINT_OFFSET] = 0;

   rts;


mainend:
   // stop profiling main process

   r0 = M[r8 + $mips_profile.MIPS.STAT_OFFSET];         // not initialized yet
   if Z rts;

   r0 = M[PROFILE_ADDR];  // calc deltat
   r1 = M[r8 + $mips_profile.MIPS.TMAIN_OFFSET];
   r0 = r0 - r1;                                        // r0 = main cycles across profiled points
   push r8;
   r8 = M[r8 + $mips_profile.MIPS.PTR_INT_OBJ_OFFSET];       // get running total from interrupt object
   r2 = M[r8 + $mips_profile.MIPS.SMAIN_OFFSET];        // get current sum of interrupt cycles
   pop r8;
   r1 = M[r8 + $mips_profile.MIPS.TINT_OFFSET];         // get initial int count
   r1 = r2 - r1;                                        // r1 = diff interrupt cycles across profiled points
   r0 = r0 - r1;                                        // subtract interrupt cycles which occured during profile
   // r0 = diff of main cycles (not including interrupts) from mainstart to mainend  
   // r1 = diff of int cycles from mainstart to mainend
   r2 = M[r8 + $mips_profile.MIPS.SINT_OFFSET];         // accumulate int cycles
   r2 = r2 + r1;
   M[r8 + $mips_profile.MIPS.SINT_OFFSET] = r2;   
   r1 = M[r8 + $mips_profile.MIPS.SMAIN_OFFSET];        // accumulate main cycles
   r0 = r0 + r1;
   M[r8 + $mips_profile.MIPS.SMAIN_OFFSET] = r0;


   r0 = M[$TIMER_TIME];
   r1 = M[r8 + $mips_profile.MIPS.TEVAL_OFFSET];

   r0 = r0 - r1;
   r1 = M[evalinterval_us];
   Null = r0 - r1;

   if NEG rts;

   // interval has elapsed. evaluate and reset;
   r0 = M[r8 + $mips_profile.MIPS.SMAIN_OFFSET];
   M[r8 + $mips_profile.MIPS.MAIN_CYCLES_OFFSET] = r0;
   r1 = M[r8 + $mips_profile.MIPS.SINT_OFFSET];
   M[r8 + $mips_profile.MIPS.INT_CYCLES_OFFSET] = r1;
   r0 = r0 + r1;
   M[r8 + $mips_profile.MIPS.TOT_CYCLES_OFFSET] = r0;


   M[r8 + $mips_profile.MIPS.STAT_OFFSET] = 0;          // not initislized
   rts;


intstart:
   r0 = M[PROFILE_ADDR];
   M[r8 + $mips_profile.MIPS.TMAIN_OFFSET] = r0;
   r0 = M[r8 + $mips_profile.MIPS.STAT_OFFSET];
   if Z jump init_int;
   rts;

init_int:
   // get first us timestamp
   r0 = M[$TIMER_TIME];
   M[r8 + $mips_profile.MIPS.TEVAL_OFFSET] = r0;

   r0 = 1;
   M[r8 + $mips_profile.MIPS.STAT_OFFSET] = r0;        // status = 1 

   r0 =  M[r8 + $mips_profile.MIPS.SMAIN_OFFSET];       // SMAIN is freerunning and  never resets
   M[r8 + $mips_profile.MIPS.SMAIN_INT_OFFSET] = r0;   // we will track diff of SMAIN over profile period
   rts;
   


intend:
   r0 = M[PROFILE_ADDR];

   r1 = M[r8 + $mips_profile.MIPS.TMAIN_OFFSET];         
   r0 = r0 - r1;                                        // capture cycle delta across profiled int handler

   r1 = M[r8 + $mips_profile.MIPS.SMAIN_OFFSET];        
   r1 = r0 + r1;
   M[r8 + $mips_profile.MIPS.SMAIN_OFFSET] = r1;        // accumulate total int cycles

   r0 = M[$TIMER_TIME];
   r1 = M[r8 + $mips_profile.MIPS.TEVAL_OFFSET];

   r0 = r0 - r1;
   r1 = M[evalinterval_us];
   Null = r0 - r1;
   if NEG rts;

   r0 = M[r8 + $mips_profile.MIPS.SMAIN_INT_OFFSET]; // holds initial value of SMAIN
   r1 = M[r8 + $mips_profile.MIPS.SMAIN_OFFSET];
   r1 = r1 - r0;  // diff of SMAIN over profile period
   M[r8 + $mips_profile.MIPS.MAIN_CYCLES_OFFSET] = r1;  


   M[r8 + $mips_profile.MIPS.STAT_OFFSET] = 0;          // not initislized
   rts;

.ENDMODULE;

// *****************************************************************************
// MODULE:
//    $M.Sleep
//
// DESCRIPTION:
//    Place Processor in IDLE and compute system MIPS
//    To read total MIPS over SPI do ($M.Sleep.Mips*proc speed)/8000
//    proc speed is 80 for Gordon and 120 for Rick
//
// *****************************************************************************
.MODULE $M.Sleep;
   .CODESEGMENT PROFILE_PM;
   .DATASEGMENT DM;

   .VAR TotalTime=0;
   .VAR LastUpdateTm=0;
   .VAR Mips=0;
   .VAR sync_flag_esco=0;

$SystemSleepAudio:
   r2 = $frame_sync.sync_flag;
   jump SleepSetSync;

$SystemSleepEsco:
   r2 = sync_flag_esco;

SleepSetSync:
   // Set the sync flag to commence sleeping (wait for it being cleared)
   r0 = 1;
   M[r2] = r0;

   // Timer status for MIPs estimate
   r1 = M[$TIMER_TIME];
   r4 = M[$interrupt.total_time];
   // save current clock rate
   r6 = M[$CLOCK_DIVIDE_RATE];
   // go to slower clock and wait for task event
   r0 = $frame_sync.MAX_CLK_DIV_RATE;
   M[$CLOCK_DIVIDE_RATE] = r0;

   // wait in loop (delay) till sync flag is reset
jp_wait:
   Null = M[r2];
   if NZ jump jp_wait;

   // restore clock rate
   M[$CLOCK_DIVIDE_RATE] = r6;

   // r1 is total idle time
   r3 = M[$TIMER_TIME];
   r1 = r3 - r1;
   r4 = r4 - M[$interrupt.total_time];
   r1 = r1 + r4;
   r0 = M[&TotalTime];
   r1 = r1 + r0;
   M[&TotalTime]=r1;

   // Check for MIPs update
   r0 = M[LastUpdateTm];
   r5 = r3 - r0;
   rMAC = 1000000;
   NULL = r5 - rMAC;
   if NEG rts;

   // Time Period
   rMAC = rMAC ASHIFT -1;
   Div = rMAC/r5;
   // Total Processing (Time Period - Idle Time)
   rMAC = r5 - r1;
   // Last Trigger Time
   M[LastUpdateTm]=r3;
   // Reset total time count
   M[&TotalTime]=NULL;
   // MIPS
   r3  = DivResult;
   rMAC  = r3 * rMAC (frac);
   // Convert for UFE format
   // UFE uses STAT_FORMAT_MIPS - Displays (m_ulCurrent/8000.0*m_pSL->GetChipMIPS())
   // Multiply by 0.008 = 1,000,000 --> 8000 = 100% of MIPs
   r3 = 0.008;
   rMAC = rMAC * r3 (frac);  // Total MIPs Est
   M[Mips]=rMAC;
   rts;

.ENDMODULE;