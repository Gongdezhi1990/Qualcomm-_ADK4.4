// *****************************************************************************
// Copyright (c) 2017 Qualcomm Technologies International, Ltd.
// Part of ADK_CSR867x.WIN. 4.4
//
// *****************************************************************************

#ifdef DEBUG_ON
   #define DEBUG_AACDEC
   #define ENABLE_PROFILER_MACROS
   #define AACDEC_CALL_ERROR_ON_POSSIBLE_CORRUPTION
   #define AACDEC_CALL_ERROR_ON_MALLOC_FAIL
#endif

#include "profiler.h"

#ifndef KALASM3

// These will map the PM_DYNAMIC_x and _SCRATCH segments to "normal" groups
// link scratch memory segments to DMxGroups (for lib build only)
//          Name                 CIRCULAR?   Link Order  Group list
.DEFSEGMENT DM_SCRATCH                       5           DM1Group  DM2Group;
.DEFSEGMENT DM1_SCRATCH                      3           DM1Group;
.DEFSEGMENT DM2_SCRATCH                      3           DM2Group;
.DEFSEGMENT DMCIRC_SCRATCH       CIRCULAR    4           DM1Group  DM2Group;
.DEFSEGMENT DM1CIRC_SCRATCH      CIRCULAR    2           DM1Group;
.DEFSEGMENT DM2CIRC_SCRATCH      CIRCULAR    2           DM2Group;

// This segment is not overlayed
.DEFSEGMENT DM_STATIC                        5           DM1Group  DM2Group;


// Default: RAM_USAGE 4
//          Name                             Link Order  Group list
.DEFSEGMENT PM_DYNAMIC_1                     4           CODEGroup;
.DEFSEGMENT PM_DYNAMIC_2                     4           CODEGroup;
.DEFSEGMENT PM_DYNAMIC_3                     4           CODEGroup;
.DEFSEGMENT PM_DYNAMIC_4                     4           CODEGroup;
.DEFSEGMENT PM_DYNAMIC_5                     4           CODEFLASHGroup;
.DEFSEGMENT PM_DYNAMIC_6                     4           CODEFLASHGroup;
.DEFSEGMENT PM_DYNAMIC_7                     4           CODEFLASHGroup;
.DEFSEGMENT PM_DYNAMIC_8                     4           CODEFLASHGroup;
.DEFSEGMENT PM_DYNAMIC_9                     4           CODEFLASHGroup;

#endif

// includes
#include "aac.h"
#ifdef AACDEC_PARAMETRIC_STEREO_ADDITIONS
   // AAC-HEV2
   #include "segments_aac_hev2.asm"
#else
#ifdef AACDEC_SBR_ADDITIONS
   // AAC-HEV1
   #include "segments_aac_hev1.asm"
#else
   // AAC-LC
   #include "segments_aac_lc.asm"

#endif
#endif


#include "global_variables.asm"
#include "init_decoder.asm"
#include "reset_decoder.asm"
#include "silence_decoder.asm"
#include "decoder_state.asm"
#include "frame_decode.asm"
#include "adts_read_frame.asm"
#include "mem_alloc.asm"
#include "getbits.asm"
#include "byte_align.asm"
#include "raw_data_block.asm"
#include "decode_sce.asm"
#include "decode_cpe.asm"
#include "discard_dse.asm"
#include "program_element_config.asm"
#include "decode_fil.asm"
#include "individual_channel_stream.asm"
#include "ics_info.asm"
#include "calc_sfb_and_wingroup.asm"
#include "section_data.asm"
#include "scalefactor_data.asm"
#include "pulse_data.asm"
#include "pulse_decode.asm"
#include "tns_data.asm"
#include "ltp_data.asm"
#include "spectral_data.asm"
#ifdef AACDEC_PACK_SPECTRAL_HUFFMAN_IN_FLASH
   #include "huffman_unpack.asm"
#endif
#include "huffman_decode.asm"
#include "reconstruct_channels.asm"
#include "apply_scalefactors_and_dequantize.asm"
#include "reorder_spec.asm"
#include "ms_decode.asm"
#include "pns_decode.asm"
#include "is_decode.asm"
#include "ltp_decode.asm"
#include "ltp_reconstruction.asm"
#include "mdct.asm"
#include "filterbank_analysis_ltp.asm"
#include "tns_encdec.asm"
#include "filterbank.asm"
#include "imdct.asm"
#include "windowing.asm"
#include "overlap_add.asm"
#include "corruption.asm"


// mp4/m4a file support
#include "mp4_read_frame.asm"
#include "mp4_sequence.asm"
#include "mp4_read_atom_header.asm"
#include "mp4_moov_routine.asm"
#include "mp4_discard_atom_data.asm"
#include "mp4_ff_rew.asm"

// latm support
#include "latm_read_frame.asm"
#include "audio_mux_element.asm"
#include "stream_mux_config.asm"
#include "audio_specific_config.asm"
#include "ga_specific_config.asm"
#include "latm_get_value.asm"
#include "payload_length_info.asm"
#include "payload_mux.asm"

