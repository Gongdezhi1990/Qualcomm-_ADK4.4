/**************************************
resampler coefficient loader
input:  r7, r8
output: r9
trashes: none, M0-M2 get reset
TBD:  
**************************************/
#ifdef USE_IIR_RESAMPLER_COEFF_CACHE


.MODULE $resampler_cache;
   .CODESEGMENT RESAMPLER_CACHE_PM;
   .DATASEGMENT DM;

   .CONST filter_addr_field                 0;
   .CONST filter_size_field                 1;
   .CONST filter_entry_size                 2;        // entry_size

   .CONST filter_s1_func_ptr_offset         4;
   

.VAR resampler_coeffs_loader_lookup_table[] =
      // Standard resampled input rates
      $M.iir_resamplev2.Up_3_Down_1.filter,       40,                  
      $M.iir_resamplev2.Up_3_Down_2.filter,       38,                  
      $M.iir_resamplev2.Up_160_Down_147.filter,   44,                  
      $M.iir_resamplev2.Up_441_Down_160.filter,   42,                  
      $M.iir_resamplev2.Up_441_Down_320.filter,   44,                  
      $M.iir_resamplev2.Up_147_Down_160.filter,   44,                  
      0;       
      
/****************************************************
    Load Filter Coeff from FLASH to RAM
  Input:   r7   filter ptr in flash
           r8   cache start addr 
  Output:  r9   filter pointer addr
           r9 = r8,   if succeed
           r9 = Null  if failed
  trashes: None
  TBD: need optimization
****************************************************/
Func:      
    // Find_Index:
    // preserve all the regs 
    pushm <r0, r4, r10>;
    pushm <I0, I1, I4>;

    I0 = r7;    
    if NZ  jump check_cache_ptr;
    // filter ptr invalid, 
    jump use_original;

check_cache_ptr:
    // preload filter index
    r4 = &resampler_coeffs_loader_lookup_table + &filter_addr_field;
    I4 = r8;     
    if NZ  jump search;
    
    // invalid cache addr, stop 
use_original:
    r9 = r7;
    jump exit;
    

search:    
    r0  = M[r4];
    if  Z  jump  use_original;  // use original if not defined
    Null = r0 - r7;
    if  Z  jump found;
    r4 = r4 + filter_entry_size;
    jump  search;   
found:
/*****************************
// caches the overall filter 
*****************************/    
    // r4 is the index
    // r7 is the filter address in the flash
    // r8 is the RAM start address
    // I1 table index ptr
    // I0 is flash addr
    // I4 is RAM addr
    M1 = 1; M0 = Null; M2 = 2;
    r10 = M[r4 + filter_size_field];   // the filter size 
    r0 = M[I0, M1]; // linear addressing, start reading 
    do  lp_cache_filter;
      M[I4,M1] = r0, r0 = M[I0, M1];
lp_cache_filter:   
/****************************
// caches the S1 FIR  
*****************************/
    // cache s1 FIR 
    // I4 ptr to the next cache write address
    // r8 is the now the filter start addr,
    I1 = r8 + filter_s1_func_ptr_offset;
    r4 = I4,     r0 = M[I1,M1];              // first s1 func ptr, advance to first factor of s1 or s2 func ptr
    Null = r0,   r0 = M[I1,M1];              // first factor in s1, advance to iir size or s2 FIR size
    if  Z  jump  cache_s2;
    // S1 active
    r10 = r0, r0 = M[I1,M1];  // read iir size, advance to second factor in s1
    r0  = M[I1,M2];   // read second factor in s1, advance to FIR filter ptr    
    r10  = r10 * r0 (int), r0 = M[I1,M0];  // get total size, read FIR ptr in Flash
    I0   = r0; 
    M[I1,2] = r4;                         // write FIR ptr in Cache, advance to S2 func ptr  
    r10 = r10 ASHIFT -1;                  // total number 
    r0 = M[I0, M1]; 
    do  lp_cache_s1_fir_coeff;    
        M[I4,M1] = r0, r0 = M[I0, M1];
