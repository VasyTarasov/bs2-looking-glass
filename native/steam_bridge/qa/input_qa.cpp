#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <cstring>
#include "../minhook/include/MinHook.h"
#pragma comment(linker,"/EXPORT:QA_Install=_QA_Install@0")
#pragma comment(linker,"/EXPORT:QA_Pressed=_QA_Pressed@4")
#pragma comment(linker,"/EXPORT:QA_Read=_QA_Read@4")
#pragma comment(linker,"/EXPORT:QA_Restore=_QA_Restore@0")
#pragma comment(linker,"/EXPORT:QA_Message=_QA_Message@0")
#pragma comment(linker,"/EXPORT:QA_WindowRestored=_QA_WindowRestored@0")
static ULONG_PTR* slot=0;static decltype(&GetAsyncKeyState) previous=0;static int pressed=0;
static HWND ownWindow=0;
static WNDPROC ownProc=0;
static HWND WINAPI fakeForeground(){return ownWindow;}
static SHORT WINAPI fakeAsync(int key){
 if(key==VK_F12&&(pressed&1))return (SHORT)0x8000;
 if(key==VK_CONTROL&&(pressed&2))return (SHORT)0x8000;
 if(key==VK_CONTROL||key==VK_SHIFT||key==VK_MENU)return 0;
 if(key==0xFE)return 0x2345;
 return previous(key);
}
extern "C" int WINAPI QA_Install(){
 BYTE* b=(BYTE*)GetModuleHandleW(L"RGSS301.dll");if(!b)return 0;
 auto nt=(IMAGE_NT_HEADERS*)(b+((IMAGE_DOS_HEADER*)b)->e_lfanew);
 DWORD size=nt->OptionalHeader.SizeOfImage;
 auto d=(IMAGE_IMPORT_DESCRIPTOR*)(b+nt->OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT].VirtualAddress);
 auto expected=(ULONG_PTR)GetProcAddress(GetModuleHandleW(L"user32.dll"),"GetAsyncKeyState");
 for(;d->Name;++d){if(d->Name>=size)return -5;if(_stricmp((char*)b+d->Name,"user32.dll"))continue;
  if(d->FirstThunk>=size)return -11;
  auto a=(IMAGE_THUNK_DATA*)(b+d->FirstThunk);
  for(;((BYTE*)a+sizeof(*a)<=b+size)&&a->u1.Function;++a){
   if(a->u1.Function!=expected)continue;
   slot=(ULONG_PTR*)&a->u1.Function;
   if(MH_Initialize()!=MH_OK)return -20;
   if(MH_CreateHook((void*)expected,fakeAsync,(void**)&previous)!=MH_OK)return -21;
   ownWindow=GetActiveWindow();ownProc=(WNDPROC)GetWindowLongPtrW(ownWindow,GWLP_WNDPROC);
   if(MH_CreateHookApi(L"user32.dll","GetForegroundWindow",fakeForeground,0)!=MH_OK)return -23;
   return MH_EnableHook(MH_ALL_HOOKS)==MH_OK?1:-22;
  }
 }return 0;
}
extern "C" int WINAPI QA_Pressed(int v){pressed=v;return 1;}
extern "C" int WINAPI QA_Read(int k){return ((decltype(&GetAsyncKeyState))*slot)(k);}
// Invoke only the installed bridge callback; never send OS keyboard input.
extern "C" int WINAPI QA_Message(){
 auto proc=(WNDPROC)GetWindowLongPtrW(ownWindow,GWLP_WNDPROC);
 if(proc==ownProc)return 0;
 return proc(ownWindow,WM_KEYDOWN,VK_F12,1)==0?1:0;
}
extern "C" int WINAPI QA_WindowRestored(){return (WNDPROC)GetWindowLongPtrW(ownWindow,GWLP_WNDPROC)==ownProc?1:0;}
extern "C" int WINAPI QA_Restore(){
 pressed=0;MH_DisableHook(MH_ALL_HOOKS);return MH_Uninitialize()==MH_OK?1:0;
}
BOOL WINAPI DllMain(HINSTANCE,DWORD,LPVOID){return TRUE;}
