using Microsoft.UI.Dispatching;
using System.Runtime.InteropServices;

namespace TactWindows;

internal sealed class TrayIcon : IDisposable
{
    private const uint CallbackMessage = 0x8001;
    private const uint WmCommand = 0x0111;
    private const uint WmLeftButtonUp = 0x0202;
    private const uint WmRightButtonUp = 0x0205;
    private const uint NimAdd = 0x00000000;
    private const uint NimDelete = 0x00000002;
    private const uint NifMessage = 0x00000001;
    private const uint NifIcon = 0x00000002;
    private const uint NifTip = 0x00000004;
    private const uint TpmReturnCommand = 0x0100;
    private const uint TpmRightButton = 0x0002;
    private const uint MfString = 0x0000;
    private const uint MfSeparator = 0x0800;
    private const uint OpenCommand = 1001;
    private const uint PreferencesCommand = 1002;
    private const uint ExitCommand = 1003;

    private readonly DispatcherQueue _dispatcher;
    private readonly Action _showDashboard;
    private readonly Action _showPreferences;
    private readonly Action _exit;
    private readonly WindowProcedure _windowProcedure;
    private readonly string _className = $"TactTray-{Guid.NewGuid():N}";
    private readonly IntPtr _instance;
    private IntPtr _window;
    private NotifyIconData _iconData;

    public TrayIcon(
        DispatcherQueue dispatcher,
        Action showDashboard,
        Action showPreferences,
        Action exit)
    {
        _dispatcher = dispatcher;
        _showDashboard = showDashboard;
        _showPreferences = showPreferences;
        _exit = exit;
        _windowProcedure = WindowCallback;
        _instance = GetModuleHandle(null);

        var windowClass = new WindowClass
        {
            Size = (uint)Marshal.SizeOf<WindowClass>(),
            Instance = _instance,
            WindowProcedure = _windowProcedure,
            ClassName = _className,
        };
        if (RegisterClassEx(ref windowClass) == 0)
            throw new InvalidOperationException("Could not register the Tact notification-area window.");

        _window = CreateWindowEx(
            0, _className, "Tact", 0, 0, 0, 0, 0,
            new IntPtr(-3), IntPtr.Zero, _instance, IntPtr.Zero);
        if (_window == IntPtr.Zero)
            throw new InvalidOperationException("Could not create the Tact notification-area window.");

        _iconData = new NotifyIconData
        {
            Size = (uint)Marshal.SizeOf<NotifyIconData>(),
            Window = _window,
            Id = 1,
            Flags = NifMessage | NifIcon | NifTip,
            CallbackMessage = CallbackMessage,
            Icon = LoadIcon(IntPtr.Zero, new IntPtr(32512)),
            Tip = "Tact",
        };
        if (!ShellNotifyIcon(NimAdd, ref _iconData))
            throw new InvalidOperationException("Could not add Tact to the notification area.");
    }

    private IntPtr WindowCallback(IntPtr window, uint message, IntPtr wParam, IntPtr lParam)
    {
        if (message == CallbackMessage)
        {
            var mouseMessage = unchecked((uint)lParam.ToInt64());
            if (mouseMessage == WmLeftButtonUp)
                _dispatcher.TryEnqueue(() => _showDashboard());
            else if (mouseMessage == WmRightButtonUp)
                ShowContextMenu();
            return IntPtr.Zero;
        }
        if (message == WmCommand)
        {
            DispatchCommand(unchecked((uint)wParam.ToInt64()) & 0xffff);
            return IntPtr.Zero;
        }
        return DefWindowProc(window, message, wParam, lParam);
    }

    private void ShowContextMenu()
    {
        var menu = CreatePopupMenu();
        AppendMenu(menu, MfString, OpenCommand, "Open Tact");
        AppendMenu(menu, MfString, PreferencesCommand, "Preferences…");
        AppendMenu(menu, MfSeparator, 0, string.Empty);
        AppendMenu(menu, MfString, ExitCommand, "Quit Tact");
        GetCursorPos(out var point);
        SetForegroundWindow(_window);
        var command = TrackPopupMenu(
            menu,
            TpmReturnCommand | TpmRightButton,
            point.X,
            point.Y,
            0,
            _window,
            IntPtr.Zero);
        DestroyMenu(menu);
        if (command != 0) DispatchCommand(command);
    }

    private void DispatchCommand(uint command) => _dispatcher.TryEnqueue(() =>
    {
        switch (command)
        {
            case OpenCommand: _showDashboard(); break;
            case PreferencesCommand: _showPreferences(); break;
            case ExitCommand: _exit(); break;
        }
    });

    public void Dispose()
    {
        if (_window == IntPtr.Zero) return;
        ShellNotifyIcon(NimDelete, ref _iconData);
        DestroyWindow(_window);
        UnregisterClass(_className, _instance);
        _window = IntPtr.Zero;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct WindowClass
    {
        public uint Size;
        public uint Style;
        [MarshalAs(UnmanagedType.FunctionPtr)] public WindowProcedure WindowProcedure;
        public int ClassExtra;
        public int WindowExtra;
        public IntPtr Instance;
        public IntPtr Icon;
        public IntPtr Cursor;
        public IntPtr Background;
        public string? MenuName;
        public string ClassName;
        public IntPtr SmallIcon;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct NotifyIconData
    {
        public uint Size;
        public IntPtr Window;
        public uint Id;
        public uint Flags;
        public uint CallbackMessage;
        public IntPtr Icon;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string Tip;
        public uint State;
        public uint StateMask;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 256)] public string Info;
        public uint TimeoutOrVersion;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 64)] public string InfoTitle;
        public uint InfoFlags;
        public Guid Item;
        public IntPtr BalloonIcon;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct Point { public int X; public int Y; }
    private delegate IntPtr WindowProcedure(IntPtr window, uint message, IntPtr wParam, IntPtr lParam);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)] private static extern IntPtr GetModuleHandle(string? name);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern ushort RegisterClassEx(ref WindowClass windowClass);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern bool UnregisterClass(string className, IntPtr instance);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern IntPtr CreateWindowEx(uint exStyle, string className, string name, uint style, int x, int y, int width, int height, IntPtr parent, IntPtr menu, IntPtr instance, IntPtr parameter);
    [DllImport("user32.dll")] private static extern bool DestroyWindow(IntPtr window);
    [DllImport("user32.dll")] private static extern IntPtr DefWindowProc(IntPtr window, uint message, IntPtr wParam, IntPtr lParam);
    [DllImport("user32.dll")] private static extern IntPtr LoadIcon(IntPtr instance, IntPtr iconName);
    [DllImport("shell32.dll", EntryPoint = "Shell_NotifyIconW", CharSet = CharSet.Unicode)] private static extern bool ShellNotifyIcon(uint message, ref NotifyIconData data);
    [DllImport("user32.dll")] private static extern IntPtr CreatePopupMenu();
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern bool AppendMenu(IntPtr menu, uint flags, uint id, string text);
    [DllImport("user32.dll")] private static extern uint TrackPopupMenu(IntPtr menu, uint flags, int x, int y, int reserved, IntPtr window, IntPtr rectangle);
    [DllImport("user32.dll")] private static extern bool DestroyMenu(IntPtr menu);
    [DllImport("user32.dll")] private static extern bool GetCursorPos(out Point point);
    [DllImport("user32.dll")] private static extern bool SetForegroundWindow(IntPtr window);
}
