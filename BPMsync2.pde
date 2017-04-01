import processing.opengl.*;                                    //Import a bunch of libraries
import ddf.minim.signals.*;
import ddf.minim.*;
import ddf.minim.analysis.*;
import ddf.minim.effects.*;
import processing.serial.*;

import oscP5.*;
import netP5.*;

OscP5 oscP5;
NetAddress myRemoteLocation;

Minim minim;
AudioInput in;
FFT fft;
PFont font;

float lastBeatTime = 0;
int beatNum = 0;

int colorChooser = 0;                                          //initilizes a bunch of variables
int redChooser = int(random(255));
int greenChooser = int(random(255));
int blueChooser = int(random(255));
int redBackground = 0;
int greenBackground = 0;
int blueBackground = 0;
int redBackground2 = 0;
int greenBackground2 = 0;
int blueBackground2 = 0;
float amp;
float barHeight;

int RED, GREEN, BLUE;
int k;

int longTermAverageSamples = 60;    //gets average volume over a period of time
int shortTermAverageSamples = 1;    //average volume over a shorter "instantanious" time
int deltaArraySamples = 300;        //number of energy deltas between long & short average to sum together
int beatAverageSamples = 100;
int beatCounterArraySamples = 400;
int maxTime = 200;
float predictiveInfluenceConstant = .1;
float predictiveInfluence;
int cyclePerBeatIntensity;

int beatBands = 30;                  //Number of bands to montiter, higher for more accuracy, lower for speed
float lowFreqCutoff = 30;

float[][] deltaArray = new float[deltaArraySamples][beatBands];
float[][] shortAverageArray = new float[shortTermAverageSamples][beatBands];
float[][] longAverageArray = new float[longTermAverageSamples/shortTermAverageSamples][beatBands];
float[] globalAverageArray = new float[longTermAverageSamples];
int[] beatCounterArray = new int[beatCounterArraySamples];
int[] beatSpread = new int[maxTime];
int beatCounterPosition = 0;
int beatCounterPosition2 = 0;
int cyclesPerBeat;

int longPosition = 0;
int shortPosition = 0;
int deltaPosition = 0;

int[] count = new int[beatBands];
float[] totalLong = new float[beatBands];
float[] totalShort = new float[beatBands];
float[] delta = new float[beatBands];
float[] c = new float[beatBands];             //multiplier used to determain threshold

int beat;
int beatCounter = 0;
float[] beatAverage = new float[beatAverageSamples];
float totalBeat = 0;
int beatPosition = 0;

float totalGlobal;
float threshold;
float standardDeviation;


//////////////////////////////////

void setup() {

  for (int i = 0; i < beatBands; i += 1) {
    count[i] = 0;
    totalLong[i] = 0;
    totalShort[i] = 0;
    delta[i] = 0;
    c[i] = 1.5;
  }

  size(500, 500, OPENGL);                                      //Sets up window

  colorMode(RGB);
  background(0);

  /* start oscP5, listening for incoming messages at port 12000 */
  oscP5 = new OscP5(this, 7001);

  /* myRemoteLocation is a NetAddress. a NetAddress takes 2 parameters,
   * an ip address and a port number. myRemoteLocation is used as parameter in
   * oscP5.send() when sending osc packets to another computer, device, 
   * application. usage see below. for testing purposes the listening port
   * and the port of the remote location address are the same, hence you will
   * send messages back to this sketch.
   */
  myRemoteLocation = new NetAddress("127.0.0.1", 7000);

  minim = new Minim(this);                                      //Sets up minim

  //in = minim.getLineIn(Minim.STEREO, 1024);
  in = minim.getLineIn(Minim.STEREO, 2048);                     //Gets values from mic (and soundcard?)
  fft = new FFT(in.bufferSize(), in.sampleRate());              //Sets up the FFT
  fft.logAverages(30, 5);                                       //Creates a 5 band/oct FFT starting at 40Hz
  rectMode(CORNERS);                                            //Changes mode for creating rectangles
}

