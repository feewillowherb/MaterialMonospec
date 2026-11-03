#:package Microsoft.AspNetCore.SignalR.Client@10.0.14
#:property PublishAot=false
// Synthetic MaterialClient.Urban against the Phase 2 gateway: hub (WebSockets + SSE), UploadStatus,
// client-list, tus R9/R10, receive R2, approve (admin) + push, R3/R4, then waits for a push of a
// record approved inside um-ingest (backplane). Output: "@@ KEY=VALUE" lines only, no secrets.
// args: <baseUrl> <proId> <clientId> <buildLicenseNo> <backplaneWaitSeconds>
using System.Collections.Concurrent;
using System.Diagnostics;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Http.Connections;
using Microsoft.AspNetCore.SignalR.Client;

var baseUrl = args[0].TrimEnd('/');
var proId = Guid.Parse(args[1]);
var clientId = args[2];
var licenseNo = args[3];
var backplaneWait = TimeSpan.FromSeconds(int.Parse(args[4]));
const string Plate = "浙A12345";

void Mark(string key, object? value) => Console.WriteLine($"@@ {key}={value}");

var pushes = new ConcurrentDictionary<Guid, DateTime>();
var http = new HttpClient(new HttpClientHandler { UseProxy = false }) { BaseAddress = new Uri(baseUrl + "/"), Timeout = TimeSpan.FromSeconds(30) };
var json = new JsonSerializerOptions(JsonSerializerDefaults.Web);

async Task<bool> WaitFor(Func<bool> condition, TimeSpan timeout)
{
    var sw = Stopwatch.StartNew();
    while (sw.Elapsed < timeout)
    {
        if (condition()) return true;
        await Task.Delay(200);
    }
    return condition();
}

HubConnection Hub(HttpTransportType transport) => new HubConnectionBuilder()
    .WithUrl(baseUrl + "/hubs/devicestatus", o =>
    {
        o.Transports = transport;
        o.HttpMessageHandlerFactory = _ => new HttpClientHandler { UseProxy = false };
    })
    .Build();

