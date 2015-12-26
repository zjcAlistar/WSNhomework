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
    interface Receive as ackReceive;
    interface Receive as freReceive;
    interface SplitControl as AMControl;
    interface Read<uint16_t> as TRead;
    interface Read<uint16_t> as HRead;
    interface Read<uint16_t> as LRead;
    interface AMPacket;
  }
}
implementation
{
  enum{
    MAX_QUEUE_LEN = 30,
  };
  message_t sendBuf;
  thlmsg_t local;
  thlmsg_t sendQueue[MAX_QUEUE_LEN];
  thlmsg_t* recvpkt;
  uint16_t counter;
  uint16_t queueIn, queueOut;
  uint16_t ack;
  uint16_t sendCount;
  bool busy = FALSE;
  bool full = FALSE;

  am_id_t id;

  void report_problem() { call Leds.led0Toggle(); }
  void report_sent() { call Leds.led1Toggle(); }
  void report_received() { call Leds.led2Toggle(); }

  event void Boot.booted() {
    local.version = 0x1;
    local.interval = TIMER_PERIOD_MILLI;
    local.nodeid = 2;
    queueIn = queueOut = 0;
    busy = FALSE;
    full = FALSE;
    sendCount = 0;
    call AMControl.start();
  }

  event void AMControl.startDone(error_t err) {
    if (err == SUCCESS) {
      call Timer.startPeriodic(TIMER_PERIOD_MILLI);
      call sendTimer.startPeriodic(TIMER_PERIOD_SEND);
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
    local.counter++;
    if(!full){
      sendQueue[queueIn].version = local.version;
      sendQueue[queueIn].nodeid = local.nodeid;    
      sendQueue[queueIn].counter = local.counter;
      sendQueue[queueIn].interval = local.interval;    
      sendQueue[queueIn].temperature = local.temperature;
      sendQueue[queueIn].humidity = local.humidity;
      sendQueue[queueIn].illumination = local.illumination;
      sendQueue[queueIn].collecttime = call Timer.getNow();
      queueIn = (queueIn + 1) % MAX_QUEUE_LEN;
      if(queueOut == queueIn){
        full = TRUE;
      }
    }
    else{
      report_problem();
      local.counter--;
    }
  }

  event void sendTimer.fired() {
    if(queueIn == queueOut && !full){
      return;
    }
    else{
      if(sendQueue[queueOut].counter == ack){
        queueOut = (queueOut + 1) % MAX_QUEUE_LEN;
        if(full){
          full = FALSE;
        }
        sendCount = 0;
      }
      else{
        if(sendCount > 1){
          report_problem();
        }
        if (sendCount >= 3){
          ack = sendQueue[queueOut].counter;
          queueOut = (queueOut + 1) % MAX_QUEUE_LEN;
          if(full){
            full = FALSE;
          }
          sendCount = 0;
        }
      }
      if(queueIn == queueOut && !full){
        return;
      }
      if(!busy){
        memcpy(call AMSend.getPayload(&sendBuf, sizeof(sendQueue[queueOut])), &sendQueue[queueOut], sizeof sendQueue[queueOut]);
        if(call AMSend.send(NODE1_ADDR, &sendBuf, sizeof sendQueue[queueOut]) == SUCCESS) {
          busy = TRUE;
        }
        if (!busy) report_problem();
      }
    }
  }


  event void AMSend.sendDone(message_t* msg, error_t err) {
    if (err == SUCCESS){
      report_sent();
      sendCount++;
    }
    else
      report_problem();
    busy = FALSE;
  }
  
  event message_t* ackReceive.receive(message_t* msg, void* payload, uint8_t len) {
    am_id_t id = call AMPacket.type(msg);
    if(id == AM_ACKRADIO){
      thlack_t* recvpkt = payload;
      if (recvpkt->nodeid == 2){
        report_received();
        if(recvpkt->counter > ack){
          ack = recvpkt->counter;
        }
      }
    }
    return msg;
  }

  event message_t* freReceive.receive(message_t* msg, void* payload, uint8_t len) {
    id = call AMPacket.type(msg);
    if(id == AM_THLRADIO){
      report_received();
      recvpkt = payload;
      if(recvpkt->version == BASE_VERSION){
        if(recvpkt->interval != local.interval){
          local.version++;
          local.interval = recvpkt->interval;
          call Timer.startPeriodic(local.interval);
          call sendTimer.startPeriodic(local.interval/2);
        }       
      }
    }
    return msg;
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