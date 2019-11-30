/* Copyright (c) 2017 Qualcomm Technologies International, Ltd. */
/*   %%version */
/*

  ANC Example application - For tuning and evaluation of ANC
 
  *** Will not function without an ANC license key ***

  REQUIRED PSKEYS
  DSP 1
  ANC LICENSE KEY + BT ADDRESS

*/


#define USES_HEADPHONE_AMP      /* will turn on the headphone amp PIO on H13179 dev board*/
#define ENABLE_MIC_BIAS         /* will turn on the mic bias voltage */
#define ENABLE_BATTERY_CHARGER

#define PSKEY_TO_READ   51 /* 51 - ANC active mode key (DSP USER 1), 52 - Leakthrough mode key (DSP USER 2) */
#define BIT_DEPTH       16 /* for ANC bit depth needs to be kept at 16 when running higher sample rates */

#include <codec_.h>
#include <file.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <panic.h>
#include <sink.h>
#include <ctype.h>
#include <source.h>
#include <stream.h>
#include <connection.h>
#include <pio.h>
#include <micbias.h>
#include <led.h>
#include <ps.h>
#include <charger.h>

bool adc_rate_flag;
bool dac_rate_flag;

typedef struct {
                bool invert_left_DAC;
                bool invert_right_DAC;
                bool hybrid_ANC;        /* if true, ANC is hybrid using 4 mics */
                bool digital_mics_only; /* true if using all digital mics, false if two mics are analog */
                bool analog_is_FF;      /* if using analog mics and true, the ADC channels A,B are used for FF, if false ADC channels A,B are used for FB (no effect if analog mics are not used)*/
                bool mixed_instances;   /* if true the left DAC is muxed with instances A,C and right DAC with B,D; if false the left DAC is muxed with A,B and right DAC with C,D */
                uint16 pskey_val[61];
                uint8 sidetone_gain_left_ff, sidetone_gain_right_ff, sidetone_gain_left_fb, sidetone_gain_right_fb; 
                uint32 input_gain_left_ff, input_gain_right_ff, input_gain_left_fb, input_gain_right_fb; 
                uint32 dac_gain_left, dac_gain_right;
                IIR_COEFFICIENTS coeff_left_ff;  
                IIR_COEFFICIENTS coeff_right_ff;
                IIR_COEFFICIENTS coeff_left_fb;  
                IIR_COEFFICIENTS coeff_right_fb;
                uint32 ADC_sample_rate;
                uint32 DAC_sample_rate;
                }ANC_config;

void init_setup(ANC_config *anc_config); 

void init_codecs(ANC_config *anc_config);

/* Declare Variables */
ANC_config setup_struct;

int main(void)
{
   /* Turn on LED before each function call, for debugging */
   LedConfigure(LED_0, LED_DUTY_CYCLE, 0x0FFF);
   LedConfigure(LED_0, LED_FLASH_ENABLE, 0);
   LedConfigure(LED_0, LED_ENABLE, 1);
   
   init_setup(&setup_struct);
     
   LedConfigure(LED_1, LED_DUTY_CYCLE, 0x0FFF);
   LedConfigure(LED_1, LED_FLASH_ENABLE, 0);
   LedConfigure(LED_1, LED_ENABLE, 1);
 
   init_codecs(&setup_struct);
   
   LedConfigure(LED_2, LED_DUTY_CYCLE, 0x0FFF);
   LedConfigure(LED_2, LED_FLASH_ENABLE, 0);
   LedConfigure(LED_2, LED_ENABLE, 1);
   
   #ifdef ENABLE_BATTERY_CHARGER
        /* Enable battery charger */    
        ChargerConfigure(CHARGER_ENABLE, TRUE); 
   #endif   
        
   MessageLoop();
   return 0; /* never get here */
}

