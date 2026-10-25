SKIPUNZIP=0

[ "$API" -lt 30 ] && abort "! Android 11 (API 30) or newer is required"

ui_print "- Setting up /data/adb/sd-redirect"
mkdir -p /data/adb/sd-redirect
if [ ! -f /data/adb/sd-redirect/config ]; then
  cp "$MODPATH/config.default" /data/adb/sd-redirect/config
  ui_print "- Default config created"
else
  ui_print "- Keeping existing config"
fi

set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/bin/sd-redirect" 0 2000 0755

ui_print "- Configure apps in the WebUI, or from a root shell:"
ui_print "  sh /data/adb/modules/sd-redirect/bin/sd-redirect help"
