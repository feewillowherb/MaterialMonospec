using System.Globalization;
using System.Text.Json;
using UrbanStableUploadCacheReplay;

var options = SimOptions.Parse(args);
var fixture = await File.ReadAllTextAsync(options.FixturePath);
var scenarios = JsonSerializer.Deserialize<List<Scenario>>(fixture, JsonOpts())
    ?? throw new InvalidOperationException("fixture is empty");

var results = new List<ScenarioResult>();
foreach (var scenario in scenarios)
{
    var samples = ScenarioSampler.Expand(scenario);
    var bills = CacheReplay.Run(samples);
    results.Add(new ScenarioResult(scenario.Id, Match(scenario.Expect, bills), bills, scenario.Expect));
}

var failed = results.Where(r => !r.Ok).Select(r => r.Id).ToList();
var result = failed.Count == 0 ? "pass" : "fail";
Directory.CreateDirectory(options.RunDir);
await WriteEvidenceAsync(options, results, result);

Console.WriteLine($"result={result} scenarios={results.Count} failed={failed.Count}");
return result == "pass" ? 0 : 1;

static bool Match(ModeExpect expect, IReadOnlyList<Bill> bills)
{
    var pending = bills.Count(b => b.Sync == "Pending");
    if (pending != expect.Pending || bills.Count != expect.BillCount)
    {
        return false;
    }

    if (bills.Count == 0)
    {
        return expect.FirstPlate.Length == 0 && expect.FirstWeight == 0m;
    }

    var first = bills[0];
    if (first.Plate != expect.FirstPlate || first.Anomaly != expect.FirstAnomaly || first.Weight != expect.FirstWeight)
    {
        return false;
    }

    if (expect.SecondPlate.Length == 0)
    {
        return bills.Count == 1;
    }

    return bills.Count > 1 && bills[1].Plate == expect.SecondPlate && bills[1].Weight == expect.SecondWeight;
}

static async Task WriteEvidenceAsync(SimOptions options, IReadOnlyList<ScenarioResult> results, string result)
{
    var summary = new
    {
        result,
        levels = new { P0 = "pass", P1 = "pass", P2 = result, P3 = "not-judged" },
        scenarios = results.Select(r => new
        {
            r.Id,
            ok = r.Ok ? "pass" : "fail",
            bills = r.Bills.Select(b => new { b.Sync, b.Weight, b.Plate, b.Anomaly })
        })
    };

    await File.WriteAllTextAsync(
        Path.Combine(options.RunDir, "summary.json"),
        JsonSerializer.Serialize(summary, JsonOpts(true)));

    var report = new System.Text.StringBuilder();
    report.AppendLine("# urban-stable-upload-cache-replay");
    report.AppendLine();
    report.AppendLine($"结果：`{result}`。P0 运行时已启动。P1 场景都已重放。P2 与夹具预期{((result == "pass") ? "一致" : "不一致")}。P3 未判定。");
    report.AppendLine();
    report.AppendLine("这次 cook 不授权改产品，也不是产品通过。上传队列不在重放里。");
    report.AppendLine();
    report.AppendLine("| 场景 | 结果 |");
    report.AppendLine("|------|------|");
    foreach (var r in results)
    {
        report.AppendLine($"| {r.Id} | {(r.Ok ? "pass" : "fail")} {Describe(r.Bills)} |");
    }

    if (results.Any(r => !r.Ok))
    {
        report.AppendLine();
        report.AppendLine("不一致的场景：");
        foreach (var r in results.Where(r => !r.Ok))
        {
            report.AppendLine($"- {r.Id} expectCount={r.Expect.BillCount} actualCount={r.Bills.Count} expectFirst={r.Expect.FirstPlate} actualFirst={(r.Bills.Count == 0 ? "" : r.Bills[0].Plate)}");
        }
    }

    await File.WriteAllTextAsync(Path.Combine(options.RunDir, "report.md"), report.ToString());

    var manifest = string.Join(Environment.NewLine, new[]
    {
        "graphId: urban-stable-upload-cache-replay",
        "graphPath: pipelines/graphs/materialclient/urban-stable-upload-cache-replay",
        $"runId: {options.RunId}",
        $"result: {result}",
        $"gitRevision: \"{options.GitRevision}\"",
        "contractPath: pipelines/graphs/materialclient/urban-stable-upload-cache-replay/contract.yaml",
        "artifacts:",
        "  - summary.json",
        "  - report.md"
    });
    await File.WriteAllTextAsync(Path.Combine(options.RunDir, "manifest.yaml"), manifest + Environment.NewLine);
}

static string Describe(IReadOnlyList<Bill> bills)
{
    if (bills.Count == 0)
    {
        return "0 笔";
    }

    var parts = bills.Select(bill =>
    {
        var plate = bill.Plate.Length == 0 ? "空牌" : bill.Plate;
        return $"{bill.Weight.ToString(CultureInfo.InvariantCulture)} 吨 {plate}";
    });
    return $"{bills.Count} 笔 " + string.Join(" / ", parts);
}

static JsonSerializerOptions JsonOpts(bool indent = false) => new()
{
    PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
    PropertyNameCaseInsensitive = true,
    WriteIndented = indent
};

internal sealed record SimOptions(string RunDir, string RunId, string FixturePath, string GitRevision)
{
    public static SimOptions Parse(string[] args)
    {
        string runDir = "";
        string fixture = "";
        string git = "";
        for (var i = 0; i < args.Length; i++)
        {
            switch (args[i])
            {
                case "--run":
                    runDir = args[++i];
                    break;
                case "--fixture":
                    fixture = args[++i];
                    break;
                case "--git":
                    git = args[++i];
                    break;
            }
        }

        if (runDir.Length == 0 || fixture.Length == 0)
        {
            throw new InvalidOperationException("required: --run <dir> --fixture <scenarios.json>");
        }

        var runId = new DirectoryInfo(runDir).Name;
        return new SimOptions(runDir, runId, fixture, git);
    }
}

internal sealed record ScenarioResult(string Id, bool Ok, IReadOnlyList<Bill> Bills, ModeExpect Expect);
