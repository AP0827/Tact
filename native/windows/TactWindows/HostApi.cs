using System.Net.Http.Json;
using System.Text.Json;

namespace TactWindows;

public sealed record HostDevice(string Id, string Label, string LastSeen, bool Active);
public sealed record HostApproval(string Id, string DeviceId, string Label, string CreatedAt);
public sealed record HostStatus(string Host, int Port, string Otp, DateTimeOffset? Expires, IReadOnlyList<HostDevice> Devices, IReadOnlyList<HostApproval> Approvals);

public sealed class HostApi
{
    private readonly HttpClient _http = new() { BaseAddress = new Uri("http://127.0.0.1:8000"), Timeout = TimeSpan.FromSeconds(5) };
    public async Task<HostStatus> StatusAsync()
    {
        using var json = await _http.GetFromJsonAsync<JsonDocument>("/api/host/status") ?? throw new InvalidOperationException("The Tact agent is not running.");
        var root = json.RootElement;
        var devices = root.GetProperty("paired_devices").EnumerateArray().Select(item => new HostDevice(item.GetProperty("device_id").GetString() ?? "", item.GetProperty("label").GetString() ?? "Controller", item.TryGetProperty("last_seen", out var seen) && seen.ValueKind == JsonValueKind.String ? seen.GetString()! : "Never", item.TryGetProperty("active", out var active) && active.GetBoolean())).ToList();
        var approvals = root.GetProperty("pending_pairings").EnumerateArray().Select(item => new HostApproval(item.GetProperty("pending_id").GetString() ?? "", item.GetProperty("device_id").GetString() ?? "", item.GetProperty("label").GetString() ?? "New controller", item.TryGetProperty("created_at", out var created) ? created.GetString() ?? "" : "")).ToList();
        DateTimeOffset? expiry = null;
        if (root.TryGetProperty("pairing_token_expires", out var expires) && expires.TryGetDouble(out var seconds)) expiry = DateTimeOffset.FromUnixTimeSeconds((long)seconds);
        return new(root.GetProperty("host").GetString() ?? "127.0.0.1", root.GetProperty("port").GetInt32(), root.TryGetProperty("pairing_token", out var otp) && otp.ValueKind == JsonValueKind.String ? otp.GetString()! : "—", expiry, devices, approvals);
    }
    public Task RegenerateAsync() => PostAsync("/api/debug/regenerate-otp", null);
    public Task ApproveAsync(string id) => PostAsync("/api/pair/approve", new { pending_id = id });
    public Task RejectAsync(string id) => PostAsync("/api/pair/reject", new { pending_id = id });
    public Task TerminateAsync(string id) => PostAsync("/api/pair/reset", new { device_id = id });
    public Task TerminateAllAsync() => PostAsync("/api/pair/reset_all", null);
    private async Task PostAsync(string path, object? body) { using var response = await _http.PostAsJsonAsync(path, body ?? new { }); response.EnsureSuccessStatusCode(); }
}
