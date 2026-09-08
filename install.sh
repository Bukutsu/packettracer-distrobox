#!/bin/sh
set -eu

CONTAINER_NAME="${CONTAINER_NAME:-ubuntu_box}"
IMAGE="${IMAGE:-docker.io/library/ubuntu:latest}"

if [ $# -lt 1 ]; then
    echo "Usage: $0 /path/to/CiscoPacketTracer.deb"
    exit 1
fi

DEB_INPUT="$1"
if [ ! -f "$DEB_INPUT" ]; then
    echo "Error: file not found: $DEB_INPUT" >&2
    exit 1
fi

DEB_PATH="$(readlink -f "$DEB_INPUT")"

for cmd in distrobox podman; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        if [ "$cmd" = "podman" ] && command -v docker >/dev/null 2>&1; then
            continue
        fi
        echo "Error: $cmd is required on host." >&2
        exit 1
    fi
done

if ! distrobox list 2>/dev/null | grep -E "(^|[[:space:]])${CONTAINER_NAME}([[:space:]]|$)"; then
    echo "Creating container '${CONTAINER_NAME}'..."
    distrobox create --name "${CONTAINER_NAME}" --image "${IMAGE}" --yes
fi

echo "Configuring container and installing Packet Tracer..."

distrobox enter "${CONTAINER_NAME}" -- bash -c "
set -eu

sudo apt-get update -qq
sudo apt-get install -y -qq \
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

if [ ! -e /usr/local/bin/fusermount ] && [ -x /bin/fusermount3 ]; then
    sudo ln -sf /bin/fusermount3 /usr/local/bin/fusermount
fi

sudo apt-get install -y -qq '$DEB_PATH'

if [ -f /opt/pt/packettracer.AppImage ]; then
    cd /tmp
    rm -rf pt-icon-extract
    mkdir -p pt-icon-extract
    cd pt-icon-extract
    /opt/pt/packettracer.AppImage --appimage-extract app.png >/dev/null 2>&1 || true
    if [ -f squashfs-root/app.png ]; then
        sudo cp squashfs-root/app.png /usr/share/pixmaps/packettracer.png
    fi
    cd /tmp
    rm -rf pt-icon-extract
fi

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

distrobox-export --bin /usr/local/bin/packettracer --export-path ~/.local/bin
distrobox-export --app packettracer --export-label none
"

mkdir -p ~/.local/share/icons
distrobox enter "${CONTAINER_NAME}" -- cat /usr/share/pixmaps/packettracer.png > ~/.local/share/icons/packettracer.png 2>/dev/null || true

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database ~/.local/share/applications >/dev/null 2>&1 || true
fi

echo "Done. You can run Packet Tracer with 'packettracer' or from your application launcher."
