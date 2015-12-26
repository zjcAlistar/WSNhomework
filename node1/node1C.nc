#include "Timer.h"
#include "THLstruct.h"

module node1C @safe()
{
  uses {
    interface Boot;
    interface Leds;
    interface Timer<TMilli> as Timer;
    interface Timer<TMilli> as sendTimer;
    interface Timer<TMilli> as transSendTimer;

    interface AMSend as AMthlSend;
    interface AMSend as AMthlTransSend;
    interface AMSend as AMackSender;

    interface Receive as transReceive;
    interface Receive as ackReceive;

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
    MAX_QUEUE_LEN = 30,
  };
  message_t sendBuf;
  message_t transSendBuf;
  message_t ackSendBuf;

  uint16_t queueIn, queueOut;
  uint16_t transQueueIn, transQueueOut;
  uint16_t lastack;
  uint16_t sendCount;
  uint16_t ack;
  bool busy = FALSE;
  bool full = FALSE;
  bool transbusy = FALSE;
  bool ackbusy = FALSE;
  bool transfull = FALSE;
  
  am_id_t id;

  thlmsg_t local;
  thlmsg_t sendQueue[MAX_QUEUE_LEN];
  thlmsg_t transSendQueue[MAX_QUEUE_LEN];

  thlack_t tempACK;
  thlack_t* recvACK; 
  thlmsg_t* recvpkt;

  void report_problem() { call Leds.led0Toggle(); }
  void report_sent() { call Leds.led1Toggle(); }
  void report_received() { call Leds.led2Toggle(); }

  event void Boot.booted() {
    local.version = 0x1;
    local.interval = TIMER_PERIOD_MILLI;
    local.nodeid = 1;
    local.counter = 0;
    queueIn = queueOut = 0;
    transQueueIn = transQueueOut = 0;
    lastack = 0;
    sendCount = 0;
    full = FALSE;
    busy = FALSE;
    transfull = FALSE;
    transbusy = FALSE;
    ackbusy = FALSE;
    call AMControl.start();
  }

  event void AMControl.startDone(error_t err) {
    if (err == SUCCESS) {
      call Timer.startPeriodic(TIMER_PERIOD_MILLI);
      call sendTimer.startPeriodic(TIMER_PERIOD_SEND);
      call transSendTimer.startPeriodic(TIMER_PERIOD_SEND);
    }
    else {
      call AMControl.start();
    }
  }

  event void AMControl.stopDone(error_t err) {
  }
  
  event message_t* transReceive.receive(message_t* msg, void* payload, uint8_t len) {
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
      else{
        tempACK.nodeid = 2;
        tempACK.counter = recvpkt->counter;
        if (!ackbusy) {
          memcpy(call AMackSender.getPayload(&ackSendBuf, sizeof(tempACK)), &tempACK, sizeof tempACK);
          if (call AMackSender.send(NODE2_ADDR, &ackSendBuf, sizeof tempACK) == SUCCESS) {
            ackbusy = TRUE;
          }
        }
        if (!ackbusy) report_problem();

        if(recvpkt->counter > lastack){
          if (!transbusy) {
            memcpy(call AMthlTransSend.getPayload(&transSendBuf, sizeof(*recvpkt)), recvpkt, sizeof *recvpkt);
            if (call AMthlTransSend.send(NODE0_ADDR, &transSendBuf, sizeof *recvpkt) == SUCCESS) {
              transbusy = TRUE;
            }
          }
          if (!transbusy) report_problem();
        }
        else{
          lastack = recvpkt->counter;
        }
      }
    }
    return msg;
  }

  event message_t* ackReceive.receive(message_t* msg, void* payload, uint8_t len) {
    id = call AMPacket.type(msg);
    if(id == AM_ACKRADIO){
      recvACK = payload;
      if(recvACK->nodeid == 1){
        report_received();
        if(recvACK->counter > ack){
          ack = recvACK->counter;
        }
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
  
  event void sendTimer.fired(){
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
        memcpy(call AMthlSend.getPayload(&sendBuf, sizeof(sendQueue[queueOut])), &sendQueue[queueOut], sizeof sendQueue[queueOut]);
        if(call AMthlSend.send(NODE0_ADDR, &sendBuf, sizeof sendQueue[queueOut]) == SUCCESS) {
          busy = TRUE;
        }
        if (!busy) report_problem();
      }
    }    
  }

  event void transSendTimer.fired(){}

  event void AMthlSend.sendDone(message_t* msg, error_t err) {
    if (err == SUCCESS){
      report_sent();
    }
    else
      report_problem();
    busy = FALSE;
  }

  event void AMthlTransSend.sendDone(message_t* msg, error_t err) {
    if (err == SUCCESS){
      report_sent();
    }
    else
      report_problem();
    transbusy = FALSE;
  }

  event void AMackSender.sendDone(message_t* msg, error_t err) {
    if (err == SUCCESS){
      report_sent();
    }
    else
      report_problem();
    ackbusy = FALSE;
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