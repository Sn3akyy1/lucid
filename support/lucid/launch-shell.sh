#!/usr/bin/env bash
# launch-shell.sh — starts Quickshell with a scene graph backend that can
# actually keep up with the monitor.
#
# Qt's wayland-egl plugin refuses threaded OpenGL on the proprietary NVIDIA
# driver (it is the QTBUG-95817 resize-freeze workaround), so Qt Quick drops to
# the basic render loop. That loop drives animations from a fixed ~16ms timer
# with no vsync awareness, which pins every animation in the shell to ~60fps
# however fast the monitor runs — the choppy motion high-refresh NVIDIA users
# report while Hyprland itself stays smooth. Qt's Vulkan RHI backend carries no
# such vendor check and keeps the threaded loop, so animations follow the real
# refresh rate again.
#
# the switch is deliberately narrow: it only happens when NVIDIA really is the
# GPU the compositor renders on. Mesa already gets the threaded loop, and
# nothing is gained by moving those systems off OpenGL.
#
# LUCID_RHI_BACKEND=vulkan|opengl overrides the detection; an existing
# QSG_RHI_BACKEND in the environment is always left alone.
# run with --explain to print the decision without starting the shell.

set -euo pipefail

# probe roots, overridable so the detection can be exercised off real hardware
: "${LUCID_NVIDIA_VERSION_FILE:=/proc/driver/nvidia/version}"
: "${LUCID_DRM_DIR:=/sys/class/drm}"
: "${LUCID_VULKAN_ICD_DIR:=/usr/share/vulkan/icd.d}"

# oldest driver branch trusted for Wayland Vulkan — 555 is where NVIDIA shipped
# explicit sync. the legacy 470/390 branches stay on the OpenGL path
MIN_NVIDIA_DRIVER=555

# major version of the loaded proprietary driver, empty when it is not loaded
nvidia_driver_major() {
    if [[ ! -r $LUCID_NVIDIA_VERSION_FILE ]]; then
        return 0
    fi
    sed -n '/NVRM version:/{s/.*Kernel Module *\([0-9]\{1,\}\)\.[0-9].*/\1/p;q}' \
        "$LUCID_NVIDIA_VERSION_FILE"
}

# the card the compositor renders on: an explicit device list wins, then the
# only card present, then the boot vga
render_card() {
    local list first name card
    list="${AQ_DRM_DEVICES:-${WLR_DRM_DEVICES:-}}"
    if [[ -n $list ]]; then
        first="${list%%:*}"
        name="${first##*/}"
        if [[ -n $name ]]; then
            printf '%s\n' "$LUCID_DRM_DIR/$name"
        fi
        return 0
    fi

    local cards=()
    for card in "$LUCID_DRM_DIR"/card*; do
        name="${card##*/}"
        # skip the per-connector directories, they are not devices
        if [[ ! $name =~ ^card[0-9]+$ ]]; then
            continue
        fi
        if [[ -r $card/device/vendor ]]; then
            cards+=("$card")
        fi
    done

    if (( ${#cards[@]} == 0 )); then
        return 0
    fi
    if (( ${#cards[@]} == 1 )); then
        printf '%s\n' "${cards[0]}"
        return 0
    fi
    for card in "${cards[@]}"; do
        if [[ -r $card/device/boot_vga && $(< "$card/device/boot_vga") == 1 ]]; then
            printf '%s\n' "$card"
            return 0
        fi
    done
    return 0
}

# an nvidia vulkan driver whose library actually resolves on disk. the icd file
# alone proves nothing: nvidia-utils is installed on plenty of non-nvidia boxes
nvidia_vulkan_icd() {
    local icd lib dir
    for icd in "$LUCID_VULKAN_ICD_DIR"/nvidia_icd*.json; do
        if [[ ! -r $icd ]]; then
            continue
        fi
        lib=$(sed -n '/"library_path"/{s/.*"library_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p;q}' "$icd")
        if [[ -z $lib ]]; then
            continue
        fi
        if [[ $lib == */* ]]; then
            if [[ -e $lib ]]; then
                return 0
            fi
            continue
        fi
        for dir in /usr/lib /usr/lib64 /usr/lib/x86_64-linux-gnu; do
            if [[ -e $dir/$lib ]]; then
                return 0
            fi
        done
    done
    return 1
}

reason=""

wants_vulkan() {
    local major card vendor

    if [[ ! -r $LUCID_NVIDIA_VERSION_FILE ]]; then
        reason="proprietary nvidia driver not loaded"
        return 1
    fi
    major=$(nvidia_driver_major)
    if [[ -z $major ]]; then
        reason="no version found in $LUCID_NVIDIA_VERSION_FILE"
        return 1
    fi
    if (( major < MIN_NVIDIA_DRIVER )); then
        reason="nvidia driver $major predates $MIN_NVIDIA_DRIVER"
        return 1
    fi

    card=$(render_card)
    if [[ -z $card || ! -r $card/device/vendor ]]; then
        reason="could not tell which gpu the compositor renders on"
        return 1
    fi
    vendor=$(< "$card/device/vendor")
    if [[ $vendor != 0x10de ]]; then
        reason="compositor renders on ${card##*/}, vendor $vendor is not nvidia"
        return 1
    fi

    if ! nvidia_vulkan_icd; then
        reason="no usable nvidia vulkan driver under $LUCID_VULKAN_ICD_DIR"
        return 1
    fi

    reason="nvidia driver $major on ${card##*/}"
    return 0
}

backend=""
if [[ -n ${QSG_RHI_BACKEND:-} ]]; then
    backend="$QSG_RHI_BACKEND"
    reason="QSG_RHI_BACKEND was already set in the environment"
else
    case "${LUCID_RHI_BACKEND:-auto}" in
        vulkan)
            backend="vulkan"
            reason="forced by LUCID_RHI_BACKEND"
            ;;
        opengl|gl)
            reason="opengl forced by LUCID_RHI_BACKEND"
            ;;
        auto|"")
            if wants_vulkan; then
                backend="vulkan"
            fi
            ;;
        *)
            printf 'launch-shell: ignoring unknown LUCID_RHI_BACKEND %s\n' \
                "$LUCID_RHI_BACKEND" >&2
            if wants_vulkan; then
                backend="vulkan"
            fi
            ;;
    esac
fi

if [[ ${1:-} == --explain ]]; then
    printf 'backend: %s\n' "${backend:-opengl (Qt default)}"
    printf 'reason:  %s\n' "$reason"
    exit 0
fi

if [[ -n $backend ]]; then
    export QSG_RHI_BACKEND="$backend"
fi

exec quickshell "$@"
