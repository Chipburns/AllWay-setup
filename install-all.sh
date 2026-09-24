
echo "=== 1. MEMICU FONDASI GRAFIS VIA SETUP-DESKTOP LINTAS X11 ==="
# Mengaktifkan repositori community resmi bawaan rilis secara otomatis
sed -i 's/^#\(.*\/community\)/\1/' /etc/apk/repositories
apk update && apk upgrade

# Memanggil penginstalan dasar desktop resmi Alpine (Non-Interaktif)
# Ini otomatis memasang X11 dasar, driver grafis universal, dan SDDM
setup-desktop lxqt 

echo "=== 2. MEMASANG UTENSIL COMPOSITOR WAYLAND MODERN ==="
# Mendaftarkan tagged repository edge testing secara aman jika belum terdaftar
if [ -f /etc/apk/repositories ]; then
    if ! grep -q "edge/testing" /etc/apk/repositories; then
        echo "-> Mendaftarkan repositori edge testing..."
        echo "@testing https://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories
        apk update
    else
        echo "-> [Aman] Repositori edge testing sudah terdaftar."
    fi
fi

apk add --no-cache alpine-keys

# Memasang labwc beserta utilitas resolusi layar Wayland dasar
apk add kanshi wlr-randr

echo "=== 3.MEMASANG LABWC (WAYLAND) BESERTA UTILITAS PELENGKAP & AUDIO ==="
# Memasang sesi desktop Wayland LXQt, Labwc, utilitas multimedia, gcompat, dan konsole
apk add lxqt-wayland-session@testing labwc wlogout lximage-qt pavucontrol-qt obconf-qt gcompat konsole
apk add brightnessctl xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk xdg-desktop-portal-kde upower
apk add swayidle swaylock-effects
apk add lxqt-policykit featherpad@testing
apk add kvantum kvantum-themes kvantum-qt5 kvantum-qt6
apk add adwaita-icon-theme papirus-icon-theme
apk add qt6-qtwayland layer-shell-qt
apk add grim slurp wl-clipboard

# === TAMBAHAN HIBRIDA: MEMASANG PAKET & MEMBUAT SKRIP KECERAHAN PINTAR ===
echo "-> Memasang utilitas kecerahan tambahan..."
apk add ddcutil i2c-tools

echo "-> Membuat skrip kontrol kecerahan hibrida pintar di /usr/local/bin/..."
cat << 'EOF' > /usr/local/bin/backlight-control.sh
#!/bin/sh
ACTION=$1

# 1. Cek apakah perangkat memiliki folder backlight internal (Laptop)
if [ -d /sys/class/backlight ] && [ "$(ls -A /sys/class/backlight 2>/dev/null)" ]; then
    if [ "$ACTION" = "up" ]; then
        brightnessctl set +5%
    else
        brightnessctl set 5%-
    fi
# 2. Menggunakan ddcutil untuk monitor eksternal via DDC/CI (PC Desktop)
else
    # Memastikan modul kernel i2c-dev aktif saat dipanggil
    modprobe i2c-dev 2>/dev/null || true
    
    # Optimasi: Menjalankan ddcutil secara instan tanpa melakukan deteksi ulang bus yang lambat
    if [ "$ACTION" = "up" ]; then
        ddcutil setvcp 10 + 10 --brief 2>/dev/null || true
    else
        ddcutil setvcp 10 - 10 --brief 2>/dev/null || true
    fi
fi
EOF
chmod +x /usr/local/bin/backlight-control.sh

echo "=== 3.5. MENYUNTIKKAN KONFIGURASI TEKS SDDM WAYLAND (LABWC) ==="
# Membuat file sddm.conf hanya jika file belum ada (Fresh Install)
if [ ! -f /etc/sddm.conf ]; then
    echo "-> Membuat konfigurasi hibrida SDDM Wayland baru..."
    cat << 'EOF' > /etc/sddm.conf
