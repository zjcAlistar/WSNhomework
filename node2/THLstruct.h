#ifndef THLSTRUCT_H
#define THLSTRUCT_H

enum {
  AM_THLRADIO = 4,
  TIMER_PERIOD_MILLI = 250,
  TIMER_PERIOD_SEND = 50
};

typedef nx_struct thlmsg {
  nx_uint16_t counter;
  nx_uint16_t version;
  nx_uint16_t interval;
  nx_uint16_t nodeid;
  nx_uint16_t temperature;
  nx_uint16_t humidity;
  nx_uint16_t illumination;
} thlmsg_t;

#endif