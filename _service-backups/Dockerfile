FROM python:3.7.9-alpine3.12
MAINTAINER toni.schoenbuchner@csgis.de
# 1-2. Install system dependencies (we only need the pg_dump binary from postgresql, other dependencies are in postgresql-client)
RUN apk add --no-cache postgresql-client && \
    apk add --no-cache --virtual BUIID_DEPS postgresql && \
    cp /usr/bin/pg_dump /bin/pg_dump && \
    apk add --no-cache curl rsync  vim ssmtp openssh-client && \
    apk add --no-cache findutils && \
    curl -O https://downloads.rclone.org/rclone-current-linux-amd64.zip && \
    unzip rclone-current-linux-amd64.zip && \
    cp rclone-*-linux-amd64/rclone /usr/bin && \
    rm -rf rclone-* && \
    apk del BUIID_DEPS

# ssh setup
# Todo: read backup host from env variable
# Todo: docker 3.1 supports secrets
# RUN touch /root/.ssh/known_hosts &&\
#    ssh-keyscan virginiaplain07.klassarchaeologie.uni-koeln.de >> /root/.ssh/known_hosts

# envsubst dependency
RUN apk add --no-cache gettext tzdata
ENV TZ Europe/Amsterdam

# The entrypoint creates the certificate
ADD assets/* /
RUN chmod +x docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]

# We run cron in foreground
CMD ["/usr/sbin/crond", "-f"]
