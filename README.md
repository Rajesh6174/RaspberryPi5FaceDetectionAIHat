# Face Detect AI HAT+ 2

Real-time face detection on a Raspberry Pi 5 with the **AI HAT+ 2** (Hailo-10H
accelerator), running as a persistent systemd service.

## About

This project deploys Hailo's own official, maintained
[`hailo-apps`](https://github.com/hailo-ai/hailo-apps) face recognition
application in **detection-only mode**: it detects faces in real time using
the Hailo-10H accelerator, but the face database is never populated, so no
detected face is ever matched to an identity. It's a packaging/deployment
layer, not a custom detection pipeline - all the actual computer-vision code
(SCRFD face detection, the GStreamer pipeline, the Hailo inference calls) is
Hailo's own, unmodified. See [Architecture](#architecture) below for exactly
where the line is drawn.

**Why detection-only by design:** it's a smaller, more reliable surface than
full recognition (no enrollment step, no face database to manage, no identity
matching to get wrong), and a sensible first milestone. Full recognition is
one command away if you want it later - see [Extending to full
recognition](#extending-to-full-recognition-optional).

**Important - this has not been tested on physical hardware.** It was built
without an AI HAT+ 2 available on the development machine. Every install step
and command here is grounded in Hailo's and Raspberry Pi's own current
documentation (not guessed), but "documented to work" and "verified working"
are different things - see [SETUP.md](./SETUP.md) for what's been checked and
what hasn't, and please open an issue with what you found if something here
doesn't match your actual hardware.

## Hardware required

- Raspberry Pi 5
- **AI HAT+ 2** (Hailo-10H) - not the original AI HAT+ (Hailo-8/8L); they use
  different, mutually exclusive software packages. See
  [SETUP.md](./SETUP.md#which-ai-hat-do-you-have) if you're not sure which one
  you have.
- A camera - a USB webcam is the simplest, most reliable option (recommended
  default); a Raspberry Pi Camera Module also works, with one documented
  caveat - see [SETUP.md](./SETUP.md#camera-setup).
- Active cooling recommended, same reasoning as any sustained Pi 5 workload.

## Installation

```bash
git clone https://github.com/Rajesh6174/RaspberryPi5FaceDetectionAIHat.git ~/.local/share/face-detect-aihat
cd ~/.local/share/face-detect-aihat
./install.sh
```

This installs the AI HAT+ 2 packages (`dkms`, `hailo-h10-all`), clones and
installs Hailo's own `hailo-apps`, and sets up the systemd service - but does
**not** start the service automatically. Do a manual dry run first (the
script tells you the exact command) before enabling it as a background
service - see [SETUP.md](./SETUP.md) for the full walkthrough, including the
real, documented gotchas around Hailo's software stack (OS version
sensitivity, driver/library version mismatches, package-name confusion
between the two AI HAT+ generations).

## Extending to full recognition (optional)

The underlying app already supports this - this project just doesn't
automate it, to keep the default scope detection-only:

```bash
source ~/.local/share/hailo-apps/setup_env.sh
cd ~/.local/share/hailo-apps/hailo_apps/python/pipeline_apps/face_recognition
python face_recognition.py --mode train   # populate the face database
```

Once trained, `run-face-detect.sh` (and the systemd service) will start
matching detected faces against the enrolled database automatically - no
code change needed, since it's the same `--mode run` invocation either way.
See [hailo-apps' own face_recognition README](https://github.com/hailo-ai/hailo-apps/blob/main/hailo_apps/python/pipeline_apps/face_recognition/README.md)
for the enrollment image format and the optional web interface for managing
enrolled faces.

## Architecture

```
Camera (USB or Pi Camera Module)
        |
        v
hailo-apps' face_recognition.py --mode run   <- Hailo's own code, unmodified
        |  (SCRFD face detection on the Hailo-10H accelerator)
        |  (LanceDB match step runs, but the database is empty - nothing
        |   detected ever matches, so this is detection-only in practice)
        v
run-face-detect.sh                            <- this project: wraps the
        |                                        above call, handles env
        v                                        config, headless DISPLAY
face-detect.service (systemd --user)          <- this project: keeps it
                                                  running persistently
```

## Update

```bash
cd ~/.local/share/face-detect-aihat
git pull
./install.sh
systemctl --user restart face-detect.service
```

## Uninstall

```bash
systemctl --user disable --now face-detect.service
rm ~/.config/systemd/user/face-detect.service
systemctl --user daemon-reload
rm -rf ~/.local/share/face-detect-aihat ~/.config/face-detect-aihat
# Optionally also remove hailo-apps itself:
rm -rf ~/.local/share/hailo-apps
```

## License

Distributed under the MIT License, see [LICENSE](./LICENSE) for more information.

## Issues

Since this hasn't been verified against physical hardware, issue reports
with what actually happened on real AI HAT+ 2 hardware are especially
valuable - open one on the
[GitHub Issues](https://github.com/Rajesh6174/RaspberryPi5FaceDetectionAIHat/issues) page.

## Acknowledgements

Built entirely on top of:

- [hailo-apps](https://github.com/hailo-ai/hailo-apps) - Hailo's own official
  application suite, including the face detection/recognition pipeline this
  project deploys
- [Hailo Model Zoo](https://github.com/hailo-ai/hailo_model_zoo) - source of
  the SCRFD face detection and ArcFace/MobileFaceNet recognition models
- [Raspberry Pi AI documentation](https://www.raspberrypi.com/documentation/computers/ai.html) -
  the official AI HAT+ setup reference
