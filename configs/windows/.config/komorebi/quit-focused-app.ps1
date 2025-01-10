Add-Type @"
using System;
using System.Runtime.InteropServices;

public class User32 {
    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
}
"@

# Get the handle of the foreground window
$foregroundWindow = [User32]::GetForegroundWindow()

# Initialize the variable before using it as a [ref]
$processId = 0
[User32]::GetWindowThreadProcessId($foregroundWindow, [ref]$processId) > $null

# Check if a valid process ID was retrieved
if ($processId -ne 0) {
    # Stop the process associated with the foreground window
    Stop-Process -Id $processId -Force
} else {
    Write-Host "Failed to retrieve the process ID for the foreground window."
}
