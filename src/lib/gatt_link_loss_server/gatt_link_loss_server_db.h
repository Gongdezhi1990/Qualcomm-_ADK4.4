/*
 * THIS FILE IS AUTOGENERATED, DO NOT EDIT!
 *
 * generated by gattdbgen from gatt_link_loss_server/gatt_link_loss_server_db.dbi_
 */
#ifndef __GATT_LINK_LOSS_SERVER_DB_H
#define __GATT_LINK_LOSS_SERVER_DB_H

#include <csrtypes.h>

#define HANDLE_LINK_LOSS_SERVICE        (0x0001)
#define HANDLE_LINK_LOSS_SERVICE_END    (0xffff)
#define HANDLE_LINK_LOSS_ALERT_LEVEL    (0x0003)

uint16 *GattGetDatabase(uint16 *len);
uint16 GattGetDatabaseSize(void);

#endif

/* End-of-File */
