configuration node1P {
}
implementation {
  components MainC;
  components LedsC;
  components node1C;

  components new TimerMilliC() as Timer0;
  components new TimerMilliC() as Timer1;

  components ActiveMessageC;
  components new AMSenderC(AM_THLRADIO);
  components new AMReceiverC(AM_THLRADIO);

  components new HamamatsuS1087ParC() as LSensor;
  components new SensirionSht11C() as Sensor;


  node2C.Boot -> MainC;
  node2C.Leds -> LedsC;

  node2C.Timer0 -> Timer0;
  node2C.Timer1 -> Timer1;

  node2C.AMControl -> ActiveMessageC;
  node2C.AMSend -> AMSenderC;
  App.Receive -> AMReceiverC;
  
  node2C.LRead -> LSensor;
  node2C.TRead -> Sensor.Temperature;
  node2C.HRead -> Sensor.Humidity;
}