var exit = 0;
try
{
    // Hub over WebSockets (primary client transport) — the connection that must receive pushes.
    var hub = Hub(HttpTransportType.WebSockets);
    string? hello = null;
    hub.On<string>("HelloResponse", m => hello = m);
    hub.On<JsonElement>("WeighingRecordApproved", p =>
    {
        if (p.TryGetProperty("clientRecordId", out var id) && id.TryGetGuid(out var g)) pushes[g] = DateTime.UtcNow;
    });
    await hub.StartAsync();
    Mark("HUB_WS_CONNECTED", hub.State == HubConnectionState.Connected);
    await hub.InvokeAsync("SayHello", "e2e");
    Mark("HUB_WS_HELLO", await WaitFor(() => hello != null, TimeSpan.FromSeconds(10)));

    // Fallback transport through the gateway (contract 02 §4: no buffering of SSE).
    var sse = Hub(HttpTransportType.ServerSentEvents);
    string? sseHello = null;
    sse.On<string>("HelloResponse", m => sseHello = m);
    await sse.StartAsync();
    await sse.InvokeAsync("SayHello", "e2e-sse");
    Mark("HUB_SSE_HELLO", await WaitFor(() => sseHello != null, TimeSpan.FromSeconds(10)));
    await sse.DisposeAsync();

    // UploadStatus joins group pro_{proId} and marks the client connected.
    await hub.InvokeAsync("UploadStatus", new
    {
        clientId, proId = proId.ToString(), proName = "E2E-PROBE", deviceType = "Scale", status = "Online", timestamp = DateTime.Now
    });
    var online = await WaitFor(() =>
    {
        var body = http.GetStringAsync($"api/app/device-status/client-list?Keyword={Uri.EscapeDataString(clientId)}&MaxResultCount=50").GetAwaiter().GetResult();
        return body.Contains(clientId) && body.Contains("\"isConnected\":true");
    }, TimeSpan.FromSeconds(15));
    Mark("CLIENT_LIST_ONLINE", online);

    // tus R9 (create / PATCH / HEAD) + R10 commit.
    var image = Convert.FromBase64String("/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=");
    string B64(string s) => Convert.ToBase64String(Encoding.UTF8.GetBytes(s));
    var create = new HttpRequestMessage(HttpMethod.Post, "api/urban-attachment/tus/") { Content = new ByteArrayContent([]) };
    create.Headers.Add("Tus-Resumable", "1.0.0");
    create.Headers.Add("Upload-Length", image.Length.ToString());
    create.Headers.Add("Upload-Metadata", $"filename {B64("e2e.jpg")},filetype {B64("image/jpeg")},buildlicenseno {B64(licenseNo)},attachtype {B64("6")}");
    var created = await http.SendAsync(create);
    // Resolve exactly like UrbanTusAttachmentClient: absolute as is, relative against the client's base address.
    var rawLocation = created.Headers.Location;
    var fileUrl = rawLocation is null ? null : rawLocation.IsAbsoluteUri ? rawLocation : new Uri(http.BaseAddress!, rawLocation);
    Mark("TUS_CREATE_HTTP", (int)created.StatusCode);
    Mark("TUS_LOCATION", rawLocation);
    Mark("TUS_LOCATION_EXTERNAL", fileUrl is not null
        && fileUrl.ToString().StartsWith(baseUrl + "/api/urban-attachment/tus/", StringComparison.OrdinalIgnoreCase));
    var fileId = fileUrl?.AbsolutePath.TrimEnd('/').Split('/').Last() ?? "";

    string Header(HttpResponseMessage r, string name) => r.Headers.TryGetValues(name, out var v) ? v.First() : "none";
    var head = new HttpRequestMessage(HttpMethod.Head, fileUrl);
    head.Headers.Add("Tus-Resumable", "1.0.0");
    var headed = await http.SendAsync(head);
    Mark("TUS_HEAD_HTTP", (int)headed.StatusCode);
    Mark("TUS_HEAD_OFFSET", Header(headed, "Upload-Offset"));

    var patch = new HttpRequestMessage(HttpMethod.Patch, fileUrl) { Content = new ByteArrayContent(image) };
    patch.Headers.Add("Tus-Resumable", "1.0.0");
    patch.Headers.Add("Upload-Offset", "0");
    patch.Content.Headers.ContentType = new("application/offset+octet-stream");
    var patched = await http.SendAsync(patch);
    Mark("TUS_PATCH_HTTP", (int)patched.StatusCode);
    Mark("TUS_PATCH_OFFSET_OK", Header(patched, "Upload-Offset") == image.Length.ToString());

    var commit = await http.PostAsJsonAsync("api/urban-attachment/tus/commit", new { fileIds = new[] { fileId } }, json);
    Mark("TUS_COMMIT_HTTP", (int)commit.StatusCode);
    var attachmentIds = new List<Guid>();
    if (commit.IsSuccessStatusCode)
    {
        var doc = await commit.Content.ReadFromJsonAsync<JsonElement>(json);
        if (doc.TryGetProperty("attachmentIds", out var ids))
            attachmentIds.AddRange(ids.EnumerateArray().Select(e => e.GetGuid()));
    }
    Mark("TUS_ATTACHMENT_IDS", attachmentIds.Count);

    async Task<Guid> Receive(string tag, List<Guid> attachments)
    {
        var clientRecordId = Guid.NewGuid();
        var resp = await http.PostAsJsonAsync("api/app/urban-weighing-record/receive", new
        {
            clientRecordId, plateNumber = Plate, totalWeight = 10.5m, weighingTime = DateTime.Now,
            buildLicenseNo = licenseNo, siteType = "Construction", proId, proName = "E2E-PROBE",
            submitMachineCode = clientId, isAnomaly = true, anomalyReason = "E2E", attachmentIds = attachments
        }, json);
        Mark($"R2_{tag}_HTTP", (int)resp.StatusCode);
        var body = await resp.Content.ReadAsStringAsync();
        Mark($"R2_{tag}_HAS_RECORD_ID", body.Contains("recordId", StringComparison.OrdinalIgnoreCase));
        return clientRecordId;
    }

    async Task<string> Pending() =>
        await http.GetStringAsync($"api/app/urban-weighing-record/pending-server-approval-sync?proId={proId}");

    // Record A: approval through the gateway (admin process) → push to this client.
    var recordA = await Receive("A", attachmentIds);
    Mark("RECORD_A", recordA);
    var approvedAt = DateTime.UtcNow;
    var approve = await http.PostAsJsonAsync("api/app/urban-weighing-record/approve",
        new { clientRecordId = recordA, plateNumber = Plate, totalWeight = 11m }, json);
    Mark("APPROVE_A_HTTP", (int)approve.StatusCode);
    Mark("PUSH_A_RECEIVED", await WaitFor(() => pushes.ContainsKey(recordA), TimeSpan.FromSeconds(15)));
    if (pushes.TryGetValue(recordA, out var tA)) Mark("PUSH_A_LATENCY_MS", (int)(tA - approvedAt).TotalMilliseconds);

    Mark("R3_CONTAINS_A", (await Pending()).Contains(recordA.ToString(), StringComparison.OrdinalIgnoreCase));
    var ack = await http.PostAsJsonAsync("api/app/urban-weighing-record/ack-approval-sync", new { clientRecordId = recordA }, json);
    Mark("R4_HTTP", (int)ack.StatusCode);
    Mark("R3_AFTER_ACK_CONTAINS_A", (await Pending()).Contains(recordA.ToString(), StringComparison.OrdinalIgnoreCase));

    // Record B: the orchestrator approves it inside um-ingest; only the Redis backplane can deliver the push here.
    var recordB = await Receive("B", []);
    Mark("AWAIT_INGEST_APPROVE", recordB);
    var waitStarted = DateTime.UtcNow;
    var gotB = await WaitFor(() => pushes.ContainsKey(recordB), backplaneWait);
    Mark("PUSH_B_RECEIVED", gotB);
    if (pushes.TryGetValue(recordB, out var tB)) Mark("PUSH_B_AFTER_WAIT_MS", (int)(tB - waitStarted).TotalMilliseconds);
    Mark("HUB_WS_STATE_END", hub.State);
    await hub.DisposeAsync();
}
catch (Exception ex)
{
    Mark("CLIENT_ERROR", ex.GetType().Name + ": " + ex.Message.Replace('\n', ' '));
    exit = 1;
}
Mark("CLIENT_DONE", "yes");
return exit;
