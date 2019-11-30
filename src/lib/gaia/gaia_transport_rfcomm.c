/*****************************************************************
Copyright (c) 2011 - 2015 Qualcomm Technologies International, Ltd.
*/

#include "gaia.h"
#include "gaia_private.h"

#ifdef GAIA_TRANSPORT_RFCOMM
#include <string.h>
#include <stream.h>
#include <source.h>
#include <sink.h>
#include <sppc.h>
#include <library.h>

#include "gaia_transport.h"
#include "gaia_transport_rfcomm.h"
#include "gaia_transport_common.h"


static const uint8 gaia_rfcomm_service_record[] =
{
    0x09, 0x00, 0x01,           /*  0  1  2  ServiceClassIDList(0x0001) */
    0x35,   17,                 /*  3  4     DataElSeq 17 bytes */
    0x1C, 0x00, 0x00, 0x11, 0x07, 0xD1, 0x02, 0x11, 0xE1, 0x9B, 0x23, 0x00, 0x02, 0x5B, 0x00, 0xA5, 0xA5,       
                                /*  5 .. 21  UUID GAIA (0x00001107-D102-11E1-9B23-00025B00A5A5) */
    0x09, 0x00, 0x04,           /* 22 23 24  ProtocolDescriptorList(0x0004) */
    0x35,   12,                 /* 25 26     DataElSeq 12 bytes */
    0x35,    3,                 /* 27 28     DataElSeq 3 bytes */
    0x19, 0x01, 0x00,           /* 29 30 31  UUID L2CAP(0x0100) */
    0x35,    5,                 /* 32 33     DataElSeq 5 bytes */
    0x19, 0x00, 0x03,           /* 34 35 36  UUID RFCOMM(0x0003) */
    0x08, SPP_DEFAULT_CHANNEL,  /* 37 38     uint8 RFCOMM channel */
#define GAIA_RFCOMM_SR_CH_IDX (38)
    0x09, 0x00, 0x06,           /* 39 40 41  LanguageBaseAttributeIDList(0x0006) */
    0x35,    9,                 /* 42 43     DataElSeq 9 bytes */
    0x09,  'e',  'n',           /* 44 45 46  Language: English */
    0x09, 0x00, 0x6A,           /* 47 48 49  Encoding: UTF-8 */
    0x09, 0x01, 0x00,           /* 50 51 52  ID base: 0x0100 */
    0x09, 0x01, 0x00,           /* 53 54 55  ServiceName 0x0100, base + 0 */
    0x25,   4,                 /* 56 57     String length 4 */
    'G', 'A', 'I', 'A',          /* 58 59 60 61  "GAIA" */
};


static const rfcomm_config_params rfcomm_config = 
{
    RFCOMM_DEFAULT_PAYLOAD_SIZE,
    RFCOMM_DEFAULT_MODEM_SIGNAL,
    RFCOMM_DEFAULT_BREAK_SIGNAL,
    RFCOMM_DEFAULT_MSC_TIMEOUT
};
        

static void sdp_register_rfcomm(uint8 channel)
{
    /* Default to use const record */
    const uint8 *sr = gaiaTransportCommonServiceRecord(gaia_rfcomm_service_record, GAIA_RFCOMM_SR_CH_IDX, channel);

    if(!sr)
        GAIA_PANIC();

    /* Store the RFCOMM channel */
    gaia->spp_listen_channel = channel;
    GAIA_TRANS_DEBUG(("gaia: ch %u\n", channel));

    /* Register the SDP record */
    ConnectionRegisterServiceRecord(&gaia->task_data, sizeof(gaia_rfcomm_service_record), sr);
}


/*************************************************************************
NAME
    gaiaTransportRfcommDropState
    
DESCRIPTION
    Clear down RFCOMM-specific components of transport state
*/
void gaiaTransportRfcommDropState(gaia_transport *transport)
{
    transport->state.spp.sink = NULL;
}


/*************************************************************************
NAME
    gaiaTransportRfcommSendPacket
    
DESCRIPTION
    Copy the passed packet to the transport sink and flush it
    If <task> is not NULL, send a confirmation message
*/
void gaiaTransportRfcommSendPacket(Task task, gaia_transport *transport, uint16 length, uint8 *data)
{
    bool status = FALSE;
    
    if (gaia)
    {
        Sink sink = gaiaTransportGetSink(transport);
        
        if (SinkClaim(sink, length) == BAD_SINK_CLAIM)
        {
            GAIA_TRANS_DEBUG(("gaia: no sink\n"));
        }

        else
        {
            uint8 *sink_data = SinkMap(sink);
            memcpy (sink_data, data, length);

#ifdef DEBUG_GAIA_TRANSPORT
            {
                uint16 idx;
                GAIA_DEBUG(("gaia: put"));
                for (idx = 0; idx < length; ++idx)
                    GAIA_DEBUG((" %02x", data[idx]));
                GAIA_DEBUG(("\n"));
            }
#endif
            status = SinkFlush(sink, length);
        }   
    }
    
    if (task)
        gaiaTransportCommonSendGaiaSendPacketCfm(transport, data, status);
    
    else
        free(data);
}


