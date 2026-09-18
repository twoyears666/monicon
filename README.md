# Monicon

Monicon is an iPadOS 16/17 SwiftUI capture-card viewer for playing Nintendo Switch (or other HDMI source) video on iPad.

## Current design

- USB capture cards are discovered through `AVCaptureDevice` (the supported iPadOS path for UVC-compatible devices).
- Video is shown with `.scaledToFit`, so the entire frame remains visible and letterboxing is preferred over cropping.
- Capture-card audio is routed to the iPad speaker/headphones only; the iPad microphone is never added to the session.
- Resolution and frame-rate controls are exposed in the UI and applied to the selected format when possible.
- MetalFX is detected as an optional capability. The first version keeps the video path on AVFoundation for stability; a later Metal texture renderer can opt into spatial upscaling without changing the UI.

## iOS 16 / TrollStore note

Apple does not expose a general-purpose UVC permission API on iOS 16. This project uses the public AVFoundation external-camera route and does not promise support for every capture card. The `tipa` workflow is intentionally a packaging hook for a TrollStore-signed build; signing and injection of a private entitlement must be supplied by the device owner. Do not ship private entitlements through the App Store build.

## Build

Open `Monicon.xcodeproj` in Xcode 15+ and select an iPadOS 16+ destination. The repository includes a GitHub Actions workflow that builds an unsigned IPA artifact on a macOS runner.

## Hardware expectations

Use a UVC class-compliant HDMI capture card with a powered USB-C hub. Some cards advertise MJPEG-only formats or expose audio as a separate USB interface; those devices may need a lower format selected in Settings.

