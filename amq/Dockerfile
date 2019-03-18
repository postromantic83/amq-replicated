FROM redhat-openjdk-18/openjdk18-openshift

USER 0

#RUN \
#    yum install -y \
#	--disablerepo \* \
#        --enablerepo amq-clients-2-for-rhel-7-server-rpms \
#	--enablerepo amq-interconnect-1-for-rhel-7-server-rpms \
#	--enablerepo rhel-7-server-rpms \
#	qpid-dispatch-router \
#	qpid-dispatch-tools \
#	bind-utils \
#	gettext \
#	hostname \
#	iproute \
#	libaio \
#	procps \
#    && \
#    yum clean all

RUN \
	curl -o /etc/yum.repos.d/redhat-local.repo http://www.demo.rht.ru/repos/redhat-local.repo  && \
    yum install -y \
		--disablerepo \* \
		--enablerepo rhel-7-server-rpms \
		bind-utils \
		gettext \
		hostname \
		iproute \
		libaio \
		procps \
    && \
    yum clean all

ARG PROMETHEUS_JMX_REPO_URL
ARG PROMETHEUS_JMX_AGENT_VERSION
ARG REDHAT_COMPONENT_NAME
ARG REDHAT_REPO_URL

ENV \
    AMQ_HOME=/opt/amq-broker \
    JAVA_OPTS_APPEND=-javaagent:/opt/prometheus/lib/jmx_prometheus_javaagent.jar=9779:/opt/prometheus/etc/prometheus-jmx-exporter-config.yaml \
    PROMETHEUS_HOME=/opt/prometheus

RUN \
    set -xe ; \
    curl -vo /tmp/$REDHAT_COMPONENT_NAME $REDHAT_REPO_URL/$REDHAT_COMPONENT_NAME && \
    unzip -d /opt /tmp/$REDHAT_COMPONENT_NAME && \
    rm -f /tmp/$REDHAT_COMPONENT_NAME && \
    mkdir -p /var/run/amq /etc/qpid-dispatch && \
    chgrp 0 /var/run/amq /etc/qpid-dispatch && \
    chmod g+w /var/run/amq /etc/qpid-dispatch && \
    ln -sf /opt/amq-broker-* /opt/amq-broker && \
    \
    mkdir -p ${PROMETHEUS_HOME}/{bin,etc,lib} && \
    export pev=${PROMETHEUS_JMX_AGENT_VERSION:-0.3.1} && \
    export per=${PROMETHEUS_JMX_REPO_URL:-http://central.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent} && \
    curl \
	${per}/${pev}/jmx_prometheus_javaagent-${pev}.jar \
        -o ${PROMETHEUS_HOME}/lib/jmx_prometheus_javaagent.jar && \
    chgrp 0 ${PROMETHEUS_HOME}/etc && \
    chmod g+w ${PROMETHEUS_HOME}/etc

USER jboss

CMD /bin/bash -c "/bin/bash $AMQ_HOME/bin/run-amq.sh"

EXPOSE 8161 9779

COPY resources/run-amq.sh $AMQ_HOME/bin/
COPY resources/prometheus-jmx-exporter-config.yaml ${PROMETHEUS_HOME}/etc

