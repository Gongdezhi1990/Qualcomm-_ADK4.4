/****************************************************************************
Copyright (c) 2018 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4
 
FILE NAME
    sink_ba_broadcaster_association.c
 
DESCRIPTION
    Broadcast association API for LE and GATT.
*/

#include "sink_ba_broadcaster_association.h"
#include "sink_debug.h"

#ifdef ENABLE_BROADCAST_AUDIO

#include "sink_gatt_server_ba.h"

#ifdef DEBUG_BA_BROADCASTER
#define DEBUG_BROADCASTER(x) DEBUG(x)
#else
#define DEBUG_BROADCASTER(x)
#endif

/* Connection ID of link to GATT peer. */
static uint16 receiver_cid = INVALID_CID;

void sinkBroadcasterHandleReceiverConnectCfm(GATT_MANAGER_REMOTE_SERVER_CONNECT_CFM_T* cfm)
{
    if (cfm->status == gatt_status_success)
    {
        DEBUG_BROADCASTER(("Broadcaster: Gatt Remote server Connect Success->Start Assoc\n"));
        receiver_cid = cfm->cid;
        /* found and connected to a csb_receiver, allow it to read the broadcaster's association data */
        sinkGattBAServerEnableAssociation(TRUE);
    }
    else
    {
        DEBUG_BROADCASTER(("Broadcaster: Gatt Remote server Connect Failed (0x%x)->Retry\n", cfm->status));
    }
}

/******************************************************************************/
void sinkBroadcasterHandleReceiverDisconnectInd(GATT_MANAGER_DISCONNECT_IND_T* ind)
{
    UNUSED(ind);

    DEBUG_BROADCASTER(("Broadcaster: Gatt Manger DisconnectInd\n"));
    receiver_cid = INVALID_CID;
    sinkGattBAServerEnableAssociation(FALSE);
    /* Send system message to stop associating led pattern LedAssociating(FALSE);*/
}

/******************************************************************************/
bool sinkBroadcasterIsReceiverCid(uint16 cid)
{
    bool cid_belongs_to_receiver = FALSE;

    if(receiver_cid != INVALID_CID)
    {
        cid_belongs_to_receiver = (cid == receiver_cid);
    }

    return cid_belongs_to_receiver;
}

#endif
