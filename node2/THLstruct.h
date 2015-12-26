#ifndef THLSTRUCT_H
#define THLSTRUCT_H

enum {
  AM_THLRADIO = 4,
  AM_ACKRADIO = 3,
  AM_FRERADIO = 2,
  NODE0_ADDR = 66,
  NODE1_ADDR = 67,
  NODE2_ADDR = 68,
  TIMER_PERIOD_MILLI = 500,
  TIMER_PERIOD_SEND = 250
};

typedef nx_struct thlmsg {
  nx_uint16_t nodeid;
  nx_uint16_t counter;
  nx_uint16_t interval;
  nx_uint16_t temperature;
  nx_uint16_t humidity;
  nx_uint16_t illumination;
  nx_uint32_t collecttime;
} thlmsg_t;

typedef nx_struct thlack {
  nx_uint16_t nodeid;
  nx_uint16_t counter;
} thlack_t;

typedef nx_struct thlfre {
  nx_uint16_t nodeid;
  nx_uint16_t interval;
} thlfre_t;
#endif