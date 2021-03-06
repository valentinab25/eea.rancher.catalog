version: '2'
services:
  sonarqube:
    labels:
      io.rancher.container.hostname_override: container_name
    image: sonarqube:7.5-community
    environment:
      SONARQUBE_WEB_JVM_OPTS: ${JVM_OPTS}
      sonar.jdbc.username: ${POSTGRES_USER}
      sonar.jdbc.password: ${POSTGRES_PASSWORD}
      sonar.jdbc.url: jdbc:postgresql://db/${POSTGRES_DB}
      TZ: ${TZ}
    volumes:
      - sonarqubedata:/opt/sonarqube/data
      - sonarqubeextensions:/opt/sonarqube/extensions
    depends_on:
      - db
      - postfix
    mem_limit: 3g
    mem_reservation: 2560m
    
  db:
    labels:
      io.rancher.container.hostname_override: container_name
      {{- if .Values.DB_HOST_LABELS}}
      io.rancher.scheduler.affinity:host_label: ${DB_HOST_LABELS}
      {{- else}}
      io.rancher.scheduler.affinity:host_label_ne: reserved=yes
      {{- end}}
    image: eeacms/postgres:9.6
    volumes:
      - postgresdata:/var/lib/postgresql/data
    environment:
      POSTGRES_DBUSER:  ${POSTGRES_USER}
      POSTGRES_DBPASS:  ${POSTGRES_PASSWORD}
      POSTGRES_DBNAME:  ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_ADMIN_USER}
      POSTGRES_PASSWORD: ${POSTGRES_ADMIN_PASSWORD}
      TZ: ${TZ}
    mem_limit: 512m
    mem_reservation: 256m



  postfix:
    image: eeacms/postfix:2.10-3.3
    labels:
      io.rancher.container.hostname_override: container_name
      io.rancher.scheduler.affinity:host_label_ne: reserved=yes
    environment:
      TZ: "${TZ}"
      MTP_HOST: "${SONARQUBE_SERVER_NAME}"
      MTP_RELAY: "${POSTFIX_RELAY}"
      MTP_PORT: "${POSTFIX_PORT}"
      MTP_USER: "${POSTFIX_USER}"
      MTP_PASS: "${POSTFIX_PASS}"
    mem_limit: 124m
    mem_reservation: 62m


volumes:
  postgresdata:
    driver: ${DB_STORAGE_DRIVER}
    {{- if .Values.DB_STORAGE_DRIVER_OPT}}
    driver_opts:
      {{.Values.DB_STORAGE_DRIVER_OPT}}
    {{- end}}
  sonarqubedata:
    driver: ${FRONT_STORAGE_DRIVER}
    {{- if .Values.FRONT_STORAGE_DRIVER_OPT}}
    driver_opts:
      {{.Values.FRONT_STORAGE_DRIVER_OPT}}
    {{- end}}
  sonarqubeextensions:
    driver: ${FRONT_STORAGE_DRIVER}
    {{- if .Values.FRONT_STORAGE_DRIVER_OPT}}
    driver_opts:
      {{.Values.FRONT_STORAGE_DRIVER_OPT}}
    {{- end}}
