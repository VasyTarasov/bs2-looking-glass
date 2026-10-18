#pragma once
#pragma comment(linker,"/EXPORT:BS2_HDMeasure=_BS2_HDMeasure@12")
#include <string>
#include <map>
#pragma comment(linker,"/EXPORT:BS2_HDIcon=_BS2_HDIcon@12")
#include <algorithm>
#include <cmath>
#pragma comment(linker,"/EXPORT:BS2_HDConfigure=_BS2_HDConfigure@24")
#pragma comment(linker,"/EXPORT:BS2_HDLayout=_BS2_HDLayout@12")
#pragma comment(linker,"/EXPORT:BS2_HDStatus=_BS2_HDStatus@4")
#pragma comment(linker,"/EXPORT:BS2_HDText=_BS2_HDText@8")
#pragma comment(linker,"/EXPORT:BS2_HDReadback=_BS2_HDReadback@8")
#pragma comment(linker,"/EXPORT:BS2_HDMonitor=_BS2_HDMonitor@4")
#pragma comment(linker,"/EXPORT:BS2_HDPresentation=_BS2_HDPresentation@4")
#pragma comment(linker,"/EXPORT:BS2_HDDPI=_BS2_HDDPI@4")
#pragma comment(linker,"/EXPORT:BS2_HDRestartDPI=_BS2_HDRestartDPI@0")
namespace HD {
static bool on=false,saved=false,dirty=true,modal=false;
static int mode=0,filter=0,sidebar=1,uiPercent=100,error=0;
static LONG originalStyle=0,originalEx=0;
static WINDOWPLACEMENT originalPlacement={sizeof(WINDOWPLACEMENT)};
static GLuint texture=0;static HDC textDC=0;static HBITMAP textBmp=0;static HGDIOBJ oldBmp=0;static void* textPixels=0;
static std::map<int,std::vector<unsigned char>> icons;
static int panelW=0,panelH=0;static std::wstring text;
static volatile LONG captureRequest=0;static std::vector<unsigned char> capture;static int captureW=0,captureH=0;
struct Layout {int w,h,x,y,gw,gh,px,py,pw,ph,font,columns;};
static Layout layout(int w,int h){
 Layout l={w,h,0,0,0,0,w,0,0,h,22,1};
 double scale=std::max(.65,std::min(3.0,(double)h/1080*uiPercent/100));
 l.font=std::max(15,(int)std::round(22*scale));
 if(on&&sidebar){
  int minimum=(int)std::round(320*scale);
  l.pw=std::max(w-(int)((double)h*sourceW/sourceH),std::min((int)(w*.4),minimum));l.px=w-l.pw;
  l.columns=1;
 }
 int area=l.px;double zoom=std::min((double)area/sourceW,(double)h/sourceH);
 if(on&&filter==2&&zoom>=1)zoom=std::floor(zoom);
 l.gw=std::max(1,(int)std::round(sourceW*zoom));l.gh=std::max(1,(int)std::round(sourceH*zoom));
 l.x=(area-l.gw)/2;l.y=(h-l.gh)/2;return l;
}
static void freePanel(){
 if(texture){glDeleteTextures(1,&texture);texture=0;}
 if(textDC){SelectObject(textDC,oldBmp);DeleteDC(textDC);textDC=0;}
 if(textBmp){DeleteObject(textBmp);textBmp=0;}textPixels=0;panelW=panelH=0;
}
static void paintIcon(int index,int x,int y,int size,const Layout& l){
 auto entry=icons.find(index);if(entry==icons.end()||!textPixels)return;
 GdiFlush();const auto& source=entry->second;auto destination=(unsigned char*)textPixels;
 for(int iy=0;iy<size&&y+iy<l.ph;++iy)for(int ix=0;ix<size&&x+ix<l.pw;++ix){
  if(x+ix<0||y+iy<0)continue;
  size_t a=((size_t)(iy*24/size)*24+ix*24/size)*4,b=((size_t)(y+iy)*l.pw+x+ix)*4;
  unsigned alpha=source[a+3];for(int c=0;c<3;++c)destination[b+c]=(unsigned char)((source[a+c]*alpha+destination[b+c]*(255-alpha))/255);
 }
}
static bool panel(const Layout& l){
 if(!l.pw||!l.ph)return false;
 if(error==10||error==11)return false;
 if(panelW!=l.pw||panelH!=l.ph){
  freePanel();textDC=CreateCompatibleDC(0);BITMAPINFO bi={};bi.bmiHeader.biSize=40;bi.bmiHeader.biWidth=l.pw;bi.bmiHeader.biHeight=-l.ph;
  bi.bmiHeader.biPlanes=1;bi.bmiHeader.biBitCount=32;textBmp=CreateDIBSection(textDC,&bi,DIB_RGB_COLORS,&textPixels,0,0);
  if(!textDC||!textBmp){error=10;return false;}oldBmp=SelectObject(textDC,textBmp);panelW=l.pw;panelH=l.ph;
  glGenTextures(1,&texture);dirty=true;
 }
 if(!dirty)return true;
 RECT all={0,0,l.pw,l.ph};HBRUSH bg=CreateSolidBrush(RGB(16,20,26));FillRect(textDC,&all,bg);DeleteObject(bg);
 int pad=std::max(12,l.font*3/4),colW=std::min(l.pw,(int)std::round(480.0*l.font/22));int column=0,y=pad,bodyTop=pad;
 HFONT body=CreateFontW(-l.font,0,0,0,FW_NORMAL,FALSE,FALSE,FALSE,DEFAULT_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,ANTIALIASED_QUALITY,DEFAULT_PITCH,L"Segoe UI");
 HFONT heading=CreateFontW(-(l.font+4),0,0,0,FW_SEMIBOLD,FALSE,FALSE,FALSE,DEFAULT_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,ANTIALIASED_QUALITY,DEFAULT_PITCH,L"Segoe UI");
 HFONT title=CreateFontW(-(l.font+8),0,0,0,FW_SEMIBOLD,FALSE,FALSE,FALSE,DEFAULT_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,ANTIALIASED_QUALITY,DEFAULT_PITCH,L"Segoe UI");
 HGDIOBJ oldFont=SelectObject(textDC,body);SetBkMode(textDC,TRANSPARENT);
 size_t pos=0;int count=0;
 while(pos<text.size()&&count++<100){
  size_t end=text.find(L'\n',pos);if(end==std::wstring::npos)end=text.size();std::wstring line=text.substr(pos,end-pos);pos=end+1;
  wchar_t kind=L'S';if(line.size()>1&&line[1]==L'\t'){kind=line[0];line.erase(0,2);}
  std::vector<std::pair<int,std::wstring>> grid;
  if(kind==L'G'){size_t at=0;while(at<line.size()){size_t end=line.find(L';',at);if(end==std::wstring::npos)end=line.size();auto cell=line.substr(at,end-at);size_t bar=cell.find(L'|');if(bar!=std::wstring::npos)grid.push_back({_wtoi(cell.substr(0,bar).c_str()),cell.substr(bar+1)});at=end+1;}line.clear();}
  int icon=-1;
  if(kind==L'I'){size_t sep=line.find(L'|');if(sep!=std::wstring::npos){icon=_wtoi(line.substr(0,sep).c_str());line.erase(0,sep+1);}}
  SelectObject(textDC,kind==L'T'?title:kind==L'H'?heading:body);
  SetTextColor(textDC,kind==L'T'?RGB(230,205,153):kind==L'H'?RGB(198,180,156):kind==L'D'?RGB(157,167,182):RGB(235,235,229));
  int left=column*colW+pad,right=(column+1)*colW-pad;
  int iconSize=std::max(20,(int)std::round(24.0*l.font/22));
  int iconLeft=left;if(icon>=0)left+=iconSize+8;
  UINT format=(kind==L'P'||kind==L'K') ? DT_SINGLELINE|DT_END_ELLIPSIS : DT_WORDBREAK;
  RECT rect={left,y,right,y};DrawTextW(textDC,line.c_str(),(int)line.size(),&rect,DT_CALCRECT|format|DT_NOPREFIX);
  int height=std::max(l.font+4,(int)(rect.bottom-rect.top))+(kind==L'H'?pad:4);
  int cells=std::max(1,(right-left)/(iconSize+10));
  int cellHeight=iconSize+std::max(14,l.font*2/3)+4;
  if(!grid.empty())height=(int)((grid.size()+cells-1)/cells)*cellHeight+4;
  if(icon>=0)height=std::max(height,iconSize+4);
  if(y+height>l.ph-pad){
   if(column+1>=l.columns)break;
   ++column;y=bodyTop;left=column*colW+pad;right=(column+1)*colW-pad;
  }
  rect={left,y,right,y+height};
  if(kind==L'A'||kind==L'K'){HBRUSH active=CreateSolidBrush(RGB(56,45,49));FillRect(textDC,&rect,active);DeleteObject(active);}
  DrawTextW(textDC,line.c_str(),(int)line.size(),&rect,format|DT_NOPREFIX);
  if(icon>=0)paintIcon(icon,iconLeft,y,iconSize,l);
  if(!grid.empty()){
   HFONT small=CreateFontW(-std::max(11,l.font*2/3),0,0,0,FW_NORMAL,FALSE,FALSE,FALSE,DEFAULT_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,ANTIALIASED_QUALITY,DEFAULT_PITCH,L"Segoe UI");
   SelectObject(textDC,small);
   for(size_t i=0;i<grid.size();++i){
    int gx=left+(int)(i%cells)*(iconSize+10),gy=y+(int)(i/cells)*cellHeight;
    paintIcon(grid[i].first,gx,gy,iconSize,l);
    RECT countRect={gx-3,gy+iconSize,gx+iconSize+6,gy+cellHeight};
    DrawTextW(textDC,grid[i].second.c_str(),(int)grid[i].second.size(),&countRect,DT_CENTER|DT_SINGLELINE|DT_NOPREFIX);
   }
   SelectObject(textDC,body);DeleteObject(small);
  }
  y+=height;
  if(kind==L'T')bodyTop=y+pad;
 }
 SelectObject(textDC,oldFont);DeleteObject(body);DeleteObject(heading);DeleteObject(title);GdiFlush();
 glBindTexture(GL_TEXTURE_2D,texture);glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_NEAREST);glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_NEAREST);
 glPixelStorei(GL_UNPACK_ALIGNMENT,4);glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,l.pw,l.ph,0,0x80E1,GL_UNSIGNED_BYTE,textPixels);
 if(glGetError()!=GL_NO_ERROR){error=11;return false;}
 dirty=false;return true;
}
static void quad(int x,int y,int w,int h){
 glBegin(GL_QUADS);glTexCoord2f(0,0);glVertex2i(x,y);glTexCoord2f(1,0);glVertex2i(x+w,y);
 glTexCoord2f(1,1);glVertex2i(x+w,y+h);glTexCoord2f(0,1);glVertex2i(x,y+h);glEnd();
}
static void restore(){
 if(saved&&game&&IsWindow(game)){
  SetWindowLongW(game,GWL_STYLE,originalStyle);SetWindowLongW(game,GWL_EXSTYLE,originalEx);SetWindowPlacement(game,&originalPlacement);
  SetWindowPos(game,0,0,0,0,0,SWP_NOACTIVATE|SWP_NOMOVE|SWP_NOSIZE|SWP_NOZORDER|SWP_FRAMECHANGED);
 }
 saved=false;on=false;dirty=true;capture.clear();captureW=captureH=0;
}
}
extern "C" int WINAPI BS2_HDLayout(int w,int h,LONG* out){
 if(!out||w<640||h<480||w>7680||h>4320)return 0;
 auto l=HD::layout(w,h);LONG v[12]={l.w,l.h,l.x,l.y,l.gw,l.gh,l.px,l.py,l.pw,l.ph,l.font,l.columns};CopyMemory(out,v,sizeof(v));return 12;
}
extern "C" int WINAPI BS2_HDConfigure(int w,int h,int mode,int filter,int sidebar,int uiPercent){
 if(!enabled||!game||GetWindowThreadProcessId(game,0)!=GetCurrentThreadId())return 0;
 if(w<640||h<480||w>7680||h>4320||mode<0||mode>2||filter<0||filter>2||(sidebar!=0&&sidebar!=1)||uiPercent<75||uiPercent>150){HD::error=1;return 0;}
 if(mode==2){HD::restore();HD::error=0;return 1;}
 HMONITOR monitor=MonitorFromWindow(game,MONITOR_DEFAULTTONEAREST);MONITORINFO mi={sizeof(mi)};
 if(!GetMonitorInfoW(monitor,&mi)){HD::error=2;return 0;}
 LONG style=GetWindowLongW(game,GWL_STYLE),ex=GetWindowLongW(game,GWL_EXSTYLE);
 RECT rect={0,0,w,h};int x=0,y=0;
 if(mode==0){
  style=(style|WS_OVERLAPPEDWINDOW)&~WS_POPUP;ex&=~WS_EX_TOPMOST;
  if(!AdjustWindowRectEx(&rect,style,FALSE,ex)){HD::error=3;return 0;}
  if(rect.right-rect.left>mi.rcWork.right-mi.rcWork.left||rect.bottom-rect.top>mi.rcWork.bottom-mi.rcWork.top){HD::error=4;return 0;}
  x=mi.rcWork.left+(mi.rcWork.right-mi.rcWork.left-(rect.right-rect.left))/2;y=mi.rcWork.top+(mi.rcWork.bottom-mi.rcWork.top-(rect.bottom-rect.top))/2;
 }else{
  style=(style&~WS_OVERLAPPEDWINDOW)|WS_POPUP;ex&=~WS_EX_TOPMOST;rect=mi.rcMonitor;x=rect.left;y=rect.top;
 }
 if(!HD::saved){HD::originalStyle=GetWindowLongW(game,GWL_STYLE);HD::originalEx=GetWindowLongW(game,GWL_EXSTYLE);
  GetWindowPlacement(game,&HD::originalPlacement);HD::saved=true;}
 LONG beforeStyle=GetWindowLongW(game,GWL_STYLE),beforeEx=GetWindowLongW(game,GWL_EXSTYLE);
 SetWindowLongW(game,GWL_STYLE,style);SetWindowLongW(game,GWL_EXSTYLE,ex);
 if(!SetWindowPos(game,0,x,y,rect.right-rect.left,rect.bottom-rect.top,SWP_NOACTIVATE|SWP_NOZORDER|SWP_FRAMECHANGED)){
  SetWindowLongW(game,GWL_STYLE,beforeStyle);SetWindowLongW(game,GWL_EXSTYLE,beforeEx);HD::error=5;return 0;
 }
 HD::on=true;HD::mode=mode;HD::filter=filter;HD::sidebar=sidebar;HD::uiPercent=uiPercent;HD::dirty=true;HD::error=0;return 1;
}
extern "C" int WINAPI BS2_HDStatus(LONG* out){
 if(!out)return 0;RECT rect={};if(game)GetClientRect(game,&rect);auto l=HD::layout(std::max(1L,rect.right),std::max(1L,rect.bottom));
 LONG v[16]={1,HD::on?1:0,HD::mode,HD::filter,HD::sidebar,HD::uiPercent,rect.right,rect.bottom,l.x,l.y,l.gw,l.gh,l.px,l.pw,HD::error,HD::dirty?1:0};CopyMemory(out,v,sizeof(v));return 16;
}
extern "C" int WINAPI BS2_HDText(const char* data,int size){
 if(!data||size<0||size>32768)return 0;
 int count=MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,data,size,0,0);if(!count&&size)return 0;
 std::wstring next(count,L'\0');if(count)MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,data,size,&next[0],count);
 if(next!=HD::text){HD::text=next;HD::dirty=true;}return 1;
}
extern "C" int WINAPI BS2_HDReadback(unsigned char* out,int size){
 if(!enabled||!HD::on)return 0;
 if(size==0){HD::captureW=HD::captureH=0;HD::capture.clear();InterlockedExchange(&HD::captureRequest,1);return 1;}
 int need=HD::captureW*HD::captureH*4;if(!need||size<need||!out)return 0;
 CopyMemory(out,HD::capture.data(),need);return need;
}
extern "C" int WINAPI BS2_HDMonitor(LONG* out){
 if(!out||!game)return 0;MONITORINFO mi={sizeof(mi)};
 if(!GetMonitorInfoW(MonitorFromWindow(game,MONITOR_DEFAULTTONEAREST),&mi))return 0;
 auto getDpi=(UINT(WINAPI*)(HWND))GetProcAddress(GetModuleHandleW(L"user32.dll"),"GetDpiForWindow");
 LONG v[6]={1,mi.rcMonitor.right-mi.rcMonitor.left,mi.rcMonitor.bottom-mi.rcMonitor.top,mi.rcWork.right-mi.rcWork.left,mi.rcWork.bottom-mi.rcWork.top,getDpi?(LONG)getDpi(game):96};
 CopyMemory(out,v,sizeof(v));return 6;
}
extern "C" int WINAPI BS2_HDPresentation(int value){
 if(value<0||value>1)return 0;
 if(HD::modal!=(value!=0)){HD::modal=value!=0;HD::dirty=true;}return 1;
}
extern "C" int WINAPI BS2_HDDPI(LONG* out){
 if(!out||!game)return 0;MONITORINFOEXW mi={};mi.cbSize=sizeof(mi);
 if(!GetMonitorInfoW(MonitorFromWindow(game,MONITOR_DEFAULTTONEAREST),(MONITORINFO*)&mi))return 0;
 DEVMODEW dm={};dm.dmSize=sizeof(dm);BOOL physical=EnumDisplaySettingsW(mi.szDevice,ENUM_CURRENT_SETTINGS,&dm);
 auto context=(HANDLE(WINAPI*)(HWND))GetProcAddress(GetModuleHandleW(L"user32.dll"),"GetWindowDpiAwarenessContext");
 auto awareness=(int(WINAPI*)(HANDLE))GetProcAddress(GetModuleHandleW(L"user32.dll"),"GetAwarenessFromDpiAwarenessContext");
 auto dpi=(UINT(WINAPI*)(HWND))GetProcAddress(GetModuleHandleW(L"user32.dll"),"GetDpiForWindow");
 int aware=context&&awareness?awareness(context(game)):(IsProcessDPIAware()?1:0);
 int virtualW=mi.rcMonitor.right-mi.rcMonitor.left,virtualH=mi.rcMonitor.bottom-mi.rcMonitor.top;
 LONG v[8]={1,aware,dpi?(LONG)dpi(game):96,physical?(LONG)dm.dmPelsWidth:virtualW,physical?(LONG)dm.dmPelsHeight:virtualH,
  virtualW,virtualH,aware==0&&physical&&((int)dm.dmPelsWidth!=virtualW||(int)dm.dmPelsHeight!=virtualH)?1:0};
 CopyMemory(out,v,sizeof(v));return 8;
}

