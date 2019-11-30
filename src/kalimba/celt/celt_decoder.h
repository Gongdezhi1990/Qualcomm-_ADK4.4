// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef CELT_DECODER_HEADER_INCLUDED
#define CELT_DECODER_HEADER_INCLUDED
// -- First five fields are the same as other audio codecs
   .CONST   $celt.dec.DECODER_IN_BUFFER_FIELD                        0; // input buffer
   .CONST   $celt.dec.DECODER_OUT_LEFT_BUFFER_FIELD                  1; // left output buffer
   .CONST   $celt.dec.DECODER_OUT_RIGHT_BUFFER_FIELD                 2; // right output buffer
   .CONST   $celt.dec.DECODER_MODE_FIELD                             3;
   .CONST   $celt.dec.DECODER_NUM_OUTPUT_SAMPLES_FIELD               4;
   
   // -- Setting Fields 
   .CONST   $celt.dec.CELT_MODE_OBJECT_FIELD                         5;  // pointer to mode object
   .CONST   $celt.dec.CELT_CODEC_FRAME_SIZE_FIELD                    6;  // codec frame size
   .CONST   $celt.dec.CELT_CHANNELS_FIELD                            7;  // 0->mono 1-> stereo
   .CONST   $celt.dec.IMDCT_FUNCTION_FIELD                           8;  // imdct function
   .CONST   $celt.dec.IMDCT_SHORT_FUNCTION_FIELD                     9;  // imdct function for short blocks
   .CONST   $celt.dec.PLC_ENABLED_FIELD                             10;  // Enable PLC or not
   .CONST   $celt.dec.PLC_HIST_LEFT_BUFFER_FIELD                    11;  // buffer for plc left
   .CONST   $celt.dec.PLC_HIST_RIGHT_BUFFER_FIELD                   12;  // buffer for plc right
   .CONST   $celt.dec.PLC_LPC_COEFSS_FIELD                          13;  // address to store LPC coeffs (for both channels)
   .CONST   $celt.dec.REINIT_DECODER_FIELD                          14;  // if NZ decoder gets reinitialized
   .CONST   $celt.dec.SYNC_BYTE_FIELD                               15;  // if NZ a sync byte is expected at the beginning of frame
   .CONST   $celt.dec.RUN_PLC_FIELD                                 16;  // if set, runs plc instead of decoder   
   .CONST   $celt.dec.TELL_FUNC_FIELD                               17;
   .CONST   $celt.dec.ALG_QUANT_FUNC_FIELD                          18;
   .CONST   $celt.dec.EC_UINT_FUNC_FIELD                            19;   
   
   // -- Mode fields 
   .CONST   $celt.dec.MODE_FIELDS_OFFSET_FIELD                      20;
   .CONST   $celt.dec.MODE_FS_FIELD                                 20;  // sampling rate of the stream
   .CONST   $celt.dec.MODE_OVERLAP_FIELD                            21;  // overlap size
   .CONST   $celt.dec.MODE_MDCT_SIZE_FIELD                          22;  // audio frame size
   .CONST   $celt.dec.MODE_AUDIO_FRAME_SIZE_FIELD                   22;
   .CONST   $celt.dec.MODE_NB_EBANDS_FIELD                          23;  // number of energy bands
   .CONST   $celt.dec.MODE_PITCH_END_FIELD                          24;  // pitch end (not use currently)
   .CONST   $celt.dec.MODE_E_PRED_COEF_FIELD                        25;  // pre/de emphasis coefficient
   .CONST   $celt.dec.MODE_NB_ALLOC_VECTORS_FIELD                   26;  // number of alloc tables
   .CONST   $celt.dec.MODE_NB_SHORT_MDCTS_FIELD                     27;  // number of short blocks per frame
   .CONST   $celt.dec.MODE_SHORT_MDCT_SIZE_FIELD                    28;  // size of short blocks = audio frame size / number of short blocks per frame
   .CONST   $celt.dec.MODE_EBANDS_ADDR_FIELD                        29;  // address to read enegy bands boundaries
   .CONST   $celt.dec.MODE_ALLOC_VECTORS_ADDR_FIELD                 30;  // address to read allocation vectors
   .CONST   $celt.dec.MODE_WINDOW_ADDR_FIELD                        31;  // address to read windowing data
   .CONST   $celt.dec.MODE_PROB_ADDR_FIELD                          32;  // address to read prob data
   .CONST   $celt.dec.MODE_BITS_VECTORS_ADDR_FIELD                  33;  // address to read bit vectors
   .CONST   $celt.dec.MODE_EBNADS_DIF_SQRT_ADDR_FIELD               34;  // address to read sqrt(diff(bands))
   .CONST   $celt.dec.MODE_TRIG_OFFSET_FIELD                        35;  // address to read trig coeffs
   // -- These fields are mode specefic 
   .CONST   $celt.dec.MODE_EXTRA1_FIELD                             36;
   .CONST   $celt.dec.MODE_EXTRA2_FIELD                             37;
   .CONST   $celt.dec.MODE_EXTRA3_FIELD                             38;
   .CONST   $celt.dec.MODE_EXTRA4_FIELD                             39;
   
   // -- State vectors addresses (needs to be allocated)
   .CONST   $celt.dec.OLD_EBAND_LEFT_FIELD                          40;  // saves band energies (required for when intra energy is not forced)
   .CONST   $celt.dec.OLD_EBAND_RIGHT_FIELD                         41;  // saves band energies for right channel
   .CONST   $celt.dec.HIST_OLA_LEFT_FIELD                           42;  // history for overlap-add operation
   .CONST   $celt.dec.HIST_OLA_RIGHT_FIELD                          43;  // history for overlap-add operation(right channel)
           
   // -- State fields 
   .CONST   $celt.dec.DEEMPH_HIST_SAMPLE_FIELD                      44;  // history of de-emphasis filter(one sample per channel)
   .CONST   $celt.dec.GET_BYTE_POS_FIELD                            46;  // byte position of the input buffer to get data from
   .CONST   $celt.dec.PLC_COUNTER_FIELD                             47;  // plc run counter
   .CONST   $celt.dec.PLC_LAST_PITCH_INDEX_FIELD                    48;  // plc pitch detected
   .CONST   $celt.dec.LAST_DECAY_FIELD                              50;  // plc decay
   
   // -- scratch vectors adresses(needs to be allocated)
   //  - can be reused when frame_decode returns
   //  - many of these vectors can overlap
   //  - alloc_scratch_mem can allocate all vectors from a scratch pool 
   .CONST   $celt.dec.DM1_SCRATCH_FIELDS_OFFSET                     52;
   .CONST   $celt.dec.DM1_SCRATCH_FIELDS_LENGTH                     14;
   .CONST   $celt.dec.BITS1_FIELD                                   52;   // normal, DM, size = NEbands
   .CONST   $celt.dec.BITS2_FIELD                                   53;   // normal, DM, size = NEbands
   .CONST   $celt.dec.ALG_UNQUANT_ST_FIELD                          54;   // normal, DM, size = FrameSize/2
   .CONST   $celt.dec.UVECTOR_FIELD                                 55;   // normal, DM, size = 130
   .CONST   $celt.dec.NORM_FREQ_FIELD                               56;   // normal, DM, size = FrameSize*C
   .CONST   $celt.dec.BANDE_FIELD                                   57;   // normal, DM, size = 2*NEbands*C
   .CONST   $celt.dec.IMDCT_OUTPUT_FIELD                            58;   // circ, DM1, size = FrameSize
   .CONST   $celt.dec.SHORT_HIST_FIELD                              59;   // circ, DM1, size = Ov
   .CONST   $celt.dec.TEMP_FFT_FIELD                                60;   // normal, DM, size = FrameSize/2
   .CONST   $celt.dec.PLC_EXC_FIELD                                 61;   // normal, DM1 , size = 1024
   .CONST   $celt.dec.PLC_PITCH_BUF_FIELD                           62;   // normal, DM, size = 512
   .CONST   $celt.dec.PLC_XLP4_FIELD                                63;   // normal, DM, size = (FrameSize+Ov)/4 
   .CONST   $celt.dec.PLC_AC_FIELD                                  64;   // normal, DM, size = 2*(LPC_order+1)
   .CONST   $celt.dec.TRANSIENT_PROC_FIELD                          65;   // normal, DM, size = FrameSize

   // -- Scratch vectors addresses in DM2 (just for cpu usage and balance concerns)
   .CONST   $celt.dec.DM2_SCRATCH_FIELDS_OFFSET                     70;
   .CONST   $celt.dec.DM2_SCRATCH_FIELDS_LENGTH                     13;
   .CONST   $celt.dec.PULSES_FIELD                                  70;   // normal, DM, size = NEbands
   .CONST   $celt.dec.FINE_QUANT_FIELD                              71;   // normal, DM, size = NEbands
   .CONST   $celt.dec.FINE_PRIORITY_FIELD                           72;   // normal, DM, size = NEbands
   .CONST   $celt.dec.NORM_FIELD                                    73;   // normal, DM, size = FrameSize
   .CONST   $celt.dec.FREQ_FIELD                                    74;   // Circular, DM2, size = FrameSize
   .CONST   $celt.dec.FREQ2_FIELD                                   75;   // Circular, DM2, size = FrameSize
   .CONST   $celt.dec.SHORT_FREQ_FIELD                              76;   // Circular, DM2, size = FrameSize
   .CONST   $celt.dec.PLC_EXC_COPY_FIELD                            77;   // Circ, DM2, size = 1024
   .CONST   $celt.dec.PLC_E_FIELD                                   78;   // Normal, DM, size = 512
   .CONST   $celt.dec.PLC_YLP4_FIELD                                79;   // normal, DM, size = 256
   .CONST   $celt.dec.PLC_MEM_LPC_FIELD                             80;   // Circ, DM2, size = 25
   .CONST   $celt.dec.PLC_XCORR_FIELD                               81;   // Normal, DM, size = max 512
   .CONST   $celt.dec.TEMP_VECT_FIELD                               82;   // Normal, DM, size = max 64
   
   // -- some single frequently used scratch fileds
   .CONST   $celt.dec.INTRA_ENER_FIELD                              90;
   .CONST   $celt.dec.SHORT_BLOCKS_FIELD                            91;
   .CONST   $celt.dec.HAS_PITCH_FIELD                               92;
   .CONST   $celt.dec.HAS_FOLD_FIELD                                93;
   .CONST   $celt.dec.TRANSIENT_TIME_FIELD                          94;
   .CONST   $celt.dec.TRANSIENT_SHIFT_FIELD                         95;
   .CONST   $celt.dec.MDCT_WEIGHT_SHIFT_FIELD                       96;
   .CONST   $celt.dec.MDCT_WEIGHT_POS_FIELD                         97;
  

   .CONST   $celt.dec.STRUC_SIZE                                   100;
#endif //.ifndef CELT_DECODER_HEADER_INCLUDED

  