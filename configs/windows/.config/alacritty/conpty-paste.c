// conpty-paste.c
//
// Routes a Ctrl+Shift+V paste to the correct mechanism for the active app
// inside a Windows ConPTY pseudo-console.
//
// Problem: all processes attached to a ConPTY share one pseudo-console input
// buffer. Different apps read input in incompatible ways:
//
//   Some apps consume a byte stream and understand bracketed-paste VT
//   sequences (\e[200~...\e[201~). Shells and other VT or line-mode
//   readers fall in this group.
//
//   Some apps call ReadConsoleInput and receive Win32 KEY_EVENT records.
//   A bracketed-paste sequence then arrives as literal text, and a
//   terminal Paste action types each clipboard character. Where Enter
//   means submit, each pasted line is sent. Those apps need a real
//   Ctrl+Shift+V KEY_EVENT injected into the shared console buffer.
//
// ConPTY provides no API to query which input mode the foreground app uses.
// This helper fills that gap by probing console mode on attached clients:
//
//   1. Locate OpenConsole.exe, the ConPTY server process that is guaranteed
//      to exist for the lifetime of a ConPTY session. Prefer the instance
//      that is a direct child of the parent terminal, fall back to any.
//   2. Attach to it only to list processes on that console
//      (GetConsoleProcessList). Do not use the server's own GetConsoleMode.
//      The server often reports ENABLE_VIRTUAL_TERMINAL_INPUT even when a
//      client has put the shared console into a different mode.
//   3. Attach to each listed client and read that console's mode. If the
//      mode is raw KEY_EVENT input, inject Ctrl+Shift+V via
//      WriteConsoleInputW. If no listed client attaches, walk descendants
//      of the terminal and probe the same way (covers a launcher that has
//      already exited and left the TUI reparented).
//   4. Otherwise, fall back to a terminal-specific paste action. Here that
//      means tapping F24 (the terminal maps F24 to its Paste action).
//      Ctrl+Shift must be released first because they are still physically
//      held when this process fires, which would prevent an unmodified F24
//      binding from matching. They are restored afterwards so V auto-repeat
//      continues to fire as Ctrl+Shift+V, giving hold-to-repeat behaviour.
//
// Build:      gcc -mwindows -O2 -o conpty-paste.exe conpty-paste.c
// Install to: ~/.local/bin/conpty-paste.exe

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <tlhelp32.h>

#define MAX_PROCS 1024