[Autologin]
Relogin=false
Session=
User=

[General]
DisplayServer=wayland
GreeterEnvironment=
HaltCommand=/usr/bin/loginctl poweroff
InputMethod=qtvirtualkeyboard
Namespaces=
Numlock=none
RebootCommand=/usr/bin/loginctl reboot

[Theme]
Current=maldives
CursorSize=
CursorTheme=
DisableAvatarsThreshold=7
EnableAvatars=true
FacesDir=/usr/share/sddm/faces
Font=
ThemeDir=/usr/share/sddm/themes

[Users]
DefaultPath=/usr/local/bin:/usr/bin:/bin
HideShells=
HideUsers=
MaximumUid=65000
MinimumUid=1000
RememberLastSession=true
RememberLastUser=true
ReuseSession=true

[Wayland]
CompositorCommand=labwc
EnableHiDPI=true
SessionCommand=/usr/share/sddm/scripts/wayland-session
SessionDir=/usr/local/share/wayland-sessions,/usr/share/wayland-sessions
SessionLogFile=.local/share/sddm/wayland-session.log

[X11]
DisplayCommand=/usr/share/sddm/scripts/Xsetup
DisplayStopCommand=/usr/share/sddm/scripts/Xstop
EnableHiDPI=true
ServerArguments=-nolisten tcp
ServerPath=/usr/bin/X
SessionCommand=/usr/share/sddm/scripts/Xsession
SessionDir=/usr/local/share/xsessions,/usr/share/xsessions
SessionLogFile=.local/share/sddm/xorg-session.log
XephyrPath=/usr/bin/Xephyr
EOF
    echo "-> Konfigurasi teks /etc/sddm.conf berhasil diterapkan."
else
    echo "-> [Aman] Berkas /etc/sddm.conf sudah ada, melewati pembuatan ulang."
fi

