## REMOVED Requirements

### Requirement: Yaohua Type1 uses continuous-query listen without host query writes

**Reason:** 现场经典 tF=1 从机不主动推流；用户要求 Demo 对齐的周期查询。

**Migration:** 使用下方「Yaohua Type1 Demo-style B-C-D poll」要求。

## ADDED Requirements

### Requirement: Yaohua Type1 Demo-style B-C-D poll

For `ScaleType.Yaohua` and `TransmissionFormatType1`, while the serial port is open and the Type1 protocol is started, the system SHALL continuously poll Demo-compatible query commands in order **B → C → D**, waiting **200 milliseconds** between each command. Each poll step MUST perform Discard→Write→sync-read-until-ETX (or reply timeout ~700ms), then parse the reply. Frame layout MUST be `STX + Address + Command + XOR ASCII nibbles + ETX` with address from `CommunicationParameter` (default `"A"`). The Type1 path MUST NOT rely on `OnDataReceived` for obtaining weight replies. The protocol MUST stop the poll loop on `OnStop`.

#### Scenario: Type1 polls B then C then D with 200ms gap

- **WHEN** Yaohua Type1 is active and the serial port is open
- **THEN** the Type1 protocol MUST issue query commands in the repeating order B, C, D
- **AND** MUST wait 200ms between consecutive commands

#### Scenario: Type1 stores C and D (and B) component values

- **WHEN** a parseable Demo-style reply arrives for command B, C, or D
- **THEN** the protocol MUST store the converted weight as gross (B), tare (C), or net (D) respectively
- **AND** MUST publish the stored components via the component-weight stream

#### Scenario: Type1 realtime weight follows B

- **WHEN** a parseable Demo-style reply arrives for command B
- **THEN** the Type1 protocol MUST publish that converted weight on the real-time weight stream

#### Scenario: Poll loop stops with protocol

- **WHEN** the Type1 protocol `OnStop` runs
- **THEN** the B-C-D poll loop MUST stop and MUST NOT write after stop

## MODIFIED Requirements

### Requirement: ScaleSettings exposes opaque CommunicationParameter

`ScaleSettings` SHALL expose `CommunicationParameter` as an opaque `string?` shared across transmission formats. Changing `TransmissionFormatType` MUST reset `CommunicationParameter` to the default for the active `ScaleType` and new format. For Yaohua, the default MUST be `"A"`. Protocol implementers SHALL own parsing/interpretation; the facade MUST NOT centrally parse the value into a shared address model. Production Yaohua Type1 MAY use `CommunicationParameter` as the address byte when building outbound poll query frames.

#### Scenario: Yaohua default parameter is A

- **WHEN** Yaohua settings are created or TransmissionFormatType is changed while ScaleType is Yaohua
- **THEN** `CommunicationParameter` MUST be `"A"` after reset

#### Scenario: Protocol owns parameter interpretation

- **WHEN** Yaohua Type0 or Type1 needs address-related behavior from `CommunicationParameter`
- **THEN** the Yaohua protocol implementation MUST interpret the opaque string
- **AND** the facade MUST NOT impose a single global address parser for all ScaleTypes

#### Scenario: Type1 uses parameter as query address

- **WHEN** Yaohua Type1 builds a poll query frame
- **THEN** the address byte MUST come from interpreting `CommunicationParameter` (default `A`)
