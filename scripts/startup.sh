#! /bin/sh

# Version 1.3.0
# This is a startup script for UniFi Controller on Debian based Google Compute Engine instances.
# For instructions and how-to:  https://metis.fi/en/2018/02/unifi-on-gcp/
# For comments and code walkthrough:  https://metis.fi/en/2018/02/gcp-unifi-code/
#
# You may use this as you see fit as long as I am credited for my work.
# (c) 2018 Petri Riihikallio Metis Oy
#
# Removed certbot/letencrypt stuffs - JAF

###########################################################
#
# Set up logging for unattended scripts and UniFi's MongoDB log
# Variables $LOG and $MONGOLOG are used later on in the script.
#
LOG="/var/log/unifi/gcp-unifi.log"
if [ ! -f /etc/logrotate.d/gcp-unifi.conf ]; then
	cat > /etc/logrotate.d/gcp-unifi.conf <<_EOF
$LOG {
	monthly
	rotate 4
	compress
}
_EOF
	echo "Script logrotate set up"
fi

MONGOLOG="/usr/lib/unifi/logs/mongod.log"
if [ ! -f /etc/logrotate.d/unifi-mongod.conf ]; then
	cat > /etc/logrotate.d/unifi-mongod.conf <<_EOF
$MONGOLOG {
	weekly
	rotate 10
	copytruncate
	delaycompress
	compress
	notifempty
	missingok
}
_EOF
	echo "MongoDB logrotate set up"
fi

###########################################################
#
# Create a swap file for small memory instances and increase /run
#
if [ ! -f /swapfile ]; then
	memory=$(free -m | grep "^Mem:" | tr -s " " | cut -d " " -f 2)
	echo "${memory} megabytes of memory detected"
	if [ -z ${memory} ] || [ "0${memory}" -lt "2048" ]; then
		fallocate -l 2G /swapfile
		chmod 600 /swapfile
		mkswap /swapfile >/dev/null
		swapon /swapfile
		echo '/swapfile none swap sw 0 0' >> /etc/fstab
		echo 'tmpfs /run tmpfs rw,nodev,nosuid,size=400M 0 0' >> /etc/fstab
		mount -o remount,rw,nodev,nosuid,size=400M tmpfs /run
		echo "Swap file created"
	fi
fi

###########################################################
#
# Add Unifi to APT sources
#
if [ ! -f /etc/apt/trusted.gpg.d/unifi-repo.gpg ]; then
    cat > /etc/apt/sources.list.d/unifi.list <<_EOF
deb http://www.ubnt.com/downloads/unifi/debian stable ubiquiti
_EOF
	curl -Lfs -o /etc/apt/trusted.gpg.d/unifi-repo.gpg https://dl.ubnt.com/unifi/unifi-repo.gpg
	echo "Unifi added to APT sources";
fi

###########################################################
#
# Add backports if it doesn't exist
#
release=$(lsb_release -a 2>/dev/null | grep "^Codename:" | cut -f 2)
if [ ${release} ] && [ ! -f /etc/apt/sources.list.d/backports.list ]; then
	cat > /etc/apt/sources.list.d/backports.list <<_EOF
deb http://deb.debian.org/debian/ ${release}-backports main
deb-src http://deb.debian.org/debian/ ${release}-backports main
_EOF
	echo "Backports (${release}) added to APT sources"
fi

###########################################################
#
# Install stuff
#
if [ ! -f /usr/share/misc/apt-upgraded-1 ]; then
	export APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=DontWarn
	curl -Lfs https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
	DEBIAN_FRONTEND=noninteractive apt-get -qq update -y >/dev/null
	DEBIAN_FRONTEND=noninteractive apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade -y >/dev/null
	rm /usr/share/misc/apt-upgraded # Old flag file
	touch /usr/share/misc/apt-upgraded-1
	echo "System upgraded"
fi

# Simple installs first
haveged=$(dpkg-query -W --showformat='${Status}\n' haveged 2>/dev/null)
if [ "x${haveged}" != "xinstall ok installed" ]; then
	if DEBIAN_FRONTEND=noninteractive apt-get -qq install -y haveged >/dev/null; then
		echo "Haveged installed"
	fi
