# Setup Guide

**Read this first**: none of this has been run against physical AI HAT+ 2
hardware during development - see the README's disclaimer. Every command
below is sourced from Raspberry Pi's and Hailo's own current documentation
(cited inline), not guessed. Treat this as a well-researched starting point,
and please report back what actually happens on real hardware.

## Which AI HAT do you have?

There are two different products, and they use different, mutually
exclusive software packages:

| Product | Chip | Package | HailoRT version (at time of writing) |
|---|---|---|---|
| AI HAT+ (original) | Hailo-8 or Hailo-8L | `hailo-all` | 4.23 |
| **AI HAT+ 2** (this project) | Hailo-10H | `hailo-h10-all` | 5.1.1 / 5.2.0 / 5.3.0 |

Installing the wrong one, or both, breaks the setup - the Raspberry Pi
Foundation's own docs state these two packages "can't co-exist." If you're
not sure which board you have, check the physical label on the HAT, or (once
`hailo-h10-all` or `hailo-all` is installed) run `hailortcli fw-control
identify` and check the reported chip name.

Source: [raspberrypi.com/documentation/computers/ai.html](https://www.raspberrypi.com/documentation/computers/ai.html)

## 1. OS requirement: Raspberry Pi OS Trixie, not Bookworm

The current `hailo-apps`/HailoRT release (4.23 for Hailo-8/8L; 5.x for the
Hailo-10H this project targets) is **built for Debian Trixie and explicitly
does not support Bookworm**, per Hailo's own release announcement. If you're
on Bookworm, you'd need to pin to an older HailoRT release instead of
following this guide as-is - check Hailo's GitHub releases for the last
Bookworm-compatible version.

Flash **Raspberry Pi OS (64-bit), Trixie or newer** via
[Raspberry Pi Imager](https://www.raspberrypi.com/software/), same headless
SSH setup approach as any other Pi project (enable SSH, set credentials, in
Imager's settings before writing).

Source: [community.hailo.ai - HailoRT 4.23 / Apps Infrastructure v25.10.0 release notes](https://community.hailo.ai/t/hailort-4-23-apps-infrastructure-v25-10-0-released/18294)

## 2. Install the AI HAT+ 2 packages

```bash
sudo apt-get update
sudo apt-get install -y dkms
sudo apt-get install -y hailo-h10-all
sudo reboot
```

`dkms` is a prerequisite - under Trixie, the Hailo kernel driver is built via
DKMS as part of package installation rather than shipped as a
pre-built Debian package. This project's `install.sh` does both of these
steps for you.

After rebooting, verify the device is detected:
```bash
hailortcli fw-control identify
dmesg | grep -i hailo
```
If neither shows the Hailo device, see [Troubleshooting](#troubleshooting)
below before continuing.

Source: [raspberrypi.com/documentation/computers/ai.html](https://www.raspberrypi.com/documentation/computers/ai.html)

## 3. Install hailo-apps (Hailo's own application suite)

```bash
git clone https://github.com/hailo-ai/hailo-apps.git ~/.local/share/hailo-apps
cd ~/.local/share/hailo-apps
./install.sh --all
```

This is a large, actively-developed repo maintained by Hailo, not something
this project vendors or copies - `install.sh` in this repo just clones and
runs their installer. It contains far more than face detection (pose
estimation, segmentation, depth estimation, generic object detection) - this
project only uses the `face_recognition` pipeline app within it, run without
ever populating its face database.

Note: the older `hailo-ai/hailo-rpi5-examples` repo you may find in searches
is now explicitly marked outdated by Hailo themselves, in favor of
`hailo-apps` - don't follow setup guides based on the older repo.

Source: [hailo-apps repo](https://github.com/hailo-ai/hailo-apps),
[face_recognition README](https://github.com/hailo-ai/hailo-apps/blob/main/hailo_apps/python/pipeline_apps/face_recognition/README.md)

## 4. Camera setup

**Recommended: a USB webcam.** Simplest and most reliable - `face_recognition.py --input usb`
just works against a standard V4L2 device with no camera-stack-specific
configuration.

**Raspberry Pi Camera Module**: two options, both supported by the
underlying app via the `--input` flag:
- `--input rpi` - uses picamera2 to capture frames and feeds them into the
  GStreamer pipeline. This is the path the app's own source-detection logic
  favors for Pi camera input.
- `--input libcamera` - uses the `libcamerasrc` GStreamer element directly
  instead. **Known issue**: a Hailo community thread reports `libcamerasrc`
  sometimes failing to find a camera that `picamera2` itself detects fine -
  if you hit "camera not found" with `--input libcamera`, try `--input rpi`
  instead before assuming a hardware problem.

Set your choice in `~/.config/face-detect-aihat/detect.env`
(`CAMERA_SOURCE=usb`, `rpi`, or `libcamera`) after running `install.sh`.

Sources: [hailo-apps GStreamer helper pipelines doc](https://github.com/hailo-ai/hailo-apps/blob/main/doc/developer_guide/gstreamer_helper_pipelines.md),
[Hailo community - libcamerasrc vs picamera2 thread](https://community.hailo.ai/t/gstreamer-libcamerasrc-cannot-find-camera-but-picamera2-works/11633)

## 5. Run a manual dry run before enabling the service

```bash
~/.local/share/face-detect-aihat/scripts/run-face-detect.sh
```

Confirm you see live detection output before moving on - this is the step
most likely to need troubleshooting on a first setup, and it's much easier
to debug interactively than through systemd's logs.

## 6. Enable the persistent background service

```bash
systemctl --user enable --now face-detect.service
systemctl --user status face-detect.service --no-pager
journalctl --user -u face-detect -f    # watch live logs
```

Because lingering was enabled by `install.sh`, this survives logout and
reboot with no login required.

## Troubleshooting

These are real, documented issues from Hailo's own community forum and
GitHub repos, not hypothetical - included here so you don't have to
rediscover them from scratch.

- **"Driver version (X) is different from library version (Y)" at device
  init.** A known HailoRT bug where firmware auto-updates independently of
  the installed userspace library. Fix: pin and hold matching versions
  across all four Hailo packages, e.g. for the historical 4.19 case:
  ```bash
  sudo apt-get install -y hailo-tappas-core=<version> hailort=<version> \
      hailo-dkms=<version> python3-hailort=<version>
  sudo apt-mark hold hailo-tappas-core hailort hailo-dkms python3-hailort
  ```
  Check `apt-cache policy hailort` for what's actually available before
  picking a version. Source: [community.hailo.ai - critical HailoRT 4.20 compatibility issue thread](https://community.hailo.ai/t/critical-hailort-4-20-compatibility-issue-with-rpi-kernel-temporary-fix-available/10277)

- **"HailoRT version not detected. Is HailoRT installed?" even though
  `hailortcli` confirms it's installed and working.** A known bug in
  `hailo-apps`' own detection logic on Trixie + Python 3.13, caused by
  hardcoding an expected package name and by hostname pattern-matching
  (looking for `rpi`/`raspberrypi`/`pi` in your hostname) to detect a
  Raspberry Pi. If your Pi has a custom hostname that doesn't match that
  pattern, this can misfire. Hailo's devs have acknowledged this and were
  moving detection to `/proc/device-tree/model` instead - check whether
  your `hailo-apps` checkout predates that fix if you hit this. Source:
  [community.hailo.ai - HailoRT installed but apps-infra says not detected, Pi 5 Trixie Python 3.13](https://community.hailo.ai/t/hailort-installed-device-works-but-apps-infra-says-hailort-not-detected-pi-5-trixie-python-3-13/18527)

- **PCIe / GStreamer issues on Pi 5** (reported against the older
  `hailo-rpi5-examples` repo, but the underlying causes are host-level and
  likely still relevant):
  ```bash
  # PCIe descriptor page-size issue:
  echo "options hailo_pci force_desc_page_size=4096" | sudo tee /etc/modprobe.d/hailo_pci.conf

  # GStreamer/libgomp issue - add to ~/.bashrc:
  export LD_PRELOAD=/usr/lib/aarch64-linux-gnu/libgomp.so.1
  ```
  Only apply these if you're actually hitting the corresponding symptom -
  don't apply speculatively. Source: [hailo-rpi5-examples Pi 5 install doc](https://github.com/hailo-ai/hailo-rpi5-examples/blob/main/doc/install-raspberry-pi5.md)

- **Wrong AI HAT package installed.** If you installed `hailo-all` instead
  of `hailo-h10-all` (or vice versa), remove it and install the correct one
  for your exact board - see [Which AI HAT do you have?](#which-ai-hat-do-you-have)
  above. Don't attempt to have both installed simultaneously.

## Known limitations worth knowing about

- This targets the AI HAT+ 2 (Hailo-10H) specifically. Adapting it for the
  original AI HAT+ (Hailo-8/8L) mainly means swapping `hailo-h10-all` for
  `hailo-all` in `install.sh` - the rest of this project's code doesn't
  reference the chip directly, since it's just invoking `hailo-apps`' own
  CLI - but that swap hasn't been tested either.
- Detection-only is enforced by convention (never running `--mode train`),
  not by a code-level restriction. If you run the training step, recognition
  turns on for anyone in the trained database - see [Extending to full
  recognition](./README.md#extending-to-full-recognition-optional) in the
  README.
- The `face_recognition` app within `hailo-apps` is marked **beta** by Hailo
  themselves - APIs may change upstream, which could break this project's
  wrapper script's assumptions about CLI flags/paths.
