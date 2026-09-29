## ADDED Requirements

### Requirement: Demo window prints live gross tare and net

`MaterialClient.Demo` MUST provide a window reachable from the demo main window that displays four labeled values. The visible labels MUST be the exact text **实时**, **毛重**, **皮重**, and **净重**. The window MUST NOT read or write production weighing records, and MUST NOT call `TruckScaleWeightService`.

#### Scenario: Four labels are visible

- **WHEN** the operator opens the Yaohua tF=0 demo window from the demo main window
- **THEN** the window MUST show the labels 实时, 毛重, 皮重, and 净重

### Requirement: Operator selects a serial port only

The demo window MUST list available serial port names and let the operator choose one. Connecting MUST open that port at 9600 baud, 8 data bits, no parity, and one stop bit. Those line settings MUST NOT be editable. While the port is open, each valid tF=0 frame MUST update 实时 and the frame text area MUST show that frame's hexadecimal bytes. A frame that fails checksum MUST NOT update 实时. Closing the window or disconnecting MUST close the port.

#### Scenario: Open port prints the received frame

- **WHEN** a valid tF=0 frame arrives on the open port
- **THEN** the frame text area MUST show that frame as hexadecimal bytes
- **AND** 实时 MUST show the displayed weight from that frame

#### Scenario: Distinct frame structures are deduplicated

- **WHEN** the open port receives repeated 12-byte weight frames that differ only in digits, sign, or checksum
- **THEN** the distinct-frame list MUST keep a single row for that structure
- **AND** a frame with a different length or different non-digit markers MUST appear as another row

#### Scenario: Line settings are not offered

- **WHEN** the operator opens the Yaohua tF=0 demo window
- **THEN** the window MUST offer a serial port selector
- **AND** MUST NOT offer controls for baud rate, data bits, parity, or stop bits

### Requirement: Replay decodes one displayed weight from a tF=0 frame

The demo MUST accept pasted hexadecimal text and extract 12-byte frames that start with `02` and end with `03`. A valid frame MUST contain a sign byte (`2B` or `2D`), six ASCII digits, a decimal-place digit `0`–`4`, and an XOR checksum of bytes 2 through 9 rendered as two ASCII nibbles in bytes 10 and 11 (nibble 0–9 encoded as `30h`–`39h`, nibble A–F encoded as `41h`–`46h`). The live value MUST be the signed six-digit integer divided by `10` raised to the decimal-place count. Bytes 10 and 11 MUST NOT be interpreted as a gross/net status flag.

#### Scenario: Known negative frame shows minus 1.30

- **WHEN** the operator loads the text `02 2D 30 30 30 31 33 30 32 31 44 03`
- **THEN** 实时 MUST display `-1.30`

#### Scenario: Checksum bytes are not a net flag

- **WHEN** the operator loads `02 2D 30 30 30 31 33 30 32 31 44 03`
- **THEN** the demo MUST treat bytes `31 44` only as a passing checksum
- **AND** MUST NOT switch the live value into a separate net-only field because those bytes are present

#### Scenario: Bad checksum does not update live weight

- **WHEN** a valid frame has already set 实时
- **AND** the operator then loads a 12-byte frame with the same layout but a wrong checksum
- **THEN** 实时 MUST remain the previous valid displayed weight

### Requirement: Host logic supplies gross tare and net

Before the operator captures a weight, the demo MUST treat the current live value as 毛重, MUST show 皮重 as `0`, and MUST show 净重 equal to 毛重. Capturing 毛重 or 皮重 MUST freeze that value at the live value shown at the moment of capture. After both are captured, 净重 MUST equal 毛重 minus 皮重, including a negative result. Clearing MUST discard both captured values and return to the uncaptured rule. Advancing to another valid frame MUST update 实时 and MUST update 毛重 or 皮重 only when that side has not been captured.

#### Scenario: Uncaptured frame follows gross mode

- **WHEN** the operator loads `02 2D 30 30 30 31 33 30 32 31 44 03` and has not captured 毛重 or 皮重
- **THEN** 毛重 MUST display `-1.30`
- **AND** 皮重 MUST display `0`
- **AND** 净重 MUST display `-1.30`

#### Scenario: Captured gross stays fixed while live advances

- **WHEN** the operator captures 毛重 while 实时 is `-1.30` and has not captured 皮重
- **AND** then advances to a later valid frame whose displayed weight is `2.05`
- **THEN** 实时 MUST display `2.05`
- **AND** 毛重 MUST still display `-1.30`
- **AND** 皮重 MUST still display `0`
- **AND** 净重 MUST still display `-1.30`

#### Scenario: Two captures compute net by subtraction

- **WHEN** the operator has captured 毛重 as `2.05` and 皮重 as `-1.30`
- **THEN** 净重 MUST display `3.35`

#### Scenario: Clear returns to gross mode

- **WHEN** the operator has captured 毛重 or 皮重 and then clears
- **AND** the current live value is `-1.30`
- **THEN** 毛重 MUST display `-1.30`
- **AND** 皮重 MUST display `0`
- **AND** 净重 MUST display `-1.30`
