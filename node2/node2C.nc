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
    interface
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
  thlmsg_t sendQueue[MAX_QUEUE_LEN];
  uint16_t queueIn, queueOut;
  uint16_t ack;
  uint16_t sendCount;
  bool full = FALSE;


  void report_problem() { call Leds.led0Toggle(); }
  void report_sent() { call Leds.led1Toggle(); }
  void report_received() { call Leds.led2Toggle(); }

  event void Boot.booted() {
    local.version = 0x1;
    local.interval = TIMER_PERIOD_MILLI;
    local.nodeid = TOS_NODE_ID;
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
    sendQueue[packetIn].version = local.version;
    sendQueue[packetIn].interval = local.interval;
    sendQueue[packetIn].nodeid = local.nodeid;
    sendQueue[packetIn].counter = local.counter;
    sendQueue[packetIn].temperature = local.temperature;
    sendQueue[packetIn].humidity = local.humidity;
    sendQueue[packetIn].illumination = local.illumination;
    packetIn = (packetIn + 1) % MAX_QUEUE_LEN;
    if(full){
      packetOut = packetIn;
      ack = sendQueue[packetOut] - 1; 
    }
  }

  event void sendTimer.fired() {
    if(packetIn == packetOut && !full){
      return;
    }
    else{
      if(sendQueue[packetOut].counter == ack){
        packetOut = (packetOut + 1) % MAX_QUEUE_LEN;
        sendCount = 0;
      }
      else{
        if (sendCount >= 3){
          ack = sendQueue[packetOut].counter;
          packetOut = (packetOut + 1) % MAX_QUEUE_LEN;
          sendCount = 0;
        }
      }
      if(packetIn == packetOut && !full){
        return;
      }
      if(!busy){
        memcpy(call AMSend.getPayload(&sendBuf, sizeof(sendQueue[packetOut])), &sendQueue[packetOut], sizeof sendQueue[packetOut]);
        if(call AMthlSend.send(69, &sendBuf, sizeof packetQueue[packetOut]) == SUCCESS) {
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
  
  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
    am_id_t id = call AMPacket.type(msg);
    if(id == 4){
      thlmsg_t* recvpkt = payload;
      if (recvpkt -> nodeid == 2 &&full != TRUE && !qbusy){
        packetQueue[packetIn].version = recvpkt->version;
        packetQueue[packetIn].interval = recvpkt->interval;
        packetQueue[packetIn].nodeid = 3;
        packetQueue[packetIn].counter = recvpkt->counter;
        packetQueue[packetIn].temperature = recvpkt->temperature;
        packetQueue[packetIn].humidity = recvpkt->humidity;
        packetQueue[packetIn].illumination = recvpkt->illumination;
        packetIn = (packetIn + 1) % PACKET_QUEUE_LEN;
      }
      else{
       report_problem();
      }
      if (packetIn == packetOut)
        full = TRUE;

      if (!qbusy)
      {
        post sendTask();
        qbusy = TRUE;
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