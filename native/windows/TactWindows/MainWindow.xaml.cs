using Microsoft.UI.Dispatching;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using System.Collections.ObjectModel;
using System.Text.Json;
using Windows.Storage;

namespace TactWindows;

public sealed partial class MainWindow : Window
{
    private readonly TactClient _client = new();
    private readonly ObservableCollection<ContainerRow> _containers = [];
    private readonly ObservableCollection<EventRow> _events = [];
    private readonly ApplicationDataContainer _settings = ApplicationData.Current.LocalSettings;

    public MainWindow()
    {
        InitializeComponent();
        Title = "Tact";
        DockerList.ItemsSource = _containers;
        EventsList.ItemsSource = _events;
        _client.ConnectionChanged += ClientConnectionChanged;
        _client.SnapshotReceived += ClientSnapshotReceived;
        _client.EventReceived += ClientEventReceived;
        _client.Error += ClientError;
        Closed += (_, _) => _client.Dispose();

        if (_settings.Values["host"] is string host &&
            _settings.Values["token"] is string token &&
            !string.IsNullOrWhiteSpace(host) &&
            !string.IsNullOrWhiteSpace(token))
        {
            ShowDashboard(host);
            _ = _client.ConnectAsync(host, token);
        }
    }

    private async void PairClicked(object sender, RoutedEventArgs e)
    {
        var host = HostInput.Text.Trim();
        var otp = OtpInput.Password.Trim();
        if (string.IsNullOrWhiteSpace(host) || otp.Length != 6)
        {
            ShowPairingNotice("Enter a host address and 6-digit pairing code.", InfoBarSeverity.Warning);
            return;
        }

        PairButton.IsEnabled = false;
        PairingProgress.Visibility = Visibility.Visible;
        ShowPairingNotice("Waiting for approval on the host…", InfoBarSeverity.Informational);
        try
        {
            var deviceId = _settings.Values["deviceId"] as string ?? Guid.NewGuid().ToString("N");
            _settings.Values["deviceId"] = deviceId;
            var token = await _client.PairAsync(host, otp, deviceId);
            _settings.Values["host"] = host;
            _settings.Values["token"] = token;
            ShowDashboard(host);
            await _client.ConnectAsync(host, token);
        }
        catch (Exception error)
        {
            ShowPairingNotice(error.Message, InfoBarSeverity.Error);
        }
        finally
        {
            PairButton.IsEnabled = true;
            PairingProgress.Visibility = Visibility.Collapsed;
        }
    }

    private void ShowDashboard(string host)
    {
        PairingView.Visibility = Visibility.Collapsed;
        DashboardView.Visibility = Visibility.Visible;
        HostLabel.Text = host;
        SettingsHost.Text = host;
        SystemHostName.Text = host;
        SubtitleLabel.Text = $"{host} is connecting…";
        if (Nav.MenuItems.FirstOrDefault() is NavigationViewItem first)
        {
            Nav.SelectedItem = first;
        }
    }

