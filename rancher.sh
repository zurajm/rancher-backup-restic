#!/bin/bash
export LC_ALL=C

source /.restic-settings

BACKUP_DIR=/backup

if [ "$1" == "restore" ]; then
  SNAPSHOT="${RESTORE_SNAPSHOT:-latest}"

  /usr/bin/restic restore $SNAPSHOT --target $BACKUP_DIR

  docker stop $RANCHER_CONTAINER_NAME
  docker run --rm --volumes-from $RANCHER_CONTAINER_NAME --env BACKUP_TO_RESTORE=`ls $BACKUP_DIR/ -tr | tail -n1` -v "$BACKUP_DIR/:/backup:z" alpine sh -c "rm /var/lib/rancher/* -rf  && tar zxvf /backup/$BACKUP_TO_RESTORE"
  docker start $RANCHER_CONTAINER_NAME
else
  NOW=$(date +"%Y%m%d-%H%M%S")
  ARCHIVE="/backup/rancher-data-backup-$RANCHER_VERSION-$NOW.tar.gz"

  # Create local backup
  docker stop $RANCHER_CONTAINER_NAME
  docker create --volumes-from $RANCHER_CONTAINER_NAME --name "rancher-data-$NOW" rancher/rancher:$RANCHER_VERSION
  docker run --volumes-from "rancher-data-$NOW" -v "${BACKUP_DIR}:/backup:z" --name "rancher-backup-$NOW" alpine tar zcf $ARCHIVE /var/lib/rancher
  docker rm "rancher-data-$NOW"
  docker rm "rancher-backup-$NOW"
  docker start $RANCHER_CONTAINER_NAME

  # Delete old backups
  find "$BACKUP_DIR/" -type f -mtime +$DELETE_OLDER_THAN_X_DAYS -exec rm {} \;

  # Off site backup with restic
  /usr/bin/restic backup $BACKUP_DIR
  /usr/bin/restic forget --prune --keep-last $KEEP_LAST --keep-daily $KEEP_DAILY --keep-weekly $KEEP_WEEKLY --keep-monthly $KEEP_MONTHLY --keep-within $KEEP_WITHIN
fi