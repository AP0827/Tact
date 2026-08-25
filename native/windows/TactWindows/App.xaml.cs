using Microsoft.UI.Xaml;

namespace TactWindows;

public partial class App : Application
{
    private MainWindow? _window;
    private PreferencesWindow? _preferences;
    private TrayIcon? _trayIcon;
    private bool _exiting;

    public App()
    {
        InitializeComponent();
    }

    protected override void OnLaunched(LaunchActivatedEventArgs args)
    {
        _window = new MainWindow();
        _window.AppWindow.Closing += (_, eventArgs) =>
        {
            if (_exiting) return;
            eventArgs.Cancel = true;
            _window.AppWindow.Hide();
        };
        _trayIcon = new TrayIcon(
            DispatcherQueue,
            ShowDashboard,
            ShowPreferences,
            ExitApplication
        );
    }

    private void ShowDashboard()
    {
        _window ??= new MainWindow();
        _window.Activate();
    }

    private void ShowPreferences()
    {
        _preferences ??= new PreferencesWindow();
        _preferences.Closed += (_, _) => _preferences = null;
        _preferences.Activate();
    }

    private void ExitApplication()
    {
        _exiting = true;
        _trayIcon?.Dispose();
        _preferences?.Close();
        _window?.Close();
        Exit();
    }
}
