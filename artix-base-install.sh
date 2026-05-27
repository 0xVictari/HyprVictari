#!/usr/bin/env bash
#
# artix-base-install.sh
#
# Instalacion base de Artix Linux con dinit desde la ISO artix-base.
# Layout con /boot separado (sin encriptar) para habilitar Plymouth a
# futuro, root y swap sobre LUKS. Swap desbloqueado por el hook 'openswap'
# con keyfile embebido, lo que permite hibernacion con UNA SOLA passphrase
# en boot (solo se pide la de root).
#
# DISENADO PARA UN CASO CONCRETO:
#   - Un solo disco NVMe/SATA
#   - LUKS sobre root y swap, ext4
#   - Single boot (sin dual-boot), UEFI
#
# LECCION APRENDIDA (importante):
#   El approach de DOS 'cryptdevice' en la linea de kernel con un 'cryptkey'
#   compartido NO funciona: el hook 'encrypt' clasico no soporta multiples
#   cryptdevices y aplica mal la llave, dejando root sin desbloquear.
#   La solucion correcta es el hook 'openswap' (paquete mkinitcpio-openswap):
#   'encrypt' desbloquea root con passphrase, y 'openswap' abre el swap
#   despues con el keyfile. Cada hook hace una sola cosa.
#
# FUERA DE SCOPE: dual-boot, LVM, btrfs/subvolumenes, RAID, multiples
# discos, y toda la fase desktop/Hyprland (va a un script post-install).
#
# USO:  Bootear ISO artix-base-dinit, CONECTAR RED (ver notas), luego:
#         sudo ./artix-base-install.sh
#
# RED EN EL LIVE (workarounds verificados en este hardware):
#   El usuario del live NO es root: todos los comandos van con sudo.
#   sudo iwctl station wlan0 connect <SSID>
#   sudo dhclient wlan0
#   sudo ip route add default via 192.168.0.1 dev wlan0   # si falta gateway
#   echo "nameserver 1.1.1.1" | sudo tee /etc/resolv.conf  # si falla DNS
#
# ADVERTENCIA: este script BORRA el disco que selecciones. Hay una
# confirmacion explicita antes de tocar nada.

set -euo pipefail

# =============================================================================
# VARIABLES DE DISENO  (decisiones estables, editar aca)
# =============================================================================

EFI_SIZE="512M"
BOOT_SIZE="1G"
SWAP_SIZE="20G"          # >= RAM (16G) + margen, requisito para hibernacion
FS_TYPE="ext4"
KERNEL="linux"

ROOT_MAPPER="luks-root"
SWAP_MAPPER="luks-swap"
SWAP_KEYFILE="/etc/cryptswap.key"

# HOOKS de mkinitcpio. Orden critico:
#   keyboard/keymap ANTES de encrypt (para tipear la passphrase)
#   encrypt -> openswap -> resume -> filesystems
#   'openswap' abre el swap con keyfile DESPUES de que encrypt abrio root.
MKINITCPIO_HOOKS="base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt openswap resume filesystems fsck"

# Keyfile embebido en initramfs para que openswap lo encuentre
MKINITCPIO_FILES="${SWAP_KEYFILE}"

DEFAULT_TIMEZONE="America/Argentina/Cordoba"
DEFAULT_KEYMAP_TTY="la-latin1"   # keymap de consola (TTY)

# Paquetes del sistema base (sin desktop).
# NOTA: mkinitcpio-openswap es OBLIGATORIO para el esquema de hibernacion.
BASE_PACKAGES="base base-devel ${KERNEL} ${KERNEL}-headers linux-firmware \
intel-ucode \
dinit elogind-dinit \
cryptsetup device-mapper \
networkmanager networkmanager-dinit iwd iwd-dinit \
grub efibootmgr \
plymouth \
mkinitcpio mkinitcpio-openswap \
nano vim git zsh sudo \
dhcpcd"

# =============================================================================
# HELPERS
# =============================================================================

