# packettracer-distrobox

Run Cisco Packet Tracer on any Linux distribution with Distrobox.

## Prerequisites

- `distrobox` and `podman` (or `docker`) installed on host.
- Cisco Packet Tracer `.deb` downloaded from Cisco NetAcad.

## Setup

### 1. Create and enter container

```sh
distrobox create --name ubuntu_box --image ubuntu:latest --yes
distrobox enter ubuntu_box
```

### 2. Inside container

Install runtime dependencies and link `fusermount3` to `fusermount`:

```sh
sudo apt update
sudo apt install -y fuse3 libopengl0 libgl1 libegl1 libnss3 libnspr4 libpulse0 libdeflate0 libjbig0 libglib2.0-bin
sudo ln -sf /bin/fusermount3 /usr/local/bin/fusermount
```

Install your downloaded `.deb`:

```sh
sudo apt install -y ~/Downloads/CiscoPacketTracer_*.deb
```

Extract icon and create desktop entry:

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

Export binary and launcher to host:

```sh
distrobox-export --bin /usr/local/bin/packettracer --export-path ~/.local/bin
distrobox-export --app packettracer --export-label none
exit
```

### 3. On host

Copy the icon to host user icons:

```sh
mkdir -p ~/.local/share/icons
distrobox enter ubuntu_box -- cat /usr/share/pixmaps/packettracer.png > ~/.local/share/icons/packettracer.png
```

Launch with `packettracer` or from your application menu.

## Troubleshooting

- **`fuse: failed to exec fusermount`**: Inside container run `sudo ln -sf /bin/fusermount3 /usr/local/bin/fusermount`. If FUSE mounting is blocked by the environment, run with `APPIMAGE_EXTRACT_AND_RUN=1 packettracer`.
- **`libOpenGL.so.0: cannot open shared object file`**: Inside container run `sudo apt install -y libopengl0 libgl1 libegl1 libnss3 libnspr4 libpulse0`.
- **D-Bus / `last: not found` warnings**: Harmless console output from QtWebEngine inside containers.

## Uninstall

```sh
distrobox enter ubuntu_box -- distrobox-export --delete --bin /usr/local/bin/packettracer --export-path ~/.local/bin
distrobox enter ubuntu_box -- distrobox-export --delete --app packettracer
rm -f ~/.local/share/icons/packettracer.png
distrobox stop ubuntu_box && distrobox rm ubuntu_box
```
