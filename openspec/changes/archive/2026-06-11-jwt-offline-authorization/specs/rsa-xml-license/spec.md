## REMOVED Requirements

### Requirement: RSA XML file parsing

**Reason**: Replaced by JWT-based offline authorization (`.urban` files). The entire RSA.xml parsing mechanism is superseded by standard JWT validation.

**Migration**: Use `JwtLicenseChecker` which implements the same `IStaticLicenseChecker` interface. License files change from `RSA.xml` to `.urban` format.

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

**Reason**: Replaced by JWT RS256 signature validation. The asymmetric mechanism is preserved but uses standard JWT libraries instead of raw RSA XML decryption.

**Migration**: JWT signature verification replaces RSA field-by-field decryption. Claims are extracted directly from the validated token payload.

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

**Reason**: Replaced by JWT `exp` claim validation. The `JwtSecurityTokenHandler` handles lifetime validation natively with configurable clock skew.

**Migration**: Expiration is validated via `TokenValidationParameters.ValidateLifetime = true` in `JwtLicenseChecker`.

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

**Reason**: The `RsaLicenseDecryptResult` record is removed along with `RsaLicenseDecryptor`. License validation results are now returned directly as `LicenseCheckResult` from `JwtLicenseChecker`.

**Migration**: `LicenseCheckResult` (already existing, unchanged) serves as the sole result type.

#### Scenario: Record instantiation
- **WHEN** `ReadAndDecrypt` completes successfully
- **THEN** the returned `RsaLicenseDecryptResult` SHALL have `AuthEndTime` set to the decrypted and parsed DateTime
- **AND** `BuildLicenseNo` set to the decrypted xmlString value
- **AND** `ProId` set to `Guid.Parse` of the decrypted proId value
- **AND** `IsExpired` computed from comparing `AuthEndTime` to `DateTime.Now`
- **AND** `DaysRemaining` computed as `(AuthEndTime - DateTime.Now).Days`
