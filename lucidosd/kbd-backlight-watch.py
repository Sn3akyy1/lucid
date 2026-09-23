#!/usr/bin/env python3
"""Report the keyboard backlight level, one line per change.

The key that changes it is handled in firmware: the kernel updates the led
and raises a sysfs notification, without anything writing the file, so a
file watch (inotify) never hears about it. poll() on brightness_hw_changed
is the interface meant for exactly this. A write from elsewhere - upower,
brightnessctl, the shell - does not raise it, and the caller watches the
file for those.

Usage: kbd-backlight-watch.py /sys/class/leds/<device>
"""
import ctypes
import errno
import os
import select
import signal
import sys


def die_with_parent():
    """Leave when the shell does.

    The watcher blocks in poll() and only writes when the level changes, so
    a shell that exits would otherwise leave it waiting for a key press with
    nobody listening, one per restart. PR_SET_PDEATHSIG has the kernel send
    the signal as soon as the parent is gone.
    """
    PR_SET_PDEATHSIG = 1
    try:
        ctypes.CDLL("libc.so.6", use_errno=True).prctl(PR_SET_PDEATHSIG, signal.SIGTERM, 0, 0, 0)
    except (OSError, AttributeError):
        return

    # the parent may already be gone by the time the signal was armed
    if os.getppid() == 1:
        os._exit(0)


def read_level(path):
    try:
        with open(path) as f:
            return int(f.read().strip() or 0)
    except (OSError, ValueError):
        return None


def arm(fd):
    """Read the notification file, which re-arms poll() for the next change.

    Returns the level the hardware last set, or None when it has not set one
    yet: until the first hardware change since boot the read fails with
    ENODATA (Documentation/ABI/testing/sysfs-class-led). That is the normal
    state right after a reboot, and the read arms poll() all the same -
    kernfs takes the event count before it asks the attribute - so it is not
    an error here. Anything else, such as the led going away with its driver,
    is left to raise.
    """
    os.lseek(fd, 0, os.SEEK_SET)
    try:
        data = os.read(fd, 64)
    except OSError as err:
        if err.errno == errno.ENODATA:
            return None
        raise
    try:
        return int(data.strip())
    except ValueError:
        return None


def main():
    if len(sys.argv) < 2:
        return 2

    die_with_parent()
    device = sys.argv[1]
    brightness = os.path.join(device, "brightness")
    hw_changed = os.path.join(device, "brightness_hw_changed")

    level = read_level(brightness)
    if level is None:
        return 1

    print(level, flush=True)

    # not every driver exposes it; without it the key is invisible here and
    # the file watch on the caller's side is all there is
    try:
        notify = os.open(hw_changed, os.O_RDONLY)
    except OSError:
        return 0

    try:
        arm(notify)
        poller = select.poll()
        poller.register(notify, select.POLLPRI | select.POLLERR)
        while True:
            if not poller.poll():
                continue

            # the notification carries the level the hardware just set, so
            # it needs no reread of brightness, which the driver may not have
            # caught up with yet
            current = arm(notify)
            if current is None:
                current = read_level(brightness)
            if current is not None and current != level:
                level = current
                print(level, flush=True)
    except OSError:
        # the led went away with its driver: every poll() would now return
        # at once, so leave rather than spin
        return 1
    finally:
        os.close(notify)


if __name__ == "__main__":
    sys.exit(main())
