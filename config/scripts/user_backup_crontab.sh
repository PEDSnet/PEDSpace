#-----------------
# GLOBAL VARIABLES
#-----------------
# Full path of your local DSpace Installation (e.g. /home/dspace or /dspace or similar)
# MAKE SURE TO CHANGE THESE VALUES!!!
DSPACE=/data/dspace
DSPACE_ANGULAR=/data/dspace-angular-dspace-8.0
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

# 1 AM daily: Run deploy_shiny script and log output. See here: https://github.research.chop.edu/SEYEDIANA1/PEDSpace_Solr_Analytics/blob/main/deploy_shiny.bash 
0 1 * * * ( echo "$(date): Running SOLR Analytics script..." && /bin/bash "$SOLR_STATS/deploy_shiny.sh"  >> /data/PEDSpace_Solr_Analytics/logs/deploy_shiny.log 2>&1