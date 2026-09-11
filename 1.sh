cat > /root/install-asterisk.sh <<'EOF'
#!/bin/bash

set -e

echo "================================================"
echo "      Asterisk 22 LTS - Debian 12 Installer"
echo "================================================"

if [ "$(id -u)" != "0" ]; then
    echo "Please run this script as root."
    exit 1
fi

echo "[1/10] Updating Debian..."
apt update
apt upgrade -y

echo "[2/10] Installing required packages..."

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
sox \
ffmpeg \
net-tools \
iproute2 \
iptables \
fail2ban \
ca-certificates

echo "[3/10] Downloading Asterisk..."

cd /usr/src

rm -f asterisk-22-current.tar.gz

wget -O asterisk-22-current.tar.gz \
https://downloads.asterisk.org/pub/telephony/asterisk/asterisk-22-current.tar.gz

rm -rf asterisk-22.*

tar -xzf asterisk-22-current.tar.gz

cd asterisk-22.*

echo "[4/10] Installing Asterisk prerequisites..."

contrib/scripts/install_prereq install

echo "[5/10] Configuring Asterisk..."

./configure

echo "[6/10] Selecting modules..."

make menuselect.makeopts

# Enable common codecs/modules
menuselect/menuselect \
--enable chan_pjsip \
--enable res_pjsip \
--enable res_pjsip_transport_websocket \
--enable res_http_websocket \
--enable codec_opus \
--enable codec_ulaw \
--enable codec_alaw \
--enable codec_gsm \
--enable codec_g722 \
--enable app_macro \
--enable app_mixmonitor \
--enable app_confbridge \
--enable app_voicemail \
--enable app_queue \
--enable app_dial \
--enable app_playback \
--enable app_record \
--enable app_read \
--enable app_directory \
--enable app_echo \
--enable res_rtp_asterisk \
--enable res_musiconhold \
--enable res_musiconhold \
menuselect.makeopts || true

echo "[7/10] Compiling Asterisk..."

make -j"$(nproc)"

echo "[8/10] Installing Asterisk..."

make install

make samples

make config

ldconfig

echo "[9/10] Creating Asterisk user..."

if ! id asterisk >/dev/null 2>&1; then
    useradd --system --home /var/lib/asterisk \
    --create-home --shell /usr/sbin/nologin asterisk
fi

mkdir -p /var/run/asterisk
mkdir -p /var/log/asterisk
mkdir -p /var/lib/asterisk
mkdir -p /var/spool/asterisk
mkdir -p /var/lib/asterisk/sounds

chown -R asterisk:asterisk \
/var/lib/asterisk \
/var/log/asterisk \
/var/spool/asterisk \
/var/run/asterisk

chmod -R 750 /var/lib/asterisk
chmod -R 750 /var/spool/asterisk

echo "[10/10] Configuring Asterisk..."

# Backup original configuration
cp /etc/asterisk/asterisk.conf \
/etc/asterisk/asterisk.conf.backup 2>/dev/null || true

# Run Asterisk as asterisk user
if grep -q "^AST_USER" /etc/default/asterisk 2>/dev/null; then
    sed -i 's/^AST_USER=.*/AST_USER="asterisk"/' /etc/default/asterisk
else
    echo 'AST_USER="asterisk"' >> /etc/default/asterisk
fi

if grep -q "^AST_GROUP" /etc/default/asterisk 2>/dev/null; then
    sed -i 's/^AST_GROUP=.*/AST_GROUP="asterisk"/' /etc/default/asterisk
else
    echo 'AST_GROUP="asterisk"' >> /etc/default/asterisk
fi

# Configure asterisk.conf
sed -i 's/^;runuser = .*/runuser = asterisk/' \
/etc/asterisk/asterisk.conf || true

sed -i 's/^;rungroup = .*/rungroup = asterisk/' \
/etc/asterisk/asterisk.conf || true

# Fix permissions
chown -R asterisk:asterisk /etc/asterisk

# Enable service
systemctl daemon-reload
systemctl enable asterisk

# Restart
systemctl restart asterisk

sleep 3

echo ""
echo "================================================"
echo "        ASTERISK INSTALLATION COMPLETE"
echo "================================================"

echo ""
echo "Asterisk Version:"
asterisk -V

echo ""
echo "Service Status:"
systemctl --no-pager status asterisk | head -20

echo ""
echo "SIP/PJSIP Port:"
ss -lunpt | grep -E '5060|5061' || true

echo ""
echo "RTP Ports:"
ss -lunp | grep asterisk || true

echo ""
echo "================================================"
echo "Useful commands"
echo "================================================"

echo "Asterisk console:"
echo "asterisk -rvvv"

echo ""
echo "PJSIP endpoints:"
echo "pjsip show endpoints"

echo ""
echo "PJSIP registrations:"
echo "pjsip show registrations"

echo ""
echo "PJSIP transports:"
echo "pjsip show transports"

echo ""
echo "Reload configuration:"
echo "asterisk -rx 'core reload'"

echo ""
echo "Restart Asterisk:"
echo "systemctl restart asterisk"

echo ""
echo "Check status:"
echo "systemctl status asterisk"

echo ""
echo "================================================"
EOF

chmod +x /root/install-asterisk.sh

bash /root/install-asterisk.sh
