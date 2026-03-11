<!--keywords[Debian_Package,dpkg,deb]-->

**Betzbirdiary Debian Package**

***Install***

- `sudo apt install .//betzbird_1.0.0_arm64.deb` installiert *dependencies*, `dpkg` nicht.

- Erfolgskontrolle mit `apt list --installed` und in `/usr/lib/betzbird`.

- Starte mit dem Kommando `sudo -u betzbird betzbird` oder besser `sudo systemctl start/stop betzbird` oder beim Booten über ein `betzbird.service`:
````
[Unit]
Description=BetzBirdiary Startup
After=network.target

[Service]
Type=simple
User=betzbird
Group=betzbird
ExecStart=/usr/bin/betzbird
WorkingDirectory=/usr/lib/betzbird
Restart=on-failure

[Install]
WantedBy=multi-user.target
````
danach
````
sudo systemctl enable betzbird.service
sudo systemctl start betzbird.service
````
`debian/betzbird.service` kann im .deb Package in `debian/` mit `postinst` installiert und aktiviert und mit `postrm` wieder gestoppt werden.

***Debian OS specifics***

- DietPI: `dropbear` durch `openSSH` ersetzen. 

***Build***

- Das Debian Package muss auf dem Raspberry (ARM CPU) gebaut werden, wenn Crosscompiler Tools vermieden werden sollen.

- In allen debian-basierten Distributionen ist Python3 über `/usr/bin/python3` ansprechbar (kein VENV).

- `sudo apt install -y build-essential devscripts debhelper dh-python python3-all`

- Im Project root `betzBirdiary` erstelle die Verzeichnisse `stationDeb/` und `debian/` .

- `stationDeb/betzbird` ist das Startup Skript (nicht `betzbird.sh`):
````
#!/bin/bash
# launcher binary for debian package
cd /usr/lib/betzbird
./startup1stage.sh
````
- alle die anderen Skripte (python, bash, config) und Verzeichnissen sind in `stationDeb`.

- Permissions wie `chmod +x *.sh` vor dem Build setzen, Bau als User `(diet)pi`. Der User darf später in `/usr/lib/betzbird` selbst in einem Skript `startupNoInet.sh` kein `chmod` mehr ausführen und auch sonst nichts schreiben lassen. Alles in `/usr/lib/betzbird` ist für den User *readonly* ! Der User darf nur nach `/var` schreiben, was in `debian/postinst` genauer vorbereitet wird.

- Verzeichnislinks der Skripte an den Installationspfad `/usr/lib/betzbird`anpassen bzw. Schreibprozesse auf `/var`. Um mit vielen debianbasierten OS wie DietPi, Raspbian und Ubuntu kompatibel zu bleiben, wird ein eigener Systemuser `betzbird` mit `postinst` angelegt.

- `program maintained states` wie `config.json`, `camdata` oder `statistics` werden selten beschrieben und sind sonst permanent zwischen Boots. Sie gehören nach `/var/lib/betzbird`. `config.json` wird bei Packageinstallation einmalig dorthin aus `/usr/lib/betzbird` durch `debian/postinst` kopiert. `camdata, statistics etc.` werden durch die App erzeugt.

- logs können nach `/var/log/betzbird` oder `/var/lib/betzbird/logs`.

- `human edited config` wie `keep/` oder `mybirds/` gehören nach `/etc/betzbirds`. Ein bestimmter User hängt ja vom Debian-OS ab.

