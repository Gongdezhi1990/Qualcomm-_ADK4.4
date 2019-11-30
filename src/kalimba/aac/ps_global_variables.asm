// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#ifdef AACDEC_PARAMETRIC_STEREO_ADDITIONS

// *****************************************************************************
// MODULE:
//    $aacdec.variables
//
// DESCRIPTION:
//    Variables
//
// *****************************************************************************
.MODULE $aacdec;
   .DATASEGMENT DM;

   //    PS Variables
   .VAR parametric_stereo_present = 0;

   .VAR ps_info[PS_INFO_SIZE];

   .VAR ps_X_hybrid_right_imag[320];  // 320 = (PS_NUM_HYBRID_SUB_SUBBANDS - 2) * PS_NUM_SAMPLES_PER_FRAME

   .VAR ps_num_sub_subbands_per_hybrid_qmf_subband [] =
                                                         6, 2, 2;

   .VAR ps_hybrid_qmf_sub_subband_offset [] =
                                                0, 6, 8;

   .VAR/DM1CIRC ps_hybrid_type_a_fir_filter_input_buffer[13];

   .VAR ps_hybrid_type_a_ifft_struc[3];

   .VAR/DMCIRC ps_hybrid_type_b_fir_filter_coefficients[3] =
                                                               0.01899487526049, -0.07293139167538, 0.30596630545168;

   // make sure in a different bank to ps_info
   .VAR/DM2 ps_iid_index_prev[PS_MAX_NUM_PARAMETERS];
   .VAR/DM2 ps_icc_index_prev[PS_MAX_NUM_PARAMETERS];


   .VAR ps_time_history_real[36];  // 36 = PS_NUM_HYBRID_QMF_BANDS_WHEN_20_PAR_BANDS * (PS_HYBRID_ANALYSIS_FIR_FILTER_LENGTH - 1)
   .VAR ps_time_history_imag[36];  // 36 = PS_NUM_HYBRID_QMF_BANDS_WHEN_20_PAR_BANDS * (PS_HYBRID_ANALYSIS_FIR_FILTER_LENGTH - 1)

   .VAR X_ps_hybrid_real_address [] =
                                       &$aacdec.synth_temp, &$aacdec.synth_temp + (2*((PS_NUM_HYBRID_SUB_SUBBANDS - 2) * PS_NUM_SAMPLES_PER_FRAME));

   .VAR X_ps_hybrid_imag_address [] =
                                       &$aacdec.synth_temp + ((PS_NUM_HYBRID_SUB_SUBBANDS - 2) * PS_NUM_SAMPLES_PER_FRAME), &$aacdec.ps_X_hybrid_right_imag;

   // permanent buffers used in decorrelation
   .BLOCK/DM1 ps_power_peak_decay_nrg_prev_block;
      .VAR ps_power_peak_decay_nrg_prev[PS_NUM_PAR_BANDS_IN_BASELINE_DECORRELATION];
      .VAR ps_power_peak_decay_nrg_prev_exponent[PS_NUM_PAR_BANDS_IN_BASELINE_DECORRELATION];
   .ENDBLOCK;

   .BLOCK/DM2 ps_power_smoothed_peak_decay_diff_nrg_prev_block;
      .VAR ps_power_smoothed_peak_decay_diff_nrg_prev[PS_NUM_PAR_BANDS_IN_BASELINE_DECORRELATION];
      .VAR ps_power_smoothed_peak_decay_diff_nrg_prev_exponent[PS_NUM_PAR_BANDS_IN_BASELINE_DECORRELATION];
   .ENDBLOCK;

   .BLOCK ps_smoothed_input_power_prev_block;
      .VAR ps_smoothed_input_power_prev[PS_NUM_PAR_BANDS_IN_BASELINE_DECORRELATION];
      .VAR ps_smoothed_input_power_prev_exponent[PS_NUM_PAR_BANDS_IN_BASELINE_DECORRELATION];
   .ENDBLOCK;

   // number of parameter bands for IID and ICC information : indexed by PS_IID_MODE and PS_ICC_MODE respectively
   .VAR ps_nr_par_table [] =
                        10, 20, 34, 10, 20, 34, 0, 0;

   // number of parameter bands for IPDOPD information : indexed by PS_IID_MODE = PS_IPD_MODE
   .VAR ps_nr_ipdopd_par_tab [] =
                        5, 11, 17, 5, 11, 17, 0, 0;

    // number of parametric stereo envelopes that the 32 element time-frame is split into
    // indexed by PS_FRAME_CLASS and PS_NUM_ENV_INDEX
   .VAR ps_num_env_tab [] =
                        0, 1, 2, 4,
                        1, 2, 3, 4;


   .VAR/DM2 map_freq_bands_to_20_par_bands_table [] =
                         1, 0, 0, 1, 2, 3,  // QMF channel_0 = 6 hybrid sub-subbands
                         4,             5,  // QMF channel_1 = 2 hybrid sub-subbands
                         6,             7,  // QMF channel_2 = 2 hybrid sub-subbands
                         8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19;

   .VAR map_freq_bands_to_20_par_bands_x_num_samples_per_frame_table [] =
                         32, 0, 0, 32, 64, 96,  // QMF channel_0 = 6 hybrid sub-subbands
                         128,             160,  // QMF channel_1 = 2 hybrid sub-subbands
                         192,             224,  // QMF channel_2 = 2 hybrid sub-subbands
                         256, 288, 320, 352, 384, 416, 448, 480, 512, 544, 576, 608;


   .VAR/DM1 frequency_border_table_20_par_bands [] =
                         // Low Frequency section
                         6, 7, 0, 1, 2, 3, // 6 hybrid sub-subbands +
                         9, 8,             // 2 hybrid sub-subbands +
                         10,11,            // 2 hybrid sub-\subbands - 3 = 7 extra frequencies intoduced by hybrid analysis
                         // High Frequency section : qmf_channel_number = sub-subband index - num_of_extra_freqs
                         10-7, 11-7, 12-7, 13-7, 14-7, 15-7, 16-7, 18-7, 21-7, 25-7, 30-7, 42-7, 71-7;


   .VAR/DM1 ps_prev_frame_last_two_hybrid_samples_real [20*2/* 2*(X_SBR_WIDTH - PS_NUM_HYBRID_QMF_BANDS_WHEN_20_PAR_BANDS)*/];
   .VAR/DM2 ps_prev_frame_last_two_hybrid_samples_imag [20*2/* 2*(X_SBR_WIDTH - PS_NUM_HYBRID_QMF_BANDS_WHEN_20_PAR_BANDS)*/];

   // ONLY NEED FOR NON-HYBRID BANDS [3:22]
   .VAR/DM1 ps_prev_frame_last_two_qmf_samples_real [20*2/* 2*(X_SBR_WIDTH - PS_NUM_HYBRID_QMF_BANDS_WHEN_20_PAR_BANDS)*/];
   .VAR/DM2 ps_prev_frame_last_two_qmf_samples_imag [20*2/* 2*(X_SBR_WIDTH - PS_NUM_HYBRID_QMF_BANDS_WHEN_20_PAR_BANDS)*/];


   .VAR ps_hybrid_allpass_feedback_buffer[120*2];
   .VAR ps_qmf_allpass_feedback_buffer[240*2];


   .VAR ps_long_delay_band_buffer_real[(PS_DECORRELATION_SHORT_DELAY_BAND - PS_DECORRELATION_NUM_ALLPASS_BANDS - 1)*PS_DECORRELATION_LONG_DELAY_IN_SAMPLES];
   .VAR ps_long_delay_band_buffer_imag[(PS_DECORRELATION_SHORT_DELAY_BAND - PS_DECORRELATION_NUM_ALLPASS_BANDS - 1)*PS_DECORRELATION_LONG_DELAY_IN_SAMPLES];
   .VAR/DM1 ps_short_delay_band_buffer_real[(64 - PS_DECORRELATION_SHORT_DELAY_BAND + 1)*PS_DECORRELATION_SHORT_DELAY_IN_SAMPLES];
   .VAR/DM2 ps_short_delay_band_buffer_imag[(64 - PS_DECORRELATION_SHORT_DELAY_BAND + 1)*PS_DECORRELATION_SHORT_DELAY_IN_SAMPLES];


   .VAR ps_h11_previous_envelope[PS_NUM_FREQ_BANDS_WHEN_20_PAR_BANDS];
   .VAR ps_h21_previous_envelope[PS_NUM_FREQ_BANDS_WHEN_20_PAR_BANDS];
   .VAR ps_h12_previous_envelope[PS_NUM_FREQ_BANDS_WHEN_20_PAR_BANDS];
   .VAR ps_h22_previous_envelope[PS_NUM_FREQ_BANDS_WHEN_20_PAR_BANDS];

   .VAR ps_iid_coarse_resolution_scale_factor_table [] =
           0.998422594908967, 0.992168508372590, 0.980669920865967, 0.953462612844232, 0.913051202983263, 0.845726164365877, 0.783030535530853,
           0.707106781186547, 0.621983254865676, 0.533617118572725, 0.407844979956312, 0.301511347115414, 0.195669378418107, 0.124906610995573,
           0.056145429030366;

   .VAR ps_iid_fine_resolution_scale_factor_table [] =
           0.999995009542206, 0.999984219941253, 0.999949996750861, 0.999841932237787, 0.999500374135919, 0.998422594908967, 0.996860042647559,
           0.993764188091722, 0.987672366863856, 0.975844865385273, 0.953462612844232, 0.929081841143710, 0.894002260435438, 0.845726164365877,
           0.783030535530853, 0.707106781186547, 0.621983254865676, 0.533617118572725, 0.448062514290066, 0.369874167606096, 0.301511347115414,
           0.218464459272730, 0.156535513227950, 0.111502174562231, 0.079183407428288, 0.056145429030366, 0.031606978033073, 0.017779982577601,
           0.009999499846593, 0.005623324094457, 0.003162261923507;

   .VAR ps_cos_alpha_table [] =
            1.0000000000, 0.9841239700, 0.9594738210, 0.8946843079, 0.8269340931, 0.7071067812, 0.4533210856, 0.0000000000;

   .VAR ps_sin_alpha_table [] =
            0.0000000000, 0.1774824264, 0.2817977763, 0.4466989918, 0.5622988580, 0.7071067812, 0.8913472911, 1.0000000000;

   .VAR ps_alpha_angle_table [] =
            0.0, 0.089213818581134, 0.142833665101547, 0.231536180345483, 0.298581576069109, 0.392699081698724, 0.550154297180687, 0.785398163397449;


   #ifdef AACDEC_PARAMETRIC_STEREO_PHI_FRACT_TABLES_IN_FLASH
      #include "ps_decorrelation_tables_flash.asm"
   #else

      .VAR/DM1 ps_phi_fract_qmf_bands_real [] =
                           0.8181497455,  -0.2638730407, -0.9969173074, -0.4115143716, 0.7181262970,  0.8980275989,
                           -0.1097343117, -0.9723699093, -0.5490227938, 0.6004202366,  0.9557930231,  0.0471064523,
                           -0.9238795042, -0.6730124950, 0.4679298103,  0.9900236726,  0.2027872950,  -0.8526401520,
                           -0.7804304361, 0.3239174187,  0.9998766184,  0.3534748554,  -0.7604059577, -0.8686315417,
                           0.1719291061,  0.9851093292,  0.4954586625,  -0.6494480371, -0.9354440570, 0.0157073177,
                           0.9460853338,  0.6252426505,  -0.5224985480, -0.9792228341, -0.1409012377, 0.8837656379,
                           0.7396311164,  -0.3826834261, -0.9988898635, -0.2940403223, 0.7996846437,  0.8358073831,
                           -0.2334453613, -0.9939609766, -0.4399391711, 0.6959127784,  0.9114032984,  -0.0784590989,
                           -0.9645574093, -0.5750052333, 0.5750052333,  0.9645574093,  0.0784590989,  -0.9114032984,
                           -0.6959127784, 0.4399391711,  0.9939609766,  0.2334453613,  -0.8358073831, -0.7996846437,
                           0.2940403223,  0.9988898635,  0.3826834261,  -0.7396311164;


      .VAR/DM2 ps_phi_fract_qmf_bands_imag [] =
                           -0.5750052333, -0.9645574093, -0.0784590989, +0.9114032984, +0.6959127784, -0.4399391711,
                           -0.9939609766, -0.2334453613, +0.8358073831, +0.7996846437, -0.2940403223, -0.9988898635,
                           -0.3826834261, +0.7396311164, +0.8837656379, -0.1409012377, -0.9792228341, -0.5224985480,
                           +0.6252426505, +0.9460853338, +0.0157073177, -0.9354440570, -0.6494480371, +0.4954586625,
                           +0.9851093292, +0.1719291061, -0.8686315417, -0.7604059577, +0.3534748554, +0.9998766184,
                           +0.3239174187, -0.7804304361, -0.8526401520, +0.2027872950, +0.9900236726, +0.4679298103,
                           -0.6730124950, -0.9238795042, +0.0471064523, +0.9557930231, +0.6004202366, -0.5490227938,
                           -0.9723699093, -0.1097343117, +0.8980275989, +0.7181262970, -0.4115143716, -0.9969173074,
                           -0.2638730407, +0.8181497455, +0.8181497455, -0.2638730407, -0.9969173074, -0.4115143716,
                           +0.7181262970, +0.8980275989, -0.1097343117, -0.9723699093, -0.5490227938, +0.6004202366,
                           +0.9557930231, +0.0471064523, -0.9238795042, -0.6730124950;

      .VAR g_decay_slope_filter_20_parameter_bands_qmf_bands_table [] =
                           0.651428222656250, 0.564697265625000, 0.489532470703125,   0.618865966796875, 0.536468505859375, 0.465057373046875,
                           0.586273193359375, 0.508239746093750, 0.440582275390625,   0.553710937500000, 0.479980468750000, 0.416107177734375,
                           0.521148681640625, 0.451751708984375, 0.391632080078125,   0.488555908203125, 0.423522949218750, 0.367126464843750,
                           0.455993652343750, 0.395294189453125, 0.342651367187500,   0.423431396484375, 0.367065429687500, 0.318176269531250,
                           0.390838623046875, 0.338806152343750, 0.293701171875000,   0.358276367187500, 0.310577392578125, 0.269226074218750,
                           0.325714111328125, 0.282348632812500, 0.244750976562500,   0.293121337890625, 0.254119873046875, 0.220275878906250,
                           0.260559082031250, 0.225860595703125, 0.195800781250000,   0.227996826171875, 0.197631835937500, 0.171325683593750,
                           0.195404052734375, 0.169403076171875, 0.146850585937500,   0.162841796875000, 0.141174316406250, 0.122375488281250,
                           0.130279541015625, 0.112915039062500, 0.097900390625000,   0.097686767578125, 0.084686279296875, 0.073425292968750,
                           0.065124511718750, 0.056457519531250, 0.048950195312500,   0.032562255859375, 0.028228759765625, 0.024475097656250;

   #endif

#include "ps_huffman_tables_flash.asm"

.ENDMODULE;

#endif

