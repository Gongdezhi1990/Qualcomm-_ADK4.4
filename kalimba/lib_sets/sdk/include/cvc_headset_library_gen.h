// -----------------------------------------------------------------------------
// Copyright (c) 2010 - 2015 Qualcomm Technologies International, Ltd.
// Generated by DerivationEngine.py
// source v1.1, namespace com.csr.cps.2 on 2018-10-03 03:41:04 by adm-ns04
// from cvc_headset.xml $Revision: #1 $
// last modifed with $Change: 3031710 $ by $Author: ns04 $ on $DateTime: 2018/06/27 14:42:10 $
// -----------------------------------------------------------------------------
#ifndef __CVC_HEADSET_LIBRARY_GEN_H__
#define __CVC_HEADSET_LIBRARY_GEN_H__

// Algorithm IDs
.CONST $CVC_HEADSET_SYSID     	0xB012;

// Piecewise Enables
.CONST $M.CVC_HEADSET.CONFIG.CNGENA           		0x008000;
.CONST $M.CVC_HEADSET.CONFIG.RERENA           		0x004000;
.CONST $M.CVC_HEADSET.CONFIG.PLCENA           		0x002000;
.CONST $M.CVC_HEADSET.CONFIG.SND_AGCBYP       		0x001000;
.CONST $M.CVC_HEADSET.CONFIG.BEXENA           		0x000800;
.CONST $M.CVC_HEADSET.CONFIG.AEQENA           		0x000400;
.CONST $M.CVC_HEADSET.CONFIG.NDVCBYP          		0x000200;
.CONST $M.CVC_HEADSET.CONFIG.RCV_AGCBYP       		0x000100;
.CONST $M.CVC_HEADSET.CONFIG.SNDOMSENA        		0x000080;
.CONST $M.CVC_HEADSET.CONFIG.RCVOMSENA        		0x000040;
.CONST $M.CVC_HEADSET.CONFIG.SIDETONEENA      		0x000010;
.CONST $M.CVC_HEADSET.CONFIG.WNRBYP           		0x000008;
.CONST $M.CVC_HEADSET.CONFIG.AECENA           		0x000002;
.CONST $M.CVC_HEADSET.CONFIG.HDBYP            		0x000004;
.CONST $M.CVC_HEADSET.CONFIG.BYPASS_AGCPERSIST		0x040000;

