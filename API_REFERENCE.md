# Philips Somneo API Reference

This document contains reverse-engineered API information for the Philips Somneo HF367x series.
The device runs an HTTPS server with a REST API at `https://<device-ip>/di/v1/products/1/`.

> **Note:** The device uses a self-signed SSL certificate that must be bypassed.

## Sources

- [pysomneo](https://github.com/theneweinstein/pysomneo) - Python library for Somneo
- [Home Assistant Somneo Integration](https://github.com/theneweinstein/somneo)
- [openHAB Somneo Binding](https://www.openhab.org/addons/bindings/somneo/)
- [homebridge-somneo](https://github.com/zackwag/homebridge-somneo)

---

## Endpoints

### Device Info
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/device` | GET | Device information |

### Sensors
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/wusrd` | GET | Sensor readings (temperature, humidity, luminance, noise) |

**Response fields:**
- `mstmp` - Temperature (Celsius)
- `msrhu` - Humidity (%)
- `mslux` - Luminance (lux)
- `mssnd` - Noise level (dB)

### Light Control
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/wulgt` | GET/PUT | Main light state |

**Fields:**
- `onoff` (bool) - Light on/off
- `ltlvl` (int) - Brightness level (1-25)
- `ngtlt` (bool) - Night light on/off
- `tempy` (bool) - Temporary/preview mode

### Alarms
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/wualm/aalms` | GET | Alarm schedules (arrays of times/days) |
| `/wualm/aenvs` | GET | Alarm enabled states (array of booleans) |
| `/wualm/prfwu` | PUT | Configure alarm (full payload required) |

**Configure alarm payload:**
```json
{
  "prfnr": 1,        // Alarm position (1-16)
  "prfen": true,     // Enabled
  "almhr": 7,        // Hour (0-23)
  "almmn": 30,       // Minute (0-59)
  "daynm": 254       // Day bitmask (see below)
}
```

**Day bitmask:**
- Bit 0 = Monday, Bit 6 = Sunday
- 0 = Once (tomorrow)
- 62 = Weekdays (Mon-Fri)
- 192 = Weekend (Sat-Sun)
- 254 = Daily

### Sunset / Wind-Down
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/wudsk` | GET/PUT | Sunset/dusk settings |

**Fields:**
- `onoff` (bool) - Sunset active
- `durat` (int) - Duration in minutes (5-60)
- `curve` (int) - Light intensity level
- `ctype` (int) - Color scheme (see below)
- `snddv` (string) - Sound device (see below)
- `sndch` (string) - Sound channel
- `sndlv` (int) - Sound volume (1-25)

**Color schemes (`ctype`):**
| Value | Name |
|-------|------|
| 0 | Sunny Day |
| 1 | Island Red |
| 2 | Nordic White |
| 3 | Caribbean Red |

### Themes / Available Sounds
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/files/lightthemes` | GET | Wake-up light themes |
| `/files/dusklightthemes` | GET | Sunset light themes |
| `/files/wakeup` | GET | Wake-up sounds |
| `/files/winddowndusk` | GET | Sunset/dusk sounds |

---

## Sound Configuration

### Sound Devices (`snddv`)

| Value | Description | Used For |
|-------|-------------|----------|
| `"wus"` | Wake-up sounds | Alarms only |
| `"dus"` | Dusk sounds | Sunset only |
| `"fmr"` | FM Radio | Both |
| `"off"` | No sound | Both |
| `"aux"` | Auxiliary input | Audio player |

### Wake-Up Sounds (`snddv: "wus"`)
Used with alarms. Channel values 1-8:

| Channel | Sound |
|---------|-------|
| 1 | Forest Birds |
| 2 | Summer Birds |
| 3 | Buddha Wakeup |
| 4 | Morning Alps |
| 5 | Yoga Harmony |
| 6 | Nepal Bowls |
| 7 | Summer Lake |
| 8 | Ocean Waves |

### Dusk/Sunset Sounds (`snddv: "dus"`)
Used with sunset. Channel values 1-2:

| Channel | Sound |
|---------|-------|
| 1 | Soft Rain |
| 2 | Ocean Waves |

> **Important:** Sunset mode has only 2 sound options. Using wake-up sound channels with sunset will fail silently.

### FM Radio (`snddv: "fmr"`)
- `sndch`: Preset number as string ("1" through "5")

---

## Example Payloads

### Start Sunset with Sound
```json
{
  "onoff": true,
  "durat": 20,
  "ctype": 0,
  "snddv": "dus",
  "sndch": "1",
  "sndlv": 12
}
```

### Start Sunset without Sound
```json
{
  "onoff": true,
  "durat": 20
}
```

### Stop Sunset
```json
{
  "onoff": false
}
```

---

## Known Quirks

1. **Sunset modifications require restart**: If sunset is already active, you must turn it off first, wait ~1 second, then apply new settings.

2. **API is single-threaded**: The device's HTTP server can only handle one connection at a time. Concurrent requests may fail.

3. **Response may be incomplete**: After PUT requests, the response may not reflect the full state. Fetch again after a short delay.

4. **SSL certificate**: The device uses a self-signed certificate that must be trusted/bypassed.
