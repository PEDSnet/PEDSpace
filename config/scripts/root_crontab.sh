# Root Crontab
# Operations requiring root/polkit privileges go here (sudo crontab -e)
#-----------------
# GLOBAL VARIABLES
#-----------------
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

#----------------
# CUSTOM TASKS
#----------------

# Weekly service restart every Monday at 05:00 (clean window)
0 5 * * 1 echo "$(date): Restarting dspace services." >> /data/backups/logs/cron_reboot.log 2>&1 && systemctl restart dspace.service >> /data/backups/logs/cron_reboot.log 2>&1 && systemctl reload pm2-dspace.service >> /data/backups/logs/cron_reboot.log 2>&1
