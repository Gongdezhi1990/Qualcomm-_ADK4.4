// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifndef CELT_ENCODER_HEADER_INCLUDED
#define CELT_ENCODER_HEADER_INCLUDED
   // -- First five fields are the same as other audio codecs
   .CONST   $celt.enc.ENCODER_OUT_BUFFER_FIELD                      0; // input buffer
   .CONST   $celt.enc.ENCODER_IN_LEFT_BUFFER_FIELD                  1; // left output buffer
   .CONST   $celt.enc.ENCODER_IN_RIGHT_BUFFER_FIELD                 2; // right output buffer
   .CONST   $celt.enc.ENCODER_MODE_FIELD                            3;
   
   // -- Setting Fields 
   .CONST   $celt.enc.CELT_MODE_OBJECT_FIELD                        5;  // pointer to mode object
   .CONST   $celt.enc.CELT_CODEC_FRAME_SIZE_FIELD                   6;  // codec frame size
   .CONST   $celt.enc.CELT_CHANNELS_FIELD                           7;  // 0->mono 1-> stereo
   .CONST   $celt.enc.MDCT_FUNCTION_FIELD                           8;  // imdct function
   .CONST   $celt.enc.MDCT_SHORT_FUNCTION_FIELD                     9;  // imdct function for short blocks
   .CONST   $celt.enc.REINIT_ENCODER_FIELD                          10; // if NZ decoder gets reinitialized
   .CONST   $celt.enc.SYNC_BYTE_FIELD                               11; // if NZ a sync byte is expected at the beginning of frame
   .CONST   $celt.enc.ENABLE_PITCH_FIELD                            12; // if NZ a sync byte is expected at the beginning of frame
   .CONST   $celt.enc.PREDICTION_ENERGY_FIELD                       13; // if NZ a sync byte is expected at the beginning of frame
   .CONST   $celt.enc.TELL_FUNC_FIELD                               17;
   .CONST   $celt.enc.ALG_QUANT_FUNC_FIELD                          18;
   .CONST   $celt.enc.EC_UINT_FUNC_FIELD                            19;
   
   // -- Mode fields 
   .CONST   $celt.enc.MODE_FIELDS_OFFSET_FIELD                      20;
   .CONST   $celt.enc.MODE_FS_FIELD                                 20;  // sampling rate of the stream
   .CONST   $celt.enc.MODE_OVERLAP_FIELD                            21;  // overlap size
   .CONST   $celt.enc.MODE_MDCT_SIZE_FIELD                          22;  // audio frame size
   .CONST   $celt.enc.MODE_AUDIO_FRAME_SIZE_FIELD                   22;
   .CONST   $celt.enc.MODE_NB_EBANDS_FIELD                          23;  // number of energy bands
   .CONST   $celt.enc.MODE_PITCH_END_FIELD                          24;  // pitch end (not use currently)
   .CONST   $celt.enc.MODE_E_PRED_COEF_FIELD                        25;  // pre/de emphasis coefficient
   .CONST   $celt.enc.MODE_NB_ALLOC_VECTORS_FIELD                   26;  // number of alloc tables
   .CONST   $celt.enc.MODE_NB_SHORT_MDCTS_FIELD                     27;  // number of short blocks per frame
   .CONST   $celt.enc.MODE_SHORT_MDCT_SIZE_FIELD                    28;  // size of short blocks = audio frame size / number of short blocks per frame
   .CONST   $celt.enc.MODE_EBANDS_ADDR_FIELD                        29;  // address to read enegy bands boundaries
   .CONST   $celt.enc.MODE_ALLOC_VECTORS_ADDR_FIELD                 30;  // address to read allocation vectors
   .CONST   $celt.enc.MODE_WINDOW_ADDR_FIELD                        31;  // address to read windowing data
   .CONST   $celt.enc.MODE_PROB_ADDR_FIELD                          32;  // address to read prob data
   .CONST   $celt.enc.MODE_BITS_VECTORS_ADDR_FIELD                  33;  // address to read bit vectors
   .CONST   $celt.enc.MODE_EBNADS_DIF_SQRT_ADDR_FIELD               34;  // address to read sqrt(diff(bands))
   .CONST   $celt.enc.MODE_TRIG_OFFSET_FIELD                        35;  // address to read trig coeffs

   // -- These fields are mode specefic 
   .CONST   $celt.enc.MODE_EXTRA1_FIELD                             36;
   .CONST   $celt.enc.MODE_EXTRA2_FIELD                             37;
   .CONST   $celt.enc.MODE_EXTRA3_FIELD                             38;
   .CONST   $celt.enc.MODE_EXTRA4_FIELD                             39;
   
   // -- State vectors addresses (needs to be allocated)
   .CONST   $celt.enc.OLD_EBAND_LEFT_FIELD                          40;  // saves band energies (required for when intra energy is not forced)
   .CONST   $celt.enc.OLD_EBAND_RIGHT_FIELD                         41;  // saves band energies for right channel
   .CONST   $celt.enc.HIST_OLA_LEFT_FIELD                           42;  // history for overlap-add operation
   .CONST   $celt.enc.HIST_OLA_RIGHT_FIELD                          43;  // history for overlap-add operation(right channel)
           
   // -- State fields 
   .CONST   $celt.enc.PREEMPH_HIST_SAMPLE_FIELD                     44;  // history of de-emphasis filter(one sample per channel)
   .CONST   $celt.enc.PUT_BYTE_POS_FIELD                            46;  // byte position of the input buffer to get data from

   // -- scratch vectors adresses(needs to be allocated)
   //  - can be reused when frame_decode returns
   //  - many of these vectors can overlap
   //  - alloc_scratch_mem can allocate all vectors from a scratch pool 
   .CONST   $celt.enc.DM1_SCRATCH_FIELDS_OFFSET                     52;
   .CONST   $celt.enc.DM1_SCRATCH_FIELDS_LENGTH                     14;
   .CONST   $celt.enc.BITS1_FIELD                                   52;   // normal, DM, size = NEbands
   .CONST   $celt.enc.BITS2_FIELD                                   53;   // normal, DM, size = NEbands
   .CONST   $celt.enc.ALG_QUANT_ST_FIELD                            54;   // normal, DM, size = FrameSize/2
   .CONST   $celt.enc.UVECTOR_FIELD                                 55;   // normal, DM, size = 130
   .CONST   $celt.enc.NORM_FREQ_FIELD                               56;   // normal, DM, size = FrameSize*C
   .CONST   $celt.enc.BANDE_FIELD                                   57;   // normal, DM, size = 2*NEbands*C
   .CONST   $celt.enc.MDCT_INPUT_IMAG_FIELD                         58;
   .CONST   $celt.enc.PREEMPH_LEFT_AUDIO_FIELD                      59;
   .CONST   $celt.enc.LOG_BANDE_FIELD                               60;
   .CONST   $celt.enc.BAND_ERROR_FIELD                              61;
   .CONST   $celt.enc.TRANSIENT_PROC_FIELD                          62;   // normal, DM, size = FrameSize

   // -- Scratch vectors addresses in DM2 (just for cpu usage and balance concerns)
   .CONST   $celt.enc.DM2_SCRATCH_FIELDS_OFFSET                     70;
   .CONST   $celt.enc.DM2_SCRATCH_FIELDS_LENGTH                     13;
   .CONST   $celt.enc.PULSES_FIELD                                  70;   // normal, DM, size = NEbands
   .CONST   $celt.enc.FINE_QUANT_FIELD                              71;   // normal, DM, size = NEbands
   .CONST   $celt.enc.FINE_PRIORITY_FIELD                           72;   // normal, DM, size = NEbands
   .CONST   $celt.enc.NORM_FIELD                                    73;   // normal, DM, size = FrameSize
   .CONST   $celt.enc.FREQ_FIELD                                    74;   // Circular, DM2, size = FrameSize
   .CONST   $celt.enc.FREQ2_FIELD                                   75;   // Circular, DM2, size = FrameSize
   .CONST   $celt.enc.SHORT_FREQ_FIELD                              76;   // Circular, DM2, size = FrameSize   
   .CONST   $celt.enc.MDCT_INPUT_REAL_FIELD                         77;
   .CONST   $celt.enc.PREEMPH_RIGHT_AUDIO_FIELD                     78;
   .CONST   $celt.enc.ABS_NORM_FIELD                                79;
   
   .CONST   $celt.enc.TEMP_VECT_FIELD                               82;   // Normal, DM, size = max 64
   
    // -- some single frequently used scratch fileds
   .CONST   $celt.enc.INTRA_ENER_FIELD                              90;
   .CONST   $celt.enc.SHORT_BLOCKS_FIELD                            91;
   .CONST   $celt.enc.HAS_PITCH_FIELD                               92;
   .CONST   $celt.enc.HAS_FOLD_FIELD                                93;
   .CONST   $celt.enc.TRANSIENT_TIME_FIELD                          94;
   .CONST   $celt.enc.TRANSIENT_SHIFT_FIELD                         95;
   .CONST   $celt.enc.MDCT_WEIGHT_SHIFT_FIELD                       96;
   .CONST   $celt.enc.MDCT_WEIGHT_POS_FIELD                         97;

   .CONST   $celt.enc.STRUC_SIZE                                   100;
#endif //.ifndef CELT_DECODER_HEADER_INCLUDED

  