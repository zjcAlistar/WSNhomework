configuration node2P {
}
implementation {
  components MainC;
  components LedsC;
  components node2C;
  components new TimerMilliC() as Timer;
  components ActiveMessageC;
  components new AMSenderC(AM_THLRADIO);
  components new HamamatsuS1087ParC() as LSensor;
  components new SensirionSht11C() as Sensor;


  node2C.Boot -> MainC;
  node2C.Leds -> LedsC;
  node2C.Timer -> Timer;
  node2C.AMControl -> ActiveMessageC;
  node2C.AMSend -> AMSenderC;
  node2C.LRead -> LSensor;
  node2C.TRead -> Sensor.Temperature;
  node2C.HRead -> Sensor.Humidity;
}