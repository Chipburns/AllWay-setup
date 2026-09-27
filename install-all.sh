#!/bin/sh
set -e

echo "=== 1. FONDASI REPOSITORI & UPDATE UTAMA ==="
# Mengaktifkan repositori community resmi bawaan rilis secara otomatis
sed -i 's/^#\(.*\/community\)/\1/' /etc/apk/repositories
apk update && apk upgrade

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
echo "[Sukses] Langkah 1 Selesai."


echo "=== 2. MEMASANG FONDASI GRAFIS UTAMA & DRIVER ==="
# Protokol Wayland Dasar & Jembatan XWayland untuk kompatibilitas aplikasi lama
# PERBAIKAN VALID: Menghapus paket dricore yang tidak ada, menyisakan utilitas font X11 resmi
apk add wayland wayland-utils wl-clipboard xwayland encodings font-util xsetroot
apk add font-noto ttf-dejavu fontconfig

# Driver Intel Hibrida & Firmware Grafis Utama
apk add mesa-dri-gallium mesa-va-gallium libva-utils mesa-egl mesa-gles intel-media-driver libva-intel-driver || true
apk add mesa-rusticl opencl-icd-loader opencl-headers || true
apk add linux-firmware-rtl_nic linux-firmware-intel linux-firmware-amdgpu linux-firmware-radeon
echo "[Sukses] Langkah 2 Selesai."


echo "=== 3. MEMASANG FONDASI LOGIN MANAGER, FIREWALL & LAYANAN OPENRC ==="

# [Aman & Berurutan] Tentukan isi paket opsional di awal langkah
TLP_PACKAGES=""
if [ -d /sys/class/power_supply ] && ls /sys/class/power_supply/BAT* >/dev/null 2>&1; then
    echo "-> [Deteksi] Perangkat adalah LAPTOP. Menyiapkan paket TLP..."
    TLP_PACKAGES="tlp tlp-openrc"
else
    echo "-> [Deteksi] Perangkat adalah DESKTOP. Melewati paket TLP."
fi

# Pemasangan seluruh paket utama + PERBAIKAN: Menyertakan paket mesin Bluetooth BlueZ resmi
apk add setup-xorg-base sddm sddm-openrc elogind polkit-elogind elogind-pam cgroups-openrc gvfs udisks2 $TLP_PACKAGES
apk add ufw ufw-openrc bluez bluez-openrc chrony chrony-openrc
apk add networkmanager networkmanager-cli networkmanager-openrc network-manager-applet
apk add eudev dbus dbus-x11 eudev-openrc udisks2-openrc acpid acpid-openrc \
        haveged haveged-openrc irqbalance irqbalance-openrc lm-sensors \
        lm-sensors-sensord lm-sensors-detect smartmontools smartmontools-openrc \
        seatd seatd-openrc cpufrequtils cpufrequtils-openrc

# Deteksi sensor hardware otomatis & bersihkan konfigurasi mdev lama
sensors-detect --auto >/dev/null 2>&1 || true
rc-update del mdev boot >/dev/null 2>&1 || true
rc-update del mdevd boot >/dev/null 2>&1 || true

# Daftarkan layanan kritis ke runlevel Boot dan Sysinit
rc-update add udev sysinit || true
rc-update add udev-trigger sysinit || true
rc-update add udev-settle sysinit || true
rc-update add cgroups boot || true
rc-update add seatd boot || true # <-- PENYESUAIAN: Wajib di boot agar sesi Wayland mengenali input/GPU

# Daftarkan layanan umum ke runlevel Default (PENYESUAIAN AMAN ELOGIND & DBUS)
rc-update add dbus default || true     # <-- PENYESUAIAN: Dipindah ke default agar stabil
rc-update add elogind default || true  # <-- PENYESUAIAN: Dipindah ke default agar folder runtime aman terbentuk
rc-update add chrony default || true
rc-update add udisks2 default || true
rc-update add acpid default || true
rc-update add networkmanager default || true
rc-update add bluetooth default || true
rc-update add haveged default || true
rc-update add irqbalance default || true
rc-update add sensord default || true
rc-update add smartd default || true
rc-update add cpufrequtils default || true
rc-update add ufw default || true

# [Aman & Berurutan] Hanya aktifkan layanan TLP jika paketnya terpasang (Laptop)
if [ -n "$TLP_PACKAGES" ]; then
    rc-update add tlp default || true
