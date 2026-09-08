# packettracer-distrobox

Run Cisco Packet Tracer 9 on any Linux distribution (Fedora, Arch Linux, openSUSE, Debian, Void, etc.) using Distrobox.

## The problem

Cisco only packages Packet Tracer for Ubuntu LTS releases. Repackaging the `.deb` directly on Fedora, Arch Linux, or openSUSE fails because modern host libraries (Qt, OpenSSL, ICU) diverge from what Cisco linked against.

Packet Tracer 9.x ships internally as an AppImage with bundled Qt6 libraries. Running it in an Ubuntu Distrobox container provides the native environment it expects while keeping your host display server (Wayland or X11), audio, and home directory.

Three specific issues break naive installs inside a container:
1. Ubuntu 24.04+ ships `fuse3` (`/bin/fusermount3`), while the AppImage runner looks for `/bin/fusermount`.
2. The bundled QtWebEngine components crash without `libOpenGL.so.0`, `libnss3`, and `libpulse0`.
3. The `.deb` extracts `/opt/pt/packettracer.AppImage` without putting a `.desktop` file into `/usr/share/applications`, which causes `distrobox-export --app` to fail.

The steps below address all three.

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

### 3. Sync the icon to the host

Run this on your host to ensure desktop launchers (GNOME, KDE Plasma, XFCE) display the application icon:

```sh
mkdir -p ~/.local/share/icons
distrobox enter ubuntu_box -- cat /usr/share/pixmaps/packettracer.png > ~/.local/share/icons/packettracer.png
```

Launch Packet Tracer by running `packettracer` from any host terminal or selecting **Cisco Packet Tracer** in your application menu.

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

If your container environment restricts FUSE mounts, tell the AppImage runtime to extract to a temporary folder instead:
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

### Benign console output

When starting from a terminal, you may see:
```
[...:ERROR:bus.cc(...)] Failed to connect to the bus: Failed to connect to socket /run/dbus/system_bus_socket
sh: 1: last: not found
```

These are harmless warnings from QtWebEngine looking for system D-Bus and the `last` utility inside the container. They do not affect Packet Tracer.

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