- Da nur `root`mounten darf, erfolgt die Aktivierung von `/var/lib/betzbird/Ramdisk  über den Systemservice mit `debian/var-lib-betzbird-ramdisk.mount`. Das systemeigene `/var/run` ist etwas undefiniert und wird vermieden. FIFO wird am besten im Startup Skript `startupNoInet.sh` von der App erzeugt, die ähnlich wie `postinst` Dateien und Verzeichnisse erzeugen kann.

- Crontab Kommandos werden in `debian/betzbird.cron.d` eingefügt. `dh_installcron (from debhelper)`  installiert / deinstalliert das in `/etc/cron.d/betzbird`. Dazu muss es aber in `rules` aktiviert sein mit `--with cron`.

- logrotate: wie crontab wird auch `debian/betzbird.logrotate` durch `dh_installlogrotate` (ohne Aktivierung in `rules`) nach `/etc/logrotate.d/betzbird` installiert und ist dort aktiv.

- `chmod +x postinst rules preinst prerm postrm`

- `debian/postinst` ausführbar mit `chmod +x postinst`:
````
#!/bin/sh
set -e

APP=betzbird
APPUSER=betzbird
APPGROUP=betzbird
# STATE is 'writedir' in configBird3.py:
STATE=/var/lib/$APP
DEFAULT=/usr/lib/$APP/config.default.json
RUNTIME=$STATE/config.json

# system user
if ! getent passwd "$APPUSER" >/dev/null; then
    adduser --system --group --home "$STATE" "$APPUSER"
fi

# persistent dirs
mkdir -p /etc/$APP
mkdir -p /var/log/$APP
mkdir -p "$STATE"
mkdir -p "$STATE/ramdisk"
mkdir -p "$STATE/keep"

# ownership
chown root:root /etc/$APP
chmod 755 /etc/$APP

chown -R $APPUSER:$APPGROUP /var/log/$APP "$STATE"
chmod 750 /var/log/$APP "$STATE"

# initial state file (first install only)
# states apart from config.json like camdata or statistics are created by the APP itself
if [ ! -f "$RUNTIME" ]; then
    cp "$DEFAULT" "$RUNTIME"
    chown $APPUSER:$APPGROUP "$RUNTIME"
    chmod 640 "$RUNTIME"
fi
# initialize keep/ from defaults (first install only, when $STATE/keep/ empty)
if [ -d /usr/lib/$APP/keep ]; then
    if [ -z "$(ls -A "$STATE/keep" 2>/dev/null)" ]; then
        cp -a /usr/lib/$APP/keep/. "$STATE/keep/"
        chown -R $APPUSER:$APPGROUP "$STATE/keep"
    fi
fi

# enable service if systemd exists
if command -v systemctl >/dev/null 2>&1; then
    systemctl daemon-reload
    systemctl enable betzbird.service
    systemctl start betzbird.service
    systemctl enable var-lib-betzbird-ramdisk.mount
	systemctl start var-lib-betzbird-ramdisk.mount
fi
exit 0
````
- `debian/postrm` mit `+x`:
````
#!/bin/sh
set -e

APP=betzbird
MOUNT_UNIT=var-lib-betzbird-ramdisk.mount

# Only interact with systemd if it exists
if command -v systemctl >/dev/null 2>&1; then
    case "$1" in
        remove|upgrade)
            # Stop service and ramdisk (but keep them enabled)
            systemctl stop $APP.service 2>/dev/null || true
            systemctl stop $MOUNT_UNIT 2>/dev/null || true
            ;;

        purge)
            # Stop and disable everything on purge
            systemctl stop $APP.service 2>/dev/null || true
            systemctl disable $APP.service 2>/dev/null || true

            systemctl stop $MOUNT_UNIT 2>/dev/null || true
            systemctl disable $MOUNT_UNIT 2>/dev/null || true
            ;;
    esac

    # Reload systemd after unit changes
    systemctl daemon-reload
fi

exit 0

````
- `debian/var-lib-betzbird-ramdisk.mount` (entspricht `/var/lib/betzbird/ramdisk`):

````
[Unit]
Description=betzbird tmpfs ramdisk
Before=betzbird.service

[Mount]
What=tmpfs
Where=/var/lib/betzbird/ramdisk
Type=tmpfs
Options=size=64M,mode=0750,uid=betzbird,gid=betzbird

[Install]
WantedBy=multi-user.target
````

- `debian/control`:
`````
Source: betzbird
Section: utils
Priority: optional
Maintainer: herbertbetz <herber7be7z@gmail.com>
Rules-Requires-Root: no
Build-Depends: debhelper-compat (= 13), dh-python, python3-all
Standards-Version: 4.7.2
Homepage: https://herbbetz.github.io/betzBirdiary/

# ← THIS BLANK LINE IS MANDATORY

Package: betzbird
Architecture: all
Depends:
 python3,
 python3-picamera2,
 libcamera-apps,
 libcamera-tools,
 bc,
 curl,
 jq,
 screen,
 ffmpeg,
 mosquitto-clients,
 python3-ephem,
 python3-flask,
 python3-markdown,
 python3-matplotlib,
 bash,
 ${python3:Depends},
 ${misc:Depends}
Description: betzBirdiary debian package - Raspicam for recording feeding birds
`````
- `debian/rules` ausführbar mit `chmod +x rules`:
````
#!/usr/bin/make -f

%:
	dh $@ --with python3
````

- `debian/install`:
````
stationDeb/*    usr/lib/betzbird/
stationDeb/betzbird usr/bin/
debian/var-lib-betzbird-ramdisk.mount  lib/systemd/system/
debian/betzbird.service   lib/systemd/system/
````
-  `debian/source/format`: `3.0 (native)`

- `debian/copyright` shortest version:

````
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Files: *
Copyright: 2026 Herbert Betz herber7be7z@gmail.com
License: MIT
````

- *Achtung*: das Verzeichnis `debian/betzbird` ist ein temporärer automatischer Artefakt, der die spätere Installation nach `usr/lib`, `usr/bin` und `usr/share` widerspiegelt (staging). `debian/betzbird` ist nicht zum Editieren oder Git-Upload gedacht, genauso wenig wie `debian/files`, `debian/*.substvars` oder `debian/.debhelper`. 

- Deshalb erstelle `../betzbirdiary/.gitignore`:
```` 
*.deb
*.changes
*.buildinfo
*.dsc
*.gz
````
und `betzBirdiary/debian/.gitignore`:
````
/betzbird/
/files
/*.substvars
/.debhelper/
/debhelper-build-stamp
````

- aus Project root `betzBirdiary`: `dpkg-buildpackage -us -uc` (in `betzBirdiary/buildDebian.sh`) erzeugt das `.deb` ein Verzeichnis höher.

- `sudo apt remove betzbird` entfernt nicht die *dependencies* . Dazu dienen `apt autoremove` oder `apt purge betzbird` oder `apt autoremove --purge`.
