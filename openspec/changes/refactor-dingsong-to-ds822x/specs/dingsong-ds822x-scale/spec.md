## ADDED Requirements

### Requirement: DingSong HEX parses DS822-X Adr=1 weight frames

When `ScaleSettings.ScaleType` is `DingSong` and communication is HEX (e.g. `TF0`), `TruckScaleWeightService` MUST accept continuous frames of the form:

`0x02`, address `A`–`Z`, command `A` or `a`, sign `+`/`-`, six ASCII weight digits, one ASCII decimal-places digit, six ASCII tare digits, one error byte, two status bytes, one checksum byte, `0x03`.

The checksum MUST equal `(XOR of all bytes before the checksum) | 0x40`. Frames that fail framing or checksum MUST NOT update weight.

The published weight MUST be the signed net-weight integer divided by `10^p`, where `p` is the decimal-places digit (0–4). Tare and status bytes MUST NOT be published on `WeightUpdates`.

#### Scenario: Valid Adr=1 frame publishes net weight

- **GIVEN** scale type is `DingSong` and HEX receive is active
- **WHEN** a 22-byte frame with command `A` or `a`, valid sign, digits, `p` in 0–4, and correct `CHK` is received
- **THEN** the service MUST publish the net weight with decimal scaling applied

#### Scenario: Adr=1 bad checksum discarded

- **GIVEN** scale type is `DingSong`
- **WHEN** an otherwise well-formed 22-byte `A`/`a` frame has an incorrect checksum
- **THEN** the service MUST NOT update weight from that frame

### Requirement: DingSong HEX parses DS822-X Adr=3 display frames

When `ScaleSettings.ScaleType` is `DingSong` and communication is HEX, the service MUST accept continuous frames of the form:

`0x02`, address `A`–`Z`, command `C` or `c`, twelve payload bytes, checksum, `0x03`, with the same checksum rule as Adr=1.

The twelve payload bytes MUST be treated as six pairs `(hi, lo)`. For each pair, if `hi` is an ASCII digit `0`–`9`, that digit is a display digit; otherwise the position is blank. The published weight MUST be the integer formed by the display digits in order (leading blanks ignored), with **zero** decimal places. The `lo` bytes MUST NOT be required to equal ASCII `0`–`3`.

#### Scenario: Field C-frame from text.txt yields 8

- **GIVEN** scale type is `DingSong` and HEX receive is active
- **WHEN** the frame `02 41 63 30 20 30 20 30 20 30 20 38 20 3C 30 74 03` is received (as in `_tmp/text.txt`)
- **THEN** the service MUST publish weight **8**

#### Scenario: Adr=3 bad checksum discarded

- **GIVEN** scale type is `DingSong`
- **WHEN** a 17-byte `C`/`c` frame has an incorrect checksum
- **THEN** the service MUST NOT update weight from that frame

### Requirement: DingSong auto-selects Adr=1 vs Adr=3 by command letter

The DingSong HEX receiver MUST inspect the command byte after the address and parse as Adr=1 when the command is `A` or `a`, and as Adr=3 when the command is `C` or `c`. Incomplete frames MUST be held in a sticky buffer until a full candidate length is available; non-matching bytes MUST be skipped without updating weight.

#### Scenario: Mixed stream of C then A

- **GIVEN** scale type is `DingSong` and HEX receive is active
- **WHEN** a valid `C` frame and a valid `A` frame arrive in the same sticky buffer
- **THEN** the service MUST publish the `C` weight first and the `A` net weight second

### Requirement: Legacy twelve-byte DingSong frames are rejected

When `ScaleType` is `DingSong`, frames matching the former twelve-byte layout `0x02`, `+`/`-`, eight ASCII digits, one marker byte, `0x03` (without DS822-X address and command letters) MUST NOT update weight.

#### Scenario: Old twelve-byte sample returns null

- **GIVEN** scale type is `DingSong`
- **WHEN** a legacy frame such as `02 2B 30 30 31 30 30 30 30 30 42 03` is parsed by the DingSong HEX path
- **THEN** the parse MUST fail (null / no weight update)

### Requirement: DingSongAddr4 behavior unchanged

`ScaleType.DingSongAddr4` MUST continue to parse `02 2A … 0D` frames as specified by `dingsong-addr4-scale`. Selecting or implementing DS822-X for `DingSong` MUST NOT change Addr4 parsing or its enum value.

#### Scenario: H610 still parses only under DingSongAddr4

- **GIVEN** scale type is `DingSongAddr4`
- **WHEN** an H610-style `02 2A … 0D` frame is received
- **THEN** the service MUST still publish **610** as before this change

#### Scenario: H610 still rejected under DingSong

- **GIVEN** scale type is `DingSong`
- **WHEN** the same H610 frame is offered to the DingSong HEX path
- **THEN** the parse MUST fail (null / no weight update)
