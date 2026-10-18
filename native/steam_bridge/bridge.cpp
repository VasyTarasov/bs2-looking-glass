#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <GL/gl.h>
#include <vector>
#include <stdint.h>
#include <intrin.h>
#include "minhook/include/MinHook.h"
#pragma comment(lib,"user32.lib")
#pragma comment(lib,"gdi32.lib")
#pragma comment(lib,"opengl32.lib")
#pragma comment(linker,"/EXPORT:BS2_Boot=_BS2_Boot@8")
#pragma comment(linker,"/EXPORT:BS2_SourceSize=_BS2_SourceSize@8")
#pragma comment(linker,"/EXPORT:BS2_Stop=_BS2_Stop@0")
#pragma comment(linker,"/EXPORT:BS2_Stats=_BS2_Stats@4")
#pragma comment(linker,"/EXPORT:BS2_CapturePause=_BS2_CapturePause@4")
#pragma comment(linker,"/EXPORT:BS2_InputStatus=_BS2_InputStatus@4")
#pragma comment(linker,"/EXPORT:BS2_FocusStatus=_BS2_FocusStatus@4")
#pragma comment(linker,"/EXPORT:BS2_OverlayTick=_BS2_OverlayTick@0")
#pragma comment(linker,"/EXPORT:BS2_RestartStatus=_BS2_RestartStatus@4")
#pragma comment(linker,"/EXPORT:BS2_Restart=_BS2_Restart@0")
// Redirect only RGSS301's named import, never a process-wide keyboard hook.
// RGSS F12 restarts the script table, which is incompatible with vanilla HZM.
static ULONG_PTR* resetSlot=0;static ULONG_PTR previousAsync=0;
static uintptr_t engineBegin=0,engineEnd=0;
static LONG resetReads=0;
static SHORT WINAPI rgssAsync(int key){
 if(key==VK_F12){InterlockedIncrement(&resetReads);return 0;}
 return ((decltype(&GetAsyncKeyState))previousAsync)(key);
}
static bool guardReset(){
 BYTE* base=(BYTE*)GetModuleHandleW(L"RGSS301.dll");if(!base)return false;
 auto dos=(IMAGE_DOS_HEADER*)base;if(dos->e_magic!=IMAGE_DOS_SIGNATURE)return false;
 auto nt=(IMAGE_NT_HEADERS*)(base+dos->e_lfanew);
 if(nt->Signature!=IMAGE_NT_SIGNATURE||nt->OptionalHeader.Magic!=IMAGE_NT_OPTIONAL_HDR32_MAGIC)return false;
 DWORD size=nt->OptionalHeader.SizeOfImage;
 engineBegin=(uintptr_t)base;engineEnd=engineBegin+size;
 auto dir=nt->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT];
 if(!dir.VirtualAddress||dir.VirtualAddress>=size||dir.Size>size-dir.VirtualAddress)return false;
 for(auto d=(IMAGE_IMPORT_DESCRIPTOR*)(base+dir.VirtualAddress);d->Name;++d){
  if(d->Name>=size||d->OriginalFirstThunk>=size||d->FirstThunk>=size)return false;
  if(_stricmp((char*)base+d->Name,"user32.dll"))continue;
  auto names=d->OriginalFirstThunk?(IMAGE_THUNK_DATA*)(base+d->OriginalFirstThunk):nullptr;
  auto addresses=(IMAGE_THUNK_DATA*)(base+d->FirstThunk);
  auto asyncAddress=(ULONG_PTR)GetProcAddress(GetModuleHandleW(L"user32.dll"),"GetAsyncKeyState");
  for(;((BYTE*)addresses+sizeof(*addresses)<=base+size)&&addresses->u1.Function;++addresses){
   bool match=false;
   if(names){
    if((BYTE*)names+sizeof(*names)>base+size)return false;
    if(!IMAGE_SNAP_BY_ORDINAL(names->u1.Ordinal)&&names->u1.AddressOfData<size){
     auto n=(IMAGE_IMPORT_BY_NAME*)(base+names->u1.AddressOfData);
     match=!strcmp((char*)n->Name,"GetAsyncKeyState");
    }
    ++names;
   }else match=addresses->u1.Function==asyncAddress;
   if(!match)continue;
   DWORD old=0;resetSlot=(ULONG_PTR*)&addresses->u1.Function;
   if(!VirtualProtect(resetSlot,sizeof(*resetSlot),PAGE_READWRITE,&old)){resetSlot=0;return false;}
   previousAsync=*resetSlot;InterlockedExchangePointer((PVOID*)resetSlot,(PVOID)rgssAsync);
   DWORD ignored=0;VirtualProtect(resetSlot,sizeof(*resetSlot),old,&ignored);return true;
  }
 }
 return false;
}
static void unguardReset(){
 if(!resetSlot)return;DWORD old=0;
 if(VirtualProtect(resetSlot,sizeof(*resetSlot),PAGE_READWRITE,&old)){
  // Do not undo a later third-party change to this import.
  InterlockedCompareExchangePointer((PVOID*)resetSlot,(PVOID)previousAsync,(PVOID)rgssAsync);
  DWORD ignored=0;VirtualProtect(resetSlot,sizeof(*resetSlot),old,&ignored);
 }
 resetSlot=0;
}
static LONG lastError=0;static thread_local bool inBridge=false;
struct CaptureGuard{bool outer;CaptureGuard():outer(!inBridge){inBridge=true;}~CaptureGuard(){if(outer)inBridge=false;}};
static LONG allCalls=0,lastWindow=0,lastW=0,lastH=0;
#pragma comment(linker,"/EXPORT:BS2_Screenshot=_BS2_Screenshot@0")
static void* screenshots=0;
static uint32_t (__cdecl *writeShot)(void*,void*,uint32_t,int,int)=0;
static void (__cdecl *hookShots)(void*,bool)=0;
static bool (__cdecl *isHooked)(void*)=0;
static void (__cdecl *registerCallback)(void*,int)=0;
static void (__cdecl *unregisterCallback)(void*)=0;
static volatile LONG request=0,shotHandle=0,shotResult=0;
static volatile LONG restartRequest=0,restartChild=0,restartError=0,lastPlainF12=0;
static bool f12Armed=false;
static void queueF12(){
 if(!f12Armed)return;
 // Modified keys belong to Steam's user-selected screenshot shortcut.
 if((GetAsyncKeyState(VK_CONTROL)|GetAsyncKeyState(VK_SHIFT)|GetAsyncKeyState(VK_MENU))&0x8000)return;
 InterlockedExchange(&lastPlainF12,(LONG)GetTickCount());InterlockedExchange(&restartRequest,1);
}
static LONG overlayActive=0,overlayEnabled=0;
static LONG steamReady=0;static bool previousHook=false;
static HWND inputWindow=0;static WNDPROC previousProc=0;static bool windowGuard=false;
static LRESULT CALLBACK inputProc(HWND hwnd,UINT msg,WPARAM key,LPARAM info){
 if(windowGuard && hwnd==inputWindow && key==VK_F12 &&
   (msg==WM_KEYDOWN||msg==WM_KEYUP||msg==WM_SYSKEYDOWN||msg==WM_SYSKEYUP)){
  InterlockedIncrement(&resetReads);
  if((msg==WM_KEYDOWN||msg==WM_SYSKEYDOWN)&&!(info&(1L<<30)))queueF12();
  return 0;
 }
 return CallWindowProcW(previousProc,hwnd,msg,key,info);
}
static bool guardWindow(HWND hwnd){
 previousProc=(WNDPROC)GetWindowLongPtrW(hwnd,GWLP_WNDPROC);inputWindow=hwnd;
 if(!previousProc)return false;
 SetLastError(0);LONG_PTR old=SetWindowLongPtrW(hwnd,GWLP_WNDPROC,(LONG_PTR)inputProc);
 if(!old)return false;
 previousProc=(WNDPROC)old;inputWindow=hwnd;windowGuard=true;return true;
}
static void unguardWindow(){
 windowGuard=false;
 if(inputWindow && (WNDPROC)GetWindowLongPtrW(inputWindow,GWLP_WNDPROC)==inputProc)
  SetWindowLongPtrW(inputWindow,GWLP_WNDPROC,(LONG_PTR)previousProc);
}
class Callback { public:
 virtual void Run(void*)=0;
 virtual void Run(void* p,bool,uint64_t){Run(p);}
 virtual int GetCallbackSizeBytes()=0;
 uint8_t callbackFlags=0;int callbackId=0;
};
class Requested:public Callback {void Run(void*) override{
 if(restartRequest||restartChild||(lastPlainF12&&DWORD(GetTickCount()-(DWORD)lastPlainF12)<500))return;
 InterlockedExchange(&request,1);
} int GetCallbackSizeBytes() override{return 0;}} requested;
class Finished:public Callback {void Run(void* p) override{uint32_t* v=(uint32_t*)p;InterlockedExchange(&shotHandle,v[0]);InterlockedExchange(&shotResult,v[1]);} int GetCallbackSizeBytes() override{return 8;}} finished;
class Activated:public Callback {void Run(void* p) override{InterlockedExchange(&overlayActive,*(uint8_t*)p?1:0);} int GetCallbackSizeBytes() override{return 1;}} activated;
static bool (__cdecl *overlayState)(void*)=0;static void* utils=0;
static void attachSteam(){
 if(steamReady)return;
 HMODULE api=GetModuleHandleW(L"steam_api.dll");if(!api)return;
 auto get=(void*(__cdecl*)())GetProcAddress(api,"SteamAPI_SteamScreenshots_v003");
 writeShot=(decltype(writeShot))GetProcAddress(api,"SteamAPI_ISteamScreenshots_WriteScreenshot");
 hookShots=(decltype(hookShots))GetProcAddress(api,"SteamAPI_ISteamScreenshots_HookScreenshots");
 isHooked=(decltype(isHooked))GetProcAddress(api,"SteamAPI_ISteamScreenshots_IsScreenshotsHooked");
 registerCallback=(decltype(registerCallback))GetProcAddress(api,"SteamAPI_RegisterCallback");
 unregisterCallback=(decltype(unregisterCallback))GetProcAddress(api,"SteamAPI_UnregisterCallback");
 if(get&&writeShot&&hookShots&&isHooked&&registerCallback&&unregisterCallback){screenshots=get();if(screenshots){previousHook=isHooked(screenshots);registerCallback(&activated,331);registerCallback(&requested,2302);registerCallback(&finished,2301);hookShots(screenshots,true);steamReady=1;}}
}
static void detachSteam(){
 if(steamReady){hookShots(screenshots,previousHook);unregisterCallback(&requested);unregisterCallback(&finished);unregisterCallback(&activated);steamReady=0;screenshots=0;}
}
static HWND game=0,canvas=0;static HDC mem=0,dc=0;static HBITMAP bmp=0;static void* pixels=0;
static HWND previousFocus=0;static bool borrowedFocus=false;static LONG focusChanges=0;
static void overlayFocus(){
 DWORD pid=0;GetWindowThreadProcessId(GetForegroundWindow(),&pid);
 if(pid!=GetCurrentProcessId())return;
 HWND focus=GetFocus();
 if(overlayActive&&canvas){
  if(!borrowedFocus){previousFocus=focus;borrowedFocus=true;}
  if(focus!=canvas&&!IsChild(canvas,focus)){SetFocus(canvas);InterlockedIncrement(&focusChanges);}
 }else if(borrowedFocus){
  if(focus==canvas||IsChild(canvas,focus)){
   DWORD owner=0;GetWindowThreadProcessId(previousFocus,&owner);
   SetFocus(owner==GetCurrentProcessId()?previousFocus:game);
  }
  borrowedFocus=false;previousFocus=0;
 }
}
static HGLRC rc=0;static GLuint tex=0;static int sw=0,sh=0,sourceW=640,sourceH=480;static LONG flags=0,frames=0,captures=0,errors=0,ready=0;static DWORD renderThread=0;
static CRITICAL_SECTION lock;static bool enabled=false,glFailed=false;
static decltype(&BitBlt) realBit=0;static decltype(&StretchBlt) realStretch=0;
static decltype(&StretchDIBits) realDIB=0;static decltype(&SetDIBitsToDevice) realSet=0;
#include "hd_display.h"
static bool ownDest(HDC d,int x,int y,int w,int h,void* caller){
 InterlockedIncrement(&allCalls);HWND target=WindowFromDC(d);lastWindow=(LONG)target;lastW=w;lastH=h;
 if(!enabled||w<160||h<1||w>8192||h>8192)return false;
 if(target==game)return true;
 // Steam's GDI redirect can replace the game DC with a windowless memory DC.
 // Accept only the RGSS full-width eight-row frame strips, originating in
 // this loaded engine (or Steam's wrapper), never arbitrary memory blits.
 if(target||GetObjectType(d)!=OBJ_MEMDC||x!=0||w!=sourceW||h!=8||y<0||y%8||y+h>sourceH)return false;
 uintptr_t address=(uintptr_t)caller;
 if(address>=engineBegin&&address<engineEnd)return true;
 HMODULE owner=0;
 return GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS|GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,(LPCWSTR)caller,&owner)&&owner==GetModuleHandleW(L"GameOverlayRenderer.dll");
}
static bool buffer(int w,int h){
 if(sw==w && sh==h && mem)return true;
 if(mem){DeleteDC(mem);mem=0;}if(bmp){DeleteObject(bmp);bmp=0;}
 mem=CreateCompatibleDC(0);BITMAPINFO bi={};bi.bmiHeader.biSize=40;bi.bmiHeader.biWidth=w;bi.bmiHeader.biHeight=-h;bi.bmiHeader.biPlanes=1;bi.bmiHeader.biBitCount=32;
 bmp=CreateDIBSection(mem,&bi,DIB_RGB_COLORS,&pixels,0,0);if(!bmp || !mem)return false;
 SelectObject(mem,bmp);sw=w;sh=h;return true;
}
static LRESULT CALLBACK canvasProc(HWND hwnd,UINT msg,WPARAM key,LPARAM info){
 if(game && IsWindow(game)){
  if(msg==WM_CLOSE||msg==WM_SYSCOMMAND||msg==WM_SYSKEYDOWN||msg==WM_SYSKEYUP)
   return SendMessageW(game,msg,key,info);
  if((msg==WM_KEYDOWN||msg==WM_KEYUP)&&(key==VK_F1||key==VK_F2||key==VK_F12))
   return SendMessageW(game,msg,key,info);
 }
 return DefWindowProcW(hwnd,msg,key,info);
}
static bool renderer(){
 if(rc&&ready)return true;if(!(flags&1)||glFailed)return false;
 HDC savedDC=wglGetCurrentDC();HGLRC savedRC=wglGetCurrentContext();
 renderThread=GetCurrentThreadId();WNDCLASSW wc={};wc.lpfnWndProc=canvasProc;wc.hInstance=GetModuleHandleW(0);wc.lpszClassName=L"BS2SteamCanvas090";wc.style=CS_OWNDC;RegisterClassW(&wc);
 canvas=CreateWindowExW(WS_EX_NOACTIVATE,wc.lpszClassName,L"",WS_CHILD|WS_VISIBLE,0,0,640,480,game,0,wc.hInstance,0);if(!canvas){glFailed=true;errors++;return false;}dc=GetDC(canvas);
 PIXELFORMATDESCRIPTOR pfd={};pfd.nSize=sizeof(pfd);pfd.nVersion=1;pfd.dwFlags=PFD_DRAW_TO_WINDOW|PFD_SUPPORT_OPENGL|PFD_DOUBLEBUFFER;pfd.iPixelType=PFD_TYPE_RGBA;pfd.cColorBits=32;
 int pf=ChoosePixelFormat(dc,&pfd);if(!pf || !SetPixelFormat(dc,pf,&pfd)){ShowWindow(canvas,SW_HIDE);glFailed=true;errors++;return false;}
 rc=wglCreateContext(dc);if(!rc || !wglMakeCurrent(dc,rc)){ShowWindow(canvas,SW_HIDE);glFailed=true;errors++;return false;}
 glGenTextures(1,&tex);glBindTexture(GL_TEXTURE_2D,tex);glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_NEAREST);glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_NEAREST);ready=1;wglMakeCurrent(savedDC,savedRC);return true;
}
static LONG capturePaused=0;
extern "C" int WINAPI BS2_CapturePause(int paused){InterlockedExchange(&capturePaused,paused?1:0);return 1;}
static void present(){
 if(InterlockedCompareExchange(&capturePaused,0,0))return;
 HDC previousDC=wglGetCurrentDC();HGLRC previousRC=wglGetCurrentContext();
 try {
 InterlockedIncrement(&captures);
 // Steam may become available after the Ruby bootstrap. Retry without Init.
 static DWORD lastAttach=0;DWORD attachNow=GetTickCount();
 if((flags&2)&&(!steamReady||!utils)&&(lastAttach==0||DWORD(attachNow-lastAttach)>1000)){
  lastAttach=attachNow;attachSteam();HMODULE api=GetModuleHandleW(L"steam_api.dll");
  if(api){const char* names[]={"SteamAPI_SteamUtils_v010","SteamAPI_SteamUtils_v009","SteamAPI_SteamUtils_v008"};
   for(auto name:names){auto get=(void*(__cdecl*)())GetProcAddress(api,name);if(get&&(utils=get()))break;}
   overlayState=(decltype(overlayState))GetProcAddress(api,"SteamAPI_ISteamUtils_IsOverlayEnabled");}
 }
 static bool wasF12=false;bool f12=(GetAsyncKeyState(VK_F12)&0x8000)!=0;
 DWORD foregroundPid=0;GetWindowThreadProcessId(GetForegroundWindow(),&foregroundPid);
 if(!f12)f12Armed=true;
 if(f12&&!wasF12&&foregroundPid==GetCurrentProcessId())queueF12();wasF12=f12;
 static DWORD lastShot=0;DWORD now=GetTickCount();
 bool wantShot=InterlockedExchange(&request,0)&&screenshots&&writeShot&&(lastShot==0||DWORD(now-lastShot)>350);
 if(utils&&overlayState)overlayEnabled=overlayState(utils)?1:0;
 if(!renderer())return;
 overlayFocus();
 if(GetCurrentThreadId()!=renderThread){lastError=1;InterlockedIncrement(&errors);return;}
 HDC oldDC=wglGetCurrentDC();HGLRC oldRC=wglGetCurrentContext();if(!wglMakeCurrent(dc,rc)){lastError=0x20000+GetLastError();InterlockedIncrement(&errors);return;}
 RECT r={};GetClientRect(game,&r);
 if(r.right<=0||r.bottom<=0){if(oldRC!=rc)wglMakeCurrent(oldDC,oldRC);return;}
 SetWindowPos(canvas,HWND_TOP,0,0,r.right,r.bottom,SWP_NOACTIVATE);glViewport(0,0,r.right,r.bottom);
 glDisable(GL_DEPTH_TEST);glDisable(GL_BLEND);glClearColor(.015f,.018f,.023f,1);glClear(GL_COLOR_BUFFER_BIT);
 glMatrixMode(GL_PROJECTION);glLoadIdentity();glOrtho(0,r.right,r.bottom,0,-1,1);glMatrixMode(GL_MODELVIEW);glLoadIdentity();
 glEnable(GL_TEXTURE_2D);glBindTexture(GL_TEXTURE_2D,tex);
 glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,HD::on&&HD::filter==1?GL_LINEAR:GL_NEAREST);
 glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,HD::on&&HD::filter==1?GL_LINEAR:GL_NEAREST);
 glPixelStorei(GL_UNPACK_ALIGNMENT,4);glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA,sw,sh,0,0x80E1,GL_UNSIGNED_BYTE,pixels);glColor4f(1,1,1,1);
 auto composition=HD::layout(r.right,r.bottom);
 HD::quad(composition.x,composition.y,composition.gw,composition.gh);
 if(HD::on&&HD::sidebar&&HD::panel(composition)){glBindTexture(GL_TEXTURE_2D,HD::texture);HD::quad(composition.px,0,composition.pw,composition.ph);}
 bool captureRequested=InterlockedExchange(&HD::captureRequest,0)!=0;
 if(HD::on&&(wantShot||captureRequested)&&r.right>0&&r.bottom>0){
  size_t length=(size_t)r.right*r.bottom*4;std::vector<unsigned char> bottomUp(length);
  glPixelStorei(GL_PACK_ALIGNMENT,4);glReadPixels(0,0,r.right,r.bottom,0x80E1,GL_UNSIGNED_BYTE,bottomUp.data());
  HD::capture.resize(length);HD::captureW=r.right;HD::captureH=r.bottom;
  for(int y=0;y<r.bottom;y++)CopyMemory(HD::capture.data()+(size_t)y*r.right*4,bottomUp.data()+(size_t)(r.bottom-1-y)*r.right*4,(size_t)r.right*4);
 }
 if(wantShot){
  lastShot=now;int width=HD::on?HD::captureW:sw,height=HD::on?HD::captureH:sh;
  unsigned char* bgra=HD::on?HD::capture.data():(unsigned char*)pixels;
  std::vector<uint8_t> rgb((size_t)width*height*3);
  for(size_t i=0;i<(size_t)width*height;i++){rgb[i*3]=bgra[i*4+2];rgb[i*3+1]=bgra[i*4+1];rgb[i*3+2]=bgra[i*4];}
  uint32_t handle=writeShot(screenshots,rgb.data(),(uint32_t)rgb.size(),width,height);
  InterlockedExchange(&shotHandle,handle);InterlockedExchange(&shotResult,handle?-1:2);
 }
 if(SwapBuffers(dc))InterlockedIncrement(&frames);else {lastError=0x30000+GetLastError();InterlockedIncrement(&errors);}if(oldRC!=rc)wglMakeCurrent(oldDC,oldRC);
 MSG m;while(PeekMessageW(&m,canvas,0,0,PM_REMOVE)){TranslateMessage(&m);DispatchMessageW(&m);}
 }catch(const std::bad_alloc&){
  lastError=ERROR_NOT_ENOUGH_MEMORY;InterlockedIncrement(&errors);InterlockedExchange(&shotResult,ERROR_NOT_ENOUGH_MEMORY);
  InterlockedExchange(&HD::captureRequest,0);wglMakeCurrent(previousDC,previousRC);
 }
}
static bool screenBuffer(){return buffer(sourceW,sourceH);}
static BOOL WINAPI bitHook(HDC d,int x,int y,int w,int h,HDC s,int sx,int sy,DWORD rop){
 void* caller=_ReturnAddress();CaptureGuard guard;BOOL result=realBit(d,x,y,w,h,s,sx,sy,rop);if(guard.outer&&ownDest(d,x,y,w,h,caller)){EnterCriticalSection(&lock);if(screenBuffer()&&realBit(mem,x,y,w,h,s,sx,sy,SRCCOPY)&&y+h>=sh)present();LeaveCriticalSection(&lock);}return result;
}
static BOOL WINAPI stretchHook(HDC d,int x,int y,int w,int h,HDC s,int sx,int sy,int ws,int hs,DWORD rop){
 void* caller=_ReturnAddress();CaptureGuard guard;BOOL result=realStretch(d,x,y,w,h,s,sx,sy,ws,hs,rop);if(guard.outer&&ownDest(d,x,y,w,h,caller)&&ws>0&&hs>0){EnterCriticalSection(&lock);if(screenBuffer()&&realStretch(mem,x,y,w,h,s,sx,sy,ws,hs,SRCCOPY)&&y+h>=sh)present();LeaveCriticalSection(&lock);}return result;
}
static int WINAPI dibHook(HDC d,int x,int y,int w,int h,int sx,int sy,int ws,int hs,const VOID* bits,const BITMAPINFO* bi,UINT use,DWORD rop){
 void* caller=_ReturnAddress();CaptureGuard guard;int result=realDIB(d,x,y,w,h,sx,sy,ws,hs,bits,bi,use,rop);if(guard.outer&&ownDest(d,x,y,w,h,caller)&&ws>0&&hs>0){EnterCriticalSection(&lock);if(screenBuffer()&&realDIB(mem,x,y,w,h,sx,sy,ws,hs,bits,bi,use,SRCCOPY)>0&&y+h>=sh)present();LeaveCriticalSection(&lock);}return result;
}
static int WINAPI setHook(HDC d,int x,int y,DWORD w,DWORD h,int sx,int sy,UINT start,UINT lines,const VOID* bits,const BITMAPINFO* bi,UINT use){
 void* caller=_ReturnAddress();CaptureGuard guard;int result=realSet(d,x,y,w,h,sx,sy,start,lines,bits,bi,use);if(guard.outer&&ownDest(d,x,y,w,h,caller)){EnterCriticalSection(&lock);if(screenBuffer()&&realSet(mem,x,y,w,h,sx,sy,start,lines,bits,bi,use)>0&&y+(int)h>=sh)present();LeaveCriticalSection(&lock);}return result;
}
extern "C" int WINAPI BS2_SourceSize(int w,int h){if(enabled||w<160||h<120||w>8192||h>8192)return 0;sourceW=w;sourceH=h;return 1;}
extern "C" int WINAPI BS2_Boot(HWND hwnd,LONG f){
 if(enabled)return 1;DWORD pid=0;GetWindowThreadProcessId(hwnd,&pid);if(!hwnd||pid!=GetCurrentProcessId())return 0;game=hwnd;flags=f;InitializeCriticalSection(&lock);
 restartRequest=0;restartChild=0;restartError=0;lastPlainF12=0;f12Armed=false;
 if(MH_Initialize()!=MH_OK){DeleteCriticalSection(&lock);return 0;}
 if(MH_CreateHookApi(L"gdi32.dll","BitBlt",bitHook,(void**)&realBit)!=MH_OK || MH_CreateHookApi(L"gdi32.dll","StretchBlt",stretchHook,(void**)&realStretch)!=MH_OK || MH_CreateHookApi(L"gdi32.dll","StretchDIBits",dibHook,(void**)&realDIB)!=MH_OK || MH_CreateHookApi(L"gdi32.dll","SetDIBitsToDevice",setHook,(void**)&realSet)!=MH_OK){MH_Uninitialize();DeleteCriticalSection(&lock);return 0;}
 if(!guardReset()){lastError=4;MH_Uninitialize();DeleteCriticalSection(&lock);return 0;}
 if(!guardWindow(hwnd)){lastError=5;unguardReset();MH_Uninitialize();DeleteCriticalSection(&lock);return 0;}
 if(flags&2){attachSteam();HMODULE api=GetModuleHandleW(L"steam_api.dll");if(api){
 const char* names[]={"SteamAPI_SteamUtils_v010","SteamAPI_SteamUtils_v009","SteamAPI_SteamUtils_v008"};
 for(auto name:names){auto get=(void*(__cdecl*)())GetProcAddress(api,name);if(get){utils=get();break;}}
 overlayState=(decltype(overlayState))GetProcAddress(api,"SteamAPI_ISteamUtils_IsOverlayEnabled");}}

 enabled=true;if(MH_EnableHook(MH_ALL_HOOKS)!=MH_OK){enabled=false;detachSteam();unguardWindow();unguardReset();MH_Uninitialize();DeleteCriticalSection(&lock);return 0;}return 1;
}
extern "C" int WINAPI BS2_InputStatus(LONG* out){if(!out)return 0;LONG v[4]={1,(resetSlot&&windowGuard)?1:0,resetReads,GetModuleHandleW(L"GameOverlayRenderer.dll")?1:0};CopyMemory(out,v,sizeof(v));return 4;}
extern "C" int WINAPI BS2_FocusStatus(LONG* out){if(!out)return 0;LONG v[4]={(LONG)GetFocus(),(LONG)previousFocus,borrowedFocus?1:0,focusChanges};CopyMemory(out,v,sizeof(v));return 4;}
extern "C" int WINAPI BS2_Stats(LONG* out){if(!out)return 0;LONG v[22]={1,enabled?1:0,captures,frames,ready,errors,sw,sh,(LONG)renderThread,(LONG)GetCurrentThreadId(),allCalls,lastWindow,lastW,lastH,(LONG)game,(LONG)canvas,steamReady,shotHandle,shotResult,overlayEnabled,overlayActive,lastError};CopyMemory(out,v,sizeof(v));return 22;}
extern "C" int WINAPI BS2_Screenshot(){if(!steamReady)return 0;InterlockedExchange(&request,1);return 1;}
extern "C" int WINAPI BS2_RestartStatus(LONG* out){if(!out)return 0;LONG v[4]={1,restartRequest,restartChild,restartError};CopyMemory(out,v,sizeof(v));return 4;}
extern "C" int WINAPI BS2_Restart(){
 if(!enabled||!restartRequest||restartChild)return 0;
 InterlockedExchange(&restartRequest,0);
 // A QA fixture must never recursively launch itself or escape its runner.
 if(GetFileAttributesW(L"test_prepare_profile.json")!=INVALID_FILE_ATTRIBUTES){restartError=ERROR_NOT_SUPPORTED;return 0;}
 wchar_t exe[32768]={};DWORD n=GetModuleFileNameW(0,exe,32768);
 if(!n||n>=32767){restartError=GetLastError();return 0;}
 std::vector<wchar_t> command;command.push_back(L'"');command.insert(command.end(),exe,exe+n);command.push_back(L'"');command.push_back(0);
 wchar_t directory[32768]={};CopyMemory(directory,exe,(n+1)*sizeof(wchar_t));
 wchar_t* slash=wcsrchr(directory,L'\\');if(!slash){restartError=ERROR_BAD_PATHNAME;return 0;}*slash=0;
 STARTUPINFOW startup={};startup.cb=sizeof(startup);PROCESS_INFORMATION child={};
 if(!CreateProcessW(exe,command.data(),0,0,FALSE,0,0,directory,&startup,&child)){restartError=GetLastError();return 0;}
 InterlockedExchange(&restartChild,(LONG)child.dwProcessId);CloseHandle(child.hThread);CloseHandle(child.hProcess);
 PostMessageW(game,WM_CLOSE,0,0);return 1;
}
extern "C" int WINAPI BS2_HDRestartDPI(){
 if(!enabled||!game)return 0;
 if(GetFileAttributesW(L"test_prepare_profile.json")!=INVALID_FILE_ATTRIBUTES){restartError=ERROR_NOT_SUPPORTED;return 0;}
 // Compatibility setting exists only in this process environment and its fresh child.
 // No registry values, global desktop settings or third-party processes are changed.
 DWORD length=GetEnvironmentVariableW(L"__COMPAT_LAYER",0,0);if(length>32768)return 0;
 std::vector<wchar_t> old(length?length:1);if(length)GetEnvironmentVariableW(L"__COMPAT_LAYER",old.data(),length);
 std::wstring next=length?old.data():L"";next+=L" HIGHDPIAWARE";
 if(!SetEnvironmentVariableW(L"__COMPAT_LAYER",next.c_str()))return 0;
 InterlockedExchange(&restartRequest,1);int result=BS2_Restart();
 if(!result)SetEnvironmentVariableW(L"__COMPAT_LAYER",length?old.data():0);
 return result;
}
extern "C" int WINAPI BS2_OverlayTick(){
 if(!enabled)return 0;
 if(!overlayActive){overlayFocus();return 0;}
 if(!mem||!ready||GetCurrentThreadId()!=renderThread)return 0;
 // RGSS Graphics.update stops rendering when its input focus moves to Steam.
 // Keep presenting the last game frame and pumping native window messages,
 // without advancing the game, Ruby events, animations or frame counters.
 {CaptureGuard guard;if(!guard.outer)return 0;EnterCriticalSection(&lock);present();LeaveCriticalSection(&lock);}
 MSG m;while(PeekMessageW(&m,0,0,0,PM_REMOVE)){
  if(m.message==WM_QUIT){PostQuitMessage((int)m.wParam);return 0;}
  TranslateMessage(&m);DispatchMessageW(&m);
 }
 Sleep(12);return 1;
}
extern "C" int WINAPI BS2_Stop(){
 if(!enabled)return 1;enabled=false;MH_DisableHook(MH_ALL_HOOKS);EnterCriticalSection(&lock);
 if(!restartChild){unguardWindow();unguardReset();}
 else {HMODULE pinned=0;GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_PIN|GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS,(LPCWSTR)inputProc,&pinned);}
 overlayActive=0;overlayFocus();
 detachSteam();HD::restore();
 if(rc && GetCurrentThreadId()==renderThread){wglMakeCurrent(dc,rc);HD::freePanel();glDeleteTextures(1,&tex);wglMakeCurrent(0,0);wglDeleteContext(rc);rc=0;}
 if(canvas)ShowWindow(canvas,SW_HIDE);if(canvas&&GetWindowThreadProcessId(canvas,0)==GetCurrentThreadId()){if(dc)ReleaseDC(canvas,dc);DestroyWindow(canvas);canvas=0;}
 if(mem)DeleteDC(mem);mem=0;if(bmp)DeleteObject(bmp);bmp=0;LeaveCriticalSection(&lock);MH_Uninitialize();DeleteCriticalSection(&lock);ready=0;return 1;
}
BOOL WINAPI DllMain(HINSTANCE,DWORD,LPVOID){return TRUE;}
