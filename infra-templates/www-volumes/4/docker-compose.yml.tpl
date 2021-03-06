version: '2'
services:
  nfs-volumes:
    image: busybox
    tty: true
    stdin_open: true
    labels:
      io.rancher.scheduler.affinity:host_label: ${HOST_LABELS}
      io.rancher.container.start_once: 'true'
    volumes:
    - www-blobstorage:/data/blobstorage
    - www-filestorage:/data/filestorage
    - www-downloads:/data/downloads
    - www-suggestions:/data/suggestions
    - www-static-resources:/data/www-static-resources
    - www-eea-controlpanel:/data/eea.controlpanel
    - www-postgres-dump:/data/postgresql.backup
    - www-postgres-archive:/var/lib/postgresql/archive
    {{- if eq .Values.DB_VOLUME_DRIVER "external"}}
    - www-postgres-data:/var/lib/postgresql/data
    {{- end }}
    volume_driver: ${NFS_VOLUME_DRIVER}
    command: ["ls", "-l", "/var/lib/postgresql/archive"]

{{- if ne .Values.DB_VOLUME_DRIVER "external"}}

  db-volumes:
    image: busybox
    tty: true
    stdin_open: true
    labels:
      io.rancher.scheduler.affinity:host_label: ${VOLUME_HOST_LABELS}
      io.rancher.scheduler.global: 'true'
      io.rancher.container.start_once: 'true'
    volumes:
    - www-postgres-data:/var/lib/postgresql/data
    volume_driver: ${DB_VOLUME_DRIVER}
    command: ["ls", "-l", "/var/lib/postgresql/data"]

{{- end}}
