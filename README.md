# packettracer-distrobox

Guide for running Cisco Packet Tracer on any Linux distribution (Fedora, Arch Linux, openSUSE, Debian, Void, etc.) using Distrobox.

## Why this approach

Cisco only distributes Packet Tracer for Linux as an Ubuntu `.deb` package. Inside the `.deb`, Packet Tracer runs as an AppImage with bundled Qt6 and WebEngine components.

Running it directly on non-Ubuntu hosts or converting the package with tools like `alien` often fails due to library mismatches (glibc, OpenSSL, NSS). Running it in an Ubuntu Distrobox container solves this while keeping your host display server (Wayland or X11), audio, GPU, and files accessible.

Two specific quirks in Packet Tracer 9.x need manual attention:
1. **FUSE executable mismatch**: The bundled AppImage calls `fusermount`, but Ubuntu 24.04+ base images only provide `/bin/fusermount3`. Without a symlink, launch fails silently or outputs `fuse: failed to exec fusermount`.
2. **Missing desktop registration**: The Cisco `.deb` extracts an AppImage to `/opt/pt/` without installing a system `.desktop` file into `/usr/share/applications`. `distrobox-export` needs a proper `.desktop` file before it can expose the app to your host desktop environment.

## Prerequisites

Install `distrobox` and a container engine (`podman` or `docker`) using your host package manager:

- Fedora: `sudo dnf install distrobox podman`
- Arch Linux: `sudo pacman -S distrobox podman`
- openSUSE: `sudo zypper install distrobox podman`
- Debian / Ubuntu: `sudo apt install distrobox podman`

Download the official Cisco Packet Tracer `.deb` installer from Cisco NetAcad or Skills for All.

## Step-by-step setup

### 1. Create and enter the container

Create a container named `ubuntu_box` using the official Ubuntu image, then enter it:

```sh
distrobox create --name ubuntu_box --image docker.io/library/ubuntu:latest --yes
distrobox enter ubuntu_box
```

### 2. Install dependencies inside the container

Update package lists and install FUSE along with runtime libraries needed by Packet Tracer's GUI and QtWebEngine:

```sh
sudo apt update
sudo apt install -y \
    fuse3 \
    libopengl0 \
    libgl1 \
    libegl1 \
    libnss3 \
    libnspr4 \
    libpulse0 \
    libdeflate0 \
    libjbig0 \
    libglib2.0-bin
```

Link `fusermount3` so the AppImage runtime can mount itself:

```sh
sudo ln -sf /bin/fusermount3 /usr/local/bin/fusermount
```

### 3. Install the Cisco package

Install the `.deb` file you downloaded. Distrobox mounts your host home directory automatically, so your files in `~/Downloads` are available:

```sh
sudo apt install -y ~/Downloads/CiscoPacketTracer_9.0.1_Ubuntu_64bit.deb
```

Adjust the filename if you have a different version.

### 4. Set up desktop entry and icon

Extract the bundled icon from the AppImage and install it system-wide inside the container:

```sh
cd /tmp
/opt/pt/packettracer.AppImage --appimage-extract app.png
sudo cp squashfs-root/app.png /usr/share/pixmaps/packettracer.png
rm -rf squashfs-root
```

Create `/usr/share/applications/packettracer.desktop`:

```sh
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

### 5. Export binary and desktop launcher to host

Inside the container, run:

```sh
distrobox-export --bin /usr/local/bin/packettracer --export-path ~/.local/bin
distrobox-export --app packettracer --export-label none
```

Now exit back to your host:

```sh
exit
```

### 6. Copy icon and refresh host desktop database

On your host terminal, place the icon in `~/.local/share/icons/` so your host desktop environment renders it:

```sh
mkdir -p ~/.local/share/icons
distrobox enter ubuntu_box -- cat /usr/share/pixmaps/packettracer.png > ~/.local/share/icons/packettracer.png
update-desktop-database ~/.local/share/applications 2>/dev/null || true
```

## Running

From any host terminal:

```sh
packettracer
```

Or open **Cisco Packet Tracer** from your host application launcher (GNOME, KDE Plasma, XFCE, etc.).

## Troubleshooting

### AppImage fails to mount (`fuse: failed to exec fusermount`)

Verify the symlink inside the container:

```sh
distrobox enter ubuntu_box -- which fusermount
```

If missing, recreate it:

```sh
distrobox enter ubuntu_box -- sudo ln -sf /bin/fusermount3 /usr/local/bin/fusermount
```

If your kernel or container environment forbids FUSE mounts, tell the AppImage to extract to a temporary directory before running:

```sh
distrobox enter ubuntu_box -- env APPIMAGE_EXTRACT_AND_RUN=1 packettracer
```

### Missing shared libraries (`libOpenGL.so.0`, `libnss3`, etc.)

If Packet Tracer exits with:

```
./PacketTracer: error while loading shared libraries: libOpenGL.so.0: cannot open shared object file
```

Install the missing packages inside the container:

```sh
distrobox enter ubuntu_box -- sudo apt install -y libopengl0 libgl1 libegl1 libnss3 libnspr4 libpulse0 libdeflate0 libjbig0
```

### Benign console warnings

Console output containing:

```
[...:ERROR:bus.cc(...)] Failed to connect to the bus: Failed to connect to socket /run/dbus/system_bus_socket
sh: 1: last: not found
```

These come from QtWebEngine looking for system D-Bus and the `last` command. They do not affect Packet Tracer's operations.

## Removal

To unexport the launcher and binary from your host:

```sh
distrobox enter ubuntu_box -- distrobox-export --delete --bin /usr/local/bin/packettracer --export-path ~/.local/bin
distrobox enter ubuntu_box -- distrobox-export --delete --app packettracer
rm -f ~/.local/share/icons/packettracer.png
```

To delete the container and free disk space:

```sh
distrobox stop ubuntu_box
distrobox rm ubuntu_box
```