//////////////////////////////////
void draw() {
  if (shortPosition >= shortTermAverageSamples) shortPosition = 0;    //Resets incremental variables
  if (longPosition >= longTermAverageSamples/shortTermAverageSamples) longPosition = 0;
  if (deltaPosition >= deltaArraySamples) deltaPosition = 0;
  if (beatPosition >= beatAverageSamples) beatPosition = 0;


  fill(redBackground, greenBackground, blueBackground);         //Clears the screen and chooses background color
  rect (0, 0, width, height);
  fill(255);
  fft.forward(in.mix);                                          //Performs the FFT
  int w = int(width/fft.avgSize());                             //Scales the FFT

  /////////////////////////////////////Calculate short and long term array averages///////////////////////////////////////////////////////////////////////////////////////////////////////////

  for (int i = 0; i <beatBands; i += 1) {
    shortAverageArray[shortPosition][i] = fft.getBand(i);   //stores the average intensity between the freq. bounds to the short term array
    totalLong[i] = 0;
    totalShort[i] = 0;

    for (int j = 0; j < longTermAverageSamples/shortTermAverageSamples; j += 1) totalLong[i]+= longAverageArray[j][i];  //adds up all the values in both of these arrays, for averaging
    for (int j = 0; j < shortTermAverageSamples; j +=1) totalShort[i] += shortAverageArray[j][i];
  }

  ///////////////////////////////////////////Find wideband frequency average intensity/////////////////////////////////////////////////////////////////////////////////////////////////////

  totalGlobal = 0;
  globalAverageArray[longPosition] = fft.calcAvg(30, 2000);
  for (int j = 0; j < longTermAverageSamples; j +=1) totalGlobal += globalAverageArray[j];
  totalGlobal = totalGlobal/longTermAverageSamples;

  //////////////////////////////////Populate long term average array//////////////////////////////////////////////////////////////////////////////////////////////////////////////

  if (shortPosition%shortTermAverageSamples == 0) {   //every time the short array is completely new it is added to long array
    for (int i = 0; i < beatBands; i += 1) {
      longAverageArray[longPosition][i] = totalShort[i];     //increases speed of program, but is the same as if each individual value was stored in long array
    }
    longPosition += 1;
  }

  /////////////////////////////////////////Find index of variation for each band///////////////////////////////////////////////////////////////////////////////////////////////////////

  for (int i = 0; i < beatBands; i += 1) {
    totalLong[i] = totalLong[i]/(float(longTermAverageSamples)/float(shortTermAverageSamples));

    delta[i] = 0;  
    deltaArray[deltaPosition][i] = pow(abs(totalLong[i]-totalShort[i]), 2);
    for (int j = 0; j < deltaArraySamples; j += 1) delta[i] += deltaArray[j][i];  
    delta[i] = delta[i]/deltaArraySamples;


    ///////////////////////////////////////////Find local beats/////////////////////////////////////////////////////////////////////////////////////////////////////

    c[i] = 1.3 + constrain(map(delta[i], 0, 3000, 0, .4), 0, .4) + //delta is usually bellow 2000
      map(constrain(pow(totalLong[i], .5), 0, 6), 0, 20, .3, 0) +    //possibly comment this out, adds weight to the lower end
      map(constrain(count[i], 0, 15), 0, 15, 1, 0) - 
      map(constrain(count[i], 30, 200), 30, 200, 0, .75);


    if (cyclePerBeatIntensity/standardDeviation > 3.5) {
      predictiveInfluence = predictiveInfluenceConstant * (1 - cos((float(beatCounter)*TWO_PI)/float(cyclesPerBeat)));
      predictiveInfluence *= map(constrain(cyclePerBeatIntensity/standardDeviation, 3.5, 20), 3.5, 15, 1, 6);
      if (cyclesPerBeat > 10) c[i] = c[i] + predictiveInfluence;
    }
  }

  beat = 0;
  for (int i = 0; i < beatBands; i += 1) {
    if (totalShort[i] > totalLong[i]*c[i] & count[i] > 7) {                  //If beat is detected

      if (count[i] > 12 & count[i] < 200) {
        beatCounterArray[beatCounterPosition%beatCounterArraySamples] = count[i];
        beatCounterPosition +=1;
      }
      count[i] = 0;                                                 //resets counter
    }
  }

  /////////////////////////////////////////Figure out # of beats, and average///////////////////////////////////////////////////////////////////////////////////////////////////////

  for (int i = 0; i < beatBands; i +=1) if (count[i] < 2) beat += 1;   //If there has been a recent beat in a band add to the global beat value

  beatAverage[beatPosition] = beat;
  for (int j = 0; j < beatAverageSamples; j +=1) totalBeat += beatAverage[j];
  totalBeat = totalBeat/beatAverageSamples;

  //println(totalBeat);

  /////////////////////////////////////////////////find global beat///////////////////////////////////////////////////////////////////////////////////////////////
  c[0] = 3.25 + map(constrain(beatCounter, 0, 5), 0, 5, 5, 0);

  if (cyclesPerBeat > 10) c[0] = c[0] + .75*(1 - cos((float(beatCounter)*TWO_PI)/float(cyclesPerBeat)));
  //println(c[0]);

  threshold = constrain(c[0]*totalBeat + map(constrain(totalGlobal, 0, 2), 0, 2, 4, 0), 5, 1000);
  //println(threshold);


  if (beat > threshold & beatCounter > 5) {
    //println(beatCounter);
    backgroundChange(100);
    beatCounter = 0;
  }
  /////////////////////////////////////////////////////Calculate beat spreads///////////////////////////////////////////////////////////////////////////////////////////

  //average = beatCounterArraySamples/200 !!!

  for (int i = 0; i < maxTime; i++) beatSpread[i] = 0;
  for (int i = 0; i < beatCounterArraySamples; i++) {
    beatSpread[beatCounterArray[i]] +=1;
  }

  cyclesPerBeat = mode(beatCounterArray);
  if (cyclesPerBeat < 20) cyclesPerBeat *= 2;

  cyclePerBeatIntensity = max(beatSpread);

  standardDeviation = 0;
  for (int i = 0; i < maxTime; i++) standardDeviation += pow(beatCounterArraySamples/maxTime-beatSpread[i], 2);
  standardDeviation = pow(standardDeviation/maxTime, .5);




  if (beatCounter < 5) {
    rect(width - 50, 0, width, 50);  //beat indication box

    float currentTime = millis();
    if (currentTime - lastBeatTime >= 120) {
      beatTap();
      beatNum++;
      println("Tap #" + beatNum + " sent");
      
      //if(currentTime - lastBeatTime >= 1000) {
     //   bpmChange();
      //  println("Reset bpm to 120");
    //  }
      lastBeatTime = millis();
      
      
    } else if (currentTime - lastBeatTime <= 50) {
      bpmChange();
      println("BPM Changed to 120");
      lastBeatTime = millis();
    }
  }

  ////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


  shortPosition += 1;
  deltaPosition += 1;
  for (int i = 0; i < beatBands; i += 1) count[i] += 1;
  beatCounter += 1;
  beatPosition += 1;
}


