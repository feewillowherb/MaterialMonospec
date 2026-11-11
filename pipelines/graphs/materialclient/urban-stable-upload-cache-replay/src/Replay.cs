namespace UrbanStableUploadCacheReplay;

internal enum ScaleStatus
{
    OffScale,
    Waiting,
    Stabilized,
    Departure
}

internal sealed record Bill(string Sync, decimal Weight, string Plate, string Anomaly);

internal sealed record Sample(decimal Time, decimal Weight, IReadOnlyList<string> Plates);

internal sealed record ProducedPlate(string Plate, decimal At);

internal static class ScenarioSampler
{
    public const decimal IntervalSeconds = 0.2m;

    public static IReadOnlyList<Sample> Expand(Scenario scenario)
    {
        var weights = new List<decimal>();
        foreach (var segment in scenario.Segments)
        {
            var count = (int)decimal.Round(segment.Seconds / IntervalSeconds, 0, MidpointRounding.AwayFromZero);
            for (var i = 0; i < count; i++)
            {
                weights.Add(segment.Weight);
            }
        }

        var plates = new List<string>[weights.Count];
        for (var i = 0; i < plates.Length; i++)
        {
            plates[i] = [];
        }

        foreach (var plate in scenario.Plates)
        {
            var index = (int)decimal.Floor(plate.T / IntervalSeconds);
            if (index < 0 || index >= plates.Length)
            {
                continue;
            }

            plates[index].Add(plate.Plate);
        }

        var samples = new List<Sample>(weights.Count);
        for (var i = 0; i < weights.Count; i++)
        {
            samples.Add(new Sample(i * IntervalSeconds, weights[i], plates[i]));
        }

        return samples;
    }
}

internal static class CacheReplay
{
    public const decimal MinWeight = 0.5m;
    public const decimal Band = 0.1m;
    public const int Periods = 15;
    public const decimal FallbackSeconds = 900m;

    public static IReadOnlyList<Bill> Run(IReadOnlyList<Sample> samples)
    {
        var window = new Queue<decimal>();
        var selection = new PlateCache();
        var bills = new List<Bill>();
        var status = ScaleStatus.OffScale;
        Bill? open = null;
        ProducedPlate? produced = null;

        foreach (var sample in samples)
        {
            foreach (var plate in sample.Plates)
            {
                selection.Add(plate);
            }

            window.Enqueue(sample.Weight);
            while (window.Count > Periods)
            {
                window.Dequeue();
            }

            var stable = Stability.Evaluate(window);
            if (produced is not null &&
                open is not null &&
                sample.Time - produced.At >= FallbackSeconds &&
                status != ScaleStatus.OffScale)
            {
                produced = null;
                open = null;
                if (status is ScaleStatus.Departure or ScaleStatus.Stabilized)
                {
                    status = ScaleStatus.Waiting;
                }
            }

            var previous = status;
            status = Step(status, sample.Weight, stable.IsStable, open != null);
            var enteredStable = previous != ScaleStatus.Stabilized && status == ScaleStatus.Stabilized;
            if (enteredStable && open == null && stable.IsStable && stable.Weight is { } weight)
            {
                var plate = selection.Pick() ?? "";
                var blocked = produced is not null &&
                    plate.Length > 0 &&
                    plate == produced.Plate &&
                    sample.Time - produced.At < FallbackSeconds;
                if (!blocked)
                {
                    var anomaly = plate.Length == 0 ? "EmptyPlate" : "";
                    open = new Bill("Pending", weight, plate, anomaly);
                    bills.Add(open);
                    produced = plate.Length == 0 ? null : new ProducedPlate(plate, sample.Time);
                }
            }
            else if (status == ScaleStatus.OffScale && open != null)
            {
                var plate = selection.Pick() ?? "";
                var current = bills[^1];
                if (plate.Length > 0)
                {
                    bills[^1] = current with { Plate = plate, Anomaly = "" };
                }

                selection.Clear();
                produced = null;
                open = null;
            }
        }

        return bills;
    }

    private static ScaleStatus Step(ScaleStatus status, decimal weight, bool stable, bool hasRecord)
    {
        if (hasRecord && weight > MinWeight && status is ScaleStatus.Stabilized or ScaleStatus.Departure or ScaleStatus.Waiting)
        {
            return ScaleStatus.Departure;
        }

        var next = status switch
        {
            ScaleStatus.OffScale when weight > MinWeight => ScaleStatus.Waiting,
            ScaleStatus.Waiting when weight < MinWeight => ScaleStatus.OffScale,
            ScaleStatus.Stabilized when weight < MinWeight => ScaleStatus.OffScale,
            ScaleStatus.Departure when weight < MinWeight => ScaleStatus.OffScale,
            _ => status
        };

        if (next == ScaleStatus.Waiting && stable && !hasRecord)
        {
            return ScaleStatus.Stabilized;
        }

        if (next == ScaleStatus.Stabilized && weight > MinWeight && hasRecord)
        {
            return ScaleStatus.Departure;
        }

        return next;
    }
}

internal static class Stability
{
    public static StabilityRead Evaluate(Queue<decimal> window)
    {
        if (window.Count != CacheReplay.Periods)
        {
            return StabilityRead.Unstable;
        }

        decimal min = decimal.MaxValue;
        decimal max = decimal.MinValue;
        foreach (var weight in window)
        {
            if (weight <= CacheReplay.MinWeight)
            {
                return StabilityRead.Unstable;
            }

            if (weight < min)
            {
                min = weight;
            }

            if (weight > max)
            {
                max = weight;
            }
        }

        if (max - min > CacheReplay.Band)
        {
            return StabilityRead.Unstable;
        }

        return new StabilityRead(true, (min + max) / 2m);
    }
}

internal readonly record struct StabilityRead(bool IsStable, decimal? Weight)
{
    public static StabilityRead Unstable => new(false, null);
}

internal sealed class PlateCache
{
    private readonly List<PlateSeen> _seen = [];

    public void Add(string plate)
    {
        if (string.IsNullOrWhiteSpace(plate))
        {
            return;
        }

        var index = _seen.FindIndex(item => item.Plate == plate);
        if (index < 0)
        {
            _seen.Add(new PlateSeen(plate, 1, _seen.Count));
            return;
        }

        var current = _seen[index];
        _seen[index] = current with { Count = current.Count + 1 };
    }

    public string? Pick()
    {
        if (_seen.Count == 0)
        {
            return null;
        }

        PlateSeen best = _seen[0];
        foreach (var item in _seen)
        {
            if (item.Count > best.Count || (item.Count == best.Count && item.FirstIndex < best.FirstIndex))
            {
                best = item;
            }
        }

        return best.Plate;
    }

    public void Clear() => _seen.Clear();
}

internal sealed record PlateSeen(string Plate, int Count, int FirstIndex);
