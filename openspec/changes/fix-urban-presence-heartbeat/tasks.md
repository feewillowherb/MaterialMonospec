## 1. TouchOnline API (UrbanManagement)

- [ ] 1.1 Add TouchOnline (or equivalent on `DeviceStatusService`) that renews live TTL/LastSeen when the key exists and **recreates** `IsConnected=true` when missing
- [ ] 1.2 Ensure LastSeen throttle still renews TTL on Touch; do not add a new Hub method

## 2. SignalR UploadStatus path

- [ ] 2.1 Call TouchOnline on every qualifying `UploadStatus` (`ProId` + `ClientId`), not only on first ConnectionId mapping
- [ ] 2.2 Keep first-mapping group join / optional broadcast behavior; remove sole dependence on first-mapping for live key creation

## 3. Receive / Legacy presence

- [ ] 3.1 After successful `ReceiveAsync` (insert or duplicate apply), Touch when ClientId is available
- [ ] 3.2 Legacy: set ClientId to `legacy:{AccessCode}` (normalized AccessCode matching project lookup); wire via `FromLegacySync` or Receive Touch args
- [ ] 3.3 Modern: Touch only when `SubmitMachineCode` is non-empty; otherwise skip without ProId-only row

## 4. Verify

- [ ] 4.1 SignalR: after live TTL expiry on same connection, a further `UploadStatus` restores `isConnected=true` (extend or re-run `urban-signalr-online-probe` as needed)
- [ ] 4.2 Legacy: successful `/Api/Post` for a registered AccessCode shows `ClientId=legacy:{AccessCode}` online in client-list within settle window
- [ ] 4.3 User L3: project management badge coherent for Urban SignalR wake and Legacy active site
- [ ] 4.4 Confirm MaterialClient has **no** required code changes in this change
