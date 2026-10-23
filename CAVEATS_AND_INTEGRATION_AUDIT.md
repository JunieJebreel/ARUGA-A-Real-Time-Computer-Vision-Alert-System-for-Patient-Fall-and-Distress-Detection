# Technical Audit & Integration Caveats: Tapo Camera Integration with ARUGA

> **Audit Date:** 2026-10-09  
> **Repository:** `aruga-full-source`  
> **Target Scope:** Biomechanical Edge Pipeline, Stream Bridge, Tapo RTSP/ONVIF/Two-way Audio, and Web App Integration.

---

## 1. Executive Summary & Architecture

The ARUGA system uses a deterministic, rule-based biomechanical engine powered by lightweight pose estimation (MediaPipe Pose / YOLOv8n-pose ONNX) rather than opaque black-box fall classifiers. It runs 100% on-device/edge without requiring cloud model inference.

The web platform (`aruga.joalvergs.tech`) is a decoupled static PWA dashboard communicating with the local pipeline via `stream_bridge.py` over HTTP MJPEG (`/video_feed`), JPEG snapshot polling (`/video_frame`), JSON telemetry (`/telemetry`), and WebSocket two-way voice (`/voice`).

Connecting the TP-Link Tapo camera to ARUGA must be done via direct camera protocols (RTSP/ONVIF and local media bridge) rather than attempting to interface with the proprietary Tapo mobile application.

```
                      +---------------------------------------+
                      |       TP-Link Tapo Camera (LAN)       |
                      |  - RTSP: 554 (stream1/stream2)        |
                      |  - Audio: G.711 A-law (PCMA 8kHz)     |
                      |  - Local Backchannel: TCP 8800 (tapo) |
                      +-------------------+-------------------+
                                          |
                        RTSP / Local LAN  | (Direct Protocol)
                                          v
                      +---------------------------------------+
                      |         ARUGA Edge Engine             |
                      |   - FramePump (Auto-reconnect)        |
                      |   - HallwayManager / YOLOv8n-Pose     |
                      |   - Biomechanical Kinematics Engine   |
                      |   - Stream Bridge (MJPEG + Telemetry) |
                      |   - Voice Relay (WebSocket PCM)       |
                      +-------------------+-------------------+
                                          |
                        HTTP / WebRTC / WS| (Local / Cloudflare Tunnel)
                                          v
                      +---------------------------------------+
                      |         ARUGA Web Dashboard           |
                      |   - Live Stream Video & Overlays      |
                      |   - Real-time Kinematics & Alerts     |
                      |   - Two-way Nurse-Patient Voice       |
                      +---------------------------------------+
```

---

## 2. Source Code & Pipeline Audit

### A. Inference & Dataset Status
- **Pose Estimation Models:** Pre-packaged in `assets/models/yolov8n-pose.onnx` (13MB).
- **Execution Providers:** Automatic provider selection benchmarker (`core/yolo_pose_backend.py`) testing thread counts and hardware providers (CUDA $\rightarrow$ DirectML $\rightarrow$ CPU).
- **Datasets:** Evaluation video clips reside under `assets/eval_clips/` (40 ADL + 30 UR Fall test clips). Benchmarked in `eval_report.csv` (Recall: 90%, F1: 71%). Zero proprietary custom dataset training is required.
- **Biomechanical Rules:** Deterministic spine angle ($\theta \ge 58^\circ$), vertical centroid speed ($V_y$), and inactivity stillness energy thresholds in `core/fall_detector.py` and `core/inactivity_monitor.py`.

### B. Streaming & Ingestion
- `core/frame_pump.py`: Threaded ring-buffer frame queue dropping outdated frames, keeping inference latency sub-frame. Automatic reconnection with exponential backoff for RTSP packet drops.
- `core/camera_sources.py`: Formats Tapo camera URLs via `build_tapo_rtsp_url(ip, user, password, stream)`.
- `stream_bridge.py`: Multi-threaded HTTP daemon providing CORS-enabled `/video_feed`, `/video_frame`, `/telemetry`, `/status`, and `/analyze_file`.

---

## 3. Comprehensive List of Technical Caveats

### Caveat 1: Proprietary Tapo Cloud App vs. Local RTSP Stream
* **Issue:** The TP-Link Tapo mobile application and cloud backend are strictly proprietary and closed-source. There is no official public cloud API for streaming video or two-way talk.
* **Impact:** Any attempt to reverse-engineer the Tapo mobile cloud API is brittle, subject to frequent token invalidation, rate limits, and encryption changes.
* **Resolution:** Bypass the mobile app completely. Connect ARUGA directly to the camera over the local network using the native RTSP/ONVIF interface.