void backgroundChange(int a) {              //Randomly changes background color
  redBackground = int(random(a));
  greenBackground = int(random(a));
  blueBackground = int(random(a));
}


int mode(int[] array) {
  int[] modeMap = new int [array.length];
  int maxEl = array[0];
  int maxCount = 1;

  for (int i = 0; i < array.length; i++) {
    int el = array[i];
    if (modeMap[el] == 0) {
      modeMap[el] = 1;
    } else {
      modeMap[el]++;
    }

    if (modeMap[el] > maxCount) {
      maxEl = el;
      maxCount = modeMap[el];
    }
  }
  return maxEl;
}

//int index(int[] array, int number){
//  for (int i = 0; i < array.length; i++){
//    if (array[i] == number) return i;
//  }
//}


void stop()                                //Closes everything on stop
{
  in.close();                              //Always close Minim audio classes when you are finished with them
  minim.stop();                            //Always stop Minim before exiting
  super.stop();                            //This closes the sketch
}

void beatTap() {
  // create OSC message
  OscMessage myMessage = new OscMessage("/playbackcontroller/tap");

  myMessage.add(1); /* add an int to the osc message */

  /* send the message */
  oscP5.send(myMessage, myRemoteLocation);
}


void bpmChange() {
  // create OSC message
  OscMessage myMessage2 = new OscMessage("/playbackcontroller/bpm");

  myMessage2.add(120); /* add an int to the osc message */

  /* send the message */
  oscP5.send(myMessage2, myRemoteLocation);
}