#!/system/bin/sh
MODDIR=${0%/*}

# The SD card is mounted by vold around late_start; `start` waits for it itself.
/system/bin/sh "$MODDIR/bin/sd-redirect" start >/dev/null 2>&1 &
