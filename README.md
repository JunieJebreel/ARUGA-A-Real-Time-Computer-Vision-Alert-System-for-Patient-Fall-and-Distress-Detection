# ARUGA: AI-Assisted Recognition and Understanding for Guided Contextual Risk Assessment

A real-time computer vision system for fall detection, prolonged inactivity monitoring, and acute cardiac distress (Levine's sign) detection. Designed for prototyping and demonstrations **without requiring custom dataset collection or model training**.

---

## 🌟 Key Features

- **Zero-Dataset Biomechanical Rules**: Uses pre-trained 33-point body pose estimation (**MediaPipe Pose** / **YOLOv8n-pose ONNX**) combined with deterministic kinematics:
  - **Spine Inclination Angle ($\theta$)**: Measures torso vector relative to vertical ($0^\circ-30^\circ$ upright, $\ge 58^\circ$ fallen).
  - **Centroid Vertical Velocity ($V_y$)**: Detects rapid downward acceleration spikes.
  - **Aspect Ratio**: Bounding box width vs height validation.
  - **Joint Mobility / Stillness Energy**: Differentiates normal resting from unresponsive motionless states.
- **Acute Cardiac Distress & Levine's Sign Recognition**:
  - Detects characteristic involuntary chest clutching (wrists converging over sternal midpoint) coupled with antalgic trunk flexion.
  - Transitions to **`CORONARY_DISTRESS`** state after a sustained duration threshold (default: 0.8s).
  - Visualized with a dedicated Rose/Amber beacon overlay on the chest center.
- **Inactivity Stopwatch**: Tracks prolonged stillness following a fall or sudden collapse, triggering an emergency **`INACTIVE ALERT`** if motionless beyond a configurable timeout (e.g. 5-30 seconds).
- **Dual Research Dataset Benchmarks**:
  - **Fall Detection**: Validated against the **UR Fall Detection Dataset** (40 ADL + 30 fall clips, 90% recall) and **Le2i FDD**.
  - **Levine's Sign (Chest Pain / Distress)**: Validated against **NTU RGB+D 120 (Action A45: "Touch Chest / Heart Pain")** and the **PatientCare** multimodal clinical dataset.
- **Interactive Web Dashboard & Headless Bridge**:
  - Streamlit web interface with live feed, skeleton overlay, kinematics charts, audio alarms, snapshot captures, and CSV incident export.
  - Headless universal `stream_bridge.py` powering the remote PWA (`aruga.joalvergs.tech`) with MJPEG video, JSON telemetry, file upload analysis, and two-way voice.

---

## 🚀 Quick Start (For Non-Tech Savvy Users)

If you downloaded or cloned this repository:

### 🌟 Just Double-Click `run.bat`!

Double-click the **`run.bat`** file in the project folder for the web dashboard,
**`run_desktop.bat`** for the native desktop app (same features, better
frame rate — no browser roundtrip), or **`run_hallway.bat`** for the
multi-person hallway monitor (see below).

#### What `run.bat` does automatically:
1. **Checks for Python**: Checks if Python is installed on your computer. If not, it displays a clear download link and instructions.
2. **First-Time Auto-Setup**: If the virtual environment (`.venv`) is missing, it automatically creates it and installs all dependencies (`requirements.txt`).
3. **Launches the App**: Starts the dashboard and automatically opens your default browser at `http://localhost:8501`.
4. **Subsequent Runs**: On future runs, it skips installation and launches immediately in 1-2 seconds!

---

## 💻 Recipient System Requirements

For another user to run this repository, their computer needs:

| Requirement | Details |
| :--- | :--- |
| **Operating System** | Windows 10 or Windows 11 (64-bit) |
| **Python** | **Python 3.10, 3.11, or 3.12** installed. *(Crucial: Check **"Add python.exe to PATH"** during Python setup).* |
| **Webcam** | Built-in laptop webcam or plug-and-play USB camera. |
| **Internet (First run only)** | Required once during setup for `run.bat` to download packages via pip. |

---

## 🛠️ Manual Terminal Run (For Developers)

If you prefer using PowerShell / Command Prompt manually:

```powershell
# 1. Create and activate virtual environment
python -m venv .venv
.\.venv\Scripts\activate

# 2. Install dependencies
pip install -r requirements.txt

# 3. Launch Streamlit dashboard
streamlit run app.py
```

Or run the lightweight OpenCV desktop pipeline directly:

```powershell
python main.py --source 0
```

---

## 📁 Project Structure

```
aruga-full-source/
├── start_aruga.sh             # Linux service launcher (bridge + tunnel supervisor)
├── run_tunnel.sh              # Cloudflare tunnel supervisor & auto-registration
├── stream_bridge.py           # Universal RTSP/Webcam stream bridge, MJPEG, & telemetry HTTP server
├── voice_relay.py             # Two-way WebSocket audio relay (nurse <-> patient)
├── run.bat                    # 1-click launcher: Streamlit web dashboard (Windows)
├── run_desktop.bat            # 1-click launcher: native desktop app (Windows)
├── run_hallway.bat            # 1-click launcher: hallway multi-person monitor (Windows)
├── run_bridge.bat             # 1-click launcher: stream_bridge.py (Windows) — webcam/RTSP source
├── app.py                     # Interactive Streamlit Web Dashboard
├── desktop_app.py             # Native desktop client (same UX, threaded pipeline)
├── hallway_app.py             # Hallway/waiting-area monitor (multi-person, zone-aware)
├── main.py                    # Lightweight standalone OpenCV runner
├── requirements.txt           # Dependency specifications
├── core/
│   ├── camera_sources.py      # Camera abstraction (Webcam, RTSP, Tapo credentials helper)
│   ├── frame_pump.py          # Threaded drop-oldest frame reader & reconnect engine
│   ├── hallway_manager.py     # Multi-person risk manager, tracking, zone mapping
│   ├── hallway_risk.py        # Contextual risk assessment (NORMAL, RESTING, SLUMP, FALLEN)
│   ├── yolo_pose_backend.py   # YOLOv8n-pose ONNX runtime inference engine
│   ├── pose_estimator.py      # 33-landmark pose extractor (MediaPipe Pose)
│   ├── person_detector.py     # Multi-person box proposals
│   ├── person_tracker.py      # Centroid track-ID assignment
│   ├── multi_person_manager.py# Per-person pose + fall + inactivity state
│   ├── feature_extractor.py   # Spine angle, aspect ratio, vertical speed, motion energy
│   ├── fall_detector.py       # Finite State Machine (NORMAL, PRE_FALL, FALLEN, RECOVERED)
│   ├── inactivity_monitor.py # Stillness detector & emergency timeout monitor
│   └── zones.py               # Polygon zones calibration (bench, floor, ignore)
├── tools/
│   ├── preflight.py           # Preflight diagnostic check (Tapo, ONNX, bridge, tunnel)
│   ├── live_verify.py         # Automated real-world pipeline verification harness
│   ├── bench_pipeline.py      # Per-stage latency/FPS benchmarking utility
│   ├── eval_clips.py          # Batch evaluation on dataset clips
│   └── test_voice_ws.py       # Voice WebSocket relay verification test
├── utils/
│   ├── hallway_overlay.py     # Multi-person bounding boxes, skeleton, & risk overlay
│   ├── visualizer.py          # Real-time HUD, skeleton lines, status tags
│   ├── logger.py              # Event logging and snapshot manager (CSV download)
│   ├── beep.py                # Platform-aware alert sounds (Linux, macOS afplay, Windows)
│   ├── risk_palette.py        # Shared color palette across all UI surfaces
│   └── synthetic_generator.py # Procedural mannequin fall simulator for testing
└── assets/                    # Models (yolov8n-pose.onnx) and demo clips
```

---

## 📱 Which app to use

- **`hallway_app.py`** — flagship desktop GUI: multi-person (up to 10), zone calibration
  (bench / floor / ignore), lost-person verify banner. Clinic hallways & waiting areas.
- **`stream_bridge.py`** — universal headless bridge for Web/PWA clients (`aruga.joalvergs.tech`):
  serves MJPEG stream (`/video_feed`), single-frame snapshot (`/video_frame`), real-time JSON
  telemetry (`/telemetry`), file upload analysis (`/analyze_file`), and two-way voice relay (`/voice`).
- **`desktop_app.py`** — local single / 2–3-person monitor; same UX as the
  dashboard, best frame rate (no browser roundtrip).
- **`app.py`** — browser dashboard for review & demo: live view, telemetry,
  incident log with CSV export.

All surfaces share the same camera drivers, detectors, alarm sound, sensitivity
presets, and the 10-minute **Acknowledge** button.

---

## 🌐 Cloudflare Tunnel & Edge Stream Bridge

To connect the edge camera pipeline to the remote web dashboard (`https://aruga.joalvergs.tech`):

```bash
# 1. Start the Stream Bridge (defaults to port 8080)
python stream_bridge.py --source 0
# Or with a Tapo camera:
python stream_bridge.py --tapo-ip 192.168.1.50 --tapo-user camera_user --tapo-pass camera_pass --stream stream2

# 2. Start the tunnel supervisor (auto-registers public URL with aruga-api):
./run_tunnel.sh

# Or start all services via systemd launcher:
./start_aruga.sh
```

### Verification & Diagnostic Tools

- **System Preflight Diagnostic**:
  ```bash
  python tools/preflight.py --tapo-ip 192.168.1.50 --tapo-user USER --tapo-pass PASS --probe
  ```
- **Automated Pipeline Verification**:
  ```bash
  python tools/live_verify.py --url rtsp://USER:PASS@IP:554/stream1 --seconds 30
  # Or headless self-test against video:
  python tools/live_verify.py --file assets/synthetic_fall_demo.mp4
  ```

---

### Research Dataset Benchmarks

Fetch and inspect evaluation clips using `tools/fetch_datasets.py`:

```bash
# Display dataset catalog, download instructions, and agreements
python tools/fetch_datasets.py --info

# Assemble UR fall evaluation clips into assets/eval_clips/
python tools/fetch_datasets.py --falls 1 --adls 1

# Batch score clips against the pipeline (writes eval_report.csv)
python tools/eval_clips.py
```

1. **UR Fall Detection Dataset & Le2i FDD**: Acted falls and Activities of Daily Living (ADL) across domestic and hallway setups.
2. **NTU RGB+D 120 (Action A45: "Touch Chest / Heart Pain")**: Canonical action benchmark for chest-clutching biometric validation (Levine's sign).
3. **PatientCare Multimodal Dataset**: Clinical monitoring benchmark covering falls and acute physical distress.

---

## ⚙️ Configuration & Sensitivity Tuning

You can adjust these parameters live in the dashboard sidebar:

| Parameter | Default | Description |
|-----------|---------|-------------|
| **Spine Angle Threshold** | `58.0°` | Angle relative to vertical where posture is considered horizontal/fallen. |
| **Velocity Threshold ($V_y$)** | `0.32` | Downward speed threshold triggering falling transition. |
| **Inactivity Timeout** | `6.0s` | Seconds of motionless horizontal posture before triggering emergency alert. |
| **Levine Hold Duration** | `0.8s` | Continuous seconds of sternal clutching + trunk flexion before triggering `CORONARY_DISTRESS`. |
| **Audio Warning** | Enabled | Plays audible alarm warning upon fall, inactivity, or coronary distress. |

---

## 🏥 Hallway Monitor (`hallway_app.py` — clinic hallways / waiting areas)

Self-contained multi-person version. One YOLOv8n-pose ONNX inference per frame
(all bodies at once) via ONNX Runtime; the fastest execution provider is
benchmarked at startup (**CUDA → DirectML (AMD/Intel iGPU) → CPU**), so the same
code runs on a Ryzen 3 laptop and scales to a gaming rig — the active backend
shows in the status bar. Models ship in `assets/models/`; after setup the app
runs **fully offline**.

Extra risk states for seating areas: **RESTING** (reclined + still on a bench,
no alarm) and **SLUMP** (sudden collapse into seating — check on person).
Draw bench/floor/ignore polygons via **Calibrate Zones** (needs a captured
empty-hallway background); with no zones file the whole frame is floor.
Each saved camera keeps its own calibration file.

```powershell
.\.venv\Scripts\python.exe hallway_app.py
# or: python tools/eval_clips.py   (batch-score recorded clips, headless)
#     python tests/simulate.py     (logic suite, no footage needed)
```

Camera sources: USB webcams (auto-discovered with a ⟳ rescan), IP/CCTV
cameras over **RTSP**/RTMP/HTTP (with connection test + auto-reconnect), and
video files. Save named cameras under 💾 Saved Cameras to switch bodies
clearly — each keeps its own zone calibration. All three apps
(`hallway_app`, `desktop_app`, `app.py`) share the same camera and frame
drivers (`core/camera_sources.py`, `core/frame_pump.py`) — no torch needed
anywhere; the .onnx model ships in assets/models/, so the app runs fully
offline after setup.

Scale-up path (no code changes): on an NVIDIA machine replace
`onnxruntime-directml` with `onnxruntime-gpu` in `requirements.txt`, optionally
drop in a larger `*-pose.onnx` as `assets/models/yolov8n-pose.onnx`.

### Performance notes (Linux)

- Startup benchmarks ONNX intra-op thread counts and picks the fastest
  (hyperthreaded CPUs often run faster at 2 threads than at 4 — the
  `[YoloPose] threads=N` lines show the trial results).
- Single-person apps (`app.py`, `desktop_app.py`) run ~5× faster with
  MediaPipe than the YOLO-ONNX fallback: use a Python ≤3.12 venv where
  `mediapipe==0.10.14` installs (`uv venv --python 3.12 .venv312 && uv pip
  install --python .venv312/bin/python -r requirements.txt`). Python 3.13+
  falls back to YOLO-ONNX automatically.
- `python tools/bench_pipeline.py` prints per-stage ms/fps on your hardware
  (run on an idle CPU).
- Live sources (RTSP/webcam) use a reader thread with drop-oldest buffering,
  so slow inference adds no stream lag — analysis always sees the newest frame.

> **Licensing note:** YOLO pose weights are AGPL-3.0 (Ultralytics export) and the
> UR/Le2i eval datasets are non-commercial/research — fine for internal
> evaluation; review licensing before any commercial deployment.
