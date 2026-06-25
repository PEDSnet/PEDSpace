# DSpace service user crontab
## NOTE: You may also need to add additional sysadmin related tasks to your crontab
## (e.g. zipping up old log files, or even removing old logs, etc).
## Install by either calling `sudo crontab [path to this file]` or by copying the contents to `sudo crontab -e`.

#-----------------
# GLOBAL VARIABLES
#-----------------
# Full path of your local DSpace Installation (e.g. /home/dspace or /dspace or similar)
# MAKE SURE TO CHANGE THESE VALUES!!!
DSPACE=/data/dspace
DSPACE_ANGULAR=/data/dspace-angular-dspace-8.1
SOLR_STATS=/data/PEDSpace_Solr_Analytics

# Add all major 'bin' directories to path
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Set JAVA_OPTS with defaults for DSpace Cron Jobs.
JAVA_OPTS="-Xmx512M -Xms512M -Dfile.encoding=UTF-8"

# On reboot: wait 5 minutes for systemd services to initialize, then rebuild frontend
@reboot sleep 300 && bash $DSPACE_ANGULAR/config/scripts/rebuild_frontend.sh >> /data/backups/logs/rebuild_frontend.log 2>&1

#--------------
# HOURLY TASKS
#--------------

# Send information about new and changed DOIs to the DOI registration agency (if needed)
0 4,12,20 * * * echo "$(date): Running DSpace DOI organiser updates." && $DSPACE/bin/dspace doi-organiser -u -q && $DSPACE/bin/dspace doi-organiser -s -q && $DSPACE/bin/dspace doi-organiser -r -q && $DSPACE/bin/dspace doi-organiser -d -q

#----------------
# DAILY TASKS
#----------------

# Update the OAI-PMH index at midnight every day
0 0 * * * echo "$(date): Running DSpace OAI import." && $DSPACE/bin/dspace oai import > /dev/null

# Clean and update the Discovery indexes at midnight every day
0 0 * * * echo "$(date): Running DSpace Discovery index update." && $DSPACE/bin/dspace index-discovery > /dev/null

# Run the index-authority script once a day at 00:45
45 0 * * * echo "$(date): Running DSpace Authority index." && $DSPACE/bin/dspace index-authority > /dev/null

# Cleanup Web Spiders from DSpace Statistics Solr Index at 01:00 every day
0 1 * * * echo "$(date): Running DSpace Statistics cleanup." && $DSPACE/bin/dspace stats-util -f

# CUSTOM: Every hour: Run deploy_shiny script and log output. See here: https://github.research.chop.edu/SEYEDIANA1/PEDSpace_Solr_Analytics/blob/main/deploy_shiny.bash
0 * * * * echo "$(date): Running SOLR Analytics script..." && /bin/bash $SOLR_STATS/deploy_shiny.bash  >> $SOLR_STATS/logs/deploy_shiny.log 2>&1

# Send out "daily" update subscription e-mails at 02:00 every day
0 2 * * * echo "$(date): Sending daily DSpace subscription emails." && $DSPACE/bin/dspace subscription-send -f D

# CUSTOM: Run backup script as dspace at 2am every day
0 2 * * * echo "$(date): Running daily custom backup script." && bash $DSPACE_ANGULAR/config/scripts/dspace_backup.sh >> /data/backups/logs/cron_backup.log 2>&1

# Run the media filter at 03:00 every day
0 3 * * * echo "$(date): Running DSpace media filter." && $DSPACE/bin/dspace filter-media

#----------------
# WEEKLY TASKS
#----------------

# Send out "weekly" update subscription e-mails at 02:00 every Sunday
0 2 * * 0 echo "$(date): Sending weekly DSpace subscription emails." && $DSPACE/bin/dspace subscription-send -f W

# Run the checksum checker at 04:00 every Sunday
0 4 * * 0 echo "$(date): Running DSpace checksum checker with -l -p options." && $DSPACE/bin/dspace checker -l -p

# Mail the results of the checksum checker at 05:00 every Sunday
0 5 * * 0 echo "$(date): Sending DSpace checksum checker email report." && $DSPACE/bin/dspace checker-emailer

#----------------
# MONTHLY TASKS
#----------------

# Send out "monthly" update subscription e-mails at 02:00 on the 1st of every month
0 2 1 * * echo "$(date): Sending monthly DSpace subscription emails." && $DSPACE/bin/dspace subscription-send -f M

# Permanently delete any bitstreams flagged as "deleted" at 01:00 on the 1st of every month
0 1 1 * * echo "$(date): Running DSpace cleanup to remove deleted bitstreams." && $DSPACE/bin/dspace cleanup > /dev/null