lp_cache_s1_fir_coeff:    
    r4 = I4, r0 = M[I1,M1];                 // s2 func ptr, 
cache_s2:
/****************************
// caches the S2 FIR  
*****************************/
    // r4, I4 ptr to the next cache write address, I1 is first factor in s2
    r0 = M[I1,M2];                          // read s2 first factor, advance to second factor  
    r10 = r0, r0 = M[I1,M2];
    r10 = r10 * r0 (int), r0 = M[I1,M1];    // advance to s2 FIR ptr  
    r10 = r10 ASHIFT -1;
    r0 = M[I1, M0];                         // read s2 FIR ptr
    I0 = r0,  M[I1, M0] = r4;    
    r0 = M[I0, M1]; 
    do  lp_cache_s2_fir_coeff;    
        M[I4,M1] = r0, r0 = M[I0, M1];
lp_cache_s2_fir_coeff:    

    M1 = M1-M1;
    M2 = M2-M2;

    r9 = r8;
    
exit:
// restore all the regs
   popm <I0, I1, I4>;
   popm <r0, r4, r10>;   
   rts;   
    
.ENDMODULE;      

#endif // USE_IIR_RESAMPLER_COEFF_CACHE

#ifdef USE_SRA_COEFF_CACHE  
#include "cbops_library.h"

 .MODULE $sra_cache;
   .DATASEGMENT DM2_SCRATCH;
   // dedicated coeff cache for interrupt
   .VAR mem[$cbops.rate_adjustment_and_shift.SRA_UPRATE * $cbops.rate_adjustment_and_shift.SRA_COEFFS_SIZE / 2];

.ENDMODULE;      

#endif // USE_SRA_COEFF_CACHE  

// alternative approach for NO_RIGHT_CHAN
#ifdef  LOWMEM_NO_RIGHT
#include "frame_sync_stream_macros.h"
#include "music_example.h"
#include "cbuffer.h"

  .MODULE  $M.utils;
  
   .CODESEGMENT PM;
   .DATASEGMENT DM;

   .VAR $master_flag = 0;
   .VAR $disable_flag = 0;
   .VAR $slave_flag = 0;
   
config_tws:

    $push_rLink_macro;
       
    pushm <r0, r3>; 
    call $block_interrupts;
    
      // setup AAC routing mode
      r3 = $TWS_ROUTING_DMIX;
      r0 = M[$tws.routing_mode];
      Null = r0 - $TWS_ROUTING_STEREO;
      if Z r0 = r3;
      M[$aacdec.routing_mode] = r0;  

       r3 = -1;
       M[$codec_rate_adj.stereo + $cbops.rate_adjustment_and_shift.Process.INPUT2_CBUFFER_ADDR_FIELD] = r3;
       M[$codec_rate_adj.stereo + $cbops.rate_adjustment_and_shift.Process.OUTPUT2_CBUFFER_ADDR_FIELD] = r3;
      
    call $unblock_interrupts;
    popm <r0, r3>;

    // aacdec.routing_mode get set in tws.audio_routing function in $relay.stop 
    jump $pop_rLink_and_rts;

/**************************************
//  (1) restore right channel cbuffer struc through overlay
//  (2) enable right channel through configuration
***************************************/     
     
config_a2dp:
    
    $push_rLink_macro;
    pushm <r0, r3, r4>; 
    
    call $block_interrupts;
    
#if defined(AAC_ENABLE) && defined(AAC_RIGHT_MEM_OVERLAY)

      // memory overlay
      r3 = $audio_out_right_cbuffer_struc_template;
      r4 = $audio_out_right_cbuffer_struc;
      call $M.copy_cbuffer_struc.func;

    //    codec_resamp_out overlay scheme
      r3 = $codec_resamp_out_right_cbuffer_struc_template;
      r4 = $codec_resamp_out_right_cbuffer_struc;
      call $M.copy_cbuffer_struc.func;  

