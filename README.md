# packettracer-distrobox

Run Cisco Packet Tracer 9 on any distro using Distrobox.

## Why distrobox

Cisco only ships Packet Tracer as a `.deb` for Ubuntu LTS. Installing that `.deb` directly on other distros fails because host libraries (Qt, OpenSSL, ICU) don't match what Cisco built against.

Packet Tracer 9.x is an AppImage with its own Qt6 bundled in. An Ubuntu Distrobox container gives it the environment it expects, and it still uses your display (Wayland or X11), audio, and home directory.

Three things break a plain install in a container:
1. Ubuntu 24.04+ ships `fuse3` (`/bin/fusermount3`), while the AppImage runner looks for `/bin/fusermount`.
2. The bundled QtWebEngine components crash without `libOpenGL.so.0`, `libnss3`, and `libpulse0`.
3. The `.deb` extracts `/opt/pt/packettracer.AppImage` with no `.desktop` file in `/usr/share/applications`, so `distrobox-export --app` fails.

## Prerequisites

- `distrobox` and `podman` (or `docker`) installed on host.
- Cisco Packet Tracer `.deb` downloaded from Cisco NetAcad or Skills for All.

## Setup

### 1. Create and enter the container

```sh
distrobox create --name ubuntu_box --image ubuntu:latest --yes
distrobox enter ubuntu_box
```

### 2. Configure dependencies and install inside the container

Update apt, install runtime libraries, and create the `fusermount` symlink:

```sh
sudo apt update
sudo apt install -y fuse3 libopengl0 libgl1 libegl1 libnss3 libnspr4 libpulse0 libdeflate0 libjbig0 libglib2.0-bin
sudo ln -sf /bin/fusermount3 /usr/local/bin/fusermount
```

Install the downloaded `.deb` package (Distrobox shares your host home directory, so `~/Downloads` is available):

```sh
sudo apt install -y ~/Downloads/CiscoPacketTracer_*.deb
```

Replace the default `/usr/local/bin/packettracer` symlink created by Cisco's installer with a wrapper that isolates Qt from host KDE/dark palettes:

```sh
sudo tee /usr/local/bin/packettracer > /dev/null << 'EOF'
#!/bin/sh
export XDG_CURRENT_DESKTOP=""
export KDE_FULL_SESSION=""
export KDE_SESSION_VERSION=""
export QT_QPA_PLATFORMTHEME=""
export QT_STYLE_OVERRIDE="Fusion"
exec /opt/pt/packettracer.AppImage "$@"
EOF
sudo chmod +x /usr/local/bin/packettracer
```

Extract the application icon and register a system `.desktop` file:

```sh
cd /tmp && /opt/pt/packettracer.AppImage --appimage-extract app.png
sudo cp squashfs-root/app.png /usr/share/pixmaps/packettracer.png && rm -rf squashfs-root

sudo tee /usr/share/applications/packettracer.desktop > /dev/null << 'EOF'
[Desktop Entry]
Name=Cisco Packet Tracer
Type=Application
Categories=Education;Network;
Exec=/usr/local/bin/packettracer %f
Icon=packettracer
Terminal=false
StartupNotify=true
MimeType=application/x-pkt;application/x-pka;application/x-pkz;application/x-pks;application/x-pksz;
EOF
```

Export the binary and desktop launcher to your host, then exit:

```sh
distrobox-export --bin /usr/local/bin/packettracer --export-path ~/.local/bin
distrobox-export --app packettracer --export-label none
exit
```

### 3. Copy the icon to the host

Run this on your host so the app menu shows the icon:

```sh
mkdir -p ~/.local/share/icons
distrobox enter ubuntu_box -- cat /usr/share/pixmaps/packettracer.png > ~/.local/share/icons/packettracer.png
```

Launch it with `packettracer` from a terminal, or pick Cisco Packet Tracer in your app menu.

## Troubleshooting

### AppImage fails to mount

Error:
```
fuse: failed to exec fusermount: No such file or directory
```

Fix: Create the symlink inside the container:
```sh
distrobox enter ubuntu_box -- sudo ln -sf /bin/fusermount3 /usr/local/bin/fusermount
```

If FUSE mounts are blocked in your container, extract on run instead:
```sh
distrobox enter ubuntu_box -- env APPIMAGE_EXTRACT_AND_RUN=1 packettracer
```

### Missing OpenGL or NSS libraries

Error:
```
./PacketTracer: error while loading shared libraries: libOpenGL.so.0: cannot open shared object file
```

Fix: Install the graphics and security runtime libraries in the container:
```sh
distrobox enter ubuntu_box -- sudo apt install -y libopengl0 libgl1 libegl1 libnss3 libnspr4 libpulse0
```

### Weird UI colors or dark theme clashes on KDE

Packet Tracer hardcodes light canvas and icon assets. When host KDE dark mode is active, Qt inherits `~/.config/kdeglobals`, causing unreadable black text on dark buttons and inverted workspace elements.

Fix: Ensure `/usr/local/bin/packettracer` inside the container isolates the environment as shown in step 2:
```sh
export XDG_CURRENT_DESKTOP=""
export KDE_FULL_SESSION=""
export KDE_SESSION_VERSION=""
export QT_QPA_PLATFORMTHEME=""
export QT_STYLE_OVERRIDE="Fusion"
```

### Harmless terminal output

When starting from a terminal, you may see:
```
[...:ERROR:bus.cc(...)] Failed to connect to the bus: Failed to connect to socket /run/dbus/system_bus_socket
sh: 1: last: not found
```

Harmless warnings. QtWebEngine looks for system D-Bus and the `last` utility in the container, Packet Tracer works fine without them.

## Removal

To unexport the launcher and binary from your host:

```sh
distrobox enter ubuntu_box -- distrobox-export --delete --bin /usr/local/bin/packettracer --export-path ~/.local/bin
distrobox enter ubuntu_box -- distrobox-export --delete --app packettracer
rm -f ~/.local/share/icons/packettracer.png
```

To delete the container:

```sh
distrobox stop ubuntu_box && distrobox rm ubuntu_box
```
