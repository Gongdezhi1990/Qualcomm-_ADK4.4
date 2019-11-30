/****************************************************************************
Copyright (c) 2004 - 2015 Qualcomm Technologies International, Ltd.
Part of ADK_CSR867x.WIN. 4.4

FILE NAME
    upgrade_partition_validation.h
    
DESCRIPTION

*/
#ifndef UPGRADE_PARTITION_VALIDATION_H_
#define UPGRADE_PARTITION_VALIDATION_H_

#include <csrtypes.h>

typedef enum {
    UPGRADE_PARTITION_VALIDATION_DONE,
    UPGRADE_PARTITION_VALIDATION_IN_PROGRESS
} UpgradePartitionValidationResult;

void UpgradePartitionValidationInit(void);
UpgradePartitionValidationResult UpgradePartitionValidationValidate(void);

#endif /* UPGRADE_PARTITION_VALIDATION_H_ */