log()  { printf '\033[1;32m[*]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

confirm_destroy() {
    local target="$1" answer
    printf '\033[1;31mEsto BORRARA todo en %s. Escribi "yes" para continuar:\033[0m ' "$target"
    read -r answer
    [[ "$answer" == "yes" ]] || die "Cancelado por el usuario."
}

require_root() { [[ "$(id -u)" -eq 0 ]] || die "Correr como root (sudo)."; }

# Variables que se setean en runtime
DISK=""
P_EFI="" P_BOOT="" P_SWAP="" P_ROOT=""
HOSTNAME_VAL=""
USERNAME_VAL=""

# =============================================================================
# FASE 0 — PRE-FLIGHT
# =============================================================================

preflight() {
    log "FASE 0 — Pre-flight checks"
    require_root

    [[ -d /sys/firmware/efi ]] || die "No se detecto UEFI. Este script asume UEFI."
    log "Firmware: UEFI OK"

    local missing=0 t
    for t in lsblk cryptsetup basestrap artix-chroot sgdisk mkfs.ext4 \
             mkfs.fat fstabgen blkid; do
        if command -v "$t" >/dev/null 2>&1; then
            log "OK   $t"
        else
            err "FALTA $t"
            missing=1
        fi
    done
    [[ "$missing" -eq 0 ]] || die "Faltan herramientas. Instalar antes (ej: pacman -Sy gptfdisk para sgdisk)."

    if ping -c1 -W3 1.1.1.1 >/dev/null 2>&1; then
        log "Conectividad OK"
    else
        die "Sin conexion a internet. Configurar red en el live (ver cabecera)."
    fi
}

# =============================================================================
# FASE 1 — SELECCION DE DISCO
# =============================================================================

select_disk() {
    log "FASE 1 — Seleccion de disco"
    echo
    echo "Discos disponibles:"
    mapfile -t disks < <(lsblk -dpno NAME,SIZE,MODEL,TYPE | awk '$NF=="disk"')
    [[ "${#disks[@]}" -gt 0 ]] || die "No se encontraron discos."

    local i
    for i in "${!disks[@]}"; do
        printf "  [%d] %s\n" "$i" "${disks[$i]}"
    done

    echo
    local sel
    printf "Numero de disco a usar: "
    read -r sel
    [[ "$sel" =~ ^[0-9]+$ ]] && [[ -n "${disks[$sel]:-}" ]] || die "Seleccion invalida."

    DISK="$(awk '{print $1}' <<< "${disks[$sel]}")"
    log "Disco seleccionado: $DISK"

    echo
    echo "Contenido actual de $DISK (se va a BORRAR):"
    lsblk "$DISK"
    echo
    confirm_destroy "$DISK"

    # Derivar nombres de particion: nvme usa 'pN', sata usa 'N'
    if [[ "$DISK" =~ nvme ]]; then
        P_EFI="${DISK}p1"; P_BOOT="${DISK}p2"; P_SWAP="${DISK}p3"; P_ROOT="${DISK}p4"
    else
        P_EFI="${DISK}1"; P_BOOT="${DISK}2"; P_SWAP="${DISK}3"; P_ROOT="${DISK}4"
    fi
    log "Particiones: EFI=$P_EFI BOOT=$P_BOOT SWAP=$P_SWAP ROOT=$P_ROOT"
}

# =============================================================================
# FASE 2 — PARTICIONADO
# =============================================================================

partition_disk() {
    log "FASE 2 — Particionado"
    sgdisk --zap-all "$DISK"
    sgdisk \
        -n 1:0:+"$EFI_SIZE"  -t 1:ef00 -c 1:"EFI" \
        -n 2:0:+"$BOOT_SIZE" -t 2:8300 -c 2:"boot" \
        -n 3:0:+"$SWAP_SIZE" -t 3:8200 -c 3:"swap" \
        -n 4:0:0             -t 4:8309 -c 4:"root" \
        "$DISK"
    sgdisk --print "$DISK"
    # Refrescar la tabla de particiones en el kernel. partprobe es opcional;
    # si no esta, udevadm settle (siempre presente) hace el trabajo.
    if command -v partprobe >/dev/null 2>&1; then
        partprobe "$DISK" 2>/dev/null || true
    fi
    udevadm settle 2>/dev/null || true
    sleep 1
}

# =============================================================================
# FASE 3 — ENCRIPTACION LUKS
# =============================================================================

setup_luks() {
    log "FASE 3 — Encriptacion LUKS"
    warn "Vas a definir la PASSPHRASE DE ROOT (la que tipeas en cada boot)."
    warn "Para el swap usa la MISMA passphrase (el keyfile la reemplaza en boot normal)."

    log "Formateando root ($P_ROOT)..."
    cryptsetup luksFormat --type luks2 "$P_ROOT"
    log "Formateando swap ($P_SWAP)..."
    cryptsetup luksFormat --type luks2 "$P_SWAP"

    log "Abriendo root..."
    cryptsetup open "$P_ROOT" "$ROOT_MAPPER"
    log "Abriendo swap..."
    cryptsetup open "$P_SWAP" "$SWAP_MAPPER"

    ls -l /dev/mapper/ | grep -E "$ROOT_MAPPER|$SWAP_MAPPER"
}

# =============================================================================
# FASE 4 — FORMATO Y MONTAJE
# =============================================================================

format_and_mount() {
    log "FASE 4 — Formato y montaje"
    mkfs.fat -F32 "$P_EFI"
    mkfs."$FS_TYPE" "$P_BOOT"
    mkfs."$FS_TYPE" "/dev/mapper/$ROOT_MAPPER"
    mkswap "/dev/mapper/$SWAP_MAPPER"

    mount "/dev/mapper/$ROOT_MAPPER" /mnt
    mkdir -p /mnt/boot
    mount "$P_BOOT" /mnt/boot
    mkdir -p /mnt/boot/efi
    mount "$P_EFI" /mnt/boot/efi
    swapon "/dev/mapper/$SWAP_MAPPER"

    lsblk "$DISK"
}

# =============================================================================
# FASE 5 — SISTEMA BASE + KEYFILE
# =============================================================================

install_base() {
    log "FASE 5 — Sistema base (basestrap)"
    # shellcheck disable=SC2086
    basestrap /mnt $BASE_PACKAGES

    log "Generando fstab..."
    fstabgen -U /mnt >> /mnt/etc/fstab

    log "Generando keyfile del swap y agregandolo como key slot..."
    dd if=/dev/urandom of="/mnt${SWAP_KEYFILE}" bs=512 count=4
    chmod 600 "/mnt${SWAP_KEYFILE}"
    cryptsetup luksAddKey "$P_SWAP" "/mnt${SWAP_KEYFILE}"

    log "Keyslots del swap (deberian ser 2: passphrase + keyfile):"
    cryptsetup luksDump "$P_SWAP" | grep -c "luks2" || true
}

# =============================================================================
# FASE 6 — CONFIGURACION (dentro de artix-chroot)
# =============================================================================

configure_system() {
    log "FASE 6 — Configuracion del sistema (chroot)"

    local UUID_ROOT UUID_SWAP
    UUID_ROOT="$(blkid -s UUID -o value "$P_ROOT")"
    UUID_SWAP="$(blkid -s UUID -o value "$P_SWAP")"
    log "UUID root (LUKS crudo): $UUID_ROOT"
    log "UUID swap (LUKS crudo): $UUID_SWAP"

    printf "Hostname: "; read -r HOSTNAME_VAL
    printf "Nombre de usuario: "; read -r USERNAME_VAL

    cat > /mnt/root/chroot-setup.sh <<CHROOT_EOF
#!/usr/bin/env bash
set -euo pipefail

# --- Timezone ---
ln -sf /usr/share/zoneinfo/${DEFAULT_TIMEZONE} /etc/localtime
hwclock --systohc

# --- Locale: display en ingles, formatos regionales AR ---
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "es_AR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
cat > /etc/locale.conf <<LOCALE
LANG=en_US.UTF-8
LC_TIME=es_AR.UTF-8
LC_MONETARY=es_AR.UTF-8
LC_PAPER=es_AR.UTF-8
LOCALE

# --- Keymap de consola (teclado latam) ---
echo "KEYMAP=${DEFAULT_KEYMAP_TTY}" > /etc/vconsole.conf

# --- Hostname ---
echo "${HOSTNAME_VAL}" > /etc/hostname
cat > /etc/hosts <<HOSTS
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME_VAL}.localdomain ${HOSTNAME_VAL}
HOSTS

# --- openswap config (CLAVE para hibernacion con passphrase unica) ---
# IMPORTANTE: el hook openswap NO lee 'keyfile=' como ruta directa. Monta
# keyfile_device y busca keyfile_filename (ruta RELATIVA, sin barra inicial)
# dentro de el. Formato verificado funcionando:
cat > /etc/openswap.conf <<OPENSWAP
swap_device=/dev/disk/by-uuid/${UUID_SWAP}
crypt_swap_name=${SWAP_MAPPER}
keyfile_device=/dev/mapper/${ROOT_MAPPER}
keyfile_filename=${SWAP_KEYFILE#/}
cryptsetup_options="--type luks2"
OPENSWAP

# --- mkinitcpio: HOOKS y FILES ---
sed -i "s|^HOOKS=.*|HOOKS=(${MKINITCPIO_HOOKS})|" /etc/mkinitcpio.conf
sed -i "s|^FILES=.*|FILES=(${MKINITCPIO_FILES})|" /etc/mkinitcpio.conf
mkinitcpio -P

# --- GRUB ---
# UN SOLO cryptdevice (root). El swap lo abre 'openswap'.
# resume= apunta al mapper del swap. SIN cryptkey, SIN GRUB_ENABLE_CRYPTODISK.
sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=.*|GRUB_CMDLINE_LINUX_DEFAULT=\"quiet cryptdevice=UUID=${UUID_ROOT}:${ROOT_MAPPER} root=/dev/mapper/${ROOT_MAPPER} resume=/dev/mapper/${SWAP_MAPPER}\"|" /etc/default/grub

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Artix
grub-mkconfig -o /boot/grub/grub.cfg

# --- Servicios dinit (por symlink) ---
# NetworkManager es el gestor de red principal y va habilitado en boot.
ln -sf /etc/dinit.d/NetworkManager /etc/dinit.d/boot.d/NetworkManager
# iwd-dinit queda INSTALADO pero NO habilitado en boot.d: habilitarlo
# competiria con NetworkManager. iwd puede usarse luego como BACKEND de
# NetworkManager via drop-in (/etc/NetworkManager/conf.d/), no como servicio
# independiente. No crear symlink de iwd en boot.d.

# --- Passwords y usuario ---
echo ">>> Defini la contrasena de ROOT:"
passwd
useradd -m -G wheel,video,audio,storage,input -s /bin/zsh "${USERNAME_VAL}"
echo ">>> Defini la contrasena de ${USERNAME_VAL}:"
passwd "${USERNAME_VAL}"

# --- sudo para wheel ---
sed -i 's|^# %wheel ALL=(ALL:ALL) ALL|%wheel ALL=(ALL:ALL) ALL|' /etc/sudoers

echo ">>> Configuracion en chroot completada."
CHROOT_EOF

    chmod +x /mnt/root/chroot-setup.sh
    log "Entrando al chroot para ejecutar la configuracion..."
    artix-chroot /mnt /root/chroot-setup.sh
    rm -f /mnt/root/chroot-setup.sh
}

# =============================================================================
# FASE 7 — CIERRE
# =============================================================================

finalize() {
    log "FASE 7 — Cierre"
    swapoff "/dev/mapper/$SWAP_MAPPER" || true
    umount -R /mnt || true
    cryptsetup close "$ROOT_MAPPER" || true
    cryptsetup close "$SWAP_MAPPER" || true
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    preflight
    select_disk
    partition_disk
    setup_luks
    format_and_mount
    install_base
    configure_system
    finalize

    echo
    log "===================== INSTALACION COMPLETA ====================="
    echo "  Saca el pendrive del live y reinicia:  reboot"
    echo
    echo "  Boot esperado:"
    echo "   1. GRUB carga (lee /boot sin encriptar)"
    echo "   2. Pide la passphrase de ROOT una sola vez"
    echo "   3. 'openswap' abre el swap con el keyfile (sin pedir nada)"
    echo "   4. Llegas al login de TTY"
    echo
    warn "Primer login: verifica red (NetworkManager) y swap (swapon --show)."
    warn "Luego corre el script post-install para el desktop (Hyprland, etc.)."
}

main "$@"