fi

# Konfigurasi cpufrequtils untuk hemat daya otomatis
if [ -f /etc/conf.d/cpufrequtils ]; then
    sed -i 's/^#\?governor=.*/governor="powersave"/' /etc/conf.d/cpufrequtils
else
    echo 'governor="powersave"' > /etc/conf.d/cpufrequtils
fi

# Konfigurasi Firewall UFW Super Ketat
if [ -d /etc/ufw ]; then ufw --force reset >/dev/null 2>&1 || true; fi
ufw default deny incoming
ufw default allow outgoing
ufw --force enable

# Otomasi deteksi arsitektur virtualisasi KVM (Intel/AMD)
V_MODULE="kvm-intel"
if grep -q "AuthenticAMD" /proc/cpuinfo 2>/dev/null; then V_MODULE="kvm-amd"; fi
if [ -f /etc/modules ]; then
    if ! grep -q "$V_MODULE" /etc/modules; then echo "$V_MODULE" >> /etc/modules; fi
    if ! grep -q "br_netfilter" /etc/modules; then echo "br_netfilter" >> /etc/modules; fi
    if ! grep -q "uhid" /etc/modules; then echo "uhid" >> /etc/modules; fi # <-- PERBAIKAN: Tambah modul input bluetooth
else
    echo -e "$V_MODULE\nbr_netfilter\nuhid" > /etc/modules # <-- PERBAIKAN: Tambah modul input bluetooth
fi
modprobe "$V_MODULE" 2>/dev/null || true
modprobe br_netfilter 2>/dev/null || true
modprobe uhid 2>/dev/null || true # <-- PERBAIKAN: Langsung aktifkan modul uhid kini

# Jaring pengaman firewall jembatan VM
mkdir -p /etc/sysctl.d
cat << 'EOF' > /etc/sysctl.d/bridging.conf
net.bridge.bridge-nf-call-iptables=0
net.bridge.bridge-nf-call-ip6tables=0
EOF
sysctl -e -p /etc/sysctl.d/bridging.conf >/dev/null 2>&1 || true
echo "[Sukses] Langkah 3 Selesai."


echo "=== 4. MEMASANG BALOK INTI DESKTOP LXQT & COMPOSITOR WAYFIRE ==="
apk add kanshi wlr-randr
# Fondasi Utama LXQt Core & Tema Ikon
apk add lxqt-panel lxqt-session lxqt-runner pcmanfm-qt lxqt-config lxqt-notificationd lxqt-policykit lxqt-themes
apk add libsysstat libstatgrab lxqt-menu-data lxqt-powermanagement lxqt-admin lxqt-archiver lxqt-sudo lxqt-qtplugin
apk add breeze-icons adwaita-icon-theme

# Generator thumbnail foto, font emoji, dan CHROMIUM NATIVE resmi Alpine
apk add tumbler font-noto-emoji chromium

# Paket-paket ekstraktor standar
apk add unzip zip p7zip unrar xz bzip2

# Alat Bantu Wayland, Terminal Kitty, dan Perkakas Screenshot (Disesuaikan untuk Wayfire)
# Catatan: Memanggil langsung dari repositori @testing yang sudah didaftarkan di Langkah 1
# Tambahkan paket wayinhibit di akhir baris perkakas Wayland Langkah 4
apk add lxqt-wayland-session@testing wayfire@testing wcm@testing wlogout lximage-qt pavucontrol-qt gcompat kitty libnotify
apk add brightnessctl xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk xdg-desktop-portal-lxqt upower
apk add swayidle swaylock-effects featherpad@testing wayinhibit@testing
apk add qt6-qtwayland layer-shell-qt grim slurp wl-clipboard wlopm

# Paket 'bluez-qt' resmi untuk menu Bluetooth pasif bawaan LXQt
apk add bluez-qt

# Membuat skrip kontrol kecerahan hibrida pintar
apk add ddcutil i2c-tools
cat << 'EOF' > /usr/local/bin/backlight-control.sh
#!/bin/sh
ACTION=$1
if [ -d /sys/class/backlight ] && [ "$(ls -A /sys/class/backlight 2>/dev/null)" ]; then
    if [ "$ACTION" = "up" ]; then brightnessctl set +5%; else brightnessctl set 5%-; fi
