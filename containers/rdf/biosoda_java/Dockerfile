FROM maven:3.9-eclipse-temurin-17 AS builder

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       git-core \
       openssh-client \
    && rm -rf /var/lib/apt/lists/*

    RUN mkdir -m 700 /root/.ssh/ \
    && touch /root/.ssh/known_hosts \
    && ssh-keyscan -p 2222 lab.dessimoz.org >> /root/.ssh/known_hosts \
    && chmod 600 /root/.ssh/known_hosts

WORKDIR /usr/src

RUN --mount=type=ssh \
    --mount=type=secret,id=labgit \
    export LABGIT="$(cat /run/secrets/labgit )" \
    && git clone ${LABGIT}/biosoda_java

RUN cd /usr/src/biosoda_java/OrthoXMLToRDF \
    && mvn package


FROM eclipse-temurin:17-jre AS runtime
COPY --from=builder /usr/src/biosoda_java/OrthoXMLToRDF/target/OrthoXMLToRDF-0.0.1-SNAPSHOT-jar-with-dependencies.jar /usr/biosoda/OrthoXMLToRDF.jar
COPY --from=builder /usr/src/biosoda_java/OrthoXMLToRDF/*owl /usr/biosoda/

CMD ["java", "-cp", "/usr/biosoda/OrthoXMLToRDF.jar", "org.omabrowser.rdf.converter.app.ConverterApp"]
