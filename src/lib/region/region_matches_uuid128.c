/*******************************************************************************
Copyright (c) 2017 Qualcomm Technologies International, Ltd.
 Part of ADK_CSR867x.WIN. 4.4
*******************************************************************************/

#include "region.h"

#include <string.h>

bool RegionMatchesUUID128(const Region *r, const uint8 *uuid)
{
    /* 16 is the only valid size */
    return (RegionSize(r) == 16 && (memcmp(uuid, r->begin, 16) == 0));
}