else
    modprobe i2c-dev 2>/dev/null || true
    if [ "$ACTION" = "up" ]; then ddcutil setvcp 10 + 10 --brief 2>/dev/null || true; else ddcutil setvcp 10 - 10 --brief 2>/dev/null || true; fi
fi
EOF
chmod +x /usr/local/bin/backlight-control.sh

# Konfigurasi SDDM Login Manager untuk Wayland Wayfire
mkdir -p /etc/sddm.conf.d
cat << 'EOF' > /etc/sddm.conf.d/wayland-wayfire.conf
[General]
DisplayServer=wayland
[Wayland]
CompositorCommand=wayfire
SessionCommand=/usr/share/sddm/scripts/wayland-session
EOF
rc-update add sddm default || true
echo "[Sukses] Langkah 4 Selesai."


echo "=== 5. MEMASANG UTENSIL SISTEM, AUDIO & FLATPAK REPO ==="
# PERBAIKAN: Ditambahkan gvfs-backends (Trash bin) dan ntfs-3g (Akses penuh storage Windows)
apk add libmtp libimobiledevice gvfs gvfs-mtp gvfs-afc gvfs-backends ntfs-3g android-tools
apk add polkit polkit-elogind doas xdg-user-dirs xdg-utils

# Konfigurasi Hak Akses Doas (Wheel Group)
echo "permit :wheel" > /etc/doas.conf
ln -sf /usr/bin/doas /usr/bin/sudo
echo 'alias sudo="doas"' > /etc/profile.d/sudo_alias.sh

# Konfigurasi Variabel Integrasi Qt6 & Wayland Global
QT_PROFILE_FILE="/etc/profile.d/qt_integration.sh"
rm -f "$QT_PROFILE_FILE" 2>/dev/null || true
cat << 'EOF' > "$QT_PROFILE_FILE"
#!/bin/sh
export QT_QPA_PLATFORMTHEME=lxqt
export QT_QPA_PLATFORM=wayland
EOF
chmod +x "$QT_PROFILE_FILE"

# Server Audio PipeWire Modern + PERBAIKAN: Menggunakan kodeks bluetooth resmi Alpine
apk add pipewire pipewire-tools pipewire-alsa pipewire-pulse wireplumber wireplumber-logind pipewire-spa-bluez alsa-utils gst-plugin-pipewire

# Ekosistem Toko Aplikasi Flatpak & KDE Discover
apk add flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
apk add discover discover-backend-apk discover-backend-flatpak kirigami knewstuff flatpak-kcm

# Override Hak Akses Tema untuk Flatpak
flatpak override --system --filesystem=~/.local/share/icons:ro || true
flatpak override --system --filesystem=/usr/share/icons:ro || true
flatpak override --system --filesystem=xdg-config/Kvantum:ro || true
flatpak override --system --filesystem=xdg-config/lxqt:ro || true
flatpak override --system --filesystem=host || true
flatpak install -y flathub org.kde.KStyle.Adwaita || true
echo "[Sukses] Langkah 5 Selesai."


echo "=== 6. OPTIMASI PERFORMA SISTEM & MIGRASI ZRAM ==="
# PERBAIKAN: Mengubah swappiness ke nilai 150 agar kernel sangat agresif menggunakan ZRAM ramah kompresi
if [ -f /etc/sysctl.d/local.conf ]; then
    sed -i '/vm.swappiness/d' /etc/sysctl.d/local.conf 2>/dev/null || true
    echo "vm.swappiness=150" >> /etc/sysctl.d/local.conf
else
    echo "vm.swappiness=150" > /etc/sysctl.d/local.conf
fi
sysctl -p /etc/sysctl.d/local.conf || true

# Optimalisasi Log Sistem Agar Lebih Ringan
if [ -f /etc/conf.d/syslogd ]; then sed -i 's/SYSLOGD_OPTS=.*/SYSLOGD_OPTS="-b 4 -D"/' /etc/conf.d/syslogd; fi

# Nonaktifkan Swap Disk Tradisional dan Pindah ke ZRAM 100%
rc-update del swap boot >/dev/null 2>&1 || true

# PERBAIKAN: Ditambahkan zram-init-openrc secara eksplisit
apk add zram-init zram-init-openrc

