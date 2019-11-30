// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.        
// All Rights Reserved. 
// Notifications and licenses (if any) are retained for attribution purposes only.     
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************
#ifndef SEGMENTS_INCLUDED
#define SEGMENTS_INCLUDED
#if !(defined(KALASM3))
    // PM segments definitions, the order is based on priority  
    // the upper ones have higher priority to stay in RAM
    // math functions from math library better to be in RAM
   .define CELT_EC_DEC_UINT_PM                              PM
   .define CELT_EC_DECODE_BIN_PM                            PM
   .define CELT_EC_DECODE_PM                                PM
   .define CELT_EC_DEC_UPDATE_PM                            PM
   .define CELT_EC_DEC_BITS_PM                              PM
   .define CELT_EC_DECODE_RAW_PM                            PM
   .define CELT_EC_DEC_TELL_PM                              PM
   .define CELT_IDIV32_PM                                   PM
   .define CELT_LOG2_FRAC_PM                                PM   
   .define CELT_IMUSDIV32_PM                                PM
   .define CELT_CWRSI2_PM                                   PM
   .define CELT_CWRSI3_PM                                   PM
   .define CELT_CWRSI4_PM                                   PM
   .define CELT_CWRSI5_PM                                   PM
   .define CELT_UPREV_PM                                    PM
   .define CELT_UNEXT_PM                                    PM
   .define CELT_CWRSI_PM                                    PM
   .define CELT_NCWRS_UROW_PM                               PM
   .define CELT_EC_DEC_NORMALISE_PM                         PM
   .define CELT_EC_DEC_INIT_PM                              PM
   .define CELT_GET1BYTE_PM                                 PM
   .define CELT_GET1BYTE_FROM_END_PM                        PM
   .define CELT_INTERP_BITS2PULSES_PM                       PM
   .define CELT_BIT2PULSES_PM                               PM
   .define CELT_COMPUTE_ALLOCATION_PM                       PM
   .define CELT_DECODE_FLAGS_PM                             PM
   .define CELT_FRAME_DECODE_PM                             PM
   .define CELT_DECODER_FRAME_INIT_PM                       PM
   .define CELT_END_READING_FRAME_PM                        PM
   .define CELT_EC_LAPLACE_DECODE_START_PM                  PM
   .define CELT_DECODE_PULSES32_PM                          PM
   .define CELT_DECODE_PULSES_PM                            PM
   .define CELT_ALG_UNQUANT_PM                              PM
   .define CELT_DECODER_SET_PARAMETERS_PM                   PM   
   .define CELT_UNQUANT_COARSE_ENERGY_PM                    PM
   .define CELT_UNQUANT_FINE_ENERGY_PM                      PM
   .define CELT_QUANT_BANDS_PM                              PM
   .define CELT_UNQUANT_ENERGY_FINALISE_PM                  PM
   .define CELT_DENORMALISE_BANDS_PM                        PM
   .define CELT_RENORMALISE_BANDS_PM                        PM
   .define CELT_INTRA_FOLD_PM                               PM
   .define CELT_NORMALISE_RESIDUAL_PM                       PM
   .define CELT_EXP_ROTATION_PM                             PM
   .define CELT_RENORMALIZE_VECTOR_PM                       PM
   .define CELT_PITCH_DOWNSAMPLE_PM                         PM
   .define CELT_FILL_PLC_BUFFERS_PM                         PM     
   .define CELT_RUN_PLC_PM                                  PM
   .define PITCH_SEARCH_PM                                  PM
   .define CELT_FINE_BEST_PITCH_PM                          PM
   .define CELT_DEEMPHASIS_PM                               PM
   .define CELT_MDCT_SHAPE_PM                               PM
   .define CELT_IMDCT_RADIX2_PM                             PM
   .define CELT_IMDCT_WINDOW_OVERLAP_ADD_PM                 PM
   .define CELT_TRANSIENT_SYNTHESIS_PM                      PM
   .define CELT_WINDOWING_OVERLAPADD_PM                     PM   
   .define CELT_STEREO_TO_MONO_CONVERT_PM                   PM
   .define CELT_MONO_TO_STEREO_CONVERT_PM                   PM
   .define CELT_AUTOCORR_PM                                 PM
   .define CELT_CALCULATE_LPC_PM                            PM
   .define CELT_FIR_PM                                      PM
   .define CELT_IIR_PM                                      PM
   .define CELT_DECODER_INIT_PM                             PM
   .define CELT_DEC_PM                                      PM   
   .define CELT_ALLOC_STATE_MEM_PM                          PM
   .define CELT_ALLOC_SCRATCH_MEM_PM                        PM
   .define CELT_PM                                          PM
   .define CELT_ENC_PM                                      PM
   .define CELT_FRAME_ENCODE_PM                             PM
   .define CELT_ENCODER_INIT_PM                             PM
   .define CELT_PREEMPHASIS_PM                              PM
   .define CELT_MDCT_RADIX2_PM                              PM
   .define CELT_WINDOW_RESHUFFLE_PM                         PM
   .define CELT_MDCT_ANALYSIS_PM                            PM
   .define CELT_COMPUTE_BAND_ENERGIES_PM                    PM
   .define CELT_BAND_PROCESS_PM                             PM
   .define CELT_NORMALISE_BANDS_PM                          PM
   .define CELT_EC_ENC_INIT_PM                              PM
   .define CELT_PUT1BYTE_PM                                 PM
   .define CELT_PUT1BYTE_TO_END_PM                          PM
   .define CELT_ENCODER_FRAME_INIT_PM                       PM
   .define CELT_EC_ENC_CARRY_OUT_PM                         PM
   .define CELT_EC_ENC_NORMALISE_PM                         PM
   .define CELT_EC_ENCODE_PM                                PM
   .define CELT_EC_ENCODE_BIN_PM                            PM
   .define CELT_EC_ENCODE_RAW_PM                            PM
   .define CELT_EC_ENC_TELL_PM                              PM
   .define CELT_EC_ENC_BITS_PM                              PM
   .define CELT_EC_ENC_UINT_PM                              PM
   .define CELT_END_WRITING_FRAME_PM                        PM
   .define CELT_ENCODE_FLAGS_PM                             PM
   .define CELT_QUANT_COARSE_ENERGY_PM                      PM
   .define CELT_EC_LAPLACE_ENCODE_START_PM                  PM
   .define CELT_QUANT_FINE_ENERGY_PM                        PM
   .define CELT_ICWRS2_PM                                   PM
   .define CELT_ENCODE_PULSES_PM                            PM
   .define CELT_ICWRS3_PM                                   PM
   .define CELT_ICWRS4_PM                                   PM
   .define CELT_ICWRS5_PM                                   PM
   .define CELT_ICWRS_PM                                    PM
   .define CELT_ENCODE_PULSES32_PM                          PM
   .define CELT_QUANT_ENERGY_FINALISE_PM                    PM
   .define CELT_TRANSIENT_ANALYSIS_PM                       PM
   .define CELT_TRANSIENT_BLOCK_PROCESS_PM                  PM
   .define CELT_MDCT_NONRADIX2_PM                           PM
   .define CELT_IMDCT_NONRADIX2_PM                          PM
   .define CELT_QUANT_BANDS_STEREO_PM                       PM
   
   .define DM_SCRATCH                                       DM
   .define DM1_SCRATCH                                      DM1
   .define DM2_SCRATCH                                      DM2   
#endif
#endif
