version: '2'
services:
    es-master:
        labels:
            io.rancher.scheduler.affinity:container_label_soft_ne: io.rancher.stack_service.name=$${stack_name}/$${service_name}
            io.rancher.container.hostname_override: container_name
            io.rancher.scheduler.affinity:host_label: ${host_labels}
        image: eeacms/elastic:6.2.4
        environment:
            - "cluster.name=${cluster_name}"
            - "node.name=$${HOSTNAME}"
            - "bootstrap.memory_lock=true"
            - "ES_JAVA_OPTS=-Xms${master_heap_size} -Xmx${master_heap_size}"
            - "discovery.zen.ping.unicast.hosts=es-master"
            - "discovery.zen.minimum_master_nodes=${minimum_master_nodes}"
            - "node.master=true"
            - "node.data=false"
            - "http.enabled=false"
            - "ENABLE_READONLY_REST=${ENABLE_READONLY_REST}"
            - "TZ=${TZ}"
        ulimits:
            memlock:
                soft: -1
                hard: -1
            nofile:
                soft: 65536
                hard: 65536
        mem_limit: ${master_mem_limit}
        mem_swappiness: 0
        cap_add:
            - IPC_LOCK
        volumes:
            - es-data:/usr/share/elasticsearch/data

    es-worker:
        labels:
            io.rancher.scheduler.affinity:container_label_soft_ne: io.rancher.stack_service.name=$${stack_name}/$${service_name}
            io.rancher.scheduler.affinity:host_label: ${host_labels}
            io.rancher.container.hostname_override: container_name
        image: eeacms/elastic:6.2.4
        environment:
            - "cluster.name=${cluster_name}"
            - "node.name=$${HOSTNAME}"
            - "bootstrap.memory_lock=true"
            - "discovery.zen.ping.unicast.hosts=es-master"
            - "ES_JAVA_OPTS=-Xms${data_heap_size} -Xmx${data_heap_size}"
            - "node.master=false"
            - "node.data=true"
            - "http.enabled=false"
            - "ENABLE_READONLY_REST=${ENABLE_READONLY_REST}"
            - "TZ=${TZ}"
        ulimits:
            memlock:
                soft: -1
                hard: -1
            nofile:
                soft: 65536
                hard: 65536
        mem_limit: ${data_mem_limit}
        mem_swappiness: 0
        cap_add:
            - IPC_LOCK
        volumes:
            - es-data:/usr/share/elasticsearch/data
        depends_on:
            - es-master

    es-client:
        labels:
            io.rancher.scheduler.affinity:container_label_soft_ne: io.rancher.stack_service.name=$${stack_name}/$${service_name}
            io.rancher.scheduler.affinity:host_label: ${host_labels}
            io.rancher.container.hostname_override: container_name
        image: eeacms/elastic:6.2.4
        environment:
            - "cluster.name=${cluster_name}"
            - "node.name=$${HOSTNAME}"
            {{- if eq .Values.ENABLE_READONLY_REST "true" }}
            - "RW_USER=${RW_USER}"
            - "RO_USER=${RO_USER}"
            - "KIBANA_USER=${KIBANA_USER}"
            - "RW_PASSWORD=${RW_PASSWORD}"
            - "KIBANA_PASSWORD=${KIBANA_PASSWORD}"
            - "RO_PASSWORD=${RO_PASSWORD}"
            {{- end}}
            - "KIBANA_HOSTNAME=kibana"
            - "bootstrap.memory_lock=true"
            - "discovery.zen.ping.unicast.hosts=es-master"
            - "ES_JAVA_OPTS=-Xms${client_heap_size} -Xmx${client_heap_size}"
            - "node.master=false"
            - "node.data=false"
            - "http.enabled=true"
            - "ENABLE_READONLY_REST=${ENABLE_READONLY_REST}"
            - "TZ=${TZ}"
    {{- if (.Values.ES_CLIENT_PORT)}}
        ports:
            - "${ES_CLIENT_PORT}:9200"
    {{- end}}
        ulimits:
            memlock:
                soft: -1
                hard: -1
            nofile:
                soft: 65536
                hard: 65536
        mem_limit: ${client_mem_limit}
        mem_swappiness: 0
        cap_add:
            - IPC_LOCK
        volumes:
            - es-data:/usr/share/elasticsearch/data
        depends_on:
            - es-master

    {{- if eq .Values.UPDATE_SYSCTL "true" }}
    es-sysctl:
        labels:
            io.rancher.scheduler.global: 'true'
            io.rancher.scheduler.affinity:host_label: ${host_labels}
            io.rancher.container.start_once: false
        network_mode: none
        image: rawmind/alpine-sysctl:0.1
        privileged: true
        environment:
            - "SYSCTL_KEY=vm.max_map_count"
            - "SYSCTL_VALUE=262144"
            - "KEEP_ALIVE=1"
    {{- end}}

    cerebro:
        image: eeacms/cerebro:0.7.3 
        depends_on:
            - es_client
       {{- if (.Values.CEREBRO_PORT)}}
        ports:
            - "${CEREBRO_PORT}:9000"
       {{- end}}
        environment:
            - CER_ES_URL=http://es-client:9200
            {{- if eq .Values.ENABLE_READONLY_REST "true" }}
            - CER_ES_USER=${RW_USER}
            - CER_ES_PASSWORD=${RW_PASSWORD}
            {{- end}}
            - "TZ=${TZ}"
        labels:
          io.rancher.container.hostname_override: container_name
          io.rancher.scheduler.affinity:host_label: ${host_labels}

   
    kibana:
        image: eeacms/elk-kibana-plugins:6.2.4-1.1
        depends_on:
            - es_client
       {{- if (.Values.KIBANA_PORT)}}
        ports:
            - "${KIBANA_PORT}:5601"
       {{- end}}
        labels:
          io.rancher.container.hostname_override: container_name
          io.rancher.scheduler.affinity:host_label: ${host_labels}
        environment:
            - ELASTICSEARCH_URL=http://es-client:9200
            {{- if eq .Values.ENABLE_READONLY_REST "true" }}
            - KIBANA_RW_PASSWORD=${KIBANA_PASSWORD}
            - KIBANA_RW_USERNAME=${KIBANA_USER}
            {{- end}}
            - "TZ=${TZ}"

    cluster-health:
        image: eeacms/esclusterhealth:1.0
        depends_on:
            - es-client
        labels:
          io.rancher.container.hostname_override: container_name
          io.rancher.scheduler.affinity:host_label: ${host_labels}
        mem_limit: 64m
        mem_reservation: 8m
        environment:
            - ES_URL=http://es-client:9200
            - PORT=12345
            - ES_USER=${RO_USER}
            - "ES_PASSWORD=${RO_PASSWORD}"

volumes:
  es-data:
    driver: ${VOLUME_DRIVER}
    {{- if eq .Values.VOLUME_EXTERNAL "yes"}}
    external: true
    {{- end}}
    {{- if .Values.VOLUME_DRIVER_OPTS}}
    driver_opts:
      {{.Values.VOLUME_DRIVER_OPTS}}
    {{- end}} 
    per_container: true

