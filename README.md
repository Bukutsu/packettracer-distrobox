# packettracer-distrobox

Run Cisco Packet Tracer on any Linux distribution (Fedora, Arch Linux, openSUSE, Debian, Void, etc.) using Distrobox and Podman or Docker.

## Why this exists

Cisco only distributes Packet Tracer for Linux as an Ubuntu `.deb` package. Inside the package, Packet Tracer runs as an AppImage coupled to specific library versions (Qt6, WebEngine, NSS, OpenSSL, and FUSE).

Installing Packet Tracer directly on non-Ubuntu distributions or newer distributions usually fails:
- Direct `.deb` conversion tools (such as `alien` or RPM conversion scripts) break when host shared libraries diverge.
- The bundled AppImage requires FUSE, but older AppImage runtimes look specifically for `/bin/fusermount`, while modern distributions provide `fusermount3`.
- Minimal container images miss desktop OpenGL, NSS, and audio shared libraries, leading to missing symbol errors during startup.

Distrobox isolates the Ubuntu runtime while keeping your host display server (Wayland or X11), GPU acceleration, audio, and home directory accessible.

## Prerequisites

On your host machine, install `distrobox` and either `podman` or `docker`:

- Fedora: `sudo dnf install distrobox podman`
- Arch Linux: `sudo pacman -S distrobox podman`
- openSUSE: `sudo zypper install distrobox podman`
- Debian / Ubuntu: `sudo apt install distrobox podman`

Download the official Cisco Packet Tracer `.deb` installer from Cisco NetAcad or Skills for All.

## Quick install

Run the install script from your host, passing the path to the downloaded `.deb`:

```sh
git clone https://github.com/Bukutsu/packettracer-distrobox.git
cd packettracer-distrobox
./install.sh ~/Downloads/CiscoPacketTracer_9.0.1_Ubuntu_64bit.deb
```

The script creates an Ubuntu container (default name `ubuntu_box`), installs required runtime libraries, installs the deb, extracts the application icon, and exports the desktop entry and binary to your host.

To customize the container name:

```sh
CONTAINER_NAME=ciscobox ./install.sh /path/to/packettracer.deb
```

## Manual installation

If you prefer running the commands step by step:

### 1. Create and enter the container

```sh
distrobox create --name ubuntu_box --image docker.io/library/ubuntu:latest --yes
distrobox enter ubuntu_box
```

### 2. Install dependencies inside the container

```sh
sudo apt-get update
sudo apt-get install -y \
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

Link `fusermount3` to `fusermount` so the AppImage runtime can mount its SquashFS layer:

```sh
sudo ln -sf /bin/fusermount3 /usr/local/bin/fusermount
```

### 3. Install the Cisco package

Replace the path with the location of your downloaded `.deb`:

```sh
sudo apt-get install -y /home/username/Downloads/CiscoPacketTracer_9.0.1_Ubuntu_64bit.deb
```

### 4. Extract application icon and configure desktop entry

```sh
cd /tmp
/opt/pt/packettracer.AppImage --appimage-extract app.png
sudo cp squashfs-root/app.png /usr/share/pixmaps/packettracer.png
rm -rf squashfs-root

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

### 5. Export to the host

Export the command line wrapper and desktop launcher:

```sh
distrobox-export --bin /usr/local/bin/packettracer --export-path ~/.local/bin
distrobox-export --app packettracer --export-label none
```

Copy the icon to your host icons directory:

```sh
exit
mkdir -p ~/.local/share/icons
distrobox enter ubuntu_box -- cat /usr/share/pixmaps/packettracer.png > ~/.local/share/icons/packettracer.png
update-desktop-database ~/.local/share/applications || true
```

## Usage

From your terminal on the host:

```sh
packettracer
```

Or open "Cisco Packet Tracer" from your desktop application launcher (GNOME, KDE Plasma, XFCE, etc.).

## Troubleshooting

### AppImage fails to mount (`fuse: failed to exec fusermount`)

Packet Tracer packages an AppImage that expects the executable name `fusermount`. Modern Ubuntu packages only supply `fusermount3`.

Fix inside the container:

```sh
sudo ln -sf /bin/fusermount3 /usr/local/bin/fusermount
```

If your container environment restricts FUSE mounting entirely, you can run the AppImage using extraction mode:

```sh
APPIMAGE_EXTRACT_AND_RUN=1 packettracer
```

### Missing shared library errors

If running `packettracer` produces:

```
./PacketTracer: error while loading shared libraries: libOpenGL.so.0: cannot open shared object file
```

Install the missing graphics and system libraries inside the container:

```sh
sudo apt-get install -y libopengl0 libgl1 libegl1 libnss3 libnspr4 libpulse0 libdeflate0 libjbig0
```

### Benign console warnings

When starting from a terminal, you may see:

```
[...:ERROR:bus.cc(...)] Failed to connect to the bus: Failed to connect to socket /run/dbus/system_bus_socket
sh: 1: last: not found
```

These are harmless warnings from QtWebEngine checking for a system D-Bus daemon and the `last` utility inside the container. They do not prevent Packet Tracer from functioning normally.

## Removal

To remove the exported files from your host:

```sh
distrobox enter ubuntu_box -- distrobox-export --delete --bin /usr/local/bin/packettracer --export-path ~/.local/bin
distrobox enter ubuntu_box -- distrobox-export --delete --app packettracer
rm -f ~/.local/share/icons/packettracer.png
```

To delete the container completely:

```sh
distrobox stop ubuntu_box
distrobox rm ubuntu_box
```
