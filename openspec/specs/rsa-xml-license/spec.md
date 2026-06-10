# RSA XML License Specification

## Purpose

定义基于 RSA XML 文件的离线授权解密能力，包括 XML 文件解析、RSA 解密、授权过期验证及结果数据结构。

## Requirements

### Requirement: RSA XML file parsing

`RsaLicenseDecryptor.ReadAndDecrypt()` SHALL load an XML file from the given path, parse it using `XmlDocument`, and extract the text content of four nodes: `/config/privateKey`, `/config/authEndTime`, `/config/xmlString`, and `/config/proId`. If any required node is missing or empty, the method SHALL throw an `InvalidDataException` with a descriptive message.

#### Scenario: Valid RSA.xml file

- **WHEN** `ReadAndDecrypt` is called with a path to a valid RSA.xml containing all four nodes
- **THEN** SHALL extract `privateKey`, `authEndTime`, `xmlString`, and `proId` values from the XML
- **AND** SHALL proceed to decrypt all three encrypted fields

#### Scenario: Missing privateKey node

- **WHEN** `ReadAndDecrypt` is called with an XML file where `/config/privateKey` is missing or empty
- **THEN** SHALL throw `InvalidDataException` with a message indicating the private key is missing

#### Scenario: Missing authEndTime node

- **WHEN** `ReadAndDecrypt` is called with an XML file where `/config/authEndTime` is missing or empty
- **THEN** SHALL throw `InvalidDataException` with a message indicating authEndTime is missing

#### Scenario: Missing xmlString node

- **WHEN** `ReadAndDecrypt` is called with an XML file where `/config/xmlString` is missing or empty
- **THEN** SHALL throw `InvalidDataException` with a message indicating xmlString is missing

#### Scenario: Missing proId node

- **WHEN** `ReadAndDecrypt` is called with an XML file where `/config/proId` is missing or empty
- **THEN** SHALL throw `InvalidDataException` with a message indicating proId is missing

#### Scenario: Malformed XML

- **WHEN** `ReadAndDecrypt` is called with a path to a file that is not valid XML
- **THEN** SHALL throw `XmlException` (propagated from `XmlDocument.Load`)

### Requirement: RSA decryption of encrypted fields

`RsaLicenseDecryptor.Decrypt()` SHALL accept a private key XML string (in `<RSAKeyValue>` format) and a Base64-encoded ciphertext string, and return the decrypted plaintext using `RSA.Create()` with `FromXmlString()` and `Decrypt(bytes, RSAEncryptionPadding.Pkcs1)`.

#### Scenario: Decrypt valid ciphertext

- **WHEN** `Decrypt` is called with a valid private key XML and a valid Base64 ciphertext encrypted with the corresponding public key using PKCS1 padding
- **THEN** SHALL return the UTF-8 decoded plaintext string

#### Scenario: Invalid Base64 ciphertext

- **WHEN** `Decrypt` is called with a string that is not valid Base64
- **THEN** SHALL throw `FormatException` (propagated from `Convert.FromBase64String`)

#### Scenario: Wrong private key

- **WHEN** `Decrypt` is called with a private key that does not match the public key used for encryption
- **THEN** SHALL throw `CryptographicException` (propagated from `RSA.Decrypt`)

### Requirement: Authorization expiration validation

`RsaLicenseDecryptor.ReadAndDecrypt()` SHALL parse the decrypted `authEndTime` value as a `DateTime`, compare it against `DateTime.Now`, and return a `RsaLicenseDecryptResult` record with `IsExpired` and `DaysRemaining` fields computed from the comparison.

#### Scenario: Authorization not expired

- **WHEN** the decrypted `authEndTime` is a future date (e.g., "2027-12-31")
- **THEN** SHALL return `RsaLicenseDecryptResult` with `IsExpired = false`
- **AND** `DaysRemaining` SHALL be a positive integer representing days until expiration

#### Scenario: Authorization expired

- **WHEN** the decrypted `authEndTime` is a past date (e.g., "2025-01-01")
- **THEN** SHALL return `RsaLicenseDecryptResult` with `IsExpired = true`
- **AND** `DaysRemaining` SHALL be a negative integer representing days since expiration

#### Scenario: Authorization expires today

- **WHEN** the decrypted `authEndTime` is today's date
- **THEN** SHALL return `RsaLicenseDecryptResult` with `IsExpired = false`
- **AND** `DaysRemaining` SHALL be 0

### Requirement: RsaLicenseDecryptResult record structure

`RsaLicenseDecryptResult` SHALL be a `public record` with five properties: `AuthEndTime` (DateTime), `BuildLicenseNo` (string), `ProId` (Guid), `IsExpired` (bool), `DaysRemaining` (int).

#### Scenario: Record instantiation

- **WHEN** `ReadAndDecrypt` completes successfully
- **THEN** the returned `RsaLicenseDecryptResult` SHALL have `AuthEndTime` set to the decrypted and parsed DateTime
- **AND** `BuildLicenseNo` set to the decrypted xmlString value (施工许可证号)
- **AND** `ProId` set to `Guid.Parse` of the decrypted proId value
- **AND** `IsExpired` computed from comparing `AuthEndTime` to `DateTime.Now`
- **AND** `DaysRemaining` computed as `(AuthEndTime - DateTime.Now).Days`
