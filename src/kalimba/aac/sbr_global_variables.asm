// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#include "aac_library.h"

#ifdef AACDEC_SBR_ADDITIONS

#include "core_library.h"
#include "fft.h"

.MODULE $aacdec;
   .DATASEGMENT DM;

   //    SBR Variables
   .VAR sbr_np_info[$aacdec.SBR_NP_size];

   .VAR sbr_limiter_band_g_boost_mantissa[6];
   .VAR sbr_limiter_band_g_boost_exponent[6];


   .VAR sbr_phi_re_sin[] =
      1, 0, -1, 0;

   .VAR sbr_phi_im_sin[] =
      0, 1, 0, -1;


   .VAR sbr_h_smooth[] =  0.03183050093751, 0.11516383427084, 0.21816949906249, 0.30150283239582,  0.33333333333333;


   .VAR sbr_est_curr_env_one_over_div[] =
#ifndef AACDEC_ELD_ADDITIONS
      0.50000000000000,   0.25000000000000,   0.16666666666667,   0.12500000000000,   0.10000000000000,   
      0.08333333333333,   0.07142857142857,   0.06250000000000,   0.05555555555556,   0.05000000000000,   
      0.04545454545455,   0.04166666666667,   0.03846153846154,   0.03571428571429,   0.03333333333333,   
      0.03125000000000,   0.02941176470588,   0.02777777777778,   0.02631578947368,   0.02500000000000,   
      0.02380952380952,   0.02272727272727,   0.02173913043478,   0.02083333333333,   0.02000000000000,   
      0.01923076923077,   0.01851851851852,   0.01785714285714,   0.01724137931034,   0.01666666666667,   
      0.01612903225806,   0.01562500000000,   0.01515151515152,   0.01470588235294,   0.01428571428571,
      0.01388888888889,   0.01351351351351,   0.01315789473684,   0.01282051282051,   0.01250000000000,   
      0.01219512195122,   0.01190476190476,   0.01162790697674,   0.01136363636364,   0.01111111111111,   
      0.01086956521739,   0.01063829787234,   0.01041666666667,   0.01020408163265,   0.01000000000000;
#else
      1.000000000000000,  0.500000000000000,  0.333333333333333,  0.250000000000000,  0.200000000000000,
      0.166666666666667,  0.142857142857143,  0.125000000000000,  0.111111111111111,  0.100000000000000,
      0.090909090909091,  0.083333333333333,  0.076923076923077,  0.071428571428571,  0.066666666666667,
      0.062500000000000,  0.058823529411765,  0.055555555555556,  0.052631578947368,  0.050000000000000,
      0.047619047619048,  0.045454545454545,  0.043478260869565,  0.041666666666667,  0.040000000000000,
      0.038461538461538,  0.037037037037037,  0.035714285714286,  0.034482758620690,  0.033333333333333,
      0.032258064516129,  0.031250000000000,  0.030303030303030,  0.029411764705882,  0.028571428571429,
      0.027777777777778,  0.027027027027027,  0.026315789473684,  0.025641025641026,  0.025000000000000,
      0.024390243902439,  0.023809523809524,  0.023255813953488,  0.022727272727273,  0.022222222222222,
      0.021739130434783,  0.021276595744681,  0.020833333333333,  0.020408163265306,  0.020000000000000,
      0.019607843137255,  0.019230769230769,  0.018867924528302,  0.018518518518519,  0.018181818181818,
      0.017857142857143,  0.017543859649123,  0.017241379310345,  0.016949152542373,  0.016666666666667,
      0.016393442622951,  0.016129032258065,  0.015873015873016,  0.015625000000000,  0.015384615384615,
      0.015151515151515,  0.014925373134328,  0.014705882352941,  0.014492753623188,  0.014285714285714,
      0.014084507042254,  0.013888888888889,  0.013698630136986,  0.013513513513514,  0.013333333333333,
      0.013157894736842,  0.012987012987013,  0.012820512820513,  0.012658227848101,  0.012500000000000,
      0.012345679012346,  0.012195121951220,  0.012048192771084,  0.011904761904762,  0.011764705882353,
      0.011627906976744,  0.011494252873563,  0.011363636363636,  0.011235955056180,  0.011111111111111,
      0.010989010989011,  0.010869565217391,  0.010752688172043,  0.010638297872340,  0.010526315789474,
      0.010416666666667,  0.010309278350515,  0.010204081632653,  0.010101010101010,  0.010000000000000;
