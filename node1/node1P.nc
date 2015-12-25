configuration node1P {
}
implementation {
  components MainC;
  components LedsC;
  components node1C;

  components new TimerMilliC() as Timer;
  components new TimerMilliC() as sendTimer;

  components ActiveMessageC;
  components new AMSenderC(AM_THLRADIO) as AMthlSender;
  components new AMSenderC(AM_THLRADIO) as AMthlTransSender;
  components new AMReceiverC(AM_THLRADIO) as AMthlTransReceiver;

  components new HamamatsuS1087ParC() as LSensor;
  components new SensirionSht11C() as Sensor;


  node1C.Boot -> MainC;
  node1C.Leds -> LedsC;

  node1C.Timer -> Timer;
  node1C.sendTimer -> sendTimer;

  node1C.AMControl -> ActiveMessageC;
  node1C.AMthlSend -> AMthlSender;
  node1C.AMthlTransSend -> AMthlTransSender;
  
  node1C.Receive -> AMthlTransReceiver;
  
  node1C.LRead -> LSensor;
  node1C.TRead -> Sensor.Temperature;
  node1C.HRead -> Sensor.Humidity;
  node1C.AMPacket -> AMthlSender; 
}