## MODIFIED Requirements

### Requirement: ViewModel inheritance hierarchy
The system SHALL define an abstract base class `AttendedWeighingDetailViewModelBase` inheriting from `ViewModelBase`, with concrete subclasses: `StandardWeighingDetailViewModel`, `SolidWasteWeighingDetailViewModel`, and `RecycleWeighingDetailViewModel`.

#### Scenario: Base class instantiation blocked
- **WHEN** code attempts to instantiate `AttendedWeighingDetailViewModelBase` directly
- **THEN** compilation fails because the class is abstract

#### Scenario: Standard mode creates correct subclass
- **WHEN** `AttendedWeighingViewModel.OpenDetail` receives an item with `WeighingMode.Standard`
- **THEN** it creates an instance of `StandardWeighingDetailViewModel` via DI

#### Scenario: SolidWaste mode creates correct subclass
- **WHEN** `AttendedWeighingViewModel.OpenDetail` receives an item with `WeighingMode.SolidWaste`
- **THEN** it creates an instance of `SolidWasteWeighingDetailViewModel` via DI

#### Scenario: Recycle mode creates Recycle subclass
- **WHEN** `AttendedWeighingViewModel.OpenDetail` receives an item with `WeighingMode.Recycle`
- **THEN** it creates an instance of `RecycleWeighingDetailViewModel` via DI
- **AND** SHALL NOT create `SolidWasteWeighingDetailViewModel`