#endif // !AACDEC_ELD_ADDITIONS

    // initialisations
   .VAR   sbr_info[SBR_SIZE] =
         0,                        // SBR_num_crc_bits
         0,                        // SBR_header_count
         1,                        // SBR_bs_amp_res
         5,                        // SBR_bs_start_freq
        -1,                        // SBR_bs_start_freq_prev
         0,                        // SBR_bs_stop_freq
         0,                        // SBR_bs_stop_freq_prev
         2,                        // SBR_bs_freq_scale
         0,                        // SBR_bs_freq_scale_prev
         1,                        // SBR_bs_alter_scale
         0,                        // SBR_bs_alter_scale_prev
         0,                        // SBR_bs_xover_band
         0,                        // SBR_bs_xover_band_prev
         2,                        // SBR_bs_noise_bands
         0,                        // SBR_bs_noise_bands_prev
         2,                        // SBR_bs_limiter_bands
         2,                        // SBR_bs_limiter_gains
         1,                        // SBR_bs_interpol_freq
         1,                        // SBR_bs_smoothing_mode
         1,                        // SBR_reset
         0,                        // SBR_k0
         0,                        // SBR_k2
         0                         // SBR_kx
         , 0 ...     // zero pad the remaining elements
         ;
         // + 23
         //1000
         //1150
         //1162 + 23 = 1185


   .VAR   sbr_fscale_gt_zero_temp_1[]  =  12, 10, 8;
   // 1 / SBR_warp
   .VAR   sbr_fscale_gt_zero_temp_2[]  =  1.0,   0.76923076923077;


   // startMin Table
   .VAR sbr_startMinTable[12] =
      7, 7, 10, 11, 12, 16, 16, 17, 24, 32, 35, 48;

   // stopMin Table
   .VAR sbr_stopMinTable[12] =
      13, 15, 20, 21, 23, 32, 32, 35, 48, 64, 70, 96;

   // SBR offsetIndexTable
   .VAR sbr_offsetIndexTable[9] =
      5, 5, 4, 4, 4, 3, 2, 1, 0;


#ifdef AACDEC_SBR_QMF_STOP_CHANNEL_OFFSET_IN_FLASH
   #include "sbr_qmf_stop_channel_offset_flash.asm"
#else
   #include "sbr_qmf_stop_channel_offset.asm"
#endif


   // SBR QMF Stop channel offset table
   .VAR sbr_qmf_stop_channel_offset[12] =
      &$aacdec.sbr_qmf_stop_channel_offset_96000,
      &$aacdec.sbr_qmf_stop_channel_offset_88200,
      &$aacdec.sbr_qmf_stop_channel_offset_64000,
      &$aacdec.sbr_qmf_stop_channel_offset_48000,
      &$aacdec.sbr_qmf_stop_channel_offset_44100,
      &$aacdec.sbr_qmf_stop_channel_offset_24000_to_32000,
      &$aacdec.sbr_qmf_stop_channel_offset_24000_to_32000,
      &$aacdec.sbr_qmf_stop_channel_offset_22050,
      &$aacdec.sbr_qmf_stop_channel_offset_16000,
      &$aacdec.sbr_qmf_stop_channel_offset_12000,
      &$aacdec.sbr_qmf_stop_channel_offset_11025,
      &$aacdec.sbr_qmf_stop_channel_offset_8000;


   // SBR offset table
   .VAR sbr_offset[6] =
      &$aacdec.sbr_offset_fs_sbr_16000,
      &$aacdec.sbr_offset_fs_sbr_22050,
      &$aacdec.sbr_offset_fs_sbr_24000,
      &$aacdec.sbr_offset_fs_sbr_32000,
      &$aacdec.sbr_offset_fs_sbr_44100_to_64000,
      &$aacdec.sbr_offset_fs_sbr_gt_64000;


   .VAR sbr_one_over_x[] =
         1.000000000000000,   0.500000000000000,   0.333333333333333,   0.250000000000000,   0.200000000000000,   0.166666666666667,   0.142857142857143,   0.125000000000000,
         0.111111111111111,   0.100000000000000,   0.090909090909091,   0.083333333333333,   0.076923076923077,   0.071428571428571,   0.066666666666667,   0.062500000000000,
         0.058823529411765,   0.055555555555556,   0.052631578947368,   0.050000000000000,   0.047619047619048,   0.045454545454545,   0.043478260869565,   0.041666666666667,
         0.040000000000000,   0.038461538461538,   0.037037037037037,   0.035714285714286,   0.034482758620690,   0.033333333333333,   0.032258064516129,   0.031250000000000;

   .VAR SBR_log2Table[] =
         0, 0, 1, 2, 2, 3, 3, 3, 3, 4;