### Caveat 2: Mandatory Camera Account Setup in Tapo App
* **Issue:** Tapo cameras ship with RTSP and ONVIF access disabled by default. The camera's cloud login (TP-Link ID) **cannot** be used to access the RTSP stream.
* **Impact:** Connecting without configuring credentials results in `401 Unauthorized` or connection refusal.
* **Resolution:** The user must perform a one-time setup inside the Tapo mobile app:
  1. Go to **Device Settings** $\rightarrow$ **Advanced Settings** $\rightarrow$ **Camera Account**.
  2. Create a dedicated local username and password.
  3. Ensure camera microphone is enabled and unmuted in Device Settings.

### Caveat 3: Tapo Stream Concurrency Limit
* **Issue:** Tapo hardware SoC limits concurrent streams to **2 simultaneous connections** (e.g., C200, C210, C310).
* **Impact:** If the user opens the Tapo mobile app while the ARUGA stream bridge and another viewer are connected, the camera drops or rejects new connections.
* **Resolution:** Ensure the mobile app live view is closed when running ARUGA in high-reliability monitoring mode, and use `stream_bridge.py` as the single ingestion source.

### Caveat 4: Browser RTSP Playback Incompatibility & Latency
* **Issue:** Web browsers (Chrome, Firefox, Safari) cannot consume raw RTSP or RTP streams natively.
* **Impact:** Direct streaming from camera to web app without a bridge is impossible.
* **Resolution:** 
  - Standard mode: `stream_bridge.py` ingests RTSP via OpenCV/FFmpeg and serves HTTP MJPEG (`/video_feed`) and snapshots (`/video_frame`).
  - Ultra-low latency mode: Deploy **go2rtc** or **MediaMTX** sidecar to convert RTSP to WebRTC for sub-200ms latency.

### Caveat 5: Two-Way Audio Protocol Asymmetry
* **Issue:** 
  - **Downlink (Camera Mic $\rightarrow$ ARUGA):** Standard RTSP stream contains G.711 A-law (PCMA 8 kHz) audio, extractable cleanly via FFmpeg.
  - **Uplink (Nurse Mic $\rightarrow$ Camera Speaker):** Tapo firmware does **not** implement ONVIF Profile T (Audio Backchannel). Instead, it uses a proprietary HTTP multipart protocol on **TCP port 8800**.
* **Impact:** Standard ONVIF two-way audio libraries fail completely.
* **Resolution:** 
  - Recommended: Use **go2rtc** `tapo://` backchannel provider on LAN TCP 8800.
  - Immediate/Fallback: Local speaker output via system audio (`--voice-sink pulse` or USB speaker placed near station).

### Caveat 6: Network Topology and Cross-Subnet / Remote Routing
* **Issue:** Tapo cameras are local LAN devices (RFC 1918 private IPs). If the web app is hosted on Cloudflare Pages (`aruga.joalvergs.tech`) and the user views it outside the local LAN, direct camera connection is unreachable.
* **Impact:** The browser cannot directly reach `192.168.x.x` when loaded over public HTTPS due to mixed-content security (HTTPS cannot fetch insecure HTTP LAN endpoints) and NAT boundaries.
* **Resolution:** 
  - Use `run_tunnel.sh` (Cloudflare Named/Quick Tunnel) to expose the ARUGA bridge securely over HTTPS/WSS (`https://<bridge-tunnel-domain>`).
  - Configure the bridge endpoint in the web dashboard settings.

### Caveat 7: Hardware & Inference Scaling
* **Issue:** Multi-person pose estimation on raw 1080p/2K stream (`stream1`) requires significant CPU/GPU compute.
* **Impact:** High frame processing latency and dropped frames on lower-end edge hardware (e.g. Raspberry Pi or entry Celeron/i3 laptops).
* **Resolution:**
  - Ingest `stream2` (360p/640x360) for inference, which yields 15-30 FPS on standard CPUs while maintaining pose accuracy.
  - Keep `stream1` only for high-definition visual archiving if required.

---

## 4. Step-by-Step Implementation & Operating Plan

1. **Phase 1: Local Tapo Setup (One-Time)**
   - Reserve static DHCP lease for Tapo camera IP.
   - Configure Camera Account in Tapo app.
   - Verify RTSP stream using `tools/live_verify.py` or `ffprobe`.

2. **Phase 2: Edge Bridge Execution**
   - Start ARUGA bridge:
     ```bash
     .venv/bin/python stream_bridge.py --tapo-ip <IP> --tapo-user <USER> --tapo-pass <PASS> --stream stream2
     ```
   - Verify HTTP video feed at `http://localhost:8080/video_feed` and telemetry at `http://localhost:8080/telemetry`.

3. **Phase 3: Web Dashboard / Remote Integration**
   - If hosting dashboard locally, connect to `http://localhost:8080`.
   - If hosting over remote web (`aruga.joalvergs.tech`), run `./run_tunnel.sh` and point the dashboard stream endpoint to the tunnel URL.

4. **Phase 4: Two-Way Audio Integration**
   - Ingest patient audio via RTSP audio stream in `voice_relay.py`.
   - Forward nurse audio to camera speaker via go2rtc `tapo://` gateway on port 8800 or fallback room speaker sink.