fi
unifi=$(dpkg-query -W --showformat='${Status}\n' unifi 2>/dev/null)
if [ "x${unifi}" != "xinstall ok installed" ]; then
	if DEBIAN_FRONTEND=noninteractive apt-get -qq install -y openjdk-8-jre-headless >/dev/null; then
		echo "Java 8 installed"
	fi
	if DEBIAN_FRONTEND=noninteractive apt-get -qq install -y unifi >/dev/null; then
		echo "Unifi installed"
	fi
	systemctl stop mongodb
	systemctl disable mongodb
fi

# Lighttpd needs a config file and a reload
httpd=$(dpkg-query -W --showformat='${Status}\n' lighttpd 2>/dev/null)
if [ "x${httpd}" != "xinstall ok installed" ]; then
	if DEBIAN_FRONTEND=noninteractive apt-get -qq install -y lighttpd >/dev/null; then
		cat > /etc/lighttpd/conf-enabled/10-unifi-redirect.conf <<_EOF
\$HTTP["scheme"] == "http" {
    \$HTTP["host"] =~ ".*" {
        url.redirect = (".*" => "https://%0:8443")
    }
}
_EOF
		systemctl reload-or-restart lighttpd
		echo "Lighttpd installed"
	fi
fi

# Fail2Ban needs three files and a reload
f2b=$(dpkg-query -W --showformat='${Status}\n' fail2ban 2>/dev/null)
if [ "x${f2b}" != "xinstall ok installed" ]; then
	if DEBIAN_FRONTEND=noninteractive apt-get -qq install -y fail2ban >/dev/null; then
			echo "Fail2Ban installed"
	fi
	if [ ! -f /etc/fail2ban/filter.d/unifi-controller.conf ]; then
		cat > /etc/fail2ban/filter.d/unifi-controller.conf <<_EOF
[Definition]
failregex = ^.* Failed .* login for .* from <HOST>\s*$
_EOF
		cat > /etc/fail2ban/jail.d/unifi-controller.conf <<_EOF
[unifi-controller]
filter   = unifi-controller
port     = 8443
logpath  = /var/log/unifi/server.log
_EOF
	fi
	# The .local file will be installed in any case
	cat > /etc/fail2ban/jail.d/unifi-controller.local <<_EOF
[unifi-controller]
enabled  = true
maxretry = 3
bantime  = 3600
findtime = 3600
_EOF
	systemctl reload-or-restart fail2ban
fi

