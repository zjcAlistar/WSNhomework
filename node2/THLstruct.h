#ifndef THL_H
#define THL_H

enum {
  AM_THLRADIO = 4,
  TIMER_PERIOD_MILLI = 250
};

typedef nx_struct THLMsg {
  nx_uint16_t nodeid;
  nx_uint16_t temperature;
  nx_uint16_t humidity;
  nx_uint16_t illumination;
} THLMsg;

#endif