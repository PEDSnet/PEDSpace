# User Crontab
#-----------------
# GLOBAL VARIABLES
#-----------------
DSPACE=/data/dspace
DSPACE_ANGULAR=/data/dspace-angular-dspace-8.1

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
JAVA_OPTS="-Xmx512M -Xms512M -Dfile.encoding=UTF-8"

#----------------
# CUSTOM TASKS
#----------------

# Daily custom backup script at 03:00 every day
0 3 * * * echo "$(date): Running daily custom backup script." && bash $DSPACE_ANGULAR/config/scripts/dspace_backup.sh >> /data/backups/logs/cron_backup.log 2>&1

# Weekly server reboot every Monday at 05:00 (clean window; triggers @reboot tasks in dspace crontab)
0 5 * * 1 /sbin/shutdown -r now >> /data/backups/logs/cron_reboot.log 2>&1
