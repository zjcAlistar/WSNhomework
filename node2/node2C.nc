#include "Timer.h"
#include "THLstruct.h"

module node2C @safe()
{
  uses {
    interface Boot;
    interface Leds;
    interface Timer<TMilli> as Timer;
    interface Timer<TMilli> as sendTimer;
    interface AMSend;
    interface SplitControl as AMControl;
    interface Read<uint16_t> as TRead;
    interface Read<uint16_t> as HRead;
    interface Read<uint16_t> as LRead;
  }
}
implementation
{
  enum{
    MAX_QUEUE_LEN = 30;
  }
  message_t sendBuf;
  thlmsg_t local;
  uint16_t counter;
  bool busy = FALSE;
  message_t sendQueue[MAX_QUEUE_LEN];
  uint16_t queueIn, queueOut;
  bool full 


  void report_problem() { call Leds.led0Toggle(); }
  void report_sent() { call Leds.led1Toggle(); }
  void report_received() { call Leds.led2Toggle(); }

  event void Boot.booted() {
    local.version = 0x1;
    local.interval = TIMER_PERIOD_MILLI;
    local.nodeid = TOS_NODE_ID;
    queueIn = queueOut = 0;

    call AMControl.start();
  }

  event void AMControl.startDone(error_t err) {
    if (err == SUCCESS) {
      call Timer.startPeriodic(TIMER_PERIOD_MILLI);
    }
    else {
      call AMControl.start();
    }
  }

  event void AMControl.stopDone(error_t err) {
  }

  event void Timer.fired() {
    if (call TRead.read() != SUCCESS)
      report_problem();
    if (call HRead.read() != SUCCESS)
      report_problem();
    if (call LRead.read() != SUCCESS)
      report_problem();
    counter++;
    local.counter = counter;
    if (!busy) {
      memcpy(call AMSend.getPayload(&sendBuf, sizeof(local)), &local, sizeof local);
      if (call AMSend.send(AM_BROADCAST_ADDR, &sendBuf, sizeof local) == SUCCESS) {
        busy = TRUE;
      }
    }
    if (!busy) report_problem();
  }

  event void AMSend.sendDone(message_t* msg, error_t err) {
    if (err == SUCCESS)
      report_sent();
    else
      report_problem();
    busy = FALSE;
  }

  event void TRead.readDone(error_t result, uint16_t data) {
    if (result != SUCCESS){
        data = 0xffff;
        report_problem();
    }
    local.temperature = -39.6+0.01*data;
  }

  event void HRead.readDone(error_t result, uint16_t data) {
    if (result != SUCCESS){
        data = 0xffff;
        report_problem();
    }
    local.humidity = -4+0.0405*data+(-2.8/1000000)*(data*data);;
  }

  event void LRead.readDone(error_t result, uint16_t data) {
    if (result != SUCCESS){
        data = 0xffff;
        report_problem();
    }
    local.illumination = data;
  }

}