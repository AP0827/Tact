using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Windows.ApplicationModel.DataTransfer;

namespace TactWindows;

public sealed partial class MainWindow : Window
{
    private readonly HostApi _host = new();
    public MainWindow() { InitializeComponent(); Title = "Tact Host"; Activated += async (_, _) => await LoadAsync(); }
    private async Task LoadAsync() { try { var status = await _host.StatusAsync(); HostText.Text = $"{status.Host}:{status.Port}"; OtpText.Text = status.Otp; Approvals.ItemsSource = status.Approvals; Devices.ItemsSource = status.Devices; StatusText.Text = $"{status.Devices.Count(d => d.Active)} active · {status.Approvals.Count} waiting"; } catch (Exception error) { StatusText.Text = error.Message; } }
    private void CopyOtp(object sender, RoutedEventArgs e) { var package = new DataPackage(); package.SetText(OtpText.Text); Clipboard.SetContent(package); }
    private async void RegenerateOtp(object sender, RoutedEventArgs e) { await _host.RegenerateAsync(); await LoadAsync(); }
    private async void Refresh(object sender, RoutedEventArgs e) => await LoadAsync();
    private async void Approve(object sender, RoutedEventArgs e) { if (sender is Button { Tag: string id }) await _host.ApproveAsync(id); await LoadAsync(); }
    private async void Reject(object sender, RoutedEventArgs e) { if (sender is Button { Tag: string id }) await _host.RejectAsync(id); await LoadAsync(); }
    private async void Terminate(object sender, RoutedEventArgs e) { if (sender is Button { Tag: string id }) await _host.TerminateAsync(id); await LoadAsync(); }
    private async void TerminateAll(object sender, RoutedEventArgs e) { await _host.TerminateAllAsync(); await LoadAsync(); }
}