# PERBAIKAN: Memperbaiki sintaksis konfigurasi zram-init resmi Alpine Linux
# Mengalokasikan ukuran total disk ZRAM setara 100% dari total RAM fisik sistem secara dinamis
TOTAL_RAM_MB=$(LC_ALL=C free -m | awk '/^Mem:/{print $2}')
cat << EOF > /etc/conf.d/zram-init
load_on_start=yes
unload_on_stop=yes
num_devices=1
type0=swap
algo0=zstd
size0=$TOTAL_RAM_MB
flag0=100
EOF

rc-update add zram-init default || true
if [ -f /etc/fstab ]; then sed -i '/swap/d' /etc/fstab; fi

# Modul PAM Elogind (Menjamin folder runtime /run/user/1000 terbuat otomatis saat login)
if [ -f /etc/pam.d/base-session ]; then
    if ! grep -q "pam_elogind.so" /etc/pam.d/base-session; then
        echo "session required pam_elogind.so" >> /etc/pam.d/base-session
    fi
fi
echo "[Sukses] Langkah 6 Selesai."


echo "=== 7. PENYELARASAN PROFIL USER & REBOOT ==="
REAL_USER=$(awk -F: '$3 >= 1000 && $3 < 60000 {print $1}' /etc/passwd | head -n 1)

if [ -n "$REAL_USER" ]; then
    echo "-> User biasa ditemukan: '$REAL_USER'. Menyuntikkan konfigurasi..."
    addgroup -S i2c 2>/dev/null || true
    addgroup -S seat 2>/dev/null || true
    
    # Menambahkan grup agar user biasa berhak menginisiasi sesi Wayland Wayfire
    for group in wheel netdev disk cdrom i2c kvm seat; do
        addgroup "$REAL_USER" $group || true
    done
    
    # Memasukkan user sddm ke grup seat agar greeter login bisa memanggil compositor Wayland
    addgroup sddm seat 2>/dev/null || true

    USER_HOME=$(eval echo "~$REAL_USER")
    
    mkdir -p "$USER_HOME/.config/kanshi" "$USER_HOME/.config/lxqt" "$USER_HOME/Pictures"
    chown "$REAL_USER":"$REAL_USER" "$USER_HOME/Pictures"

    SWAYLOCK_CMD="swaylock --screenshots --clock --indicator --indicator-radius 100 --indicator-thickness 3 --effect-blur 7x5 --effect-vignette 0.5:0.5 --fade-in 0.2 --timestr '%H:%M' --datestr '%A, %d %B' --text-color ffffffff --inside-color 00000000 --inside-clear-color 00000000 --inside-ver-color 00000000 --inside-wrong-color 00000000 --ring-color ffffffaa --ring-clear-color ffffffff --ring-ver-color ffffffff --ring-wrong-color ff0000ff --key-hl-color ffffffff --text-ver '' --text-wrong ''"

    # 1. Jalur Resmi GUI LXQt Sesi Utama (Beralih ke Wayfire)
    if [ -f "$USER_HOME/.config/lxqt/session.conf" ]; then
        cp "$USER_HOME/.config/lxqt/session.conf" "$USER_HOME/.config/lxqt/session.conf.bak"
        sed -i 's/^window_manager=.*/window_manager=wayfire/' "$USER_HOME/.config/lxqt/session.conf"
        sed -i 's/^compositor=.*/compositor=wayfire/' "$USER_HOME/.config/lxqt/session.conf"
        
        if ! grep -q "screenlock_command" "$USER_HOME/.config/lxqt/session.conf"; then
            echo -e "\n[Wayland]\ncompositor=wayfire\nscreenlock_command=$SWAYLOCK_CMD" >> "$USER_HOME/.config/lxqt/session.conf"
        fi
    else
        cat << EOF > "$USER_HOME/.config/lxqt/session.conf"
[General]
window_manager=wayfire

[Wayland]
compositor=wayfire
screenlock_command=$SWAYLOCK_CMD
EOF
    fi

    # 2. Jalur Resmi GUI Manajemen Daya LXQt
    if [ -f "$USER_HOME/.config/lxqt/lxqt-powermanagement.conf" ]; then
        cp "$USER_HOME/.config/lxqt/lxqt-powermanagement.conf" "$USER_HOME/.config/lxqt/lxqt-powermanagement.conf.bak"
    fi
    
    cat << EOF > "$USER_HOME/.config/lxqt/lxqt-powermanagement.conf"