# Memastikan folder drop-in dikosongkan agar tidak bentrok dengan setelan global kita
if [ -d /etc/sddm.conf.d ]; then
    rm -rf /etc/sddm.conf.d/* 2>/dev/null || true
fi

# Mengaktifkan servis SDDM agar otomatis berjalan saat booting komputer dinyalakan
rc-update add sddm default || true

echo "=== 4. MEMASANG FONDASI GRAFIS UTAMA & DRIVER AKSELERASI AKURAT ==="
# Protokol Wayland Dasar & Jembatan XWayland untuk kompatibilitas aplikasi lama
apk add wayland wayland-utils wl-clipboard xwayland
apk add font-noto ttf-dejavu fontconfig

# PERBAIKAN DRIVER INTEL HIBRIDA (Mendukung Gen 3, Gen 4, dan di atasnya)
apk add mesa-dri-gallium mesa-va-gallium libva-utils mesa-egl mesa-gles
apk add intel-media-driver libva-intel-driver

apk add mesa-rusticl opencl-icd-loader opencl-headers || true
apk add linux-firmware-rtl_nic linux-firmware-intel linux-firmware-amdgpu linux-firmware-radeon

echo "=== 7. MEMASANG DETEKSI PENGIRIMAN FILE HP (MTP & iOS) ==="
apk add libmtp libimobiledevice gvfs gvfs-mtp gvfs-afc android-tools

echo "=== 8. MEMASANG UTILITAS OTENTIKASI, HAK AKSES & SISTEM ==="
# Memasangkan perkakas manajemen pelacak perubahan konfigurasi resmi Alpine
apk add update-conf polkit polkit-elogind doas xdg-user-dirs xdg-utils apk-new

echo "permit :wheel" > /etc/doas.conf

# ========================================================================
# PENGAMAN INTEGRASI VISUAL QT6 & WAYLAND GLOBAL (ANTI-DUPLIKASI & REPLACE)
# ========================================================================
QT_PROFILE_FILE="/etc/profile.d/qt_integration.sh"

echo "-> Mengonfigurasi variabel integrasi visual Qt6 global..."

# Logika Pembersihan: Jika file sudah ada, hapus agar konten baru bisa ditulis ulang (Replace)
if [ -f "$QT_PROFILE_FILE" ]; then
    echo "   [Info] Berkas konfigurasi lama ditemukan, memperbarui konten..."
    rm -f "$QT_PROFILE_FILE" 2>/dev/null || true
fi

# Menulis ulang isi konfigurasi secara bersih (Anti-Duplikasi baris ganda)
cat << 'EOF' > "$QT_PROFILE_FILE"
#!/bin/sh
# Memaksa seluruh aplikasi Qt (termasuk KDE Discover) menggunakan modul integrasi visual LXQt
export QT_QPA_PLATFORMTHEME=lxqt

# Mengaktifkan akselerasi rendering teks Wayland untuk pustaka Qt6 murni secara global
export QT_QPA_PLATFORM=wayland
EOF

# Memberikan hak akses eksekusi agar terbaca otomatis saat boot sistem
chmod +x "$QT_PROFILE_FILE"
echo "   [Sukses] Integrasi visual Qt6 & Wayland berhasil dikunci."
# ========================================================================


# Membuat jembatan sistem permanen dari perintah sudo ke doas
ln -sf /usr/bin/doas /usr/bin/sudo

# TAMBAHAN BARU: Membuat alias otomatis agar perintah 'sudo' diarahkan ke 'doas' secara global
echo 'alias sudo="doas"' > /etc/profile.d/sudo_alias.sh

# ========================================================================
# KONFIGURASI FIREWALL ULTRA KETAT (ANTI-DUPLIKASI & REPLACE)
# ========================================================================
echo "=== 8.5. MEMASANG & MENGAKTIFKAN FIREWALL RINGAN (UFW) ==="
# Memasang paket firewall bawaan Alpine
apk add ufw ufw-openrc

# Logika Pembersihan: Reset konfigurasi lama jika skrip dijalankan ulang (Replace)
if [ -d /etc/ufw ]; then
    echo "-> Mengatur ulang aturan firewall ke setelan standar hibrida..."
    ufw --force reset >/dev/null 2>&1 || true
fi

# Mengunci kebijakan: Tutup total akses MASUK, buka penuh akses KELUAR
# Karena Anda memakai USB langsung, semua port masuk dikunci rapat demi keamanan maksimal
ufw default deny incoming
ufw default allow outgoing

# Mengaktifkan firewall secara instan dan permanen
ufw --force enable

# Mendaftarkan ke sistem boot OpenRC agar aktif sejak komputer dinyalakan
rc-update add ufw default || true
echo "   [Sukses] Firewall dikunci rapat. Aman dari pemindaian Wi-Fi liar."
# ========================================================================

echo "=== 9. MEMASANG JARINGAN NETWORKMANAGER (PENGGANTI IFUPDOWN) ==="
apk add networkmanager networkmanager-cli networkmanager-openrc network-manager-applet

echo "=== 10. MENAMBAHKAN DAEMON SERVIS PERANGKAT KERAS (OPENRC) ==="
apk add eudev dbus dbus-x11 eudev-openrc \
        acpid acpid-openrc \
        haveged haveged-openrc \
        irqbalance irqbalance-openrc \
        lm-sensors lm-sensors-sensord lm-sensors-detect \
        smartmontools smartmontools-openrc \
        seatd seatd-openrc \
        elogind elogind-openrc \
        cpufrequtils cpufrequtils-openrc

# Deteksi sensor hardware otomatis
sensors-detect --auto >/dev/null 2>&1 || true

# Pengaturan urutan boot OpenRC
rc-update del mdev boot >/dev/null 2>&1 || true
rc-update del mdevd boot >/dev/null 2>&1 || true
rc-update add udev sysinit || true
rc-update add udev-trigger sysinit || true
rc-update add udev-settle sysinit || true

# SINKRONISASI STABILITAS: D-Bus dan Elogind dikunci di runlevel boot agar grafis menyala sempurna
rc-update add cgroups boot || true
rc-update add dbus boot || true
rc-update add elogind boot || true

# Penataan daemon kustom default level
rc-update add acpid default || true
rc-update add networkmanager default || true
rc-update add haveged default || true
rc-update add irqbalance default || true
rc-update add sensord default || true
rc-update add smartd default || true
rc-update add cpufrequtils default || true

if [ -f /etc/init.d/lm_sensors ]; then rc-update add lm_sensors default || true; fi
if [ -f /etc/init.d/chronyd ]; then rc-update add chronyd default || true; fi
if [ -f /etc/init.d/upowerd ]; then rc-update add upowerd default || true; fi

# SUNTIKAN TEKS: Mengonfigurasi cpufrequtils untuk driver intel_pstate (Otomatis Dinamis)
# Karena menggunakan intel_pstate, profil default terbaik dan otomatis adalah "powersave"
if [ -f /etc/conf.d/cpufrequtils ]; then
    sed -i 's/^#\?governor=.*/governor="powersave"/' /etc/conf.d/cpufrequtils