#ifdef AACDEC_SBR_LOG2_TABLE_IN_FLASH
   #include "sbr_log2_table_flash.asm"
#else
   #include "sbr_log2_table.asm"
#endif


   .VAR sbr_pow2_table[] =
      0.50000000000000,   0.50544464302585,   0.51094857432706,   0.51651243951061,   0.52213689121371,   0.52782258918028,
      0.53357020033841,   0.53938039887856,   0.54525386633263,   0.55119129165392,   0.55719337129795,   0.56326080930412,
      0.56939431737835,   0.57559461497649,   0.58186242938879,   0.58819849582514,   0.59460355750136,   0.60107836572635,
      0.60762367999023,   0.61424026805344,   0.62092890603674,   0.62769037851235,   0.63452547859587,   0.64143500803939,
      0.64841977732550,   0.65548060576238,   0.66261832157987,   0.66983376202665,   0.67712777346845,   0.68450121148730,
      0.69195494098192,   0.69948983626916,   0.70710678118655,   0.71480666919599,   0.72259040348852,   0.73045889709032,
      0.73841307296975,   0.74645386414563,   0.75458221379671,   0.76279907537227,   0.77110541270397,   0.77950220011892,
      0.78799042255394,   0.79657107567113,   0.80524516597463,   0.81401371092867,   0.82287773907698,   0.83183829016337,
      0.84089641525371,   0.85005317685926,   0.85930964906124,   0.86866691763685,   0.87812608018665,   0.88768824626326,
      0.89735453750155,   0.90712608775020,   0.91700404320467,   0.92698956254169,   0.93708381705515,   0.94728799079348,
      0.95760328069857,   0.96803089674615,   0.97857206208770,   0.98922801319398,   1.00000000000000;


#ifdef AACDEC_SBR_HUFFMAN_IN_FLASH
   #include "sbr_huffman_tables_flash.asm"
#else
   #include "sbr_huffman_tables.asm"
#endif

#ifdef AACDEC_SBR_Q_DIV_TABLE_IN_FLASH
   #include "sbr_q_div_table_flash.asm"
#else
   #include "sbr_q_div_table.asm"
#endif

#ifdef AACDEC_SBR_V_NOISE_IN_FLASH
   #include "sbr_v_noise_table_flash.asm"
#else
   #include "sbr_v_noise_table.asm"
#endif
#ifdef AACDEC_ELD_ADDITIONS
    #include "ld_envelopetables.asm"
#endif


   .VAR/DM1CIRC x_input_buffer_left[X_INPUT_BUFFER_LENGTH];
   .VAR/DM1CIRC x_input_buffer_right[X_INPUT_BUFFER_LENGTH];

   .VAR x_input_buffer_write_pointers[SBR_CHANNELS] =
         &x_input_buffer_left,
         &x_input_buffer_right;

   // Analysis & Synthesis filterbank buffers
   .VAR in_synth = 0;
 #ifndef AACDEC_ELD_ADDITIONS
   .VAR in_synth_loops = 32;
 #else 
  .VAR in_synth_loops = 16;
 #endif 
   #ifdef AACDEC_SBR_HALF_SYNTHESIS
      .VAR synth_temp[1024];
   #endif


   .VAR sbr_dct_dst;
 #ifdef AACDEC_ELD_ADDITIONS
   .VAR/DM2CIRC sbr_temp_5[SBR_N]; 
   .VAR/DM1CIRC sbr_temp_6[SBR_N];  
   .VAR/DM2CIRC sbr_temp_7[SBR_N]; 
   .VAR/DM1CIRC sbr_temp_8[SBR_N]; 
 #endif  
   .VAR construct_v_functions[2] =   // This relies on SBR_NORMALSAMPLED and SBR_DOWNSAMPLED being 0 & 1 respectively
      &$aacdec.sbr_synthesis_construct_v,
      &$aacdec.sbr_synthesis_downsampled_construct_v;