/*! @brief
 */
void gaiaTransportRfcommConnectRes(gaia_transport *transport)
{
    UNUSED(transport);
}

/*! @brief
 */
void gaiaTransportRfcommDisconnectReq(gaia_transport *transport)
{
    ConnectionRfcommDisconnectRequest(&gaia->task_data, gaiaTransportRfcommGetSink(transport));
}

/*! @brief
 */
void gaiaTransportRfcommDisconnectRes(gaia_transport *transport)
{
    UNUSED(transport);
}

/*! @brief
 */
void gaiaTransportRfcommStartService(void)
{
    ConnectionRfcommAllocateChannel(&gaia->task_data, SPP_DEFAULT_CHANNEL);
}

/*! @brief
 */
Sink gaiaTransportRfcommGetSink(gaia_transport *transport)
{
    return transport->state.spp.sink;
}


/*! @brief
 */
bool gaiaTransportRfcommHandleMessage(Task task, MessageId id, Message message)
{
    bool msg_handled = TRUE;    /* default position is we've handled the message */

    switch (id)
    {
        case GAIA_INTERNAL_MORE_DATA:
            {
                GAIA_INTERNAL_MORE_DATA_T *m = (GAIA_INTERNAL_MORE_DATA_T *) message;
                GAIA_TRANS_DEBUG(("gaia: GAIA_INTERNAL_MORE_DATA: t=%p\n", (void *) m->transport));
                gaiaTransportProcessSource(m->transport);
            }
            break;
            
            
        case MESSAGE_MORE_DATA:
            {
                MessageMoreData *m = (MessageMoreData *) message;
                gaia_transport *t = gaiaTransportFromSink(StreamSinkFromSource(m->source));
                GAIA_TRANS_DEBUG(("gaia: MESSAGE_MORE_DATA: t=%p\n", (void *) t));
                
                if (t && (t->type == gaia_transport_rfcomm))
                    gaiaTransportProcessSource(t);
                
                else
                    msg_handled = FALSE;
            }
            break;
            

        case CL_RFCOMM_REGISTER_CFM:
            {
                CL_RFCOMM_REGISTER_CFM_T *m = (CL_RFCOMM_REGISTER_CFM_T *) message;
                GAIA_TRANS_DEBUG(("gaia: CL_RFCOMM_REGISTER_CFM: %d = %d\n", m->server_channel, m->status));
                
                if (m->status == success)
                    sdp_register_rfcomm(m->server_channel);
                
                else
                    gaiaTransportCommonSendGaiaStartServiceCfm(gaia_transport_rfcomm, NULL, FALSE);
            }
            break;
        
            
        case CL_SDP_REGISTER_CFM:
            {
                CL_SDP_REGISTER_CFM_T *m = (CL_SDP_REGISTER_CFM_T *) message;
                GAIA_TRANS_DEBUG(("gaia: CL_SDP_REGISTER_CFM: %d\n", m->status));
                
                if (m->status == sds_status_success)
                {
                    if (gaia->spp_sdp_handle == 0)
                        gaiaTransportCommonSendGaiaStartServiceCfm(gaia_transport_rfcomm, NULL, TRUE);
                    
                    gaia->spp_sdp_handle = m->service_handle;
                }
                
                else
                    gaiaTransportCommonSendGaiaStartServiceCfm(gaia_transport_rfcomm, NULL, FALSE);
            }
            break;

            
        case CL_RFCOMM_CONNECT_IND:
            {
                CL_RFCOMM_CONNECT_IND_T *m = (CL_RFCOMM_CONNECT_IND_T *) message;
                gaia_transport *transport = gaiaTransportFindFree();

                GAIA_TRANS_DEBUG(("gaia: CL_RFCOMM_CONNECT_IND\n"));
                
                if (transport == NULL)
                    ConnectionRfcommConnectResponse(task, FALSE, m->sink, m->server_channel, &rfcomm_config);
                
                else
                {
                    transport->type = gaia_transport_rfcomm;
                    transport->state.spp.sink = m->sink;
                    transport->state.spp.rfcomm_channel = m->server_channel;
                    ConnectionRfcommConnectResponse(task, TRUE, m->sink, m->server_channel, &rfcomm_config);
                }
            }
            break;
            
            
        case CL_RFCOMM_SERVER_CONNECT_CFM:
            {
                CL_RFCOMM_SERVER_CONNECT_CFM_T *m = (CL_RFCOMM_SERVER_CONNECT_CFM_T *) message;
                gaia_transport *transport = gaiaTransportFromRfcommChannel(m->server_channel);
                
                GAIA_TRANS_DEBUG(("gaia: CL_RFCOMM_SERVER_CONNECT_CFM: ch=%d sts=%d\n", 
                                  m->server_channel, m->status));
                
                if (m->status == rfcomm_connect_success)
                {
                    transport->state.spp.sink = m->sink;
                    transport->state.spp.rfcomm_channel = m->server_channel;
                    ConnectionUnregisterServiceRecord(task, gaia->spp_sdp_handle);
                    gaiaTransportCommonSendGaiaConnectInd(transport, TRUE);
                    transport->connected = TRUE;
                    transport->enabled = TRUE;
                }
                
                else
                    gaiaTransportCommonSendGaiaConnectInd(transport, FALSE);
                    
            }
            break;
            
            
        case CL_SDP_UNREGISTER_CFM:
            {
                CL_SDP_UNREGISTER_CFM_T *m = (CL_SDP_UNREGISTER_CFM_T *) message;
                GAIA_TRANS_DEBUG(("gaia: CL_SDP_UNREGISTER_CFM: %d\n", m->status));
                if (m->status == sds_status_success)
                {
                /*  Get another channel from the pool  */
                    ConnectionRfcommAllocateChannel(task, SPP_DEFAULT_CHANNEL);
                }
            }
            break;
 
            
        case CL_RFCOMM_DISCONNECT_IND:
            {
                CL_RFCOMM_DISCONNECT_IND_T *m = (CL_RFCOMM_DISCONNECT_IND_T *) message;
                gaia_transport *transport = gaiaTransportFromSink(m->sink);
                
                GAIA_TRANS_DEBUG(("gaia: CL_RFCOMM_DISCONNECT_IND\n"));
                
                ConnectionRfcommDisconnectResponse(m->sink);
		/* throw away any remaining input data */
		gaiaTransportFlushInput(transport);

            /*  release channel for re-use  */
                ConnectionRfcommDeallocateChannel(task, transport->state.spp.rfcomm_channel);
            }
            break;
        

        case CL_RFCOMM_DISCONNECT_CFM:
            {
                CL_RFCOMM_DISCONNECT_CFM_T *m = (CL_RFCOMM_DISCONNECT_CFM_T *) message;
                gaia_transport *transport = gaiaTransportFromSink(m->sink);
                
                GAIA_TRANS_DEBUG(("gaia: CL_RFCOMM_DISCONNECT_CFM\n"));
                gaiaTransportTidyUpOnDisconnection(transport);
                gaiaTransportCommonSendGaiaDisconnectCfm(transport);

                /* Flush any remaining input data */
                gaiaTransportFlushInput(transport);

                /* Release channel for re-use  */
                ConnectionRfcommDeallocateChannel(task, transport->state.spp.rfcomm_channel);
            }
            break;
            
            
        case CL_RFCOMM_UNREGISTER_CFM:
            {
                CL_RFCOMM_UNREGISTER_CFM_T *m = (CL_RFCOMM_UNREGISTER_CFM_T *) message;
                GAIA_TRANS_DEBUG(("gaia: CL_RFCOMM_UNREGISTER_CFM\n"));
                
                if (m->status == success)
                {
                    gaia_transport *transport = gaiaTransportFromRfcommChannel(m->server_channel);
                    gaiaTransportCommonSendGaiaDisconnectInd(transport);                            
                }
            }
            break;
            
        case CL_RFCOMM_PORTNEG_IND:
            {
                CL_RFCOMM_PORTNEG_IND_T *m = (CL_RFCOMM_PORTNEG_IND_T*)message;
                GAIA_TRANS_DEBUG(("gaia:CL_RFCOMM_PORTNEG_IND\n"));

                /* If this was a request send our default port params, otherwise accept any requested changes */
                ConnectionRfcommPortNegResponse(task, m->sink, m->request ? NULL : &m->port_params);
            }
            break;

             /*  Things to ignore  */
        case MESSAGE_MORE_SPACE:
        case MESSAGE_SOURCE_EMPTY:
        case CL_RFCOMM_CONTROL_IND:
        case CL_RFCOMM_LINE_STATUS_IND:
            break;

        default:
            {
                /* indicate we couldn't handle the message */
            /*  GAIA_DEBUG(("gaia: rfcomm: unh 0x%04X\n", id));  */
                msg_handled = FALSE;
            }
            break;
    }

    return msg_handled;
}

#endif /* GAIA_TRANSPORT_RFCOMM */