else
    echo 'governor="powersave"' > /etc/conf.d/cpufrequtils
fi

# ========================================================================
# OPTIMASI AKSELERASI VIRTUALISASI PINTAR (DETEKSI INTEL & AMD AUTOMATIC)
# ========================================================================
echo "-> Menganalisis merek prosesor untuk akselerasi KVM & jembatan..."

# 1. Kernel membaca informasi /proc/cpuinfo secara real-time
V_MODULE="kvm-intel"
if grep -q "AuthenticAMD" /proc/cpuinfo 2>/dev/null; then
    echo "   [Info] CPU AMD terdeteksi."
    V_MODULE="kvm-amd"
else
    echo "   [Info] CPU Intel terdeteksi."
fi

# 2. Daftarkan modul KVM yang sesuai dan br_netfilter (jembatan) ke /etc/modules
# Menggunakan logika anti-duplikasi string (grep -q)
for mod in "$V_MODULE" "br_netfilter"; do
    if [ -f /etc/modules ]; then
        if ! grep -q "$mod" /etc/modules; then
            echo "$mod" >> /etc/modules
            echo "   [Sukses] Mendaftarkan modul: $mod"
        else
            echo "   [Aman] Modul $mod sudah terdaftar sebelumnya."
        fi
    else
        echo "$mod" > /etc/modules
    fi
    # Picu langsung ke memori kernel sekarang juga agar aktif tanpa reboot
    modprobe "$mod" 2>/dev/null || true
done

# 3. Jaring Pengaman Firewall untuk Jembatan VM
mkdir -p /etc/sysctl.d
cat << 'EOF' > /etc/sysctl.d/bridging.conf
net.bridge.bridge-nf-call-iptables=0
net.bridge.bridge-nf-call-ip6tables=0
EOF
sysctl -p /etc/sysctl.d/bridging.conf >/dev/null 2>&1 || true
# ========================================================================

echo "=== 12. PENYEMPURNAAN AUDIO MODERN PIPEWIRE ==="
# Menggunakan wireplumber-logind agar kompatibel dengan sistem elogind Alpine
apk add pipewire pipewire-tools pipewire-alsa pipewire-pulse wireplumber wireplumber-logind alsa-utils gst-plugin-pipewire

echo "=== 13. MEMASANG INTEGRASI FLATPAK UNIVERSAL (DISCOVER) ==="
apk add flatpak
# Alamat Flathub diarahkan ke repositori flatpakrepo yang valid
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
apk add discover discover-backend-apk discover-backend-flatpak kirigami knewstuff flatpak-kcm

