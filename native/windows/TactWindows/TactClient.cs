using System.Net.Http.Json;
using System.Net.WebSockets;
using System.Text;
using System.Text.Json;

namespace TactWindows;

public sealed record ConnectionChangedEventArgs(string State, string? Message = null);

public sealed class TactClient : IDisposable
{
    private readonly HttpClient _http = new() { Timeout = TimeSpan.FromSeconds(8) };
    private ClientWebSocket? _socket;
    private CancellationTokenSource? _lifetime;
    private string _host = string.Empty;
    private string _token = string.Empty;
    private bool _manualDisconnect = true;

    public event EventHandler<ConnectionChangedEventArgs>? ConnectionChanged;
    public event EventHandler<JsonElement>? SnapshotReceived;
    public event EventHandler<EventRow>? EventReceived;
    public event EventHandler<string>? Error;

    public async Task<string> PairAsync(string host, string otp, string deviceId)
    {
        host = CleanHost(host);
        using var response = await _http.PostAsJsonAsync(
            $"http://{host}:8000/api/pair/request",
            new { token = otp, device_id = deviceId, label = "Tact Windows" });
        if (!response.IsSuccessStatusCode)
        {
            throw new InvalidOperationException("The pairing code is invalid or expired.");
        }

        for (var attempt = 0; attempt < 60; attempt++)
        {
            await Task.Delay(1_000);
            using var status = await _http.GetAsync($"http://{host}:8000/api/pair/me?device_id={Uri.EscapeDataString(deviceId)}");
            if (!status.IsSuccessStatusCode) continue;
            using var document = JsonDocument.Parse(await status.Content.ReadAsStringAsync());
            if (document.RootElement.TryGetProperty("paired", out var paired) && paired.GetBoolean())
            {
                return deviceId;
            }
        }
        throw new TimeoutException("Pairing was not approved within one minute.");
    }

    public async Task ConnectAsync(string host, string token)
    {
        _host = CleanHost(host);
        _token = token;
        _manualDisconnect = false;
        _lifetime?.Cancel();
        _lifetime = new CancellationTokenSource();
        await OpenSocketAsync(_lifetime.Token);
    }

    private async Task OpenSocketAsync(CancellationToken cancellationToken)
    {
        ConnectionChanged?.Invoke(this, new("Connecting"));
        _socket?.Dispose();
        _socket = new ClientWebSocket();
        _socket.Options.KeepAliveInterval = TimeSpan.FromSeconds(20);
        try
        {
            await _socket.ConnectAsync(new Uri($"ws://{_host}:8000/ws"), cancellationToken);
            await SendAsync(new { type = "auth", token = _token, label = "Tact Windows" }, cancellationToken);
            _ = ReceiveLoopAsync(_socket, cancellationToken);
        }
        catch (Exception error) when (!cancellationToken.IsCancellationRequested)
        {
            ConnectionChanged?.Invoke(this, new("Reconnecting", error.Message));
            _ = ReconnectAsync(cancellationToken);
        }
    }

    private async Task ReceiveLoopAsync(ClientWebSocket socket, CancellationToken cancellationToken)
    {
        var buffer = new byte[64 * 1024];
        try
        {
            while (socket.State == WebSocketState.Open && !cancellationToken.IsCancellationRequested)
            {
                using var message = new MemoryStream();
                WebSocketReceiveResult result;
                do
                {
                    result = await socket.ReceiveAsync(new ArraySegment<byte>(buffer), cancellationToken);
                    if (result.MessageType == WebSocketMessageType.Close) throw new WebSocketException("Host closed the connection.");
                    message.Write(buffer, 0, result.Count);
                } while (!result.EndOfMessage);

                using var document = JsonDocument.Parse(message.ToArray());
                HandleMessage(document.RootElement);
            }
        }
        catch (Exception error) when (!cancellationToken.IsCancellationRequested && !_manualDisconnect)
        {
            ConnectionChanged?.Invoke(this, new("Reconnecting", error.Message));
            await ReconnectAsync(cancellationToken);
        }
    }

    private void HandleMessage(JsonElement root)
    {
        var type = root.String("type");
        switch (type)
        {
            case "init":
            case "telemetry":
                ConnectionChanged?.Invoke(this, new("Connected"));
                if (root.TryGetProperty("payload", out var payload)) SnapshotReceived?.Invoke(this, payload.Clone());
                break;
            case "event":
                if (root.TryGetProperty("payload", out var item))
                {
                    EventReceived?.Invoke(this, new(
                        item.String("title") ?? "Tact event",
                        item.String("description") ?? string.Empty));
                }
                break;
            case "error":
                Error?.Invoke(this, root.String("message") ?? "The host rejected the connection.");
                break;
            case "action_result":
                var result = root.Object("result");
                if (result.Boolean("ok") == false) Error?.Invoke(this, result.String("error") ?? "The action failed.");
                break;
        }
    }

    public Task SendActionAsync(string actionId, object? payload = null) => SendAsync(new
    {
        type = "action",
        action_id = actionId,
        request_id = Guid.NewGuid().ToString("N"),
        payload = payload ?? new { },
    }, _lifetime?.Token ?? CancellationToken.None);

    private async Task SendAsync(object payload, CancellationToken cancellationToken)
    {
        if (_socket?.State != WebSocketState.Open)
        {
            Error?.Invoke(this, "Connect to a host before using controls.");
            return;
        }
        var bytes = Encoding.UTF8.GetBytes(JsonSerializer.Serialize(payload));
        await _socket.SendAsync(bytes, WebSocketMessageType.Text, true, cancellationToken);
    }

    private async Task ReconnectAsync(CancellationToken cancellationToken)
    {
        for (var attempt = 0; attempt < 8 && !_manualDisconnect && !cancellationToken.IsCancellationRequested; attempt++)
        {
            await Task.Delay(Math.Min(500 * (1 << attempt), 8_000), cancellationToken);
            try
            {
                await OpenSocketAsync(cancellationToken);
                return;
            }
            catch when (!cancellationToken.IsCancellationRequested) { }
        }
    }

    public void Disconnect()
    {
        _manualDisconnect = true;
        _lifetime?.Cancel();
        _socket?.Abort();
        _socket?.Dispose();
        _socket = null;
        ConnectionChanged?.Invoke(this, new("Disconnected"));
    }

    public void Dispose()
    {
        Disconnect();
        _lifetime?.Dispose();
        _http.Dispose();
    }

    private static string CleanHost(string host) => host.Trim()
        .Replace("http://", string.Empty, StringComparison.OrdinalIgnoreCase)
        .Replace("https://", string.Empty, StringComparison.OrdinalIgnoreCase)
        .Split('/', ':')[0];
}
