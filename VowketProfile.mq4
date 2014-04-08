#property copyright "Viaxl"
#property link "http://viaxl.com"
// VowketProfile Version 1.0.3
/*
  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/					   

#property indicator_chart_window


extern int _interval=0;  // 0 for day, 1 for week, 2 for month
extern int _total=30;
extern int _color1=Violet;
extern int _color0=LawnGreen; // http://docs.mql4.com/constants/colors

#define MAX_BARS 1000
#define MAX_TOTAL 100
#define DEBUG 0

string _prefix="zz_VP_";
int _window=0;
int handle;

int _digits,_digitsShift;
int _intervalPeriod;  // Minutes
int _bars;
datetime _indexTime[MAX_TOTAL];
int _indexBar[MAX_TOTAL];
int _initialized=0;

int priceToPip(double price) {
  return(price*_digitsShift);
}

double pipToPrice(int pip) {
  return (1.0*pip/_digitsShift);
}

int drawProfile(int m[][MAX_BARS], int mN[], int p0, int p1, int blockLow, int blockHigh) {

  int r0,g0,b0;
  double rD,gD,bD;
  r0=(_color0&0xff0000)>>16;
  g0=(_color0&0x00ff00)>>8;
  b0=(_color0&0x0000ff);
  rD=((double)((_color1&0xff0000)>>16)-(double)r0)/_bars;
  gD=((double)((_color1&0x00ff00)>>8)-(double)g0)/_bars;
  bD=((double)((_color1&0x0000ff)>>0)-(double)b0)/_bars;;

  for(int y=blockLow; y<=blockHigh; y++)
    for(int x=p0; x>p0-mN[y-blockLow] ;x--) {
      datetime time=Time[x];
      double price=pipToPrice(y);
      string name=_prefix+y+"_"+x;
      if(ObjectFind(name)==_window)
	continue;
      ObjectCreate(name, OBJ_RECTANGLE, _window,
		   time, price,
		   time+Period()*60, price+pipToPrice(1)
		   );
      int v=m[y-blockLow][p0-x];
      int colorV=r0+rD*v;
      colorV=(colorV<<8)+g0+gD*v;
      colorV=(colorV<<8)+b0+bD*v;  //Shitty language can't cast (int).
      ObjectSet(name, OBJPROP_COLOR, colorV);
      ObjectSet(name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSet(name, OBJPROP_BACK, true);
    }

  return(0);
}


int compressBlock(int index) {

  int blockLow=priceToPip(iLow(Symbol(),_intervalPeriod,index));
  int blockHigh=priceToPip(iHigh(Symbol(),_intervalPeriod,index));
  int m[][MAX_BARS],mN[];
  ArrayResize(m,blockHigh-blockLow+1);
  ArrayResize(mN,blockHigh-blockLow+1);
  ArrayInitialize(mN,0);
  
  int p0=_indexBar[index];
  int p1;
  if(index==0)
    p1=-1;
  else
    p1=_indexBar[index-1];
  for(int bar=p0;bar>p1;bar--) {
    int x,y;
    x=p0-bar;
    for(y=priceToPip(Low[bar])-blockLow;
	y<=priceToPip(High[bar])-blockLow;
	y++) {

      m[y][mN[y]]=x;
      mN[y]++;

    }
  }

  drawProfile(m,mN,p0,p1,blockLow,blockHigh);

  return(0);
}
    

int init() {
  /*
  FileDelete("VowketProfile.log");
  handle=FileOpen("VowketProfile.log",FILE_CSV|FILE_READ|FILE_WRITE,';');
  if(handle<1) {
    Print("Error: ", GetLastError());
    return(-1);
  }
  */
  
  if(_interval<0
     || _interval>2
     || _total<=0
     || _total >MAX_TOTAL
     ) {
    Print("Error: Incorrect or excessive parameters.");
    return(-1);
  }

  switch(_interval) {
  case 0:
    _intervalPeriod=PERIOD_D1;  //1440
    break;
  case 1:
    _intervalPeriod=PERIOD_W1;
    break;
  case 2:
    _intervalPeriod=PERIOD_MN1;
    break;
  case 3:
    _intervalPeriod=PERIOD_H1;
    break;
  case 4:
    _intervalPeriod=PERIOD_H4;
    break;
  default:
    return(-1);
  }
  _bars=_intervalPeriod/Period();
  if(_bars>MAX_BARS) {
    Print("ERROR: Too many TPOs per profile.\n");
    return(-1);
  }

  _digits=Digits;
  if(Digits==5)
    _digits=4;
  if(Digits==3)
    _digits=2;
  _digitsShift=MathPow(10,_digits);

  return(0);
}

int start() {

  if(
     _intervalPeriod<Period()
     )
    return(-1);

  while(iTime(Symbol(),_intervalPeriod,0)==0
	|| Time[0]<iTime(Symbol(),_intervalPeriod,0)) {
    RefreshRates();
    //    Sleep(500);   ///Can't be called for custom indicators.
    Comment("Waiting for rates data...");
    debugOutput("Waiting for rates data");
    return(-1);
  }
  int pBar=0;
  int q=0;
  while(q<_total) {
    while(1) {
      if(
	 Time[pBar]<=iTime(Symbol(),_intervalPeriod,q)
	 && (pBar==0 || Time[pBar-1]>iTime(Symbol(),_intervalPeriod,q))
	 )
	break;
      pBar++;
    }
    
    _indexBar[q]=pBar;
    
    pBar++;
    q++;
  }

  string str0="_indexBar[]={"+_indexBar[0];
  for(int i=1;i<_total;i++)
    str0=str0+","+_indexBar[i];
  str0=str0+"}";

  bool error=false;
  if(!_initialized) {
    for(int ii=0;ii<_total;ii++) {
      if(compressBlock(ii)==-1) {
	error=true;
	break;
      }
    }
    _initialized=1;
  }
  else
    if(compressBlock(0)==-1)
      error=true;
     
  if(error) {
    Print("ERROR: compressBlock() failed miserably.\n");
    return(-1);
  }

  FileFlush(handle);
  return(0);
  
}

int deinit() {

  ObjectsDeleteAll(0, OBJ_RECTANGLE);
  /*
    for(int i=0;i<ObjectsTotal();i++)
    if(StringFind(ObjectName(i),_prefix,0)==0)
    ObjectDelete(ObjectName(i));
  */

  _initialized=0;
  
  return(0);
  
}


int debugOutput(string a) {

  if(!DEBUG)
    return(-1);
  
  FileWrite(handle,a);
  
  return(0);
}