// Append msg to %LOCALAPPDATA%\conpty-paste\conpty-paste-err.txt.
// Called only on hard Win32 failures that prevent the normal flow.
static void log_error(const char *msg) {
    char base[MAX_PATH];
    if (!GetEnvironmentVariableA("LOCALAPPDATA", base, MAX_PATH)) return;
    char dir[MAX_PATH], path[MAX_PATH];
    wsprintfA(dir,  "%s\\conpty-paste",                       base);
    wsprintfA(path, "%s\\conpty-paste\\conpty-paste-err.txt", base);
    CreateDirectoryA(dir, NULL);
    HANDLE h = CreateFileA(path, GENERIC_WRITE, 0, NULL,
                           OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (h == INVALID_HANDLE_VALUE) return;
    SetFilePointer(h, 0, NULL, FILE_END);
    DWORD w; WriteFile(h, msg, lstrlenA(msg), &w, NULL);
    CloseHandle(h);
}

// Build a keyboard INPUT record for the given virtual key and event flags.
static INPUT make_vk(USHORT vk, DWORD flags) {
    INPUT i = {0};
    i.type       = INPUT_KEYBOARD;
    i.ki.wVk     = vk;
    i.ki.dwFlags = flags;
    return i;
}

// Tap F24 as a terminal-specific signal for VT-mode paste
// (the terminal maps F24 to its built-in Paste action).
// Releases Ctrl and Shift before F24 so the key arrives without modifiers,
// then restores them so the next V auto-repeat fires as Ctrl+Shift+V
// and triggers another paste, giving correct hold-to-repeat behaviour.
static void tap_f24(void) {
    HWND hw = GetForegroundWindow();
    if (hw) SetForegroundWindow(hw);

    BOOL lc = (GetAsyncKeyState(VK_LCONTROL) & 0x8000) != 0;
    BOOL rc = (GetAsyncKeyState(VK_RCONTROL) & 0x8000) != 0;
    BOOL ls = (GetAsyncKeyState(VK_LSHIFT)   & 0x8000) != 0;
    BOOL rs = (GetAsyncKeyState(VK_RSHIFT)   & 0x8000) != 0;

    INPUT in[10]; // up to 4 releases + 2 F24 + 4 restores
    int n = 0;
    if (lc) in[n++] = make_vk(VK_LCONTROL, KEYEVENTF_KEYUP);
    if (rc) in[n++] = make_vk(VK_RCONTROL, KEYEVENTF_KEYUP);
    if (ls) in[n++] = make_vk(VK_LSHIFT,   KEYEVENTF_KEYUP);
    if (rs) in[n++] = make_vk(VK_RSHIFT,   KEYEVENTF_KEYUP);
    in[n++] = make_vk(VK_F24, 0);
    in[n++] = make_vk(VK_F24, KEYEVENTF_KEYUP);
    if (lc) in[n++] = make_vk(VK_LCONTROL, 0);
    if (rc) in[n++] = make_vk(VK_RCONTROL, 0);
    if (ls) in[n++] = make_vk(VK_LSHIFT,   0);
    if (rs) in[n++] = make_vk(VK_RSHIFT,   0);
    SendInput(n, in, sizeof(INPUT));
}

// Open the current console's input buffer with read+write access.
// Must be called after AttachConsole; GetStdHandle is invalid for GUI apps.
static HANDLE open_conin(void) {
    return CreateFileA("CONIN$",
                       GENERIC_READ | GENERIC_WRITE,
                       FILE_SHARE_READ | FILE_SHARE_WRITE,
                       NULL, OPEN_EXISTING, 0, NULL);
}

// Returns TRUE if the console expects VT byte-stream paste, FALSE if it
// expects raw KEY_EVENT injection.
//
// Byte-stream: pipe stdin, handles with no console mode, cooked-mode
// shells (ENABLE_PROCESSED_INPUT / ENABLE_LINE_INPUT / ENABLE_ECHO_INPUT),
// and consoles where the client enabled ENABLE_VIRTUAL_TERMINAL_INPUT
// (0x0200) so it reads VT sequences rather than KEY_EVENTs.
//
// KEY_EVENT (returns FALSE): the client cleared those flags, so a
// terminal Paste action would type each clipboard character. Where Enter
// means submit, each pasted line is sent.
static BOOL wants_byte_paste(HANDLE hIn) {
    if (!hIn || hIn == INVALID_HANDLE_VALUE) return TRUE;
    if (GetFileType(hIn) == FILE_TYPE_PIPE)  return TRUE;
    DWORD mode = 0;
    if (!GetConsoleMode(hIn, &mode)) return TRUE;
    if (mode & (ENABLE_PROCESSED_INPUT | ENABLE_LINE_INPUT | ENABLE_ECHO_INPUT)) return TRUE;
    if (mode & ENABLE_VIRTUAL_TERMINAL_INPUT) return TRUE;
    return FALSE;
}

// Inject a Ctrl+Shift+V KEY_EVENT pair into the console input buffer hIn.
// All processes sharing the ConPTY receive this record; only the one blocked
// on ReadConsoleInput consumes it, which is the active raw-console app.
static BOOL inject_ctrl_shift_v(HANDLE hIn) {
    INPUT_RECORD rec[2] = {0};
    rec[0].EventType                        = KEY_EVENT;
    rec[0].Event.KeyEvent.bKeyDown          = TRUE;
    rec[0].Event.KeyEvent.wRepeatCount      = 1;
    rec[0].Event.KeyEvent.wVirtualKeyCode   = 'V';
    rec[0].Event.KeyEvent.wVirtualScanCode  = 0x2F; // scan code for V
    rec[0].Event.KeyEvent.uChar.UnicodeChar = 0x16; // Ctrl+V character
    rec[0].Event.KeyEvent.dwControlKeyState = SHIFT_PRESSED | LEFT_CTRL_PRESSED;
    rec[1]                                  = rec[0];
    rec[1].Event.KeyEvent.bKeyDown          = FALSE;
    DWORD written = 0;
    return WriteConsoleInputW(hIn, rec, 2, &written) && written == 2;
}

// Attach to pid, and if that console wants KEY_EVENT paste, inject
// Ctrl+Shift+V. Always detaches. Returns TRUE only when injection ran.
static BOOL try_inject_from_pid(DWORD pid) {
    if (!AttachConsole(pid)) return FALSE;
    HANDLE hIn = open_conin();
    BOOL injected = FALSE;
    if (hIn && hIn != INVALID_HANDLE_VALUE && !wants_byte_paste(hIn))
        injected = inject_ctrl_shift_v(hIn);
    if (hIn && hIn != INVALID_HANDLE_VALUE) CloseHandle(hIn);
    FreeConsole();
    return injected;
}

static BOOL has_ancestor(DWORD pid, DWORD ancestor,
                         const DWORD *pids, const DWORD *parents, int nprocs) {
    for (int guard = 0; guard < nprocs; guard++) {
        if (pid == ancestor) return TRUE;
        int found = -1;
        for (int i = 0; i < nprocs; i++)
            if (pids[i] == pid) { found = i; break; }
        if (found < 0) return FALSE;
        DWORD p = parents[found];
        if (p == 0 || p == pid) return FALSE;
        pid = p;
    }
    return FALSE;
}

int WINAPI WinMain(HINSTANCE hi, HINSTANCE hp, LPSTR lp, int ns) {
    (void)hi; (void)hp; (void)lp; (void)ns;

    DWORD self = GetCurrentProcessId();

    // 1. Snapshot all running processes to build the parent-child map.
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) {
        char msg[64]; wsprintfA(msg, "snapshot err=%lu\n", GetLastError());
        log_error(msg); tap_f24(); return 0;
    }

    static DWORD pids[MAX_PROCS], parents[MAX_PROCS];
    static WCHAR names[MAX_PROCS][64];
    int nprocs = 0;
    PROCESSENTRY32W pe = { .dwSize = sizeof(pe) };
    if (Process32FirstW(snap, &pe)) {
        do {
            if (nprocs < MAX_PROCS) {
                pids[nprocs]    = pe.th32ProcessID;
                parents[nprocs] = pe.th32ParentProcessID;
                lstrcpynW(names[nprocs], pe.szExeFile, 64);
                nprocs++;
            }
        } while (Process32NextW(snap, &pe));
    }
    CloseHandle(snap);

    // 2. Identify the parent terminal's PID as the direct parent of this process.
    DWORD root = 0;
    for (int i = 0; i < nprocs; i++)
        if (pids[i] == self) { root = parents[i]; break; }

    if (!root) {
        char msg[64]; wsprintfA(msg, "self not in snapshot pid=%lu\n", self);
        log_error(msg); tap_f24(); return 0;
    }

    // 3. Find the ConPTY server (OpenConsole.exe). It is started by the terminal
    //    via conpty.dll and lives for the full session, so it is reliably present
    //    even after transient launcher processes (e.g. cmd.exe /c) have exited.
    //    Prefer the instance whose parent is the terminal; fall back to any found.
    DWORD server = 0, server_any = 0;
    for (int i = 0; i < nprocs; i++) {
        if (lstrcmpiW(names[i], L"OpenConsole.exe") != 0) continue;
        if (parents[i] == root) { server = pids[i]; break; }
        if (!server_any) server_any = pids[i];
    }
    if (!server) server = server_any;

    if (!server) {
        tap_f24(); return 0;
    }

    // 4. Attach to the ConPTY server only to list clients. Probe each
    //    client's console mode, never the server's. Skip the server, the
    //    terminal, and this helper.
    DWORD clients[256];
    DWORD nclients = 0;
    FreeConsole();
    if (AttachConsole(server)) {
        nclients = GetConsoleProcessList(clients, 256);
        if (nclients > 256) nclients = 0;
        FreeConsole();
    }
    for (DWORD i = 0; i < nclients; i++) {
        DWORD pid = clients[i];
        if (pid == self || pid == server || pid == root) continue;
        if (try_inject_from_pid(pid)) return 0;
    }

    // 5. If the server's process list had no usable client (launcher gone,
    //    attach failed), probe descendants of the terminal the same way.
    for (int i = 0; i < nprocs; i++) {
        DWORD pid = pids[i];
        if (pid == self || pid == server || pid == root) continue;
        if (!has_ancestor(pid, root, pids, parents, nprocs) &&
            !has_ancestor(pid, server, pids, parents, nprocs))
            continue;
        if (try_inject_from_pid(pid)) return 0;
    }

    // 6. VT or line-mode console: fall back to F24 tap for bracketed paste.
    tap_f24();
    return 0;
}
