# cBackup worker é um projeto Java antigo.
#
# Problemas encontrados:
# 1. Maven 3.8+ bloqueia repositórios HTTP legados.
# 2. expect4j depende de:
#      net.sourceforge.tcljava:com.springsource.tcl.lang.jacl:1.4.1
# 3. O POM transitivo do expect4j aponta para repository.springsource.com,
#    que não resolve mais DNS.
# 4. repo.spring.io/libs-milestone hoje retorna 401 Unauthorized.
#
# Correção:
# - Usar Maven 3.6.3 + Java 8.
# - Espelhar os repositórios SpringSource antigos para um repositório público
#   que ainda possui o artefato: maven-eu.nuxeo.org.

FROM maven:3.6.3-jdk-8 AS builder

ARG CBACKUP_WORKER_REPO=https://github.com/cBackup/worker.git
ARG CBACKUP_WORKER_BRANCH=master

WORKDIR /build

RUN git clone --depth=1 --branch "${CBACKUP_WORKER_BRANCH}" "${CBACKUP_WORKER_REPO}" /build/worker

WORKDIR /build/worker

RUN mkdir -p /root/.m2 \
    && cat > /root/.m2/settings.xml <<'EOF'
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
          xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0 https://maven.apache.org/xsd/settings-1.0.0.xsd">

  <mirrors>
    <mirror>
      <id>nuxeo-springsource-release-mirror</id>
      <mirrorOf>com.springsource.repository.bundles.release</mirrorOf>
      <url>https://maven-eu.nuxeo.org/nexus/content/groups/public</url>
    </mirror>

    <mirror>
      <id>nuxeo-springsource-external-mirror</id>
      <mirrorOf>com.springsource.repository.bundles.external</mirrorOf>
      <url>https://maven-eu.nuxeo.org/nexus/content/groups/public</url>
    </mirror>
  </mirrors>

  <profiles>
    <profile>
      <id>legacy-public-repos</id>
      <repositories>
        <repository>
          <id>nuxeo-public</id>
          <url>https://maven-eu.nuxeo.org/nexus/content/groups/public</url>
          <releases>
            <enabled>true</enabled>
          </releases>
          <snapshots>
            <enabled>true</enabled>
          </snapshots>
        </repository>

        <repository>
          <id>central</id>
          <url>https://repo.maven.apache.org/maven2</url>
          <releases>
            <enabled>true</enabled>
          </releases>
          <snapshots>
            <enabled>false</enabled>
          </snapshots>
        </repository>
      </repositories>

      <pluginRepositories>
        <pluginRepository>
          <id>central</id>
          <url>https://repo.maven.apache.org/maven2</url>
          <releases>
            <enabled>true</enabled>
          </releases>
          <snapshots>
            <enabled>false</enabled>
          </snapshots>
        </pluginRepository>
      </pluginRepositories>
    </profile>
  </profiles>

  <activeProfiles>
    <activeProfile>legacy-public-repos</activeProfile>
  </activeProfiles>
</settings>
EOF

RUN mvn -v \
    && echo "===== /root/.m2/settings.xml =====" \
    && cat /root/.m2/settings.xml

# Baixa explicitamente o artefato problemático antes de compilar o projeto.
RUN mvn -B -U dependency:get \
    -Dartifact=net.sourceforge.tcljava:com.springsource.tcl.lang.jacl:1.4.1 \
    -DremoteRepositories=nuxeo-public::default::https://maven-eu.nuxeo.org/nexus/content/groups/public \
    -Dtransitive=false

# Preenche cache Maven. Se falhar parcialmente, o clean package ainda tenta resolver.
RUN mvn -B -U -DskipTests dependency:go-offline || true

RUN mvn -B -DskipTests clean package

FROM eclipse-temurin:8-jre-jammy

ENV DEBIAN_FRONTEND=noninteractive
ENV CBACKUP_HOME=/opt/cbackup

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    bash \
    openssh-client \
    snmp \
    git \
    netcat-openbsd \
    mariadb-client \
    procps \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -d ${CBACKUP_HOME} -s /bin/bash cbackup \
    && mkdir -p ${CBACKUP_HOME}/data \
    && mkdir -p ${CBACKUP_HOME}/git \
    && mkdir -p /var/log/cbackup \
    && mkdir -p /opt/cbackup-worker

COPY --from=builder /build/worker/target/*.jar /opt/cbackup-worker/cbackup.jar

COPY docker/daemon/entrypoint.sh /usr/local/bin/cbackup-daemon-entrypoint
COPY docker/daemon/daemon-runner.sh /usr/local/bin/cbackup-daemon-runner

RUN chmod +x /usr/local/bin/cbackup-daemon-entrypoint \
    && chmod +x /usr/local/bin/cbackup-daemon-runner \
    && chown -R cbackup:cbackup ${CBACKUP_HOME} \
    && chown -R cbackup:cbackup /var/log/cbackup \
    && chown -R cbackup:cbackup /opt/cbackup-worker

WORKDIR ${CBACKUP_HOME}

ENTRYPOINT ["cbackup-daemon-entrypoint"]
CMD ["cbackup-daemon-runner"]
