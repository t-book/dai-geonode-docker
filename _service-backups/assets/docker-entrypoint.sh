#!/bin/sh

#envsubst '\$DATABASE_URL' < crontab.envsubst > crontab
#envsubst '\$DATABASE' < crontab.envsubst > crontab
/usr/bin/crontab crontab
rm crontab
chmod +x /backup.sh

envsubst < smtp_template.conf > /etc/ssmtp/ssmtp.conf

touch /root/.ssh/known_hosts
ssh-keyscan ${BACKUP_HOST} >> /root/.ssh/known_hosts

exec "$@"
