using System.Diagnostics;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Data.Sqlite;

if (args.Length < 1)
{
    Console.Error.WriteLine("Usage: backup <source> <destination> | probe <db> <baseUrl> <runDir> <logRoot> <lockSeconds> <settleMs> <timeoutSeconds>");
    return 2;
}

try
{
    if (args[0] == "backup")
    {
        if (args.Length != 3) throw new ArgumentException("backup requires source and destination paths");
        await BackupAsync(args[1], args[2]);
        return 0;
    }

    if (args[0] == "probe")
    {
        if (args.Length != 8) throw new ArgumentException("probe requires db, baseUrl, runDir, logRoot, lockSeconds, settleMs and timeoutSeconds");
        var result = await ProbeAsync(args[1], args[2], args[3], args[4], int.Parse(args[5]), int.Parse(args[6]), int.Parse(args[7]));
        return result ? 0 : 1;
    }

    throw new ArgumentException($"Unknown command: {args[0]}");
}
catch (Exception exception)
{
    Console.Error.WriteLine(exception);
    return 3;
}

static async Task BackupAsync(string source, string destination)
{
    if (!File.Exists(source)) throw new FileNotFoundException("Seed database does not exist", source);
    if (File.Exists(destination)) throw new IOException("Refusing to overwrite an existing run database");
    Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(destination))!);
    var sourceBuilder = new SqliteConnectionStringBuilder { DataSource = Path.GetFullPath(source), Mode = SqliteOpenMode.ReadOnly };
    var targetBuilder = new SqliteConnectionStringBuilder { DataSource = Path.GetFullPath(destination), Mode = SqliteOpenMode.ReadWriteCreate };
    await using var sourceDb = new SqliteConnection(sourceBuilder.ToString());
    await using var targetDb = new SqliteConnection(targetBuilder.ToString());
    await sourceDb.OpenAsync();
    await targetDb.OpenAsync();
    sourceDb.BackupDatabase(targetDb);
    Console.WriteLine($"Created working database: {Path.GetFileName(destination)}");
}

static async Task<bool> ProbeAsync(string database, string baseUrl, string runDir, string logRoot, int lockSeconds, int settleMs, int timeoutSeconds)
{
    Directory.CreateDirectory(runDir);
    var runId = Path.GetFileName(runDir.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar));
    var plate = "FEV" + DateTimeOffset.UtcNow.ToUnixTimeMilliseconds().ToString("X");
    var httpEvidence = new List<object>();
    var logOffsets = CaptureLogOffsets(logRoot);
    var lockStarted = false;
    var lockReleased = false;
    var preCount = await CountAsync(database, plate);
    await WriteJsonAsync(Path.Combine(runDir, "db-before.json"), new { testPlate = plate, matchingRows = preCount });
    using var client = new HttpClient { BaseAddress = new Uri(baseUrl.TrimEnd('/') + "/"), Timeout = TimeSpan.FromSeconds(10) };

    await RecordRequestAsync(client, HttpMethod.Get, "", null, httpEvidence);
    await RecordRequestAsync(client, HttpMethod.Post, "api/scale/weight", new { weight = 0.3 }, httpEvidence);
    await Task.Delay(settleMs);

    var connectionBuilder = new SqliteConnectionStringBuilder { DataSource = Path.GetFullPath(database), Mode = SqliteOpenMode.ReadWrite, Pooling = false };
    await using var connection = new SqliteConnection(connectionBuilder.ToString());
    await connection.OpenAsync();
    await using var transaction = connection.BeginTransaction(deferred: false);
    await using (var command = connection.CreateCommand())
    {
        command.Transaction = transaction;
        command.CommandText = "CREATE TABLE IF NOT EXISTS __FevWriteLockProbe (Id INTEGER PRIMARY KEY, RunId TEXT NOT NULL)";
        await command.ExecuteNonQueryAsync();
        command.CommandText = "INSERT INTO __FevWriteLockProbe (RunId) VALUES ($runId)";
        command.Parameters.AddWithValue("$runId", runId);
        await command.ExecuteNonQueryAsync();
    }
    lockStarted = true;
    var lockEvidence = new { acquired = lockStarted, durationSeconds = lockSeconds, table = "__FevWriteLockProbe" };
    await WriteJsonAsync(Path.Combine(runDir, "lock.json"), lockEvidence);

    await RecordRequestAsync(client, HttpMethod.Post, "api/lpr/test-plate", new { plateNumber = plate, deviceName = "SQLiteWriteContentionFEV" }, httpEvidence);
    await RecordRequestAsync(client, HttpMethod.Post, "api/scale/weight", new { weight = 10.95 }, httpEvidence);
    await Task.Delay(TimeSpan.FromSeconds(lockSeconds));
    await transaction.RollbackAsync();
    lockReleased = true;

    var timer = Stopwatch.StartNew();
    while (timer.Elapsed < TimeSpan.FromSeconds(timeoutSeconds))
    {
        var logText = ReadLogDelta(logRoot, logOffsets);
        if (logText.Contains("Error occurred while creating weighing record for cycle", StringComparison.OrdinalIgnoreCase) &&
            logText.Contains("SQLite Error 5", StringComparison.OrdinalIgnoreCase)) break;
        await Task.Delay(1000);
    }

    var fullLog = ReadLogDelta(logRoot, logOffsets);
    var matched = fullLog.Contains("Error occurred while creating weighing record for cycle", StringComparison.OrdinalIgnoreCase) &&
                  fullLog.Contains("SQLite Error 5", StringComparison.OrdinalIgnoreCase);
    var postCount = await CountAsync(database, plate);
    await WriteJsonAsync(Path.Combine(runDir, "db-after.json"), new { testPlate = plate, matchingRows = postCount });
    await WriteJsonAsync(Path.Combine(runDir, "http.json"), httpEvidence);
    await File.WriteAllTextAsync(Path.Combine(runDir, "log-excerpt.txt"), ExtractRelevantLines(fullLog));

    var result = matched && postCount == preCount ? "pass" : "fail";
    var summary = new { graphId = "fev-sqlite-write-contention-repro", graphPath = "pipelines/graphs/materialclient/fev-sqlite-write-contention-repro", runId, result, fevVerdict = result == "pass" ? "FEASIBLE" : "INFEASIBLE", testPlate = plate, lockStarted, lockReleased, lockErrorObserved = matched, matchingRowsBefore = preCount, matchingRowsAfter = postCount };
    await WriteJsonAsync(Path.Combine(runDir, "summary.json"), summary);
    var revision = RunGitRevision();
    await File.WriteAllTextAsync(Path.Combine(runDir, "manifest.yaml"), $"graphId: fev-sqlite-write-contention-repro\ngraphPath: pipelines/graphs/materialclient/fev-sqlite-write-contention-repro\nrunId: {runId}\nresult: {result}\ngitRevision: {revision}\nevidence: [summary.json, http.json, lock.json, db-before.json, db-after.json, log-excerpt.txt]\n");
    await File.WriteAllTextAsync(Path.Combine(runDir, "report.md"), $"# SQLite contention FEV run\n\n- Run: `{runId}`\n- Result: `{result}`\n- FEV verdict: `{summary.fevVerdict}`\n- Test plate: `{plate}`\n- Lock acquired / released: `{lockStarted}` / `{lockReleased}`\n- Target lock error observed: `{matched}`\n- Matching rows before / after: `{preCount}` / `{postCount}`\n\nThis is synthetic external contention evidence only. It does not identify the production incident lock owner or validate a fix.\n");
    return result == "pass";
}

