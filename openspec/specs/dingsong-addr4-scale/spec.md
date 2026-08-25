# dingsong-addr4-scale Specification

## Purpose

顶松Addr4（`ScaleType.DingSongAddr4`）秤型：枚举与设置可选性，以及 H610/H1320（`02 2A … 0D`）HEX 帧重量解析，且不改变既有顶松（`DingSong`）行为。

## Requirements

### Requirement: ScaleType DingSongAddr4 represents 顶松Addr4

`ScaleType` MUST include member `DingSongAddr4` with numeric value `4` and description text 「顶松Addr4」. Existing members (`Yaohua`, `DingSong`, `TestMode`, `PortableXPSY`) MUST keep their current values and meanings. Selecting `DingSongAddr4` MUST NOT alter behavior of `DingSong` (顶松).

#### Scenario: Enum value and description

- **WHEN** application code reads `ScaleType.DingSongAddr4`
- **THEN** the underlying integer value MUST be `4`
- **AND** `GetDescription()` (or equivalent) MUST yield 「顶松Addr4」

#### Scenario: Settings can select 顶松Addr4

- **WHEN** the operator opens scale settings and views available scale types
- **THEN** 「顶松Addr4」 MUST appear as a selectable option corresponding to `DingSongAddr4`

### Requirement: DingSongAddr4 HEX parse of H610 and H1320 frames

When `ScaleSettings.ScaleType` is `DingSongAddr4` and communication is HEX (e.g. `TF0`), `TruckScaleWeightService` MUST parse continuous frames of the form:

`0x02`, `0x2A` (`*`), prefix byte(s), space `0x20`, twelve ASCII digit bytes, `0x0D` (CR).

The weight in kilograms MUST be the integer parsed from the **first six** digit characters of that twelve-digit payload (no additional decimal scaling beyond existing `ConvertWeight` / `ScaleUnit`). Frames that do not match this layout MUST be discarded without updating weight.

#### Scenario: H610 frame yields 610 kg

- **GIVEN** scale type is `DingSongAddr4` and HEX receive is active
- **WHEN** a frame `02 2A 30 20 30 30 30 36 31 30 30 30 30 30 30 30 0D` is received (Hex **610 kg**, as in `_temp/H610.txt`)
- **THEN** the service MUST publish / store weight **610** (before unit conversion if unit is already kg)

#### Scenario: H1320 frame yields 1320 kg

- **GIVEN** scale type is `DingSongAddr4` and HEX receive is active
- **WHEN** a frame `02 2A 30 20 30 30 31 33 32 30 30 30 30 30 30 30 0D` is received (Hex **1320 kg**, same layout as `_temp/H1320.txt`)
- **THEN** the service MUST publish / store weight **1320** (before unit conversion if unit is already kg)

#### Scenario: DingSong still rejects the same frames

- **GIVEN** scale type is `DingSong`
- **WHEN** the same H610 or H1320 frame bytes are parsed by the DingSong HEX path
- **THEN** the parse MUST fail (null / no weight update)

#### Scenario: Incomplete or wrong terminator discarded

- **GIVEN** scale type is `DingSongAddr4`
- **WHEN** a buffer starts with `02 2A` but ends with `03` instead of `0D`, or has fewer than 17 bytes
- **THEN** the service MUST NOT treat it as a valid DingSongAddr4 weight update
