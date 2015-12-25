#ifndef THLSTRUCT_H
#define THLSTRUCT_H

enum {
  AM_THLRADIO = 4,
  MAX_SEQ_NUM = 10,
  TIMER_PERIOD_MILLI = 250
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

typedef struct msgSequence{
	uint16_t head;
	uint16_t tail;
	uint16_t length;
	thlmsg queue[MAX_SEQ_NUM];
}msgSequence_t;

#endif