//   .VAR/DM1CIRC v_buffer_left[SBR_N*10];   now defined in global_variables.asm as part of the sbr_x_imag block
   .VAR/DM1CIRC v_buffer_right[SBR_N*10];
   .VAR v_left_cbuffer_struc[$cbuffer.STRUC_SIZE] =
         LENGTH(v_buffer_left),
         &v_buffer_left+127,
         &v_buffer_left+127;
   .VAR v_right_cbuffer_struc[$cbuffer.STRUC_SIZE] =
         LENGTH(v_buffer_right),
         &v_buffer_right+127,
         &v_buffer_right+127;
   .VAR v_cbuffer_struc_address[SBR_CHANNELS] =
         &v_left_cbuffer_struc,
         &v_right_cbuffer_struc;


   // structure used for ffts
   .VAR fft_pointer_struct[$fft.STRUC_SIZE];

   // Analysis and Synthesis filterbanks tables of constants
   #include "sbr_analysis_synthesis_tables.asm"


   //    X_sbr
   //             ...--------------------- sbr_x_real block -------------------->|
   //                 ___________________________________________________________              _______________________
   //                |  |                       |                                |            |                       |
   //                |  |                       |                                |            |                       |
   //                |  |                       |                                |            |                       |
   //                | Z|    X_sbr_curr_real    |       X_sbr_shared_real        |X_SBR_WIDTH |    X_sbr_other_real   |
   //                |  |                       |                                |            |                       |
   //                |  |                       |                                |            |                       |
   //                |  |                       |                                |            |                       |
   //                |__|_______________________|________________________________|            |_______________________|
   //         SBR_tHFAdj  SBR_tHFGen-SBR_tHFAdj        SBR_numTimeSlotsRate                     SBR_tHFGen-SBR_tHFAdj
   //
   //    Z = X_sbr_2env_real
   //
   //    Similar for imag
   //
   //    The sbr_x_real block contains some padding at the front. The above diagram starts at (&$aacdec.sbr_x_real + 512)
   //    with X_sbr_2env_real. The layout of this is shown below. X_sbr_other_real is stored separately from everything
   //    else. When switching channels the data from areas marked 'other' is swapped with that from areas marked 'curr'.
   //
   //    The imaginary parts of X_sbr are stored as above except that they start at (&$aacdec.sbr_x_imag + 1536).


   // X_sbr_2env_real
   //    ___________________________________________________________________________________________________
   //   |________________________|________________________|________________________|________________________|
   //     current chan column 1      other chan column 1    current chan column 2      other chan column 2
   //
   //    Similar for imag

   // all other parts of X_sbr now defined in global_variables.asm in the sbr_x_real and sbr_x_imag blocks
   .VAR/DM1 X_sbr_other_imag [X_SBR_LEFTRIGHT_SIZE];




   .VAR sbr_goal_sb_tab[] = 21, 23, 32, 43, 46, 64, 85, 93, 128, 0, 0, 0;


   .VAR sbr_E_pan_tab[] =
      0.00024408100000,   0.00048804300000,   0.00097561000000,   0.00194932000000,   0.00389105000000,
      0.00775194000000,   0.01538460000000,   0.03030300000000,   0.05882350000000,   0.11111100000000,
      0.20000000000000,   0.33333300000000,   0.50000000000000,   0.66666700000000,   0.80000000000000,
      0.88888900000000,   0.94117600000000,   0.96969700000000,   0.98461500000000,   0.99224800000000,
      0.99610900000000,   0.99805100000000,   0.99902400000000,   0.99951200000000,   0.99975600000000;


   // limiter frequency table constants and variables
                  // 0.49/Q/8        Q = [1.2, 2, 3];   divide by 8 to match sbr_log_base2_table
   .VAR sbr_limiter_bands_compare [] = 0.051041666666667, 0.030625, 0.020416666666667;
   .VAR sbr_lim_table_base_ptr;
   .VAR sbr_patch_borders_base_ptr;

.ENDMODULE;

#endif