// Exact body-font measurement for Ruby's paginated HD reference. No rendering or gameplay calls.
extern "C" int WINAPI BS2_HDMeasure(const char* data,int size,int font){
 if(!data||size<0||size>4096||font<10||font>100)return -1;
 int count=MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,data,size,0,0);if(!count&&size)return -1;
 std::wstring value(count,L'\0');if(count)MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,data,size,&value[0],count);
 HDC dc=CreateCompatibleDC(0);if(!dc)return -1;
 HFONT face=CreateFontW(-font,0,0,0,FW_NORMAL,FALSE,FALSE,FALSE,DEFAULT_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,ANTIALIASED_QUALITY,DEFAULT_PITCH,L"Segoe UI");
 if(!face){DeleteDC(dc);return -1;}
 HGDIOBJ old=SelectObject(dc,face);SIZE extent={};BOOL ok=GetTextExtentPoint32W(dc,value.c_str(),count,&extent);
 SelectObject(dc,old);DeleteObject(face);DeleteDC(dc);return ok?extent.cx:-1;
}

extern "C" int WINAPI BS2_HDIcon(int index,const unsigned char* pixels,int size){
 if(!pixels||index<0||index>4095||size!=24*24*4)return 0;
 if(HD::icons.size()>=256&&HD::icons.find(index)==HD::icons.end())return 0;
 HD::icons[index]=std::vector<unsigned char>(pixels,pixels+size);HD::dirty=true;return 1;
}