# PERBAIKAN AKSES TEMA: Mengizinkan Flatpak membaca direktori ikon dan konfigurasi tema sistem
echo "-> Mengonfigurasi hak akses ikon & tema global untuk Flatpak..."
flatpak override --system --filesystem=~/.local/share/icons:ro || true
flatpak override --system --filesystem=/usr/share/icons:ro || true
flatpak override --system --filesystem=xdg-config/Kvantum:ro || true
flatpak override --system --filesystem=xdg-config/lxqt:ro || true
flatpak override --system --filesystem=host || true

# Memasang runtime gaya aplikasi agar Kirigami Qt6 di Discover bisa sinkron ke Dark Mode
flatpak install -y flathub org.kde.KStyle.Adwaita || true

echo "=== 14. PENYELARASAN HAK AKSES PENGGUNA & REPLIKASI PROFIL DESKTOP ==="
REAL_USER=$(awk -F: '$3 >= 1000 && $3 < 60000 {print $1}' /etc/passwd | head -n 1)

if [ -n "$REAL_USER" ]; then
    echo "-> User biasa terdeteksi: '$REAL_USER'. Memulai konfigurasi..."
    
    # Menambahkan grup esensial hibrida dan grup KVM untuk Virtual Machine
    for group in wheel netdev disk cdrom i2c kvm; do
        addgroup "$REAL_USER" $group || true
    done
    USER_HOME=$(eval echo "~$REAL_USER")
    
    mkdir -p "$USER_HOME/.config/labwc"
    mkdir -p "$USER_HOME/.config/kanshi"
    mkdir -p "$USER_HOME/.config/lxqt"
    
    # PARAMETER TEMA KUNCI: SWAYLOCK ULTRA CLEAN & MINIMALIS ELEGAN
    SWAYLOCK_CMD="swaylock --screenshots --clock --indicator --indicator-radius 100 --indicator-thickness 3 --effect-blur 7x5 --effect-vignette 0.5:0.5 --fade-in 0.2 --timestr '%H:%M' --datestr '%A, %d %B' --text-color ffffffff --inside-color 00000000 --inside-clear-color 00000000 --inside-ver-color 00000000 --inside-wrong-color 00000000 --ring-color ffffffaa --ring-clear-color ffffffff --ring-ver-color ffffffff --ring-wrong-color ff0000ff --key-hl-color ffffffff --text-ver '' --text-wrong ''"

    # ------------------------------------------------------------------------
    # A. CONFIG CORE GUI SESSIONS LXQT WAYLAND (TEMA DIATUR MANUAL VIA GUI)
    # ------------------------------------------------------------------------
    echo "-> Mengunci konfigurasi otomatis Sesi Wayland di session.conf..."
    cat << EOF > "$USER_HOME/.config/lxqt/session.conf"
[General]
window_manager=labwc

