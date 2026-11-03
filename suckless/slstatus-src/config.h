/* See LICENSE file for copyright and license details. */

/* interval between updates (in ms) */
const unsigned int interval = 1000;

/* text to show if no value can be retrieved */
static const char unknown_str[] = "n/a";

/* maximum output string length */
#define MAXLEN 2048

/*
 * function            description                     argument (example)
 *
 * battery_perc        battery percentage              battery name (BAT0)
 *                                                     NULL on OpenBSD/FreeBSD
 * battery_remaining   battery remaining HH:MM         battery name (BAT0)
 *                                                     NULL on OpenBSD/FreeBSD
 * battery_state       battery charging state          battery name (BAT0)
 *                                                     NULL on OpenBSD/FreeBSD
 * cat                 read arbitrary file             path
 * cpu_freq            cpu frequency in MHz            NULL
 * cpu_perc            cpu usage in percent            NULL
 * datetime            date and time                   format string (%F %T)
 * disk_free           free disk space in GB           mountpoint path (/)
 * disk_perc           disk usage in percent           mountpoint path (/)
 * disk_total          total disk space in GB          mountpoint path (/)
 * disk_used           used disk space in GB           mountpoint path (/)
 * entropy             available entropy               NULL
 * gid                 GID of current user             NULL
 * hostname            hostname                        NULL
 * ipv4                IPv4 address                    interface name (eth0)
 * ipv6                IPv6 address                    interface name (eth0)
 * kernel_release      `uname -r`                      NULL
 * keyboard_indicators caps/num lock indicators        format string (c?n?)
 *                                                     see keyboard_indicators.c
 * keymap              layout (variant) of current     NULL
 *                     keymap
 * load_avg            load average                    NULL
 * netspeed_rx         receive network speed           interface name (wlan0)
 * netspeed_tx         transfer network speed          interface name (wlan0)
 * num_files           number of files in a directory  path
 *                                                     (/home/foo/Inbox/cur)
 * ram_free            free memory in GB               NULL
 * ram_perc            memory usage in percent         NULL
 * ram_total           total memory size in GB         NULL
 * ram_used            used memory in GB               NULL
 * run_command         custom shell command            command (echo foo)
 * swap_free           free swap in GB                 NULL
 * swap_perc           swap usage in percent           NULL
 * swap_total          total swap size in GB           NULL
 * swap_used           used swap in GB                 NULL
 * temp                temperature in degree celsius   sensor file
 *                                                     (/sys/class/thermal/...)
 *                                                     NULL on OpenBSD
 *                                                     thermal zone on FreeBSD
 *                                                     (tz0, tz1, etc.)
 * uid                 UID of current user             NULL
 * uptime              system uptime                   NULL
 * username            username of current user        NULL
 * vol_perc            OSS/ALSA volume in percent      mixer file (/dev/mixer)
 *                                                     NULL on OpenBSD/FreeBSD
 * wifi_essid          WiFi ESSID                      interface name (wlan0)
 * wifi_perc           WiFi signal in percent          interface name (wlan0)
 */
 /* \00N before a block makes it clickable: dwm runs statuscmds[] id N
  * (victariwm/config.h). Octal on purpose: \x01 would eat a following hex digit. */
 static const struct arg args[] = {
	/* function       format                          argument */
	/* micrófono: solo aparece (en rojo) cuando está ABIERTO */
	{ run_command,    "\001 ^c#ef4444^%s^d^",               "wpctl get-volume @DEFAULT_AUDIO_SOURCE@ | grep -q MUTED && echo || echo '󰍬^d^ | '" },
	/* volumen: ícono distinto si está en mute (wpctl, igual que las teclas de dwm) */
	{ run_command,    "\002^c#f59e0b^%s^d^ | ",             "wpctl get-volume @DEFAULT_AUDIO_SINK@ | LC_ALL=C awk '{printf \"%s %d%%\", ($3==\"[MUTED]\" ? \"󰝟\" : \"󰕾\"), $2*100}'" },
	{ datetime,       "\003^c#84cc16^󰅐 %s^d^ | ",           "%I:%M:%S %p" },
	/* SSID cortado a 5 caracteres + banda calculada de la frecuencia */
	{ wifi_essid,     "\004^c#3b82f6^ %.5s ",            "wlp1s0" },
	{ run_command,    "%s ",                           "iwgetid wlp1s0 -f -r | LC_ALL=C awk '{f=$1/1e9; print (f>=5.9 ? \"6G\" : (f>=4.9 ? \"5G\" : \"2G\"))}'" },
	{ wifi_perc,      "%s%%^d^ | ",                     "wlp1s0" },
	{ cpu_perc,       "\005^c#06b6d4^ %s%%^d^ ",          NULL },
	/* zona x86_pkg_temp; si muestra n/a tras un update de kernel, buscarla de nuevo */
	{ temp,           "^c#06b6d4^%s°^d^ | ",            "/sys/class/thermal/thermal_zone16/temp" },
	{ ram_perc,       "\005^c#a855f7^󰫗 %s%%^d^ | ",         NULL },
	{ battery_state,  "\006^c#f43f5e^ %s ",               "BAT0" },
	{ battery_perc,   "%s%%^d^",                       "BAT0" },
 };