void init_codecs(ANC_config *anc_config)
{
    /* Initialize DAC sink variables */
    Sink DAC_snk_A = NULL;	
    Sink DAC_snk_B = NULL;
   
    /* Initialize ADC source variables */
    Source ADC_src_A = NULL;
    Source ADC_src_B = NULL;
    Source ADC_src_C = NULL;
    Source ADC_src_D = NULL;

   /* Configure the DAC sink */
   DAC_snk_A = StreamAudioSink(AUDIO_HARDWARE_CODEC, AUDIO_INSTANCE_0, AUDIO_CHANNEL_A);
   DAC_snk_B = StreamAudioSink(AUDIO_HARDWARE_CODEC, AUDIO_INSTANCE_0, AUDIO_CHANNEL_B);
   
   SinkConfigure(DAC_snk_A, STREAM_CODEC_OUTPUT_RATE, anc_config->DAC_sample_rate);
   SinkConfigure(DAC_snk_B, STREAM_CODEC_OUTPUT_RATE, anc_config->DAC_sample_rate);

   /* Configure the gains for DAC */ 
   SinkConfigure(DAC_snk_A, STREAM_CODEC_RAW_OUTPUT_GAIN, anc_config->dac_gain_left);
   SinkConfigure(DAC_snk_B, STREAM_CODEC_RAW_OUTPUT_GAIN, anc_config->dac_gain_right);
   
   /* Configure the precision for DAC */ 
   SinkConfigure(DAC_snk_A, STREAM_AUDIO_SAMPLE_SIZE, BIT_DEPTH);
   SinkConfigure(DAC_snk_B, STREAM_AUDIO_SAMPLE_SIZE, BIT_DEPTH);
   
/* Initialize Instance 0 mics */
if (anc_config->digital_mics_only)
{
   
   ADC_src_A = StreamAudioSource(AUDIO_HARDWARE_DIGITAL_MIC, AUDIO_INSTANCE_0, AUDIO_CHANNEL_A);
   ADC_src_B = StreamAudioSource(AUDIO_HARDWARE_DIGITAL_MIC, AUDIO_INSTANCE_0, AUDIO_CHANNEL_B);
   
   PanicFalse(SourceConfigure(ADC_src_A, STREAM_DIGITAL_MIC_INPUT_RATE, anc_config->ADC_sample_rate));
   PanicFalse(SourceConfigure(ADC_src_B, STREAM_DIGITAL_MIC_INPUT_RATE, anc_config->ADC_sample_rate));
}
else
{

   ADC_src_A = StreamAudioSource(AUDIO_HARDWARE_CODEC, AUDIO_INSTANCE_0, AUDIO_CHANNEL_A);
   ADC_src_B = StreamAudioSource(AUDIO_HARDWARE_CODEC, AUDIO_INSTANCE_0, AUDIO_CHANNEL_B);
   
   SourceConfigure(ADC_src_A, STREAM_CODEC_INPUT_RATE, anc_config->ADC_sample_rate);  
   SourceConfigure(ADC_src_B, STREAM_CODEC_INPUT_RATE, anc_config->ADC_sample_rate);
}

/* Configure the precision for ADC */ 
SourceConfigure(ADC_src_A, STREAM_AUDIO_SAMPLE_SIZE, BIT_DEPTH);
SourceConfigure(ADC_src_B, STREAM_AUDIO_SAMPLE_SIZE, BIT_DEPTH); 

if (anc_config->hybrid_ANC)
{
   /* Initialize Instance 1 digital mics for Right earcup (FF & FB) */
   ADC_src_C = StreamAudioSource(AUDIO_HARDWARE_DIGITAL_MIC, AUDIO_INSTANCE_1, AUDIO_CHANNEL_A);
   ADC_src_D = StreamAudioSource(AUDIO_HARDWARE_DIGITAL_MIC, AUDIO_INSTANCE_1, AUDIO_CHANNEL_B);

   PanicFalse(SourceConfigure(ADC_src_C, STREAM_DIGITAL_MIC_INPUT_RATE, anc_config->ADC_sample_rate));
   PanicFalse(SourceConfigure(ADC_src_D, STREAM_DIGITAL_MIC_INPUT_RATE, anc_config->ADC_sample_rate));
   
   SourceConfigure(ADC_src_C, STREAM_AUDIO_SAMPLE_SIZE, BIT_DEPTH);
   SourceConfigure(ADC_src_D, STREAM_AUDIO_SAMPLE_SIZE, BIT_DEPTH); 
   
   if (anc_config->mixed_instances) /*sidetone routing - mixed instances means A&C are routed to left DAC, B&D are routed to right DAC */
    {
        SinkConfigure(DAC_snk_A, STREAM_CODEC_SIDETONE_SOURCE_MASK, 0x5); /* 0x05 is CH A and C. 0x03 is CH A and B. this mask affects the key settings below */
        SinkConfigure(DAC_snk_A, STREAM_CODEC_INDIVIDUAL_SIDETONE_ENABLE, TRUE);
        SinkConfigure(DAC_snk_A, STREAM_CODEC_SIDETONE_INJECTION_POINT, 1); /* 1 = digital DAC gain is in the path */
       
        SinkConfigure(DAC_snk_B, STREAM_CODEC_SIDETONE_SOURCE_MASK, 0xA); /* 0xA is  Channel B + D, 0xC is CH C and D. this mask affects the key settings below */
        SinkConfigure(DAC_snk_B, STREAM_CODEC_INDIVIDUAL_SIDETONE_ENABLE, TRUE);
        SinkConfigure(DAC_snk_B, STREAM_CODEC_SIDETONE_INJECTION_POINT, 1);
    }
    else /* standard all digital hybrid and analog hybrid single channel cases */
    {
        SinkConfigure(DAC_snk_A, STREAM_CODEC_SIDETONE_SOURCE_MASK, 0x3); /* 0x05 is CH A and C. 0x03 is CH A and B. this mask affects the key settings below */
        SinkConfigure(DAC_snk_A, STREAM_CODEC_INDIVIDUAL_SIDETONE_ENABLE, TRUE);
        SinkConfigure(DAC_snk_A, STREAM_CODEC_SIDETONE_INJECTION_POINT, 1); /* 1 = digital DAC gain is in the path */
        
        SinkConfigure(DAC_snk_B, STREAM_CODEC_SIDETONE_SOURCE_MASK, 0xC); /* 0xA is  Channel B + D, 0xC is CH C and D. this mask affects the key settings below */
        SinkConfigure(DAC_snk_B, STREAM_CODEC_INDIVIDUAL_SIDETONE_ENABLE, TRUE);
        SinkConfigure(DAC_snk_B, STREAM_CODEC_SIDETONE_INJECTION_POINT, 1);
    }

}
else
{  /*not hybrid, ADC A is routed to DAC A, ADC B is routed to DAC B */
   SinkConfigure(DAC_snk_A, STREAM_CODEC_SIDETONE_SOURCE_MASK, 0x1); /* 0x05 is CH A and C. 0x03 is CH A and B. this mask affects the key settings below */
   SinkConfigure(DAC_snk_A, STREAM_CODEC_INDIVIDUAL_SIDETONE_ENABLE, TRUE);
   SinkConfigure(DAC_snk_A, STREAM_CODEC_SIDETONE_INJECTION_POINT, 1); /* 1 = digital DAC gain is in the path */
   
   SinkConfigure(DAC_snk_B, STREAM_CODEC_SIDETONE_SOURCE_MASK, 0x2); /* 0xA is  Channel B + D, 0xC is CH C and D. this mask affects the key settings below */
   SinkConfigure(DAC_snk_B, STREAM_CODEC_INDIVIDUAL_SIDETONE_ENABLE, TRUE);
   SinkConfigure(DAC_snk_B, STREAM_CODEC_SIDETONE_INJECTION_POINT, 1);
}

 
/* Enable or disable the external headphone amp on the CSR8675 dev board - PIO 14 */
#ifdef USES_HEADPHONE_AMP 
    PioSetDir32(0x4000,0x4000);
    PioSet32(0x4000,0x4000);
#else     
    PioSetDir32(0x0000,0x0000);
    PioSet32(0x0000,0x0000);
#endif

/* set DAC phase inversion */     
SinkConfigure(DAC_snk_A, STREAM_CODEC_SIDETONE_INVERT, anc_config->invert_left_DAC);
SinkConfigure(DAC_snk_B, STREAM_CODEC_SIDETONE_INVERT, anc_config->invert_right_DAC);
    
/* Configure the mic bias voltage */
#ifdef ENABLE_MIC_BIAS
    /* Set Bias Voltage 1 = 2.6V 2 = 1.8V */
    MicbiasConfigure(MIC_BIAS_0, MIC_BIAS_ENABLE, MIC_BIAS_FORCE_ON); 
    MicbiasConfigure(MIC_BIAS_0, MIC_BIAS_VOLTAGE, 1);  

    MicbiasConfigure(MIC_BIAS_1, MIC_BIAS_ENABLE, MIC_BIAS_FORCE_ON); 
    MicbiasConfigure(MIC_BIAS_1, MIC_BIAS_VOLTAGE, 1);  
#else
    MicbiasConfigure(MIC_BIAS_0, MIC_BIAS_ENABLE, MIC_BIAS_OFF); 
    MicbiasConfigure(MIC_BIAS_1, MIC_BIAS_ENABLE, MIC_BIAS_OFF);   
#endif

/* Load IIR coefficients */    
if (anc_config->hybrid_ANC)
{
    if (anc_config->mixed_instances)
    {
        if (anc_config->digital_mics_only)
        {
        /* all digital mics hybrid mode, A&B on the left, C&D on the right*/     
        PanicFalse(CodecSetIirFilter16Bit(0x1, 0x1, &anc_config->coeff_left_ff));  /* IIR A */
        PanicFalse(CodecSetIirFilter16Bit(0x2, 0x1, &anc_config->coeff_left_fb));  /* IIR B */
        PanicFalse(CodecSetIirFilter16Bit(0x4, 0x1, &anc_config->coeff_right_ff)); /* IIR C */
        PanicFalse(CodecSetIirFilter16Bit(0x8, 0x1, &anc_config->coeff_right_fb)); /* IIR D */
        
        /* set ADC gains */
        PanicFalse(SourceConfigure(ADC_src_A, STREAM_DIGITAL_MIC_INPUT_GAIN, anc_config->input_gain_left_ff)); 
        PanicFalse(SourceConfigure(ADC_src_B, STREAM_DIGITAL_MIC_INPUT_GAIN, anc_config->input_gain_right_ff)); 
        PanicFalse(SourceConfigure(ADC_src_C, STREAM_DIGITAL_MIC_INPUT_GAIN, anc_config->input_gain_left_fb));
        PanicFalse(SourceConfigure(ADC_src_D, STREAM_DIGITAL_MIC_INPUT_GAIN, anc_config->input_gain_right_fb));
        
        /* set sidetone gains */
        SourceConfigure(ADC_src_A, STREAM_DIGITAL_MIC_INDIVIDUAL_SIDETONE_GAIN, anc_config->sidetone_gain_left_ff);
        SourceConfigure(ADC_src_A, STREAM_DIGITAL_MIC_SIDETONE_SOURCE_POINT, 1); /* 1 - sidetone includes digital gain block */ 
        SourceConfigure(ADC_src_B, STREAM_DIGITAL_MIC_INDIVIDUAL_SIDETONE_GAIN, anc_config->sidetone_gain_right_ff); 
        SourceConfigure(ADC_src_B, STREAM_DIGITAL_MIC_SIDETONE_SOURCE_POINT, 1); /* 1 - sidetone includes digital gain block */ 
        SourceConfigure(ADC_src_C, STREAM_DIGITAL_MIC_INDIVIDUAL_SIDETONE_GAIN, anc_config->sidetone_gain_left_fb); 
        SourceConfigure(ADC_src_C, STREAM_DIGITAL_MIC_SIDETONE_SOURCE_POINT, 1); /* 1 - sidetone includes digital gain block */
        SourceConfigure(ADC_src_D, STREAM_DIGITAL_MIC_INDIVIDUAL_SIDETONE_GAIN, anc_config->sidetone_gain_right_fb); 
        SourceConfigure(ADC_src_D, STREAM_DIGITAL_MIC_SIDETONE_SOURCE_POINT, 1); /* 1 - sidetone includes digital gain block */ 
        }
        
        else
        {
            if (anc_config->analog_is_FF)
            {   /* analog mics for FF, digital mics for FB */
                /* FF uses instance 0 (ADC channels A and B) */
                PanicFalse(CodecSetIirFilter16Bit(0x1, 0x1, &anc_config->coeff_left_ff));  /* IIR A */
                PanicFalse(CodecSetIirFilter16Bit(0x2, 0x1, &anc_config->coeff_right_ff));  /* IIR B */
                PanicFalse(CodecSetIirFilter16Bit(0x4, 0x1, &anc_config->coeff_left_fb)); /* IIR C */
                PanicFalse(CodecSetIirFilter16Bit(0x8, 0x1, &anc_config->coeff_right_fb)); /* IIR D */
                
                /* set ADC gains */
                PanicFalse(SourceConfigure(ADC_src_A, STREAM_CODEC_RAW_INPUT_GAIN, anc_config->input_gain_left_ff));  
                PanicFalse(SourceConfigure(ADC_src_B, STREAM_CODEC_RAW_INPUT_GAIN, anc_config->input_gain_right_ff));
                PanicFalse(SourceConfigure(ADC_src_C, STREAM_DIGITAL_MIC_INPUT_GAIN, anc_config->input_gain_left_fb)); 
                PanicFalse(SourceConfigure(ADC_src_D, STREAM_DIGITAL_MIC_INPUT_GAIN, anc_config->input_gain_right_fb));
                
                /* set sidetone gains */
                SourceConfigure(ADC_src_A, STREAM_CODEC_INDIVIDUAL_SIDETONE_GAIN, anc_config->sidetone_gain_left_ff);
                SourceConfigure(ADC_src_A, STREAM_CODEC_SIDETONE_SOURCE_POINT, 1); /* 1 - sidetone includes digital gain block */
                SourceConfigure(ADC_src_B, STREAM_CODEC_INDIVIDUAL_SIDETONE_GAIN, anc_config->sidetone_gain_right_ff); 
                SourceConfigure(ADC_src_B, STREAM_CODEC_SIDETONE_SOURCE_POINT, 1); /* 1 - sidetone includes digital gain block */
                SourceConfigure(ADC_src_C, STREAM_DIGITAL_MIC_INDIVIDUAL_SIDETONE_GAIN, anc_config->sidetone_gain_left_fb); 
                SourceConfigure(ADC_src_C, STREAM_DIGITAL_MIC_SIDETONE_SOURCE_POINT, 1); /* 1 - sidetone includes digital gain block */
                SourceConfigure(ADC_src_D, STREAM_DIGITAL_MIC_INDIVIDUAL_SIDETONE_GAIN, anc_config->sidetone_gain_right_fb); 
                SourceConfigure(ADC_src_D, STREAM_DIGITAL_MIC_SIDETONE_SOURCE_POINT, 1); /* 1 - sidetone includes digital gain block */ 
            }
            else
            {   /* analog mics for FB, digital mics for FF */
                PanicFalse(CodecSetIirFilter16Bit(0x1, 0x1, &anc_config->coeff_left_fb));  /* IIR A */
                PanicFalse(CodecSetIirFilter16Bit(0x2, 0x1, &anc_config->coeff_right_fb));  /* IIR B */
                PanicFalse(CodecSetIirFilter16Bit(0x4, 0x1, &anc_config->coeff_left_ff)); /* IIR C */
                PanicFalse(CodecSetIirFilter16Bit(0x8, 0x1, &anc_config->coeff_right_ff)); /* IIR D */
               
                /* set ADC gains */
                PanicFalse(SourceConfigure(ADC_src_A, STREAM_CODEC_RAW_INPUT_GAIN, anc_config->input_gain_left_fb));  
                PanicFalse(SourceConfigure(ADC_src_B, STREAM_CODEC_RAW_INPUT_GAIN, anc_config->input_gain_right_fb));
                PanicFalse(SourceConfigure(ADC_src_C, STREAM_DIGITAL_MIC_INPUT_GAIN, anc_config->input_gain_left_ff)); 
                PanicFalse(SourceConfigure(ADC_src_D, STREAM_DIGITAL_MIC_INPUT_GAIN, anc_config->input_gain_right_ff));
                
                /* set sidetone gains */
                SourceConfigure(ADC_src_A, STREAM_CODEC_INDIVIDUAL_SIDETONE_GAIN, anc_config->sidetone_gain_left_fb);
                SourceConfigure(ADC_src_A, STREAM_CODEC_SIDETONE_SOURCE_POINT, 1); /* 1 - sidetone includes digital gain block */
                SourceConfigure(ADC_src_B, STREAM_CODEC_INDIVIDUAL_SIDETONE_GAIN, anc_config->sidetone_gain_right_fb); 
                SourceConfigure(ADC_src_B, STREAM_CODEC_SIDETONE_SOURCE_POINT, 1); /* 1 - sidetone includes digital gain block */
                SourceConfigure(ADC_src_C, STREAM_DIGITAL_MIC_INDIVIDUAL_SIDETONE_GAIN, anc_config->sidetone_gain_left_ff); 
                SourceConfigure(ADC_src_C, STREAM_DIGITAL_MIC_SIDETONE_SOURCE_POINT, 1); /* 1 - sidetone includes digital gain block */
                SourceConfigure(ADC_src_D, STREAM_DIGITAL_MIC_INDIVIDUAL_SIDETONE_GAIN, anc_config->sidetone_gain_right_ff); 
                SourceConfigure(ADC_src_D, STREAM_DIGITAL_MIC_SIDETONE_SOURCE_POINT, 1); /* 1 - sidetone includes digital gain block */ 
               
            }

        }  
    }
    else /* HYBRID with non-mixed IIR instances A,B are muxed to left DAC, C,D are muxed to right DAC */
    {
    
    PanicFalse(CodecSetIirFilter16Bit(0x1, 0x1, &anc_config->coeff_left_ff));  /* IIR A */
    PanicFalse(CodecSetIirFilter16Bit(0x2, 0x1, &anc_config->coeff_left_fb));  /* IIR B */
    PanicFalse(CodecSetIirFilter16Bit(0x4, 0x1, &anc_config->coeff_right_ff)); /* IIR C */
    PanicFalse(CodecSetIirFilter16Bit(0x8, 0x1, &anc_config->coeff_right_fb)); /* IIR D */
        
        if (anc_config->digital_mics_only) /* all digital mics with non-mixed IIR instances */
        {
            /* set ADC gains */
            PanicFalse(SourceConfigure(ADC_src_A, STREAM_DIGITAL_MIC_INPUT_GAIN, anc_config->input_gain_left_ff)); 
            PanicFalse(SourceConfigure(ADC_src_B, STREAM_DIGITAL_MIC_INPUT_GAIN, anc_config->input_gain_left_fb)); 
            PanicFalse(SourceConfigure(ADC_src_C, STREAM_DIGITAL_MIC_INPUT_GAIN, anc_config->input_gain_right_ff));
            PanicFalse(SourceConfigure(ADC_src_D, STREAM_DIGITAL_MIC_INPUT_GAIN, anc_config->input_gain_right_fb));
            
            /* set sidetone gains */
            SourceConfigure(ADC_src_A, STREAM_DIGITAL_MIC_INDIVIDUAL_SIDETONE_GAIN, anc_config->sidetone_gain_left_ff);
            SourceConfigure(ADC_src_A, STREAM_DIGITAL_MIC_SIDETONE_SOURCE_POINT, 1); /* 1 - sidetone includes digital gain block */ 
            SourceConfigure(ADC_src_B, STREAM_DIGITAL_MIC_INDIVIDUAL_SIDETONE_GAIN, anc_config->sidetone_gain_left_fb);
            SourceConfigure(ADC_src_B, STREAM_DIGITAL_MIC_SIDETONE_SOURCE_POINT, 1); /* 1 - sidetone includes digital gain block */ 
            SourceConfigure(ADC_src_C, STREAM_DIGITAL_MIC_INDIVIDUAL_SIDETONE_GAIN, anc_config->sidetone_gain_right_ff); 
            SourceConfigure(ADC_src_C, STREAM_DIGITAL_MIC_SIDETONE_SOURCE_POINT, 1); /* 1 - sidetone includes digital gain block */
            SourceConfigure(ADC_src_D, STREAM_DIGITAL_MIC_INDIVIDUAL_SIDETONE_GAIN, anc_config->sidetone_gain_right_fb); 
            SourceConfigure(ADC_src_D, STREAM_DIGITAL_MIC_SIDETONE_SOURCE_POINT, 1); /* 1 - sidetone includes digital gain block */ 
        }
        else /* this case is for hybrid test mode using analog mics, ADC A and B are analog */
        {     /* set ADC gains */
            PanicFalse(SourceConfigure(ADC_src_A, STREAM_CODEC_RAW_INPUT_GAIN, anc_config->input_gain_left_ff));  
            PanicFalse(SourceConfigure(ADC_src_B, STREAM_CODEC_RAW_INPUT_GAIN, anc_config->input_gain_left_fb));
            PanicFalse(SourceConfigure(ADC_src_C, STREAM_DIGITAL_MIC_INPUT_GAIN, anc_config->input_gain_right_ff));
            PanicFalse(SourceConfigure(ADC_src_D, STREAM_DIGITAL_MIC_INPUT_GAIN, anc_config->input_gain_right_fb));
            
            /* set sidetone gains */
            SourceConfigure(ADC_src_A, STREAM_CODEC_INDIVIDUAL_SIDETONE_GAIN, anc_config->sidetone_gain_left_ff);
            SourceConfigure(ADC_src_A, STREAM_CODEC_SIDETONE_SOURCE_POINT, 1); /* 1 - sidetone includes digital gain block */
            SourceConfigure(ADC_src_B, STREAM_CODEC_INDIVIDUAL_SIDETONE_GAIN, anc_config->sidetone_gain_left_fb); 
            SourceConfigure(ADC_src_B, STREAM_CODEC_SIDETONE_SOURCE_POINT, 1); /* 1 - sidetone includes digital gain block */
            SourceConfigure(ADC_src_C, STREAM_DIGITAL_MIC_INDIVIDUAL_SIDETONE_GAIN, anc_config->sidetone_gain_right_ff); 
            SourceConfigure(ADC_src_C, STREAM_DIGITAL_MIC_SIDETONE_SOURCE_POINT, 1); /* 1 - sidetone includes digital gain block */
            SourceConfigure(ADC_src_D, STREAM_DIGITAL_MIC_INDIVIDUAL_SIDETONE_GAIN, anc_config->sidetone_gain_right_fb); 
            SourceConfigure(ADC_src_D, STREAM_DIGITAL_MIC_SIDETONE_SOURCE_POINT, 1); /* 1 - sidetone includes digital gain block */ 
        }
    }
}
else /*non-hybrid mode (FF or FB only)*/
{
    PanicFalse(CodecSetIirFilter16Bit(0x1, 0x1, &anc_config->coeff_left_ff));  /* IIR A */
    PanicFalse(CodecSetIirFilter16Bit(0x2, 0x1, &anc_config->coeff_right_ff));  /* IIR B */
    
    if (anc_config->digital_mics_only)
    {
            /* set ADC gains */
        PanicFalse(SourceConfigure(ADC_src_A, STREAM_DIGITAL_MIC_INPUT_GAIN, anc_config->input_gain_left_ff)); 
        PanicFalse(SourceConfigure(ADC_src_B, STREAM_DIGITAL_MIC_INPUT_GAIN, anc_config->input_gain_right_ff)); 
        
        /* set sidetone gains */
        SourceConfigure(ADC_src_A, STREAM_DIGITAL_MIC_INDIVIDUAL_SIDETONE_GAIN, anc_config->sidetone_gain_left_ff);
        SourceConfigure(ADC_src_A, STREAM_DIGITAL_MIC_SIDETONE_SOURCE_POINT, 1); /* 1 - sidetone includes digital gain block */ 
        SourceConfigure(ADC_src_B, STREAM_DIGITAL_MIC_INDIVIDUAL_SIDETONE_GAIN, anc_config->sidetone_gain_right_ff);
        SourceConfigure(ADC_src_B, STREAM_DIGITAL_MIC_SIDETONE_SOURCE_POINT, 1); /* 1 - sidetone includes digital gain block */ 
    }
    else
    {

    /* set ADC gains */
        SourceConfigure(ADC_src_A, STREAM_CODEC_RAW_INPUT_GAIN, anc_config->input_gain_left_ff);  
        SourceConfigure(ADC_src_B, STREAM_CODEC_RAW_INPUT_GAIN, anc_config->input_gain_right_ff);
        
        /* set sidetone gains */
        SourceConfigure(ADC_src_A, STREAM_CODEC_INDIVIDUAL_SIDETONE_GAIN, anc_config->sidetone_gain_left_ff);
        SourceConfigure(ADC_src_A, STREAM_CODEC_SIDETONE_SOURCE_POINT, 1); /* 1 - sidetone includes digital gain block */
        SourceConfigure(ADC_src_B, STREAM_CODEC_INDIVIDUAL_SIDETONE_GAIN, anc_config->sidetone_gain_right_ff); 
        SourceConfigure(ADC_src_B, STREAM_CODEC_SIDETONE_SOURCE_POINT, 1); /* 1 - sidetone includes digital gain block */

    }
}

/* connect streams to kalimba to force software rate matching */        
PanicFalse(StreamConnect(ADC_src_A, StreamKalimbaSink(0)));
PanicFalse(StreamConnect(ADC_src_B, StreamKalimbaSink(1)));

if (anc_config->hybrid_ANC)
{   
    PanicFalse(StreamConnect(ADC_src_C, StreamKalimbaSink(2)));
    PanicFalse(StreamConnect(ADC_src_D, StreamKalimbaSink(3)));
}

/* connect dummy DAC streams */
PanicFalse(StreamConnect(StreamKalimbaSource(0), DAC_snk_A));
PanicFalse(StreamConnect(StreamKalimbaSource(1), DAC_snk_B));
}

