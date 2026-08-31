using System.Text.Json;
using Microsoft.Data.Sqlite;

if (args.Length < 2)
{
    Console.Error.WriteLine("Usage: UpsertLicenseInfo <databasePath> <licenseJsonPath>");
    return 1;
}

var databasePath = Path.GetFullPath(args[0]);
var licenseJsonPath = Path.GetFullPath(args[1]);

if (!File.Exists(licenseJsonPath))
{
    Console.Error.WriteLine($"License JSON not found: {licenseJsonPath}");
    return 1;
}

using var document = JsonDocument.Parse(await File.ReadAllTextAsync(licenseJsonPath));
var root = document.RootElement;

var id = GetRequiredGuid(root, "id");
var projectId = GetRequiredGuid(root, "projectId");
var accessCode = GetOptionalString(root, "accessCode");
var authEndTime = GetRequiredDateTime(root, "authEndTime");
var proName = GetOptionalString(root, "proName");
var machineCode = GetRequiredString(root, "machineCode");
var latestJwtToken = GetOptionalString(root, "latestJwtToken");

var dbDirectory = Path.GetDirectoryName(databasePath);
if (!string.IsNullOrWhiteSpace(dbDirectory))
{
    Directory.CreateDirectory(dbDirectory);
}

var now = DateTime.UtcNow.ToString("yyyy-MM-dd HH:mm:ss.fffffff");

await using var connection = new SqliteConnection($"Data Source={databasePath}");
await connection.OpenAsync();

await using (var pragma = connection.CreateCommand())
{
    pragma.CommandText = "PRAGMA foreign_keys = OFF;";
    await pragma.ExecuteNonQueryAsync();
}

await using (var delete = connection.CreateCommand())
{
    delete.CommandText = "DELETE FROM LicenseInfo;";
    await delete.ExecuteNonQueryAsync();
}

await using (var insert = connection.CreateCommand())
{
    insert.CommandText = """
        INSERT INTO LicenseInfo (
            Id, ProjectId, AuthEndTime, MachineCode, AccessCode, ProName, LatestJwtToken,
            CreatedAt, UpdatedAt, CreatorId, LastModifierId
        ) VALUES (
            $id, $projectId, $authEndTime, $machineCode, $accessCode, $proName, $latestJwtToken,
            $createdAt, $updatedAt, NULL, NULL
        );
        """;
    insert.Parameters.AddWithValue("$id", id.ToString());
    insert.Parameters.AddWithValue("$projectId", projectId.ToString());
    insert.Parameters.AddWithValue("$authEndTime", authEndTime.ToString("yyyy-MM-dd HH:mm:ss.fffffff"));
    insert.Parameters.AddWithValue("$machineCode", machineCode);
    insert.Parameters.AddWithValue("$accessCode", (object?)accessCode ?? DBNull.Value);
    insert.Parameters.AddWithValue("$proName", (object?)proName ?? DBNull.Value);
    insert.Parameters.AddWithValue("$latestJwtToken", (object?)latestJwtToken ?? DBNull.Value);
    insert.Parameters.AddWithValue("$createdAt", now);
    insert.Parameters.AddWithValue("$updatedAt", now);
    await insert.ExecuteNonQueryAsync();
}

Console.WriteLine(
    $"LicenseInfo upserted: Id={id}, ProjectId={projectId}, AuthEndTime={authEndTime:yyyy-MM-dd HH:mm:ss}");
return 0;

static Guid GetRequiredGuid(JsonElement root, string name)
{
    if (!root.TryGetProperty(name, out var value) || !Guid.TryParse(value.GetString(), out var guid))
    {
        throw new InvalidOperationException($"Missing or invalid GUID field '{name}'.");
    }

    return guid;
}

static string GetRequiredString(JsonElement root, string name)
{
    if (!root.TryGetProperty(name, out var value))
    {
        throw new InvalidOperationException($"Missing string field '{name}'.");
    }

    var text = value.GetString();
    if (string.IsNullOrWhiteSpace(text))
    {
        throw new InvalidOperationException($"Field '{name}' must not be empty.");
    }

    return text.Trim();
}

static string? GetOptionalString(JsonElement root, string name)
{
    if (!root.TryGetProperty(name, out var value))
    {
        return null;
    }

    var text = value.GetString();
    return string.IsNullOrWhiteSpace(text) ? null : text.Trim();
}

static DateTime GetRequiredDateTime(JsonElement root, string name)
{
    if (!root.TryGetProperty(name, out var value))
    {
        throw new InvalidOperationException($"Missing datetime field '{name}'.");
    }

    var text = value.GetString();
    if (string.IsNullOrWhiteSpace(text) || !DateTime.TryParse(text, out var parsed))
    {
        throw new InvalidOperationException($"Missing or invalid datetime field '{name}'.");
    }

    return parsed;
}
