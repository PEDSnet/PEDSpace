#-----------------
# GLOBAL VARIABLES
#-----------------
# Full path of your local DSpace Installation (e.g. /home/dspace or /dspace or similar)
# MAKE SURE TO CHANGE THESE VALUES!!!
DSPACE=/data/dspace
DSPACE_ANGULAR=/data/dspace-angular-dspace-8.1
SOLR_STATS=/data/PEDSpace_Solr_Analytics

# Shell to use
SHELL=/bin/bash

# Add all major 'bin' directories to path
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Set JAVA_OPTS with defaults for DSpace Cron Jobs.
JAVA_OPTS="-Xmx512M -Xms512M -Dfile.encoding=UTF-8"

#----------------
# CUSTOM TASKS
#----------------

# Daily custom backup script at 02:00 every day
0 3 * * * echo "$(date): Running daily custom backup script." && bash $DSPACE_ANGULAR/config/scripts/dspace_backup.sh >> /data/backups/logs/cron_backup.log 2>&1
