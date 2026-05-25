## Context

Two weighing windows (`AttendedWeighingWindow` in MaterialClient, `UrbanAttendedWeighingWindow` in MaterialClient.Urban) implement the same 4-row layout independently:

```
Row 0 (48px):  PrimaryBlue header — logo, menu buttons, window controls
Row 1 (72px):  Blue gradient weight/status display area
Row 2 (*):     Main content grid (columns differ per window)
Row 3 (36px):  DeviceStatusBar with device indicators
```

Both windows also share identical code-behind logic for:
- `TitleBar_OnPointerPressed` → `BeginMoveDrag`
- `OnMinimizeButtonClick` → `WindowState.Minimized`
- `OnCloseButtonClick` → `Close()`

The duplication is ~80 lines of chrome XAML and ~20 lines of handler code per window. Any visual change (colors, spacing, button style) must be applied twice.

### Constraints
- `MaterialClient.UI` cannot reference app-specific projects (MaterialClient, MaterialClient.Urban).
- The base control must work for both `SystemDecorations="None"` (Attended) and `SystemDecorations="BorderOnly"` (Urban with resize grips).
- Both windows are Avalonia `Window` subclasses — the shared base must be a `UserControl` (content), not a `Window` subclass (Avalonia doesn't support multi-project Window inheritance cleanly).

## Goals / Non-Goals

**Goals:**
- Eliminate duplicated header/status bar XAML between the two weighing windows.
- Provide a single `WeighingWindowBase` UserControl with well-defined content slots.
- Normalize Urban header to match MaterialClient's PrimaryBlue header style.
- Keep both windows as `Window` subclasses — they host `WeighingWindowBase` as their `Content`.

**Non-Goals:**
- No ViewModel refactoring.
- No TemplatedControl with ControlTheme (UserControl is sufficient for this extraction).
- No shared base Window class.
- No resize-grip extraction (Urban keeps its own resize grips outside the UserControl).

## Decisions

### Decision 1: UserControl over TemplatedControl

**Choice**: `WeighingWindowBase` is a `UserControl` with `ContentPresenter` slots.

**Rationale**: TemplatedControl requires a separate ControlTheme and template part convention. For a layout shell with 4 fixed rows, UserControl is simpler, allows direct XAML editing, and matches the existing pattern in MaterialClient.UI (`DeviceStatusBar` is also a UserControl).

**Alternatives considered**:
- `TemplatedControl` + `ControlTheme`: Overkill for a structural layout. Would require `PART_` naming and template binding complexity for no benefit.

### Decision 2: Dependency Properties for content injection

**Choice**: Four DP slots — `HeaderLeftContent`, `MenuItems`, `WeightAreaContent`, `MainContent`.

| DP | Type | Purpose |
|---|---|---|
| `HeaderLeftContent` | `object` | Logo/title region (left side of header) |
| `MenuItems` | `object` | Center menu buttons |
| `WeightAreaContent` | `object` | Entire row 1 content |
| `MainContent` | `object` | Entire row 2 content |

Status bar bindings (`DeviceStatuses`, `CameraStatusDetails`) are also DPs so the base control can bind them to the host window's DataContext.

**Rationale**: DPs allow XAML inline content injection via Avalonia's `ContentControl.Content` binding. Consumers set the DPs directly in XAML:
```xml
<ui:WeighingWindowBase MenuItems="{StaticResource AttendedMenuItems}"
                        WeightAreaContent="{StaticResource ...}"
                        MainContent="{StaticResource ...}" />
```
Or more simply, use the `Content=` attribute with inline XAML.

### Decision 3: Window chrome handlers stay in code-behind

**Choice**: TitleBar drag, minimize, and close handlers remain in each Window's code-behind. They are ~5 lines each and require access to `Window` APIs (`BeginMoveDrag`, `WindowState`, `Close`) which are not available inside a UserControl.

**Rationale**: The duplicated handler code is minimal (3 methods, ~15 lines total). Moving these to a helper class or attached behavior would add complexity for negligible gain.

### Decision 4: Layout structure of WeighingWindowBase

```
┌─────────────────────────────────────────────────────────────┐
│ WeighingWindowBase : UserControl                             │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ Grid RowDefinitions="Auto,Auto,*,Auto"                  ││
│  │                                                         ││
│  │ Row 0: Border Background="{DynamicResource PrimaryBlue}"││
│  │   Grid ColDefs="Auto,*,Auto"                            ││
│  │   Col 0: ContentPresenter → HeaderLeftContent DP        ││
│  │   Col 1: ContentPresenter → MenuItems DP                ││
│  │   Col 2: StackPanel (minimize + close buttons)          ││
│  │                                                         ││
│  │ Row 1: ContentPresenter → WeightAreaContent DP          ││
│  │         Background: LinearGradientBrush (#4169E1→#4A85F9)││
│  │                                                         ││
│  │ Row 2: ContentPresenter → MainContent DP                ││
│  │         Background="White"                              ││
│  │                                                         ││
│  │ Row 3: Border (DeviceStatusBar region)                  ││
│  │   ui:DeviceStatusBar with ItemsSource/Details DPs       ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

**Rationale**: The 4-row structure is identical between both windows. Only the content injected into each row differs. The header row's 3-column grid (logo | menu | controls) is also shared.

### Decision 5: Minimize/Close buttons embedded in base control

**Choice**: The minimize (─) and close (✕) buttons live inside `WeighingWindowBase`, using routed events (`ButtonClick`) that the host Window code-behind handles.

**Rationale**: Both windows use identical button markup for minimize/close. The host Window still handles the events since it owns `Window` APIs. The base raises routed events or the Window attaches handlers via `x:Name` access.

### Architecture Diagram

```
Component Hierarchy
├── MaterialClient.UI (shared library)
│   └── Controls/
│       ├── DeviceStatusBar (existing)
│       └── WeighingWindowBase (NEW)
│           ├── HeaderLeftContent slot
│           ├── MenuItems slot
│           ├── WeightAreaContent slot
│           ├── MainContent slot
│           └── DeviceStatusBar (embedded)
│
├── MaterialClient (app)
│   └── AttendedWeighingWindow : Window
│       └── Content → WeighingWindowBase
│           ├── HeaderLeftContent → logo Image
│           ├── MenuItems → 5 buttons + Popup
│           ├── WeightAreaContent → delivery-type + weight + plate
│           └── MainContent → 3-column grid
│
└── MaterialClient.Urban (app)
    └── UrbanAttendedWeighingWindow : Window
        ├── Content → WeighingWindowBase
        │   ├── HeaderLeftContent → "凡" logo + title
        │   ├── MenuItems → "系统设置" button
        │   ├── WeightAreaContent → weight text + status
        │   └── MainContent → 2-column grid
        └── Resize grips (outside WeighingWindowBase)
```

## Risks / Trade-offs

- **[DP content injection verbosity]** → Inline XAML content via DPs can be verbose. Mitigation: Consumers can define content as `DataTemplate` resources or use `<ui:WeighingWindowBase.WeightAreaContent>` property element syntax for readability.

- **[Window decoration mismatch]** → AttendedWeighingWindow uses `SystemDecorations="None"`, Urban uses `BorderOnly`. The base control doesn't handle this — it's the Window's responsibility. Mitigation: Each Window keeps its own decoration setting and resize grips.

- **[OverlayDialogHost]** → AttendedWeighingWindow wraps its grid in a `Panel` with an `OverlayDialogHost` sibling. The base control's content area won't include this. Mitigation: The host Window adds `OverlayDialogHost` as a sibling to `WeighingWindowBase` in a Panel wrapper (same pattern as current).

## Detailed Code Change Inventory

| File Path | Change Type | Change Description | Affected Module |
|-----------|-------------|-------------------|-----------------|
| `MaterialClient.UI/Controls/WeighingWindowBase.axaml` | New | 4-row Grid layout with 4 ContentPresenter DP slots, embedded minimize/close buttons, embedded DeviceStatusBar | MaterialClient.UI |
| `MaterialClient.UI/Controls/WeighingWindowBase.axaml.cs` | New | DPs: HeaderLeftContent, MenuItems, WeightAreaContent, MainContent, DeviceStatuses, CameraStatusDetails. Window button click handlers as routed events. | MaterialClient.UI |
| `MaterialClient/Views/AttendedWeighing/AttendedWeighingWindow.axaml` | Modify | Replace 4-row Grid with `<Panel><ui:WeighingWindowBase .../><ursa:OverlayDialogHost/></Panel>`. Inject menu items, weight area, 3-col main grid via DP slots. | MaterialClient |
| `MaterialClient/Views/AttendedWeighing/AttendedWeighingWindow.axaml.cs` | Modify | Remove duplicated TitleBar/Minimize/Close handlers (subscribe to base's routed events or keep forwarding). Keep Popup/DataManagement dialog logic. | MaterialClient |
| `MaterialClient.Urban/Views/UrbanAttendedWeighingWindow.axaml` | Modify | Replace 4-row ContentGrid with `<Grid><ui:WeighingWindowBase .../> + resize grips</Grid>`. Inject "凡" logo, single menu item, simplified weight area, 2-col main grid via DP slots. | MaterialClient.Urban |
| `MaterialClient.Urban/Views/UrbanAttendedWeighingWindow.axaml.cs` | Modify | Remove duplicated TitleBar/Minimize/Close handlers (subscribe to base's routed events or keep forwarding). Keep tab click/record click/settings logic. | MaterialClient.Urban |

## Open Questions

None — the approach is straightforward UserControl extraction with well-defined DP slots.