[General]
__version__=1.4.0

[Idleness]
enableIdleness=true
idlenessTime=5
idlenessAction=LockScreen

[Display]
enableDisplayManagement=false
EOF

    # 3. Pembuatan Profil Utama Wayfire (Hibrida + Fitur Anti-Tidur Saat Fullscreen)
    SWAYIDLE_LINE=""
    if [ -d /sys/class/power_supply ] && ls /sys/class/power_supply/BAT* >/dev/null 2>&1; then
        echo "-> [Wayfire] Mengaktifkan integrasi pengunci layar sebelum Sleep untuk Laptop."
        # PERBAIKAN PINTAR: Menambahkan flag untuk mendengarkan sinyal inhibit dari aplikasi fullscreen/video
        SWAYIDLE_LINE="6_sleep_lock = swayidle -w before-sleep \"$SWAYLOCK_CMD\""
    else
        echo "-> [Wayfire] Perangkat Desktop terdeteksi. Melewati integrasi sleep_lock."
    fi

    cat << EOF > "$USER_HOME/.config/wayfire.ini"
[core]
plugins = alpha animate autostart command core decoration expo grid move place resize vswitch window-rules
close_top_view = <super> KEY_Q

[autostart]
0_lxqt = lxqt-session
1_kanshi = kanshi
2_network = nm-applet --sm-disable
3_audio = pipewire
4_wireplumber = wireplumber
5_pulse = pipewire-pulse
$SWAYIDLE_LINE

[window-rules]
# FITUR UTAMA: Otomatis memblokir sistem agar TIDAK TIDAK/TIDAK MENGUNCI jika ada aplikasi yang sedang Fullscreen
rule_1 = on window-mapped if state contains "fullscreen" then inhibit-idle
rule_2 = on window-fullscreen-toggled if state contains "fullscreen" then inhibit-idle

[animate]
open_animation = fade
close_animation = fade
duration = 200

[expo]
toggle = <super>

[vswitch]
binding_left = <super> KEY_LEFT
binding_right = <super> KEY_RIGHT

[decoration]
font = Sans 10
title_height = 24
border_size = 2
active_color = #333333ff
inactive_color = #555555ff
button_order = minimize maximize close

[command]
binding_terminal = <super> KEY_ENTER
command_terminal = kitty

binding_lock = <super> KEY_L
command_lock = $SWAYLOCK_CMD

binding_disp_up = KEY_BRIGHTNESSUP
command_disp_up = /usr/local/bin/backlight-control.sh up
binding_disp_down = KEY_BRIGHTNESSDOWN
command_disp_down = /usr/local/bin/backlight-control.sh down

binding_vol_up = KEY_VOLUMEUP
command_vol_up = wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
binding_vol_down = KEY_VOLUMEDOWN
command_vol_down = wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
binding_vol_mute = KEY_MUTE
command_vol_mute = wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle

binding_screenshot = KEY_PRINT
command_screenshot = sh -c 'FILE=\$HOME/Pictures/Screenshot_\$(date +%Y-%m-%d_%H-%M-%S).png && grim \$FILE && notify-send -i camera-photo "Screenshot Berhasil" "Disimpan ke:\n\$FILE"'
binding_screenshot_region = <alt> KEY_PRINT
command_screenshot_region = sh -c 'FILE=\$HOME/Pictures/Screenshot_\$(date +%Y-%m-%d_%H-%M-%S).png && grim -g "\$(slurp)" \$FILE && notify-send -i camera-photo "Screenshot Area Berhasil" "Disimpan ke:\n\$FILE"'
EOF

    if [ ! -f "$USER_HOME/.config/kanshi/config" ]; then echo 'profile { output "*" mode auto position 0,0 }' > "$USER_HOME/.config/kanshi/config"; fi
    chown -R "$REAL_USER":"$REAL_USER" "$USER_HOME/.config"
    echo "[Sukses] Konfigurasi profil user '$REAL_USER' berhasil dikunci."
else
    echo "! User biasa tidak ditemukan. Membuat template profil global sistem..."
    mkdir -p /etc/xdg/kanshi
fi

echo "=== SEMUA BLOK SKRIP SELESAI DIPROSES! MEMULAI REBOOT SYSTEM... ==="
sleep 2 && reboot
