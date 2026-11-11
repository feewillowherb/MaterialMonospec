using System.Globalization;
using System.Text.Json;
using UrbanBusyWeighingSim;

var options = SimOptions.Parse(args);
var fixture = await File.ReadAllTextAsync(options.FixturePath);
var scenarios = JsonSerializer.Deserialize<List<Scenario>>(fixture, JsonOpts())
    ?? throw new InvalidOperationException("fixture is empty");

var results = new List<ScenarioResult>();
foreach (var scenario in scenarios)
{
    var samples = ScenarioSampler.Expand(scenario);
    var legacy = WeighingReplay.Run(samples, ReplayMode.Legacy);
    var resetOnly = WeighingReplay.Run(samples, ReplayMode.ResetOnly);
    var restart = WeighingReplay.Run(samples, ReplayMode.Restart);
    results.Add(new ScenarioResult(
        scenario.Id,
        Match(scenario.Expect.Legacy, legacy),
        Match(scenario.Expect.ResetOnly, resetOnly),
        Match(scenario.Expect.Restart, restart),
        legacy,
        resetOnly,
        restart,
        scenario.Expect));
}

var failed = results.Where(r => !r.LegacyOk || !r.ResetOnlyOk || !r.RestartOk).Select(r => r.Id).ToList();
var result = failed.Count == 0 ? "pass" : "fail";
Directory.CreateDirectory(options.RunDir);
await WriteEvidenceAsync(options, results, result);

Console.WriteLine($"result={result} scenarios={results.Count} failed={failed.Count}");
return result == "pass" ? 0 : 1;

static bool Match(ModeExpect expect, IReadOnlyList<Bill> bills)
{
    var pending = bills.Count(b => b.Sync == "Pending");
    var progress = bills.Count(b => b.Sync == "WeighingInProgress");
    if (pending != expect.Pending || progress != expect.InProgress || bills.Count != expect.BillCount)
    {
        return false;
    }

    if (expect.EmptyCount >= 0 && bills.Count(b => b.Plate.Length == 0) != expect.EmptyCount)
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

    if (expect.SecondCount <= 0)
    {
        return true;
    }

    var second = bills.Where(b => b.Weight == expect.SecondWeight).ToList();
    return second.Count == expect.SecondCount && second[0].Plate == expect.SecondFirstPlate;
}

