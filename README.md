# Rokid Tesla HUD


> **🔵 Connectivity Update — May 2025**
> The glasses connection has been migrated from **raw TCP sockets** to
> **Bluetooth via the Rokid AI glasses SDK** (`pod 'RokidSDK' ~> 1.10.2`).
> No Wi-Fi port forwarding is needed. See **SDK Setup** below.

iOS app that connects to the **Tesla Fleet API** and streams live vehicle data to **Rokid AR glasses** (TCP :8092).

```
Tesla Fleet API ──HTTPS──▶ iPhone (RokidTesla) ──Bluetooth/RokidSDK──▶ Rokid Glasses
```

## What's displayed

### On the Rokid glasses (TCP :8092)

JSON lines pushed on every poll and immediately on alerts:

```json
{"type":"vehicle","vehicle":"Model Y","text":"89%  268 mi  Disconnected  |  🔒 Locked"}
{"type":"vehicle","vehicle":"Model Y","text":"42%  126 mi  ⚡ 28 mi/hr  11 kW"}
{"type":"alert","text":"✅ Model Y fully charged!"}
{"type":"alert","text":"🪫 Low battery: 17%  51 mi"}
```

### In the app

| Tab | Content |
|-----|---------|
| **Dashboard** | Battery bar, charge rate + ETA, climate temps, lock/drive state, command buttons |
| **Glasses** | Live format preview on mockup, raw JSON, client count |
| **Settings** | Token, region, poll interval, alert configuration |

## Display formats

| Format | Example |
|--------|---------|
| **Compact** | `89%  268 mi  Disconnected  \|  🔒 Locked` |
| **Detailed** | Multi-line: battery, charge rate, climate, odometer |
| **Minimal** | `89%  268 mi` |

## Commands

The dashboard includes one-tap commands sent to the vehicle:

| Button | Action |
|--------|--------|
| Lock / Unlock | Toggle door locks |
| Start / Stop Climate | HVAC on/off |
| Honk | Horn |
| Flash Lights | Locate vehicle |
| Open Charge Port | Open charge port door |

## Alerts

| Alert | Condition |
|-------|-----------|
| ✅ Charge Complete | `charging_state` transitions Charging → Complete |
| 🪫 Low Battery | Battery ≤ threshold % while unplugged |
| 🔓 Left Unlocked | Transitions to Unlocked while Parked |

## SDK Setup

The glasses now connect over **Bluetooth via the Rokid AI glasses SDK** — no Wi-Fi port or TCP server needed.

The only thing left for each app is filling in the three credential constants (`kAppKey`, `kAppSecret`, `kAccessKey`) from [account.rokid.com/#/setting/prove](https://account.rokid.com/#/setting/prove), then running `pod install`.

1. **Get credentials** at <https://account.rokid.com/#/setting/prove> and paste them into the glasses Swift file:
   ```swift
   private let kAppKey    = "YOUR_APP_KEY"
   private let kAppSecret = "YOUR_APP_SECRET"
   private let kAccessKey = "YOUR_ACCESS_KEY"
   ```

2. **Install CocoaPods dependencies** from the repo root:
   ```bash
   pod install
   open *.xcworkspace   # always open the .xcworkspace, not .xcodeproj
   ```

3. *(Glasses now connect automatically over Bluetooth — no TCP port needed.)*

## Setup

1. Open `RokidTesla.xcodeproj` in Xcode 15+.
2. Set your team in Signing & Capabilities.
3. Build and run on iPhone (iOS 17+).
4. Get a Tesla Fleet API access token:
   - Visit [auth.tesla.com](https://auth.tesla.com) or use the Fleet API OAuth flow.
   - A refresh token can be stored so the app auto-renews the access token.
5. In **Settings**: paste the token and choose your region.
6. Tap **Apply & Reload** — your vehicles appear in the Dashboard.
7. If the vehicle is asleep, tap **Wake**.
8. *(Glasses now connect automatically over Bluetooth — no TCP port needed.)*

## Tesla Fleet API

| Endpoint | Use |
|----------|-----|
| `GET /api/1/vehicles` | List vehicles |
| `POST /api/1/vehicles/{id}/wake_up` | Wake sleeping vehicle |
| `GET /api/1/vehicles/{id}/vehicle_data?endpoints=charge_state,climate_state,drive_state,vehicle_state` | Full snapshot |
| `POST /api/1/vehicles/{id}/command/door_lock` | Lock |
| `POST /api/1/vehicles/{id}/command/door_unlock` | Unlock |
| `POST /api/1/vehicles/{id}/command/auto_conditioning_start` | Climate on |
| `POST /api/1/vehicles/{id}/command/auto_conditioning_stop` | Climate off |
| `POST /api/1/vehicles/{id}/command/honk_horn` | Honk |
| `POST /api/1/vehicles/{id}/command/flash_lights` | Flash |
| `POST /api/1/vehicles/{id}/command/charge_port_door_open` | Open charge port |

Regional base URLs:

| Region | Base URL |
|--------|----------|
| North America | `https://fleet-api.prd.na.vn.cloud.tesla.com` |
| Europe / EMEA | `https://fleet-api.prd.eu.vn.cloud.tesla.com` |
| China | `https://fleet-api.prd.cn.vn.cloud.tesla.com` |

## Requirements

- iOS 17.0+
- Xcode 15+
- Tesla vehicle (any model with Fleet API access)
- Tesla Fleet API access token
- Rokid AR glasses on the same Wi-Fi (optional — app works standalone)
