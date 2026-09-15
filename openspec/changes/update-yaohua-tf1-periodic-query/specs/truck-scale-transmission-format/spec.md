## REMOVED Requirements

### Requirement: Yaohua Type1 uses continuous-query listen without host query writes

**Reason:** 现场经典 tF=1 从机不主动推流；用户要求周期性下发查询命令以触发应答。

**Migration:** 使用下方「Yaohua Type1 Demo-style periodic exchange」要求。

## ADDED Requirements

### Requirement: Yaohua Type1 Demo-style periodic exchange

For `ScaleType.Yaohua` and `TransmissionFormatType1`, while the serial port is open and the Type1 protocol is started, the system SHALL periodically perform a Demo-compatible serial exchange: discard inbound buffer, write one query frame, then synchronously read bytes until ETX or reply timeout (~700ms), then parse the reply and publish real-time weight. The exchange MUST run immediately on start (dueTime zero) and then every **10 seconds**. The query frame MUST use address from `CommunicationParameter` (Yaohua default `"A"`), command code **`B`**, and layout `STX + Address + Command + XOR ASCII nibbles + ETX`. The Type1 path MUST NOT rely on `OnDataReceived` for obtaining weight replies (DataReceived handling MAY be a no-op for Type1). The protocol MUST stop the periodic exchanger on `OnStop`.

#### Scenario: Type1 exchanges on start and every 10 seconds

- **WHEN** Yaohua Type1 is active and the serial port is open
- **THEN** the Type1 protocol MUST perform Discard→Write→read-until-ETX exchange with command `B` and the configured address
- **AND** MUST repeat that exchange every 10 seconds until stopped

#### Scenario: Type1 publishes weight from exchange reply

- **WHEN** an exchange receives a parseable Demo-style weight reply
- **THEN** the Type1 protocol MUST publish the converted weight on the real-time weight stream

#### Scenario: Type1 does not depend on DataReceived for replies

- **WHEN** Yaohua Type1 is obtaining weight for display or weighing
- **THEN** the production path MUST obtain replies via the synchronous exchange path (not solely via DataReceived fragment reads)

#### Scenario: Periodic exchanger stops with protocol

- **WHEN** the Type1 protocol `OnStop` runs (port close / restart / dispose)
- **THEN** the periodic exchanger MUST stop and MUST NOT write after stop

## MODIFIED Requirements

### Requirement: ScaleSettings exposes opaque CommunicationParameter

`ScaleSettings` SHALL expose `CommunicationParameter` as an opaque `string?` shared across transmission formats. Changing `TransmissionFormatType` MUST reset `CommunicationParameter` to the default for the active `ScaleType` and new format. For Yaohua, the default MUST be `"A"`. Protocol implementers SHALL own parsing/interpretation; the facade MUST NOT centrally parse the value into a shared address model. Production Yaohua Type1 MAY use `CommunicationParameter` as the address byte when building outbound periodic query frames.

#### Scenario: Yaohua default parameter is A

- **WHEN** Yaohua settings are created or TransmissionFormatType is changed while ScaleType is Yaohua
- **THEN** `CommunicationParameter` MUST be `"A"` after reset

#### Scenario: Protocol owns parameter interpretation

- **WHEN** Yaohua Type0 or Type1 needs address-related behavior from `CommunicationParameter`
- **THEN** the Yaohua protocol implementation MUST interpret the opaque string
- **AND** the facade MUST NOT impose a single global address parser for all ScaleTypes

#### Scenario: Type1 uses parameter as query address

- **WHEN** Yaohua Type1 builds a periodic query frame
- **THEN** the address byte MUST come from interpreting `CommunicationParameter` (default `A`)