[Wayland]
compositor=labwc
screenlock_command=$SWAYLOCK_CMD
EOF

    # ------------------------------------------------------------------------
    # B. MANAJEMEN DEKORASI JENDELA & SHORTCUT KEYBOARD (LABWC rc.xml)
    # ------------------------------------------------------------------------
    if [ ! -f "$USER_HOME/.config/labwc/rc.xml" ]; then
        echo "-> Menyalin template konfigurasi dasar Labwc ke folder user..."
        cp -r /etc/xdg/labwc/. "$USER_HOME/.config/labwc/" 2>/dev/null || true
    fi
    
    if [ ! -f "$USER_HOME/.config/labwc/autostart" ]; then
        echo "#!/bin/sh" > "$USER_HOME/.config/labwc/autostart"
    fi
    
    # Rantai Autostart Sesi Grafis & Multimedia
    for cmd in "kanshi &" "nm-applet --sm-disable &" "lxqt-powermanagement &" "pipewire &" "wireplumber &" "pipewire-pulse &" "swayidle -w timeout 600 '$SWAYLOCK_CMD' &"; do
        if ! grep -qF "$cmd" "$USER_HOME/.config/labwc/autostart"; then
            echo "$cmd" >> "$USER_HOME/.config/labwc/autostart"
        fi
    done
    chmod +x "$USER_HOME/.config/labwc/autostart"

    # Fungsi pembantu penyuntik keybind ke rc.xml secara aman (Anti-Duplikasi & Presisi)
    inject_keybind() {
        local check_string="$1"
        local content="$2"
        if ! grep -q "$check_string" "$USER_HOME/.config/labwc/rc.xml"; then
            awk -v text="$content" '/<\/keyboard>/ {print text} {print}' "$USER_HOME/.config/labwc/rc.xml" > "$USER_HOME/.config/labwc/rc.xml.tmp"
            mv "$USER_HOME/.config/labwc/rc.xml.tmp" "$USER_HOME/.config/labwc/rc.xml"
        fi
    }

    if [ -f "$USER_HOME/.config/labwc/rc.xml" ]; then
        echo "-> Menyuntikkan konfigurasi pintasan keyboard (Shortcut Labwc)..."
        
        # 1. Shortcut Kecerahan Hibrida Laptop/Desktop
        BRIGHTNESS_BIND=$(cat << 'EOF'
  <!-- PENGATURAN KECERAHAN HIBRIDA (LAPTOP & DESKTOP) -->
  <keybind key="XF86MonBrightnessUp">
    <action name="Execute" command="/usr/local/bin/backlight-control.sh up" />
  </keybind>
  <keybind key="XF86MonBrightnessDown">
    <action name="Execute" command="/usr/local/bin/backlight-control.sh down" />
  </keybind>
EOF
)
        inject_keybind "backlight-control.sh" "$BRIGHTNESS_BIND"

        # 2. Shortcut Audio PipeWire
        AUDIO_BIND=$(cat << 'EOF'
  <!-- PENGATURAN VOLUME AUDIO WIREPLUMBER -->
  <keybind key="XF86AudioRaiseVolume">
    <action name="Execute" command="wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+" />
  </keybind>
  <keybind key="XF86AudioLowerVolume">
    <action name="Execute" command="wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-" />
  </keybind>
  <keybind key="XF86AudioMute">
    <action name="Execute" command="wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle" />
  </keybind>
EOF
)
        inject_keybind "wpctl set-volume" "$AUDIO_BIND"

        # 3. Shortcut Tangkap Layar (Screenshot Grim + Slurp)
        apk add --no-cache libnotify
        mkdir -p "$USER_HOME/Pictures"
        chown "$REAL_USER":"$REAL_USER" "$USER_HOME/Pictures"

        SCREENSHOT_BIND=$(cat << 'EOF'
  <!-- PENGATURAN TANGKAP LAYAR NATIVE WAYLAND + NOTIFIKASI -->
  <keybind key="Print">
    <action name="Execute" command="sh -c 'FILE=$HOME/Pictures/Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png && grim $FILE && notify-send -i camera-photo \"Screenshot Berhasil\" \"Disimpan ke:\n$FILE\"'" />
  </keybind>
  <keybind key="A-Print">
    <action name="Execute" command="sh -c 'FILE=$HOME/Pictures/Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png && grim -g \"$(slurp)\" $FILE && notify-send -i camera-photo \"Screenshot Area Berhasil\" \"Disimpan ke:\n$FILE\"'" />
  </keybind>
EOF
)
        inject_keybind "grim" "$SCREENSHOT_BIND"

        # 4. Shortcut Kunci Layar Manual Super Clean (Super + L)
        LOCK_BIND=$(cat << EOF
  <!-- PINTASAN KUNCI LAYAR GRAFIS ULTRA CLEAN (SWAYLOCK-EFFECTS) -->
  <keybind key="W-l">
    <action name="Execute" command="$SWAYLOCK_CMD" />
  </keybind>
EOF
)
        inject_keybind "swaylock" "$LOCK_BIND"
    fi

    if [ ! -f "$USER_HOME/.config/kanshi/config" ]; then
        cat << 'EOF' > "$USER_HOME/.config/kanshi/config"
