cat > /root/install.sh <<'EOF'
#!/bin/bash

set -e

echo "===================================================="
echo " HostServerBD - Asterisk 22 PBX Full Installer"
echo " Debian 12"
echo "===================================================="

if [ "$(id -u)" != "0" ]; then
    echo "ERROR: Run this script as root."
    exit 1
fi

ASTERISK_VERSION="22.11.0"
ASTERISK_SRC="/usr/src/asterisk-${ASTERISK_VERSION}"

echo ""
echo "[1/12] Checking Asterisk..."

if command -v asterisk >/dev/null 2>&1; then
    echo "Asterisk already installed:"
    asterisk -V
else
    echo "Asterisk not found. Installing..."

    apt update
    apt upgrade -y

    apt install -y \
        wget curl git vim nano unzip tar gzip \
        build-essential autoconf automake libtool pkg-config \
        subversion \
        libxml2-dev \
        libncurses5-dev \
        libncurses-dev \
        libsqlite3-dev \
        libjansson-dev \
        libssl-dev \
        libedit-dev \
        uuid-dev \
        libcurl4-openssl-dev \
        libspeex-dev \
        libspeexdsp-dev \
        libsrtp2-dev \
        libogg-dev \
        libvorbis-dev \
        libopus-dev \
        libmp3lame-dev \
        ffmpeg \
        sox \
        net-tools \
        iproute2 \
        fail2ban \
        ca-certificates

    cd /usr/src

    if [ ! -d "$ASTERISK_SRC" ]; then
        wget -O asterisk-22-current.tar.gz \
        https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-22-current.tar.gz

        tar -xzf asterisk-22-current.tar.gz
    fi

    cd "$ASTERISK_SRC"

    echo "[2/12] Installing prerequisites..."
    contrib/scripts/install_prereq install

    echo "[3/12] Configuring Asterisk..."
    ./configure

    echo "[4/12] Preparing modules..."
    make menuselect.makeopts

    echo "[5/12] Compiling Asterisk..."
    make -j"$(nproc)"

    echo "[6/12] Installing Asterisk..."
    make install
    make samples
    make config
    ldconfig
fi

echo "[7/12] Creating Asterisk user..."

if ! id asterisk >/dev/null 2>&1; then
    useradd \
        --system \
        --home /var/lib/asterisk \
        --create-home \
        --shell /usr/sbin/nologin \
        asterisk
fi

echo "[8/12] Fixing permissions..."

mkdir -p \
    /var/lib/asterisk \
    /var/log/asterisk \
    /var/spool/asterisk \
    /var/run/asterisk \
    /var/lib/asterisk/sounds

chown -R asterisk:asterisk \
    /etc/asterisk \
    /var/lib/asterisk \
    /var/log/asterisk \
    /var/spool/asterisk \
    /var/run/asterisk

chmod 750 /var/lib/asterisk
chmod 750 /var/spool/asterisk

echo "[9/12] Configuring Asterisk user..."

cat > /etc/default/asterisk <<'CONF'
AST_USER="asterisk"
AST_GROUP="asterisk"
CONF

# Add runuser/rungroup if missing
if ! grep -q "^runuser" /etc/asterisk/asterisk.conf; then
    sed -i '/^\[directories\]/a runuser = asterisk\nrungroup = asterisk' \
        /etc/asterisk/asterisk.conf
fi

echo "[10/12] Checking PJSIP..."

if asterisk -rx "module show like res_pjsip" | grep -q "res_pjsip"; then
    echo "PJSIP module loaded successfully."
else
    echo "WARNING: PJSIP module not detected."
fi

echo "[11/12] Restarting Asterisk..."

systemctl daemon-reload
systemctl enable asterisk
systemctl restart asterisk

sleep 3

echo "[12/12] Final checks..."

echo ""
echo "----------------------------------------------------"
echo "Asterisk Version"
echo "----------------------------------------------------"
asterisk -V

echo ""
echo "----------------------------------------------------"
echo "Asterisk Service"
echo "----------------------------------------------------"
systemctl is-active asterisk

echo ""
echo "----------------------------------------------------"
echo "PJSIP Modules"
echo "----------------------------------------------------"
asterisk -rx "module show like pjsip" | head -30

echo ""
echo "----------------------------------------------------"
echo "SIP Listening Ports"
echo "----------------------------------------------------"
ss -lunpt | grep -E '5060|5061|8088|8089' || true

echo ""
echo "===================================================="
echo "       ASTERISK INSTALLATION COMPLETED"
echo "===================================================="

echo ""
echo "Asterisk CLI:"
echo "  asterisk -rvvv"

echo ""
echo "PJSIP Endpoints:"
echo "  asterisk -rx 'pjsip show endpoints'"

echo ""
echo "PJSIP Transports:"
echo "  asterisk -rx 'pjsip show transports'"

echo ""
echo "PJSIP Registrations:"
echo "  asterisk -rx 'pjsip show registrations'"

echo ""
echo "Asterisk Status:"
echo "  systemctl status asterisk"

echo ""
echo "Restart:"
echo "  systemctl restart asterisk"

echo ""
echo "===================================================="
EOF

chmod +x /root/install.sh
bash /root/install.sh