static async Task RecordRequestAsync(HttpClient client, HttpMethod method, string path, object? body, List<object> evidence)
{
    using var request = new HttpRequestMessage(method, path);
    if (body is not null) request.Content = JsonContent.Create(body);
    using var response = await client.SendAsync(request);
    var text = await response.Content.ReadAsStringAsync();
    evidence.Add(new { method = method.Method, path = "/" + path, status = (int)response.StatusCode, response = text });
    response.EnsureSuccessStatusCode();
}

static async Task<int> CountAsync(string database, string plate)
{
    var builder = new SqliteConnectionStringBuilder { DataSource = Path.GetFullPath(database), Mode = SqliteOpenMode.ReadOnly };
    await using var connection = new SqliteConnection(builder.ToString());
    await connection.OpenAsync();
    await using var command = connection.CreateCommand();
    command.CommandText = "SELECT COUNT(*) FROM WeighingRecords WHERE PlateNumber = $plate";
    command.Parameters.AddWithValue("$plate", plate);
    return Convert.ToInt32(await command.ExecuteScalarAsync());
}

static Dictionary<string, long> CaptureLogOffsets(string root)
{
    if (!Directory.Exists(root)) return new Dictionary<string, long>(StringComparer.OrdinalIgnoreCase);
    return Directory.EnumerateFiles(root, "*.log", SearchOption.AllDirectories)
        .ToDictionary(path => path, path => new FileInfo(path).Length, StringComparer.OrdinalIgnoreCase);
}

static string ReadLogDelta(string root, Dictionary<string, long> offsets)
{
    if (!Directory.Exists(root)) return "";
    var changes = new List<string>();
    foreach (var path in Directory.EnumerateFiles(root, "*.log", SearchOption.AllDirectories))
    {
        var start = offsets.TryGetValue(path, out var offset) ? offset : 0;
        using var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete);
        if (stream.Length < start) start = 0;
        stream.Seek(start, SeekOrigin.Begin);
        using var reader = new StreamReader(stream);
        changes.Add(reader.ReadToEnd());
    }
    return string.Join(Environment.NewLine, changes);
}

static string ExtractRelevantLines(string text) => string.Join(Environment.NewLine, text.Split('\n')
    .Where(line => line.Contains("creating weighing record for cycle", StringComparison.OrdinalIgnoreCase) || line.Contains("SQLite Error 5", StringComparison.OrdinalIgnoreCase)));

static async Task WriteJsonAsync(string path, object value) => await File.WriteAllTextAsync(path, JsonSerializer.Serialize(value, new JsonSerializerOptions { WriteIndented = true }));

static string RunGitRevision()
{
    try
    {
        using var process = Process.Start(new ProcessStartInfo("git", "rev-parse --short HEAD") { RedirectStandardOutput = true, UseShellExecute = false })!;
        var value = process.StandardOutput.ReadToEnd().Trim();
        process.WaitForExit(3000);
        return process.ExitCode == 0 ? value : "unknown";
    }
    catch { return "unknown"; }
}