// SPI Status Block
.CONST $M.CVC_HEADSET.STATUS.CUR_MODE_OFFSET      		0;
.CONST $M.CVC_HEADSET.STATUS.CALL_STATE_OFFSET    		1;
.CONST $M.CVC_HEADSET.STATUS.SYS_CONTROL_OFFSET   		2;
.CONST $M.CVC_HEADSET.STATUS.CUR_DAC_OFFSET       		3;
.CONST $M.CVC_HEADSET.STATUS.PRIM_PSKEY_OFFSET    		4;
.CONST $M.CVC_HEADSET.STATUS.SEC_STAT_OFFSET      		5;
.CONST $M.CVC_HEADSET.STATUS.PEAK_DAC_OFFSET      		6;
.CONST $M.CVC_HEADSET.STATUS.PEAK_ADC_OFFSET      		7;
.CONST $M.CVC_HEADSET.STATUS.PEAK_SCO_IN_OFFSET   		8;
.CONST $M.CVC_HEADSET.STATUS.PEAK_SCO_OUT_OFFSET  		9;
.CONST $M.CVC_HEADSET.STATUS.PEAK_MIPS_OFFSET     		10;
.CONST $M.CVC_HEADSET.STATUS.NDVC_NOISE_EST_OFFSET		11;
.CONST $M.CVC_HEADSET.STATUS.NDVC_DAC_ADJ_OFFSET  		12;
.CONST $M.CVC_HEADSET.STATUS.PEAK_AUX_OFFSET      		13;
.CONST $M.CVC_HEADSET.STATUS.COMPILED_CONFIG      		14;
.CONST $M.CVC_HEADSET.STATUS.SIDETONE_GAIN        		15;
.CONST $M.CVC_HEADSET.STATUS.VOLUME               		16;
.CONST $M.CVC_HEADSET.STATUS.CONNSTAT             		17;
.CONST $M.CVC_HEADSET.STATUS.PLC_PACKET_LOSS      		18;
.CONST $M.CVC_HEADSET.STATUS.AEQ_GAIN_LOW         		19;
.CONST $M.CVC_HEADSET.STATUS.AEQ_GAIN_HIGH        		20;
.CONST $M.CVC_HEADSET.STATUS.AEQ_STATE            		21;
.CONST $M.CVC_HEADSET.STATUS.AEQ_POWER_TEST       		22;
.CONST $M.CVC_HEADSET.STATUS.AEQ_TONE_POWER       		23;
.CONST $M.CVC_HEADSET.STATUS.PEAK_SIDETONE        		24;
.CONST $M.CVC_HEADSET.STATUS.SND_AGC_SPEECH_LVL   		25;
.CONST $M.CVC_HEADSET.STATUS.SND_AGC_GAIN         		26;
.CONST $M.CVC_HEADSET.STATUS.RCV_AGC_SPEECH_LVL   		27;
.CONST $M.CVC_HEADSET.STATUS.RCV_AGC_GAIN         		28;
.CONST $M.CVC_HEADSET.STATUS.WNR_PWR_LVL          		29;
.CONST $M.CVC_HEADSET.STATUS.WIND_FLAG            		30;
.CONST $M.CVC_HEADSET.STATUS.AEC_COUPLING_OFFSET  		31;
.CONST $M.CVC_HEADSET.STATUS.INTERFACE_TYPE       		32;
.CONST $M.CVC_HEADSET.STATUS.INPUT_RATE           		33;
.CONST $M.CVC_HEADSET.STATUS.OUTPUT_RATE          		34;
.CONST $M.CVC_HEADSET.STATUS.CODEC_RATE           		35;
.CONST $M.CVC_HEADSET.STATUS.DSP_VOL_FLAG         		36;
.CONST $M.CVC_HEADSET.STATUS.DSP_VOL              		37;
.CONST $M.CVC_HEADSET.STATUS.BLOCK_SIZE                		38;

// System Mode
.CONST $M.CVC_HEADSET.SYSMODE.STANDBY  		0;
.CONST $M.CVC_HEADSET.SYSMODE.HFK      		1;
.CONST $M.CVC_HEADSET.SYSMODE.SSR      		2;
.CONST $M.CVC_HEADSET.SYSMODE.PSTHRGH  		3;
.CONST $M.CVC_HEADSET.SYSMODE.LPBACK   		5;
.CONST $M.CVC_HEADSET.SYSMODE.LOWVOLUME		7;
.CONST $M.CVC_HEADSET.SYSMODE.MAX_MODES		8;

// Call State
.CONST $M.CVC_HEADSET.CALLST.UNKNOWN   		0;
.CONST $M.CVC_HEADSET.CALLST.CONNECTED 		1;
.CONST $M.CVC_HEADSET.CALLST.CONNECTING		2;
.CONST $M.CVC_HEADSET.CALLST.MUTE      		3;

// System Control
.CONST $M.CVC_HEADSET.CONTROL.DAC_OVERRIDE      		0x8000;
.CONST $M.CVC_HEADSET.CONTROL.CALLSTATE_OVERRIDE		0x4000;
.CONST $M.CVC_HEADSET.CONTROL.MODE_OVERRIDE     		0x2000;

// AEQ State

// System Control

// W_Flag

// Interface
.CONST $M.CVC_HEADSET.INTERFACE.ANALOG		0;
.CONST $M.CVC_HEADSET.INTERFACE.I2S   		1;