profile { output "*" mode auto position 0,0 }
EOF
    fi

    # Menyerahkan kepemilikan folder konfigurasi secara bersih ke user biasa
    chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME/.config"
else
    echo "! User biasa tidak ditemukan. Membuat template global di /etc/xdg/"
    mkdir -p /etc/xdg/labwc /etc/xdg/kanshi
fi

echo "=== 15. OPTIMASI KONSUMSI RAM & PERFORMA SISTEM ==="
mkdir -p /etc/sysctl.d
if [ -f /etc/sysctl.d/local.conf ]; then
    if ! grep -q "vm.swappiness" /etc/sysctl.d/local.conf; then
        echo "vm.swappiness=60" >> /etc/sysctl.d/local.conf
    fi
else
    echo "vm.swappiness=60" > /etc/sysctl.d/local.conf
fi
sysctl -p /etc/sysctl.d/local.conf || true

if [ -f /etc/conf.d/syslogd ]; then
    sed -i 's/SYSLOGD_OPTS=.*/SYSLOGD_OPTS="-b 4 -D"/' /etc/conf.d/syslogd
fi

# ========================================================================
# OPTIMASI PERAWATAN SSD ADATA SU650 VIA FSTRIM MINGGUAN (OVERWRITE MURNI)
# ========================================================================
echo "-> Memasang utilitas fstrim untuk kesehatan SSD..."
apk add util-linux

mkdir -p /etc/periodic/weekly
cat << 'EOF' > /etc/periodic/weekly/fstrim
#!/bin/sh
# Membersihkan sel kosong SSD ADATA SU650 agar memperpanjang umur hardware
/sbin/fstrim -a || true
EOF
chmod +x /etc/periodic/weekly/fstrim

# Pastikan crond menyala untuk mengeksekusi fstrim mingguan
rc-update add crond default || true
echo "   [Sukses] FSTRIM mingguan otomatis dikunci untuk SSD ADATA SU650."
# ========================================================================

echo "=== 16. MENONAKTIFKAN SWAP DISK & BERMIGRASI KE COMPRESSED ZRAM ==="
rc-update del swap boot >/dev/null 2>&1 || true
apk add zram-init
mkdir -p /etc/conf.d
cat << 'EOF' > /etc/conf.d/zram-init
type=swap
algorithm=zstd
num_devices=1
# Perubahan Baru: Membatasi ukuran zram maksimal sebesar 100% dari total RAM fisik Anda 
# (Sangat ideal untuk memperpanjang umur multitasking Intel generasi lama)
flag_disksize_max=100
EOF
rc-update add zram-init default || true
if [ -f /etc/fstab ]; then sed -i '/swap/d' /etc/fstab; fi

# Sinkronisasi PAM agar folder /run/user/1000 terbuat otomatis untuk Elogind secara aman
if [ -f /etc/pam.d/base-session ]; then
    if ! grep -q "pam_elogind.so" /etc/pam.d/base-session; then
        echo "-> Menyuntikkan modul pam_elogind ke sistem session..."
        echo "session required pam_elogind.so" >> /etc/pam.d/base-session
    else
        echo "-> [Aman] Modul pam_elogind sudah aktif di base-session."
    fi
fi

# PERBAIKAN UTAMA USB TETHERING: Menghapus total sisa interface ifupdown tradisional agar NetworkManager stabil
rc-update del networking boot >/dev/null 2>&1 || true
rc-update del networking default >/dev/null 2>&1 || true
if [ -f /etc/network/interfaces ]; then
    cat <<EOF > /etc/network/interfaces
auto lo
iface lo inet loopback
EOF
fi

apk verify && apk fix
echo "=== MASTER SKRIP PLUS V13 HYBRID BERHASIL SELESAI! REBOOTING... ==="
sleep 2 && reboot