#endif  // AAC_RIGHT_MEM_OVERLAY

      // rest buffers in right channel
        r4 = $audio_out_right_cbuffer_struc;
        call $M.utils.reset_cbuffer;
        r4 = $codec_resamp_out_right_cbuffer_struc;
        call $M.utils.reset_cbuffer;   
        r4 = $codec_rate_adj_out_right_cbuffer_struc;
        call $M.utils.reset_cbuffer;    

        
        // cbuffer sync
        r3 = $audio_out_left_cbuffer_struc;
        r4 = $audio_out_right_cbuffer_struc;
        call $M.utils.sync_cbuffer;
        
        r3 = $codec_resamp_out_left_cbuffer_struc;
        r4 = $codec_resamp_out_right_cbuffer_struc;
        call $M.utils.sync_cbuffer; 
        
        r3 = $codec_rate_adj_out_left_cbuffer_struc;
        r4 = $codec_rate_adj_out_right_cbuffer_struc;
        call $M.utils.sync_cbuffer;

        // no left to right copy for a2dp
        r3 = &$M.system_config.data.stream_map_left_in;
        M[$left_to_right_obj + $M.audio_proc.stream_gain.OFFSET_OUTPUT_PTR] = r3;
        
        // stereo AAC for a2dp
        M[$aacdec.routing_mode]= Null;
        M[$master_flag] = Null;
        M[$slave_flag] = Null;
        
        // stereo sra for a2dp
        r3 = $codec_rate_adj_out_right_cbuffer_struc;
        M[$codec_rate_adj.stereo + $cbops.rate_adjustment_and_shift.Process.OUTPUT2_CBUFFER_ADDR_FIELD] = r3;
        r3 = $codec_resamp_out_right_cbuffer_struc;
        r4 = $audio_out_right_cbuffer_struc;
        Null = M[$codec_resampler.resampler_active];
        if  Z  r3 = r4;   
        M[$codec_rate_adj.stereo + $cbops.rate_adjustment_and_shift.Process.INPUT2_CBUFFER_ADDR_FIELD] = r3;

        
   call $unblock_interrupts;
        
   popm <r0, r3, r4>;
   
   jump $pop_rLink_and_rts;
  
   
/**************************
input r3: source
      r4: dest
output: none
trashes      

***************************/
sync_cbuffer:

    $push_rLink_macro;
    pushm <r0, r1, r2>;
    push I0;    
   
      //  L/R synchronization
      r0  = r3;
      call  $cbuffer.calc_amount_data;
      // r0 amount of data
      r1 = M[r4 + $cbuffer.READ_ADDR_FIELD]; 
      r2 = M[r4 + $cbuffer.SIZE_FIELD]; 
      I0 = r1;
      L0 = r2;
#ifdef BASE_REGISTER_MODE
      r2 = M[r4 + $cbuffer.START_ADDR_FIELD]; 
      push r2;
      pop  B0;
#endif      
      M0 = r0; 
      r0 = r4,  r1 = M[I0, M0];
      r1 = I0;
      call $cbuffer.set_write_address;
      M0 = Null;
      L0 = Null;
#ifdef BASE_REGISTER_MODE
      push Null;
      pop  B0;
#endif      
  
   pop I0;
   popm <r0, r1, r2>;   
   jump $pop_rLink_and_rts;
   
/**************************
reset_cbuffer
input r4 cbuffer ptr
output: none
trashes: none
***************************/
reset_cbuffer:

    pushm <r0, r10>;
    push I0;    
   
      // reset content 
    r10 = M[r4 + $cbuffer.SIZE_FIELD]; 
    r0  = M[r4 + $cbuffer.READ_ADDR_FIELD]; 
    I0 = r0;
    L0 = r10;
#ifdef BASE_REGISTER_MODE
    r0 = M[r4 + $cbuffer.START_ADDR_FIELD]; 
    push r0;
    pop  B0;
#endif      

    r0 = Null;
    do  lp_cbuffer_reset;
          M[I0,1] = r0;
lp_cbuffer_reset:      
    L0 = Null;
#ifdef BASE_REGISTER_MODE
    push Null;
    pop  B0;
#endif      
  
   pop I0;
   popm <r0, r10>;   
   rts; 
  
  .ENDMODULE;
#endif  // LOWMEM_NO_RIGHT
