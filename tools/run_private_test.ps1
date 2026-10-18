param([Parameter(Mandatory=$true)][string]$Game, [int]$TimeoutSeconds = 45, [switch]$SteamProbe)
$testRoot = [IO.Path]::GetFullPath($Game)
$testExe = Join-Path $testRoot 'Game.exe'
if (-not (Test-Path -LiteralPath $testExe)) { throw 'Test executable missing' }
$preparedPath = Join-Path $testRoot 'test_prepare_profile.json'
if (-not (Test-Path -LiteralPath $preparedPath)) { throw 'Refusing unprepared game: silent test harness required' }
$prepared = Get-Content -LiteralPath $preparedPath -Raw | ConvertFrom-Json
$scriptsHash = (Get-FileHash -LiteralPath (Join-Path $testRoot 'Data\Scripts.rvdata2') -Algorithm SHA256).Hash.ToLowerInvariant()
$validSteamMode = $prepared.steam_disabled -or ($SteamProbe -and $prepared.steam_probe -eq 'screenshots_only' -and $prepared.synthetic_scene)
if (-not $prepared.silent -or -not $validSteamMode -or -not $prepared.test_harness -or $scriptsHash -ne $prepared.scripts_sha256) {
  throw 'Refusing unverified test harness'
}
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class BS2PrivateTest {
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
  struct STARTUPINFO {
    public uint cb; public string lpReserved,lpDesktop,lpTitle;
    public uint dwX,dwY,dwXSize,dwYSize,dwXCountChars,dwYCountChars,dwFillAttribute,dwFlags;
    public short wShowWindow,cbReserved2; public IntPtr lpReserved2,hStdInput,hStdOutput,hStdError;
  }
  [StructLayout(LayoutKind.Sequential)]
  struct PROCESS_INFORMATION { public IntPtr process,thread; public uint processId,threadId; }
  [DllImport("user32.dll",CharSet=CharSet.Unicode,SetLastError=true)]
  static extern IntPtr CreateDesktop(string name,IntPtr device,IntPtr mode,uint flags,uint access,IntPtr attributes);
  [DllImport("user32.dll",SetLastError=true)] static extern bool CloseDesktop(IntPtr desktop);
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)]
  static extern bool CreateProcess(string application,string commandLine,IntPtr pa,IntPtr ta,bool inherit,uint flags,IntPtr environment,string directory,ref STARTUPINFO startup,out PROCESS_INFORMATION process);
  [DllImport("kernel32.dll")] static extern uint WaitForSingleObject(IntPtr handle,uint milliseconds);
  [DllImport("kernel32.dll")] static extern bool GetExitCodeProcess(IntPtr handle,out uint code);
  [DllImport("kernel32.dll")] static extern bool TerminateProcess(IntPtr handle,uint code);
  [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);

  [StructLayout(LayoutKind.Sequential)]
  struct BASIC_LIMIT {public long processTime,jobTime;public uint flags;public UIntPtr minSet,maxSet;public uint active;public UIntPtr affinity;public uint priority,scheduling;}
  [StructLayout(LayoutKind.Sequential)]
  struct IO_COUNTERS {public ulong a,b,c,d,e,f;}
  [StructLayout(LayoutKind.Sequential)]
  struct EXT_LIMIT {public BASIC_LIMIT basic;public IO_COUNTERS io;public UIntPtr processMemory,jobMemory,peakProcessMemory,peakJobMemory;}
  [DllImport("kernel32.dll")] static extern uint SetErrorMode(uint mode);
  [DllImport("kernel32.dll")] static extern uint GetErrorMode();
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr CreateJobObject(IntPtr attributes,string name);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool SetInformationJobObject(IntPtr job,int kind,IntPtr data,uint size);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool AssignProcessToJobObject(IntPtr job,IntPtr process);
  [DllImport("kernel32.dll",SetLastError=true)] static extern uint ResumeThread(IntPtr thread);
  static IntPtr SilentJob() {
    IntPtr job=CreateJobObject(IntPtr.Zero,null);
    if(job==IntPtr.Zero)throw new Exception("Cannot create QA job: "+Marshal.GetLastWin32Error());
    EXT_LIMIT limits=new EXT_LIMIT();limits.basic.flags=0x2400;
    int size=Marshal.SizeOf(typeof(EXT_LIMIT));IntPtr memory=Marshal.AllocHGlobal(size);
    try {Marshal.StructureToPtr(limits,memory,false);if(!SetInformationJobObject(job,9,memory,(uint)size))throw new Exception("Cannot set QA job limits: "+Marshal.GetLastWin32Error());}
    catch {CloseHandle(job);throw;}
    finally {Marshal.FreeHGlobal(memory);}
    return job;
  }
  delegate bool EnumCallback(IntPtr hwnd,IntPtr data);
  [DllImport("user32.dll")] static extern bool EnumDesktopWindows(IntPtr desktop,EnumCallback callback,IntPtr data);
  [DllImport("user32.dll")] static extern bool EnumChildWindows(IntPtr parent,EnumCallback callback,IntPtr data);
  [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr hwnd,out uint pid);
  [DllImport("user32.dll",CharSet=CharSet.Unicode)] static extern int GetWindowText(IntPtr hwnd,System.Text.StringBuilder text,int length);
  static string OwnDialogs(IntPtr desktop,uint ownPid) {
    var text=new System.Text.StringBuilder();
    EnumDesktopWindows(desktop,delegate(IntPtr hwnd,IntPtr unused) {
      uint pid;GetWindowThreadProcessId(hwnd,out pid);if(pid!=ownPid)return true;
      var title=new System.Text.StringBuilder(1024);GetWindowText(hwnd,title,1024);text.AppendLine(title.ToString());
      EnumChildWindows(hwnd,delegate(IntPtr child,IntPtr ignore) {var line=new System.Text.StringBuilder(1024);GetWindowText(child,line,1024);text.AppendLine(line.ToString());return true;},IntPtr.Zero);
      return true;
    },IntPtr.Zero);return text.ToString();
  }
  public static string Run(string exe,string directory,int seconds) {
    string name="BS2QoLTest_"+Guid.NewGuid().ToString("N");
    IntPtr desktop=CreateDesktop(name,IntPtr.Zero,IntPtr.Zero,0,0x10000000,IntPtr.Zero);
    if(desktop==IntPtr.Zero) throw new Exception("Private desktop creation failed: "+Marshal.GetLastWin32Error());
    PROCESS_INFORMATION pi=new PROCESS_INFORMATION();
    IntPtr job=IntPtr.Zero;
    try {
      job=SilentJob();
      STARTUPINFO si=new STARTUPINFO(); si.cb=(uint)Marshal.SizeOf(typeof(STARTUPINFO));
      // The window is shown only on this separate, never switched-to desktop.
      // This permits native RGSS frame updates without exposing a foreground window.
      si.lpDesktop="winsta0\\"+name; si.dwFlags=1; si.wShowWindow=1;
      uint oldMode=SetErrorMode(GetErrorMode()|0x8003);
      try {
        if(!CreateProcess(exe,null,IntPtr.Zero,IntPtr.Zero,false,4,IntPtr.Zero,directory,ref si,out pi))
          throw new Exception("Private test process failed: "+Marshal.GetLastWin32Error());
      } finally {SetErrorMode(oldMode);}
      if(!AssignProcessToJobObject(job,pi.process)) {int error=Marshal.GetLastWin32Error();TerminateProcess(pi.process,125);throw new Exception("Cannot contain QA child: "+error);}
      if(ResumeThread(pi.thread)==0xffffffff)throw new Exception("Cannot resume QA child");
      uint wait=WaitForSingleObject(pi.process,(uint)(seconds*1000));
      if(wait==258) { System.IO.File.WriteAllText(System.IO.Path.Combine(directory,"own_qa_dialog.txt"),OwnDialogs(desktop,pi.processId)); TerminateProcess(pi.process,124); WaitForSingleObject(pi.process,5000); return "test_timeout=true; original_game_untouched=true"; }
      if(wait!=0)throw new Exception("Cannot wait for own QA child: "+Marshal.GetLastWin32Error());
      uint code;if(!GetExitCodeProcess(pi.process,out code))throw new Exception("Cannot read own QA exit code: "+Marshal.GetLastWin32Error());
      return "test_exit="+code+"; hex=0x"+code.ToString("X8")+"; pid="+pi.processId+"; private_desktop=true; dialogs_suppressed=true; exe="+exe;
    } finally {
      if(pi.thread!=IntPtr.Zero) CloseHandle(pi.thread);
      if(pi.process!=IntPtr.Zero) CloseHandle(pi.process);
      if(job!=IntPtr.Zero) CloseHandle(job);
      CloseDesktop(desktop);
    }
  }
}
'@
$execution = [BS2PrivateTest]::Run($testExe,$testRoot,$TimeoutSeconds)
Write-Output $execution
@{utc=[DateTime]::UtcNow.ToString('o');executable=$testExe;outcome=$execution;system_error_dialogs_isolated=$true} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $testRoot 'native_process_result.json') -Encoding utf8
if (Test-Path -LiteralPath (Join-Path $testRoot 'test_result.txt')) {
  $report = Get-Content -LiteralPath (Join-Path $testRoot 'test_result.txt') -Encoding utf8 -Raw
  Write-Output $report
}
if ($execution -notmatch '^test_exit=0;' -or $report -notmatch '(?m)^result=PASS;') { throw 'Native test did not complete successfully; see report' }