###########################################################
#
# Set the time zone
#
tz=$(curl -fs -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/timezone")
if [ ${tz} ] && [ -f /usr/share/zoneinfo/${tz} ]; then
	DEBIAN_FRONTEND=noninteractive apt-get -qq install -y dbus >/dev/null
	if ! systemctl start dbus; then
		echo "Trying to start dbus"
		sleep 15
		systemctl start dbus
	fi
	if timedatectl set-timezone $tz; then echo "Localtime set to ${tz}"; fi
	systemctl reload-or-restart rsyslog
fi

###########################################################
#
# Set up unattended upgrades after 04:00 with automatic reboots
#
if [ ! -f /etc/apt/apt.conf.d/51unattended-upgrades-unifi ]; then
	cat > /etc/apt/apt.conf.d/51unattended-upgrades-unifi <<_EOF
Acquire::AllowReleaseInfoChanges "true";
Unattended-Upgrade::Origins-Pattern {
	"o=Debian,a=stable";
	"c=ubiquiti";
};
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "true";
_EOF

	cat > /etc/systemd/system/timers.target.wants/apt-daily-upgrade.timer <<_EOF
[Unit]
Description=Daily apt upgrade and clean activities
After=apt-daily.timer
[Timer]
OnCalendar=4:00
RandomizedDelaySec=30m
Persistent=true
[Install]
WantedBy=timers.target
_EOF
	systemctl daemon-reload
	systemctl reload-or-restart unattended-upgrades
	echo "Unattended upgrades set up"
fi

###########################################################
#
# Set up automatic repair for broken MongoDB on boot
#
if [ ! -f /usr/local/sbin/unifidb-repair.sh ]; then
	cat > /usr/local/sbin/unifidb-repair.sh <<_EOF
#! /bin/sh
if ! pgrep mongod; then
	if [ -f /var/lib/unifi/db/mongod.lock ] \
	|| [ -f /var/lib/unifi/db/WiredTiger.lock ] \
	|| [ -f /var/run/unifi/db.needsRepair ] \
	|| [ -f /var/run/unifi/launcher.looping ]; then
		if [ -f /var/lib/unifi/db/mongod.lock ]; then rm -f /var/lib/unifi/db/mongod.lock; fi
		if [ -f /var/lib/unifi/db/WiredTiger.lock ]; then rm -f /var/lib/unifi/db/WiredTiger.lock; fi
		if [ -f /var/run/unifi/db.needsRepair ]; then rm -f /var/run/unifi/db.needsRepair; fi
		if [ -f /var/run/unifi/launcher.looping ]; then rm -f /var/run/unifi/launcher.looping; fi
		echo >> $LOG
		echo "Repairing Unifi DB on \$(date)" >> $LOG
		su -c "/usr/bin/mongod --repair --dbpath /var/lib/unifi/db --smallfiles --logappend --logpath ${MONGOLOG} 2>>$LOG" unifi
	fi
else
	echo "MongoDB is running. Exiting..."
	exit 1
fi
exit 0
_EOF
	chmod a+x /usr/local/sbin/unifidb-repair.sh

	cat > /etc/systemd/system/unifidb-repair.service <<_EOF
[Unit]
Description=Repair UniFi MongoDB database at boot
Before=unifi.service mongodb.service
After=network-online.target
Wants=network-online.target
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/unifidb-repair.sh
[Install]
WantedBy=multi-user.target
_EOF
	systemctl enable unifidb-repair.service
	echo "Unifi DB autorepair set up"
fi

###########################################################
#
# Set up daily backup to a bucket after 01:00
#
#bucket=$(curl -fs -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/bucket")
#if [ ${bucket} ]; then
#	cat > /etc/systemd/system/unifi-backup.service <<_EOF
#[Unit]
#Description=Daily backup to ${bucket} service
#After=network-online.target
#Wants=network-online.target
#[Service]
#Type=oneshot
#ExecStart=/usr/bin/gsutil rsync -r -d /var/lib/unifi/backup gs://$bucket
#_EOF
#
#	cat > /etc/systemd/system/unifi-backup.timer <<_EOF
#[Unit]
#Description=Daily backup to ${bucket} timer
#[Timer]
#OnCalendar=1:00
#RandomizedDelaySec=30m
#[Install]
#WantedBy=timers.target
#_EOF
#	systemctl daemon-reload
#	systemctl start unifi-backup.timer
#	echo "Backups to ${bucket} set up"
#fi

###########################################################
#
# Adjust Java heap (advanced setup)
#
# xms=$(curl -fs -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/xms")
# xmx=$(curl -fs -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/instance/attributes/xmx")
# if [ ${xms} ] || [ ${xmx} ]; then touch /usr/share/misc/java-heap-adjusted; fi
#
# if [ -e /usr/share/misc/java-heap-adjusted ]; then
#	 if [ "0${xms}" -lt 100 ]; then xms=1024; fi
#	 if grep -e "^\s*unifi.xms=[0-9]" /var/lib/unifi/system.properties >/dev/null; then
#	 	sed -i -e "s/^[[:space:]]*unifi.xms=[[:digit:]]\+/unifi.xms=${xms}/" /var/lib/unifi/system.properties
#	 else
#	 	echo "unifi.xms=${xms}" >>/var/lib/unifi/system.properties
#	 fi
#	 message=" xms=${xms}"
#
#	 if [ "0${xmx}" -lt "${xms}" ]; then xmx=${xms}; fi
#	 if grep -e "^\s*unifi.xmx=[0-9]" /var/lib/unifi/system.properties >/dev/null; then
#	 	sed -i -e "s/^[[:space:]]*unifi.xmx=[[:digit:]]\+/unifi.xmx=${xmx}/" /var/lib/unifi/system.properties
#	 else
#	 	echo "unifi.xmx=${xmx}" >>/var/lib/unifi/system.properties
#	 fi
#	 message="${message} xmx=${xmx}"
#
#	 if [ -n "${message}" ]; then
#	 	echo "Java heap set to:${message}"
#	 fi
#	 systemctl restart unifi
# fi