// FF/REW support
#include "aac_ff_rew.asm"

// SBR support
#ifdef AACDEC_SBR_ADDITIONS
   #include "sbr_extension_data.asm"
   #include "sbr_header.asm"
   #include "sbr_reset.asm"
   #include "sbr_calc_tables.asm"
   #include "sbr_fband_tables.asm"
   #include "sbr_fmaster_table_calc_fscale_gt_zero.asm"
   #include "sbr_fmaster_table_calc_fscale_eq_zero.asm"
   #include "sbr_single_channel_element.asm"
   #include "sbr_channel_pair_element.asm"
   #include "sbr_dtdf.asm"
   #include "sbr_invf.asm"
   #include "sbr_grid.asm"
   #include "sbr_huff_dec.asm"
   #include "sbr_allocate_and_unpack_from_flash.asm"
   #include "sbr_read_one_word_from_flash.asm"
   #include "sbr_envelope.asm"
   #include "sbr_noise.asm"
   #include "sbr_bubble_sort.asm"
   #include "sbr_envelope_time_border_vector.asm"
   #include "sbr_envelope_noise_border_vector.asm"
   #include "sbr_middle_border.asm"
   #include "sbr_extract_envelope_data.asm"
   #include "sbr_extract_noise_floor_data.asm"
   #include "sbr_envelope_noise_dequantisation.asm"
   #include "sbr_envelope_noise_dequantisation_coupling_mode.asm"
   #include "sbr_read_qdiv_tables.asm"
   #include "sbr_fp_mult_frac.asm"
   #include "sbr_hf_generation.asm"
   #include "sbr_calc_chirp_factors.asm"
   #include "sbr_patch_construction.asm"
   #include "sbr_auto_correlation_opt.asm"
   #include "sbr_prediction_coeff.asm"
   #include "sbr_limiter_frequency_table.asm"

   #include "sbr_hf_adjustment.asm"
   #include "sbr_estimate_current_envelope.asm"
   #include "sbr_calculate_gain.asm"
   #include "sbr_calculate_limiter_band_boost_coefficients.asm"
   #include "sbr_get_s_mapped.asm"
   #include "sbr_hf_assembly.asm"
   #include "sbr_hf_assembly_initialise_outer_loop_iteration.asm"
   #include "sbr_hf_assembly_save_persistent_gain_signal_envelopes.asm"
   #include "sbr_hf_assembly_initialise_signal_gain_and_component_loop.asm"
   #include "sbr_hf_assembly_calc_gain_filters_smoothing_mode.asm"

   #include "sbr_analysis_filterbank.asm"
   #include "sbr_analysis_dct_kernel.asm"
   #include "sbr_construct_x_matrix.asm"
   #include "sbr_synthesis_filterbank_combined.asm"
   #include "sbr_synthesis_construct_v.asm"
   #include "sbr_synthesis_downsampled_construct_v.asm"
   #include "sbr_save_prev_data.asm"
   #include "sbr_wrap_last_thfgen_envelopes.asm"

   #include "sbr_swap_channels.asm"
#endif

#ifdef AACDEC_ELD_ADDITIONS
   #include "eld_specific_config.asm"
   #include "er_raw_data_block_eld.asm"
   #include "decode_sce_eld.asm"
   #include "decode_cpe_eld.asm"
   #include "individual_channel_stream_eld.asm"
   #include "imdct480.asm"
   #include "ld_envelopetables.asm"
   #include "sbr_ld_grid.asm"
   #include "er_low_delay_sbr_block.asm"
   #include "ld_sbr_header.asm"
   #include "low_delay_sbr_data.asm"
#endif

#ifdef AACDEC_PARAMETRIC_STEREO_ADDITIONS
   #include "ps_data.asm"
   #include "ps_extension.asm"
   #include "ps_huff_dec.asm"
   #include "ps_data_decode.asm"
   #include "ps_hybrid_analysis.asm"
   #include "ps_hybrid_type_a_fir_filter.asm"
   #include "ps_hybrid_type_b_fir_filter.asm"
   #include "ps_hybrid_synthesis.asm"
   #include "ps_delta_decode.asm"
   #include "ps_map_34_parameters_to_20.asm"
   #include "ps_decorrelate.asm"
   #include "ps_stereo_mixing.asm"
   #include "ps_transient_detection.asm"
   #include "initialise_ps_transient_detection_for_hybrid_freq_bins_flash.asm"
   #include "initialise_ps_transient_detection_for_qmf_freq_bins_flash.asm"
   #include "initialise_ps_decorrelation_for_hybrid_freq_bins_flash.asm"
   #include "initialise_ps_decorrelation_for_qmf_freq_bins_flash.asm"
   #include "initialise_ps_stereo_mixing_for_hybrid_freq_bins_flash.asm"
   #include "initialise_ps_stereo_mixing_for_qmf_freq_bins_flash.asm"
#endif

// main function
#include "aacdec_api.asm"

#ifdef BUILD_WITH_C_SUPPORT
   #include "aac_library_c_stubs.asm"
#endif