static async Task WriteEvidenceAsync(SimOptions options, IReadOnlyList<ScenarioResult> results, string result)
{
    var summary = new
    {
        result,
        levels = new { P0 = "pass", P1 = "pass", P2 = result, P3 = "not-judged" },
        gate = "not-simulated",
        scenarios = results.Select(r => new
        {
            r.Id,
            legacy = r.LegacyOk ? "pass" : "fail",
            resetOnly = r.ResetOnlyOk ? "pass" : "fail",
            restart = r.RestartOk ? "pass" : "fail",
            legacyBills = r.Legacy.Select(BillView.From),
            resetOnlyBills = Summarize(r.ResetOnly),
            restartBills = Summarize(r.Restart)
        })
    };

    await File.WriteAllTextAsync(
        Path.Combine(options.RunDir, "summary.json"),
        JsonSerializer.Serialize(summary, JsonOpts(true)));

    var report = new System.Text.StringBuilder();
    report.AppendLine("# urban-busy-weighing-sim");
    report.AppendLine();
    report.AppendLine($"结果：`{result}`。P0 运行时已启动。P1 八个场景都已重放。P2 与夹具预期{((result == "pass") ? "一致" : "不一致")}。P3 未判定。");
    report.AppendLine();
    report.AppendLine("道闸未模拟。这次 cook 不授权打开开关，也不是产品通过。");
    report.AppendLine();
    report.AppendLine("| 场景 | 现行 | 只清周期 | 拉回空磅 |");
    report.AppendLine("|------|------|----------|----------|");
    foreach (var r in results)
    {
        report.AppendLine($"| {r.Id} | {Describe(r.Legacy)} | {Describe(r.ResetOnly)} | {Describe(r.Restart)} |");
    }

    report.AppendLine();
    report.AppendLine("只清周期是 `ResetCycle`：清记录和车牌缓存，状态留在已稳定。拉回空磅是同一笔上传之后把状态写成 `OffScale`，重量仍高于 0.5 吨。");
    report.AppendLine();
    var rise = results.First(r => r.Id == "B1");
    var dip = results.First(r => r.Id == "B1-dip");
    report.AppendLine($"B1 第二段脚本是 70 吨，拉回空磅的后段是 {Wave(rise.Restart, 70m)}。B1-dip 第二段脚本是 55 吨，后段是 {Wave(dip.Restart, 55m)}。只清周期两段都是 {Describe(rise.ResetOnly)} 与 {Describe(dip.ResetOnly)}。后段吨数跟着脚本走，不是拟合出来的现场合重。");
    if (results.Any(r => !r.LegacyOk || !r.ResetOnlyOk || !r.RestartOk))
    {
        report.AppendLine();
        report.AppendLine("不一致的场景：");
        foreach (var r in results.Where(r => !r.LegacyOk || !r.ResetOnlyOk || !r.RestartOk))
        {
            report.AppendLine($"- {r.Id} legacy={r.LegacyOk} resetOnly={r.ResetOnlyOk} restart={r.RestartOk} expectLegacy={r.Expect.Legacy.BillCount} actualLegacy={r.Legacy.Count} expectReset={r.Expect.ResetOnly.BillCount} actualReset={r.ResetOnly.Count} expectRestart={r.Expect.Restart.BillCount} actualRestart={r.Restart.Count}");
        }
    }

    await File.WriteAllTextAsync(Path.Combine(options.RunDir, "report.md"), report.ToString());

    var manifest = string.Join(Environment.NewLine, new[]
    {
        "graphId: urban-busy-weighing-sim",
        "graphPath: pipelines/graphs/materialclient/urban-busy-weighing-sim",
        $"runId: {options.RunId}",
        $"result: {result}",
        $"gitRevision: \"{options.GitRevision}\"",
        "contractPath: pipelines/graphs/materialclient/urban-busy-weighing-sim/contract.yaml",
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

    var first = bills[0];
    var plate = first.Plate.Length == 0 ? "空牌" : first.Plate;
    var sync = first.Sync == "Pending" ? "Pending" : "在磅";
    if (bills.Count == 1)
    {
        return $"1 笔 {sync} {first.Weight.ToString(CultureInfo.InvariantCulture)} 吨 {plate}";
    }

    return $"{bills.Count} 笔，首笔 {sync} {first.Weight.ToString(CultureInfo.InvariantCulture)} 吨 {plate}";
}

static string Wave(IReadOnlyList<Bill> bills, decimal weight)
{
    var wave = bills.Where(b => b.Weight == weight).ToList();
    if (wave.Count == 0)
    {
        return "0 笔";
    }

    var plate = wave[0].Plate.Length == 0 ? "空牌" : wave[0].Plate;
    return $"{wave.Count} 笔 {weight.ToString(CultureInfo.InvariantCulture)} 吨，首笔 {plate}";
}

static object Summarize(IReadOnlyList<Bill> bills) => new
{
    count = bills.Count,
    first = bills.Count == 0 ? null : BillView.From(bills[0]),
    weights = bills.Select(b => b.Weight).Distinct().ToList()
};

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

internal sealed record ScenarioResult(
    string Id,
    bool LegacyOk,
    bool ResetOnlyOk,
    bool RestartOk,
    IReadOnlyList<Bill> Legacy,
    IReadOnlyList<Bill> ResetOnly,
    IReadOnlyList<Bill> Restart,
    Expect Expect);

internal sealed record BillView(string Sync, decimal Weight, string Plate, string Anomaly)
{
    public static BillView From(Bill bill) => new(bill.Sync, bill.Weight, bill.Plate, bill.Anomaly);
}
