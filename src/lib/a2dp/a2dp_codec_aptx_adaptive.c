/****************************************************************************
Copyright (c) 2018 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4

FILE NAME
    a2dp_codec_aptx_adaptive.c

DESCRIPTION
    This file contains aptX Adaptive specific code.

NOTES

*/

#ifndef A2DP_SBC_ONLY

/****************************************************************************
    Header files
*/
#include "a2dp.h"
#include "a2dp_private.h"
#include "a2dp_caps_parse.h"
#include "a2dp_codec_aptx_adaptive.h"

static aptx_adaptive_ttp_latencies_t getNq2qTargetTtpLatencies(void)
{
    aptx_adaptive_ttp_latencies_t nq2q_ttp = {100, 100, 75, 100};
    return nq2q_ttp;
}

/**************************************************************************/
void selectOptimalAptxAdCapsSink(const uint8 *local_codec_caps, uint8 *remote_codec_caps)
{
    /* Choose what is supported at both sides */
    remote_codec_caps[10] = (remote_codec_caps[10]) & (local_codec_caps[10]);

    /* Select sample frequency */
    if (remote_codec_caps[10] & 0x20)
    {   /* choose 44k1 */
        remote_codec_caps[10] &= 0x2f;
    }
    else
    {   /* choose 48k */
        remote_codec_caps[10] &= 0x1f;
    }

    /*Choose stereo */
    remote_codec_caps[10] &= 0xf2;
}


/**************************************************************************/
void selectOptimalAptxAdCapsSource(const uint8 *local_codec_caps, uint8 *remote_codec_caps)
{
    /* Choose what is supported at both sides */
    remote_codec_caps[10] = (remote_codec_caps[10]) & (local_codec_caps[10]);

    /* Select sample frequency */
    if (remote_codec_caps[10] & 0x10)
    {   /* choose 48k */
        remote_codec_caps[10] &= 0x1f;
    }
    else
    {   /* choose 44k1 */
        remote_codec_caps[10] &= 0x2f;
    }

    /*Choose stereo */
    remote_codec_caps[10] &= 0xf2;
}

/*************************************************************************/
void getAptxAdConfigSettings(const uint8 *service_caps, a2dp_codec_settings *codec_settings)
{
    codec_settings->codecData.packet_size = 668;
    codec_settings->channel_mode = a2dp_stereo;

    codec_settings->codecData.aptx_ad_params.avrcp_cmd_supported = FALSE;
    codec_settings->codecData.aptx_ad_params.q2q_enabled = FALSE;
    codec_settings->codecData.aptx_ad_params.nq2q_ttp = getNq2qTargetTtpLatencies();

    if (service_caps && (service_caps[10] & 0x10))
    {
        codec_settings->rate = 48000;
    }
    else
    {
        codec_settings->rate = 44100;
    }
}

#else
    static const int dummy;
#endif /* A2DP_SBC_ONLY */
