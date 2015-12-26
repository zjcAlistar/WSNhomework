configuration node0P {
}
implementation {
  components MainC, node0C, LedsC;
  components ActiveMessageC as Radio, SerialActiveMessageC as Serial;
  components new AMSenderC(AM_ACKRADIO) as ackSender;
  
  MainC.Boot <- node0C;

  node0C.RadioControl -> Radio;
  node0C.SerialControl -> Serial;
  
  node0C.UartSend -> Serial;
  node0C.UartReceive -> Serial.Receive;
  node0C.UartPacket -> Serial;
  node0C.UartAMPacket -> Serial;
  
  node0C.RadioSend -> Radio;
  node0C.RadioReceive -> Radio.Receive;
  node0C.RadioSnoop -> Radio.Snoop;
  node0C.RadioPacket -> Radio;
  node0C.RadioAMPacket -> Radio;

  node0C.ackSend -> ackSender;
  
  node0C.Leds -> LedsC;
}