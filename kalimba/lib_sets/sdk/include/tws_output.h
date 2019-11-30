/****************************************************************************
//  Copyright (c) 2017 Qualcomm Technologies International, Ltd.
 %%version
****************************************************************************/

#ifndef TWS_OUTPUT_H
#define TWS_OUTPUT_H

#include <md.h>
#include <bitwriter.h>

#define TWS_PACKET_HEADER_SIZE (5)
#define TWS_FRAME_HEADER_SIZE (3)

#ifdef KCC

#include <core_library_c_stubs.h>
#include <rtime.h>

typedef struct tws_output_params
{
    unsigned output_port;

    /** The minimum time before time-to-play to Tx frame */
    time_t tx_time_min;
    time_t tx_time_flush;

    /** Maximum number of audio payload */
    unsigned max_audio_size;

    /** The meta-data list for input frames */
    md_list_t *frame_in_md_list;

    /** The meta-data list for output frames */
    md_list_t *frame_out_md_list;

    /** Internal state */
    unsigned audio_size;
    int tx_time_before_ttp;
    md_list_t frame_tx_md_list;
    bitwriter_t bw; 
    volatile unsigned tx_ready;   
    unsigned tx_ttp;
    unsigned system_time_source;
    unsigned volume;
} tws_output_params_t;

void tws_output_initialise(struct tws_output_params *params);
void tws_output_process(struct tws_output_params *params);
void tws_output_set_tx_window(struct tws_output_params *params, time_t tx_time_min, time_t tx_time_flush);
void tws_output_set_volume(struct tws_output_params *params, unsigned int volume);
void tws_output_copy(struct tws_output_params *params);

#else /* KCC */

#include <md.h>

#endif /* KCC */

/* Size in words of the tws_output_params structure */
#define TWS_OUTPUT_PARAMS_STRUC_SIZE (12 + MD_LIST_STRUC_SIZE + BITWRITER_STRUC_SIZE)

#ifdef KCC
#include <kalimba_c_util.h>
STRUC_SIZE_CHECK(tws_output_params_t, TWS_OUTPUT_PARAMS_STRUC_SIZE);
#endif /* KCC */

#endif /* TWS_OUTPUT */
