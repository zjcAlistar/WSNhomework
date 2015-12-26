#include "Timer.h"
#include "THLstruct.h"

module node1C @safe()
{
  uses {
    interface Boot;
    interface Leds;
    interface Timer<TMilli> as Timer;
    interface Timer<TMilli> as sendTimer;
    interface AMSend as AMthlSend;
    interface AMSend as AMthlTransSend;
    interface Receive;
    interface SplitControl as AMControl;
    interface Read<uint16_t> as TRead;
    interface Read<uint16_t> as HRead;
    interface Read<uint16_t> as LRead;
    interface AMPacket;
  }
}
implementation
{
  enum {
    PACKET_QUEUE_LEN = 30,
  };
  message_t sendBuf[PACKET_QUEUE_LEN];
  thlmsg_t local;
  bool busy = FALSE;
  bool qbusy = FALSE;
  bool full = FALSE;
  thlmsg_t packetQueue[PACKET_QUEUE_LEN];

  uint8_t    packetIn, packetOut;

  void report_problem() { call Leds.led0Toggle(); }
  void report_sent() { call Leds.led1Toggle(); }
  void report_received() { call Leds.led2Toggle(); }

  task void sendTask() {
    atomic
      if (packetIn == packetOut && !full)
      {
        qbusy = FALSE;
        return;
      }
    memcpy(call AMthlSend.getPayload(&sendBuf[packetOut], sizeof(packetQueue[packetOut])), &packetQueue[packetOut], sizeof packetQueue[packetOut]);
    if(call AMthlSend.send(69, &sendBuf[packetOut], sizeof packetQueue[packetOut]) == SUCCESS) {
        busy = TRUE;
      }
    if (!busy) report_problem();
  }

  event void Boot.booted() {
    local.interval = TIMER_PERIOD_MILLI;
    local.nodeid = TOS_NODE_ID;
    local.counter = 0;
    packetIn = packetOut = 0;
    full = FALSE;
    busy = FALSE;
    qbusy = FALSE;
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
  
  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
    am_id_t id = call AMPacket.type(msg);
    if(id == 4){
      thlmsg_t* recvpkt = payload;
      if (recvpkt -> nodeid == 2 &&full != TRUE && !qbusy){
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

  event void Timer.fired() {
    if (call TRead.read() != SUCCESS)
      report_problem();
    if (call HRead.read() != SUCCESS)
      report_problem();
    if (call LRead.read() != SUCCESS)
      report_problem();
    local.counter++;
    if(full != TRUE && !qbusy){
      packetQueue[packetIn].version = local.version;
      packetQueue[packetIn].interval = local.interval;
      packetQueue[packetIn].nodeid = local.nodeid;
      packetQueue[packetIn].counter = local.counter;
      packetQueue[packetIn].temperature = local.temperature;
      packetQueue[packetIn].humidity = local.humidity;
      packetQueue[packetIn].illumination = local.illumination;
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

  event void AMthlSend.sendDone(message_t* msg, error_t err) {
    if (err != SUCCESS)
      report_problem();
    else{
      atomic{
        if (++packetOut >= PACKET_QUEUE_LEN)
        packetOut = 0;
      if (full)
        full = FALSE;
      report_sent();
      }
    }
    busy = FALSE;
    post sendTask();
  }

  event void AMthlTransSend.sendDone(message_t* msg, error_t err) {
    
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