    private void NavChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        var page = args.IsSettingsSelected
            ? "Settings"
            : (args.SelectedItem as NavigationViewItem)?.Tag?.ToString() ?? "System";
        SystemPage.Visibility = page == "System" ? Visibility.Visible : Visibility.Collapsed;
        DeveloperPage.Visibility = page == "Developer" ? Visibility.Visible : Visibility.Collapsed;
        MediaPage.Visibility = page == "Media" ? Visibility.Visible : Visibility.Collapsed;
        EventsPage.Visibility = page == "Events" ? Visibility.Visible : Visibility.Collapsed;
        DeckPage.Visibility = page == "Deck" ? Visibility.Visible : Visibility.Collapsed;
        SettingsPage.Visibility = page == "Settings" ? Visibility.Visible : Visibility.Collapsed;
    }

    private async void ActionClicked(object sender, RoutedEventArgs e)
    {
        if (sender is Button { Tag: string actionId })
        {
            await _client.SendActionAsync(actionId);
        }
    }

    private async void LockClicked(object sender, RoutedEventArgs e) =>
        await _client.SendActionAsync("system.lock_screen");

    private void DisconnectClicked(object sender, RoutedEventArgs e)
    {
        _client.Disconnect();
        _settings.Values.Remove("host");
        _settings.Values.Remove("token");
        DashboardView.Visibility = Visibility.Collapsed;
        PairingView.Visibility = Visibility.Visible;
        OtpInput.Password = string.Empty;
    }

    private void ClientConnectionChanged(object? sender, ConnectionChangedEventArgs e) =>
        DispatcherQueue.TryEnqueue(() =>
        {
            ConnectionLabel.Text = e.State;
            SubtitleLabel.Text = e.State == "Connected"
                ? $"{HostLabel.Text} is connected and ready."
                : e.Message ?? e.State;
        });

    private void ClientSnapshotReceived(object? sender, JsonElement snapshot) =>
        DispatcherQueue.TryEnqueue(() => ApplySnapshot(snapshot));

    private void ClientEventReceived(object? sender, EventRow item) =>
        DispatcherQueue.TryEnqueue(() =>
        {
            _events.Insert(0, item);
            while (_events.Count > 100) _events.RemoveAt(_events.Count - 1);
        });

    private void ClientError(object? sender, string message) =>
        DispatcherQueue.TryEnqueue(() => SubtitleLabel.Text = message);

    private void ApplySnapshot(JsonElement root)
    {
        var system = root.Object("system");
        SetMetric(CpuValue, CpuProgress, system.Number("cpu"));
        SetMetric(MemoryValue, MemoryProgress, system.Number("memory"));
        SetMetric(DiskValue, DiskProgress, system.Number("disk"));
        var battery = system.Object("battery").Number("percent") ?? system.Number("battery");
        SetMetric(BatteryValue, BatteryProgress, battery);

        var git = root.Object("git");
        if (git.ValueKind != JsonValueKind.Object)
        {
            git = root.Object("workspace").Object("git");
        }
        BranchValue.Text = git.String("branch") ?? "No repository";
        var changed = git.Integer("changed_files") ?? 0;
        GitStatusValue.Text = git.Boolean("clean") == true
            ? "Working tree clean"
            : $"{changed} changed files · ↑{git.Integer("ahead") ?? 0} ↓{git.Integer("behind") ?? 0}";

        _containers.Clear();
        var docker = root.Object("docker");
        if (docker.TryGetProperty("containers", out var containers) && containers.ValueKind == JsonValueKind.Array)
        {
            foreach (var container in containers.EnumerateArray())
            {
                _containers.Add(new ContainerRow(
                    container.String("name") ?? "Container",
                    $"{container.String("image")} · {container.String("status")}"));
            }
        }

        var active = root.Object("media").Object("active");
        TrackTitle.Text = active.String("title") ?? "Nothing playing";
        TrackArtist.Text = active.String("artist") ?? string.Empty;
    }

    private static void SetMetric(TextBlock label, ProgressBar progress, double? value)
    {
        label.Text = value is null ? "—" : $"{Math.Round(value.Value)}%";
        progress.Value = Math.Clamp(value ?? 0, 0, 100);
    }

    private void ShowPairingNotice(string message, InfoBarSeverity severity)
    {
        PairingNotice.Message = message;
        PairingNotice.Severity = severity;
        PairingNotice.IsOpen = true;
    }
}

public sealed record ContainerRow(string Name, string Detail);
public sealed record EventRow(string Title, string Description);

internal static class JsonExtensions
{
    public static JsonElement Object(this JsonElement element, string name) =>
        element.ValueKind == JsonValueKind.Object && element.TryGetProperty(name, out var value)
            ? value
            : default;

    public static string? String(this JsonElement element, string name) =>
        element.ValueKind == JsonValueKind.Object && element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String
            ? value.GetString()
            : null;

    public static double? Number(this JsonElement element, string name) =>
        element.ValueKind == JsonValueKind.Object && element.TryGetProperty(name, out var value) && value.TryGetDouble(out var number)
            ? number
            : null;

    public static int? Integer(this JsonElement element, string name) =>
        element.ValueKind == JsonValueKind.Object && element.TryGetProperty(name, out var value) && value.TryGetInt32(out var number)
            ? number
            : null;

    public static bool? Boolean(this JsonElement element, string name) =>
        element.ValueKind == JsonValueKind.Object && element.TryGetProperty(name, out var value) && value.ValueKind is JsonValueKind.True or JsonValueKind.False
            ? value.GetBoolean()
            : null;
}