// Parameter Block
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_HFK_CONFIG               		0;
// Send OMS
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_HFK_OMS_AGGR             		1;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_ASR_OMS_AGGR             		2;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_OMS_HARMONICITY          		3;
// Wind Noise
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_WNR_AGGR                 		4;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_WNR_POWER_THRES          		5;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_WNR_HOLD                 		6;
// AEC
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_CNG_Q                    		7;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_CNG_SHAPE                		8;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_DTC_AGGR                 		9;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_ENABLE_AEC_REUSE         		10;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_ADCGAIN                  		11;
// NDVC
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_NDVC_HYSTERESIS          		12;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_NDVC_ATK_TC              		13;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_NDVC_DEC_TC              		14;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_NDVC_NUMVOLSTEPS         		15;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_NDVC_MAXNOISELVL         		16;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_NDVC_MINNOISELVL         		17;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_NDVC_LB                  		18;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_NDVC_HB                  		19;
// Send PEQ
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_PEQ_CONFIG           		20;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_PEQ_GAIN_EXP         		21;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_PEQ_GAIN_MANT        		22;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_PEQ_STAGE1_B2        		23;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_PEQ_STAGE1_B1        		24;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_PEQ_STAGE1_B0        		25;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_PEQ_STAGE1_A2        		26;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_PEQ_STAGE1_A1        		27;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_PEQ_STAGE2_B2        		28;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_PEQ_STAGE2_B1        		29;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_PEQ_STAGE2_B0        		30;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_PEQ_STAGE2_A2        		31;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_PEQ_STAGE2_A1        		32;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_PEQ_STAGE3_B2        		33;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_PEQ_STAGE3_B1        		34;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_PEQ_STAGE3_B0        		35;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_PEQ_STAGE3_A2        		36;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_PEQ_STAGE3_A1        		37;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_PEQ_STAGE4_B2        		38;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_PEQ_STAGE4_B1        		39;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_PEQ_STAGE4_B0        		40;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_PEQ_STAGE4_A2        		41;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_PEQ_STAGE4_A1        		42;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_PEQ_STAGE5_B2        		43;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_PEQ_STAGE5_B1        		44;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_PEQ_STAGE5_B0        		45;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_PEQ_STAGE5_A2        		46;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_PEQ_STAGE5_A1        		47;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_PEQ_SCALE1           		48;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_PEQ_SCALE2           		49;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_PEQ_SCALE3           		50;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_PEQ_SCALE4           		51;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_PEQ_SCALE5           		52;
// Receive PEQ
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_PEQ_CONFIG           		53;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_PEQ_GAIN_EXP         		54;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_PEQ_GAIN_MANT        		55;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_PEQ_STAGE1_B2        		56;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_PEQ_STAGE1_B1        		57;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_PEQ_STAGE1_B0        		58;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_PEQ_STAGE1_A2        		59;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_PEQ_STAGE1_A1        		60;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_PEQ_STAGE2_B2        		61;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_PEQ_STAGE2_B1        		62;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_PEQ_STAGE2_B0        		63;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_PEQ_STAGE2_A2        		64;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_PEQ_STAGE2_A1        		65;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_PEQ_STAGE3_B2        		66;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_PEQ_STAGE3_B1        		67;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_PEQ_STAGE3_B0        		68;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_PEQ_STAGE3_A2        		69;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_PEQ_STAGE3_A1        		70;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_PEQ_STAGE4_B2        		71;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_PEQ_STAGE4_B1        		72;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_PEQ_STAGE4_B0        		73;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_PEQ_STAGE4_A2        		74;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_PEQ_STAGE4_A1        		75;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_PEQ_STAGE5_B2        		76;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_PEQ_STAGE5_B1        		77;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_PEQ_STAGE5_B0        		78;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_PEQ_STAGE5_A2        		79;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_PEQ_STAGE5_A1        		80;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_PEQ_SCALE1           		81;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_PEQ_SCALE2           		82;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_PEQ_SCALE3           		83;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_PEQ_SCALE4           		84;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_PEQ_SCALE5           		85;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_LVMODE_THRES             		86;
// Inverse DAC Table
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_INV_DAC_GAIN_TABLE       		87;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_INV_DAC_GAIN_TABLE1      		88;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_INV_DAC_GAIN_TABLE2      		89;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_INV_DAC_GAIN_TABLE3      		90;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_INV_DAC_GAIN_TABLE4      		91;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_INV_DAC_GAIN_TABLE5      		92;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_INV_DAC_GAIN_TABLE6      		93;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_INV_DAC_GAIN_TABLE7      		94;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_INV_DAC_GAIN_TABLE8      		95;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_INV_DAC_GAIN_TABLE9      		96;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_INV_DAC_GAIN_TABLE10     		97;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_INV_DAC_GAIN_TABLE11     		98;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_INV_DAC_GAIN_TABLE12     		99;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_INV_DAC_GAIN_TABLE13     		100;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_INV_DAC_GAIN_TABLE14     		101;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_INV_DAC_GAIN_TABLE15     		102;
// Hard clipper
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_CLIP_POINT               		103;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SIDETONE_LIMIT           		104;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_BOOST                    		105;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_BOOST_CLIP_POINT         		106;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_G_ALFA                   		107;
// Sidetone with High-Pass Filters
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_ST_CLIP_POINT            		108;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_ST_ADJUST_LIMIT          		109;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_STF_SWITCH               		110;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_STF_NOISE_LOW_THRES      		111;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_STF_NOISE_HIGH_THRES     		112;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_STF_GAIN_EXP             		113;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_STF_GAIN_MANTISSA        		114;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_ST_PEQ_CONFIG            		115;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_ST_PEQ_GAIN_EXP          		116;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_ST_PEQ_GAIN_MANT         		117;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_ST_PEQ_STAGE1_B2         		118;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_ST_PEQ_STAGE1_B1         		119;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_ST_PEQ_STAGE1_B0         		120;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_ST_PEQ_STAGE1_A2         		121;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_ST_PEQ_STAGE1_A1         		122;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_ST_PEQ_STAGE2_B2         		123;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_ST_PEQ_STAGE2_B1         		124;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_ST_PEQ_STAGE2_B0         		125;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_ST_PEQ_STAGE2_A2         		126;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_ST_PEQ_STAGE2_A1         		127;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_ST_PEQ_STAGE3_B2         		128;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_ST_PEQ_STAGE3_B1         		129;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_ST_PEQ_STAGE3_B0         		130;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_ST_PEQ_STAGE3_A2         		131;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_ST_PEQ_STAGE3_A1         		132;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_ST_PEQ_SCALE1            		133;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_ST_PEQ_SCALE2            		134;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_ST_PEQ_SCALE3            		135;
// Pre-Gain
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SNDGAIN_MANTISSA         		136;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SNDGAIN_EXPONENT         		137;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCVGAIN_MANTISSA         		138;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCVGAIN_EXPONENT         		139;
// Pass-Through Gain
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_PT_SNDGAIN_MANTISSA      		140;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_PT_SNDGAIN_EXPONENT      		141;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_PT_RCVGAIN_MANTISSA      		142;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_PT_RCVGAIN_EXPONENT      		143;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_REF_DELAY                		144;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_ADCGAIN_SSR              		145;
// Send VAD
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_VAD_ATTACK_TC        		146;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_VAD_DECAY_TC         		147;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_VAD_ENVELOPE_TC      		148;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_VAD_INIT_FRAME_THRESH		149;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_VAD_RATIO            		150;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_VAD_MIN_SIGNAL       		151;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_VAD_MIN_MAX_ENVELOPE 		152;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_VAD_DELTA_THRESHOLD  		153;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_VAD_COUNT_THRESHOLD  		154;
// Send AGC
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_AGC_G_INITIAL        		155;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_AGC_TARGET           		156;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_AGC_ATTACK_TC        		157;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_AGC_DECAY_TC         		158;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_AGC_A_90_PK          		159;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_AGC_D_90_PK          		160;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_AGC_G_MAX            		161;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_AGC_START_COMP       		162;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_AGC_COMP             		163;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_AGC_INP_THRESH       		164;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_AGC_SP_ATTACK        		165;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_AGC_AD_THRESH1       		166;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_AGC_AD_THRESH2       		167;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_AGC_G_MIN            		168;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SND_AGC_ECHO_HOLD_TIME   		169;
// Receive VAD
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_VAD_ATTACK_TC        		170;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_VAD_DECAY_TC         		171;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_VAD_ENVELOPE_TC      		172;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_VAD_INIT_FRAME_THRESH		173;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_VAD_RATIO            		174;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_VAD_MIN_SIGNAL       		175;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_VAD_MIN_MAX_ENVELOPE 		176;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_VAD_DELTA_THRESHOLD  		177;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_VAD_COUNT_THRESHOLD  		178;
// Receive AGC
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_AGC_G_INITIAL        		179;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_AGC_TARGET           		180;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_AGC_ATTACK_TC        		181;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_AGC_DECAY_TC         		182;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_AGC_A_90_PK          		183;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_AGC_D_90_PK          		184;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_AGC_G_MAX            		185;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_AGC_START_COMP       		186;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_AGC_COMP             		187;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_AGC_INP_THRESH       		188;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_AGC_SP_ATTACK        		189;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_AGC_AD_THRESH1       		190;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_AGC_AD_THRESH2       		191;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_AGC_G_MIN            		192;
// Adaptive EQ
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_AEQ_ATK_TC               		193;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_AEQ_ATK_1MTC             		194;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_AEQ_DEC_TC               		195;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_AEQ_DEC_1MTC             		196;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_AEQ_LO_GOAL_LOW          		197;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_AEQ_LO_GOAL_MID          		198;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_AEQ_LO_GOAL_HIGH         		199;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_AEQ_HI_GOAL_LOW          		200;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_AEQ_HI_GOAL_MID          		201;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_AEQ_HI_GOAL_HIGH         		202;
// Bandwidth Expansion
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_BEX_HI2_GOAL_LOW         		203;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_BEX_HI2_GOAL_MID         		204;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_BEX_HI2_GOAL_HIGH        		205;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_BEX_TOTAL_ATT_LOW        		206;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_BEX_TOTAL_ATT_MID        		207;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_BEX_TOTAL_ATT_HIGH       		208;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_BEX_NOISE_LVL_FLAGS      		209;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_BEX_LOW_STEP             		210;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_BEX_HIGH_STEP            		211;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_AEQ_POWER_TH             		212;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_AEQ_MIN_GAIN             		213;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_AEQ_MAX_GAIN             		214;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_AEQ_VOL_STEP_UP_TH1      		215;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_AEQ_VOL_STEP_UP_TH2      		216;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_AEQ_LOW_STEP             		217;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_AEQ_LOW_STEP_INV         		218;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_AEQ_HIGH_STEP            		219;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_AEQ_HIGH_STEP_INV        		220;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_AEQ_LOW_BAND_INDEX       		221;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_AEQ_LOW_BANDWIDTH        		222;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_AEQ_LOG2_LOW_BANDWIDTH   		223;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_AEQ_MID_BANDWIDTH        		224;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_AEQ_LOG2_MID_BANDWIDTH   		225;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_AEQ_HIGH_BANDWIDTH       		226;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_AEQ_LOG2_HIGH_BANDWIDTH  		227;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_AEQ_MID1_BAND_INDEX      		228;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_AEQ_MID2_BAND_INDEX      		229;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_AEQ_HIGH_BAND_INDEX      		230;
// Packet Loss
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_PLC_STAT_INTERVAL        		231;
// Receive OMS
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_RCV_OMS_HFK_AGGR         		232;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_OMS_HI_RES_MODE          		233;
// Aux Input
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_AUX_GAIN                 		234;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_SCO_STREAM_MIX           		235;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_AUX_STREAM_MIX           		236;
// AEC Half-Duplex
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_HD_THRESH_GAIN           		237;
// User Parameters
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_DSP_USER_0               		238;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_DSP_USER_1               		239;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_DSP_USER_2               		240;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_DSP_USER_3               		241;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_DSP_USER_4               		242;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_DSP_USER_5               		243;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_DSP_USER_6               		244;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_DSP_USER_7               		245;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_DSP_USER_8               		246;
.CONST $M.CVC_HEADSET.PARAMETERS.OFFSET_DSP_USER_9               		247;
.CONST $M.CVC_HEADSET.PARAMETERS.STRUCT_SIZE                    		248;


#endif // __CVC_HEADSET_LIBRARY_GEN_H__