uint16 size_ps_key, i;
uint16 sidetone_gain[3];
void init_setup(ANC_config *returnvalue){
    /* load setup from PSkeys */
       
    size_ps_key = PsRetrieve(PSKEY_TO_READ, returnvalue->pskey_val, 61);
    
    /* initialize some values */
    returnvalue->hybrid_ANC = 0;

     /* get sidetone gain PSKEY USER 44 */
    PsFullRetrieve(0x02B6, sidetone_gain, 3);
    returnvalue->sidetone_gain_left_ff = sidetone_gain[2] & 0x000F;
    returnvalue->sidetone_gain_right_ff = sidetone_gain[2] & 0x000F;
    returnvalue->sidetone_gain_left_fb = sidetone_gain[2] & 0x000F;
    returnvalue->sidetone_gain_right_fb = sidetone_gain[2] & 0x000F;

    if (size_ps_key > 0)
    {
       for (i = 0;i<11;i++)
       {
          /* first section is FF, second section is FB (left and right sections are the same */
          returnvalue->coeff_left_ff.coefficients[i] = returnvalue->pskey_val[i];
          returnvalue->coeff_right_ff.coefficients[i] = returnvalue->pskey_val[i+11];
       }
       
       /* get raw input gain */
       returnvalue->input_gain_left_ff  = (((unsigned long)returnvalue->pskey_val[22]) << 16) + returnvalue->pskey_val[26];
       returnvalue->input_gain_right_ff = (((unsigned long)returnvalue->pskey_val[23]) << 16) + returnvalue->pskey_val[27];
                 
       /* get raw output gain */
       returnvalue->dac_gain_left = ((unsigned long)returnvalue->pskey_val[24]<<16) + returnvalue->pskey_val[28];
       returnvalue->dac_gain_right = ((unsigned long)returnvalue->pskey_val[25]<<16) + returnvalue->pskey_val[29];  
       
       /* get phase inversion */
       returnvalue->invert_left_DAC = returnvalue->pskey_val[30] & 0x0008;
       returnvalue->invert_right_DAC = returnvalue->pskey_val[30] & 0x0004;
       
       /* get sample rates */
       adc_rate_flag = returnvalue->pskey_val[30] & 0x0020;
       dac_rate_flag = returnvalue->pskey_val[30] & 0x0010;

       /* get config bits */
       returnvalue->digital_mics_only = returnvalue->pskey_val[30] & 0x1000;
       returnvalue->analog_is_FF = returnvalue->pskey_val[30] & 0x0100;
       returnvalue->mixed_instances = returnvalue->pskey_val[30] & 0x0200;
       
       if (adc_rate_flag)
       {
           returnvalue->ADC_sample_rate = 96000;
       }
       else
       {
           returnvalue->ADC_sample_rate = 48000; 
       }

       if (dac_rate_flag)
       {
           returnvalue->DAC_sample_rate = 192000;
       }
       else
       {
           returnvalue->DAC_sample_rate = 96000;
       }
    }
    if (size_ps_key > 31) /* if PSkey is longer than 31 words, assume hybrid */
    {
       returnvalue->hybrid_ANC = 1;

       for (i = 0;i<11;i++)
       {
        returnvalue->coeff_left_fb.coefficients[i] = returnvalue->pskey_val[i+33]; /* FB coefficients start at word 33 */
        returnvalue->coeff_right_fb.coefficients[i] = returnvalue->pskey_val[i+33+11];
       }

       /* get raw input gain */
       returnvalue->input_gain_left_fb  = ((unsigned long)returnvalue->pskey_val[55]<<16) + returnvalue->pskey_val[57];
       returnvalue->input_gain_right_fb = ((unsigned long)returnvalue->pskey_val[56]<<16) + returnvalue->pskey_val[58];

    }
    
    }


