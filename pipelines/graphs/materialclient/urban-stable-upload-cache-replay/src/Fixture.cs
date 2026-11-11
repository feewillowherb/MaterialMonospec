namespace UrbanStableUploadCacheReplay;

internal sealed record Scenario(
    string Id,
    List<Segment> Segments,
    List<PlateAt> Plates,
    ModeExpect Expect);

internal sealed record Segment(decimal Seconds, decimal Weight);

internal sealed record PlateAt(decimal T, string Plate);

internal sealed record ModeExpect(
    int Pending,
    int BillCount,
    string FirstPlate,
    string FirstAnomaly,
    decimal FirstWeight,
    string SecondPlate,
    decimal SecondWeight);
