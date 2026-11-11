namespace UrbanBusyWeighingSim;

internal sealed record Scenario(
    string Id,
    List<Segment> Segments,
    List<PlateAt> Plates,
    Expect Expect);

internal sealed record Segment(decimal Seconds, decimal Weight);

internal sealed record PlateAt(decimal T, string Plate);

internal sealed record Expect(ModeExpect Legacy, ModeExpect ResetOnly, ModeExpect Restart);

internal sealed record ModeExpect(
    int Pending,
    int InProgress,
    int BillCount,
    string FirstPlate,
    string FirstAnomaly,
    decimal FirstWeight,
    int EmptyCount,
    int SecondCount,
    decimal SecondWeight,
    string SecondFirstPlate);
