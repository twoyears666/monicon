# Monicon

Monicon is an iPadOS 16 TrollStore-only capture-card viewer for playing Nintendo Switch (or other HDMI source) video on iPad.

## Scope

This project intentionally does not ship an iOS 17 public/App Store build. The only target is iPadOS 16 on TrollStore-compatible devices, packaged as a TIPA file.

## Architecture

- Direct UVC backend is the target path: libusb/libuvc enumerates the capture card and receives UVC frames.
- MJPEG/YUYV/H.264 frames are decoded in-process using libjpeg-turbo, Metal shaders, or VideoToolbox as appropriate.
- Capture-card audio is routed to the iPad speaker/headphones only; the iPad microphone is not used.
- The video viewport uses aspect-fit, so black bars are preferred over cropping.
- Resolution and frame-rate selection are exposed in the UI.
- MetalFX is optional and only applies to the custom Metal texture path.

## iPadOS 16 / TrollStore

Apple's public iOS APIs do not provide a general-purpose raw USB host API for arbitrary UVC devices on iPadOS 16. libuvc itself does not grant USB permissions; it is built on top of libusb. The direct backend therefore requires a TrollStore/private-entitlement/device-specific path and is not intended for App Store distribution.

The repository's normal build output is an unsigned TIPA input for TrollStore. Signing, entitlement injection, and any device-specific USB host shim must be supplied by the device owner.

## Build

GitHub Actions builds the iPadOS 16 TrollStore package only. Download the TIPA artifact from the Actions run and install it with TrollStore.

Use a powered USB-C hub and a UVC class-compliant HDMI capture card.
