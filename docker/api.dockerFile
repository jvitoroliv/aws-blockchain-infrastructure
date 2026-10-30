# Base image pinned to specific version — prevents supply chain drift
FROM corda/enterprise-notary:4.5.2-zulu-openjdk8u242
LABEL mantainer="developer@example-company.com"

# Layer ordering: dependencies first (cacheable), app code last (changes frequently)
COPY --chown=1000:1000 ./shared/clients-1.1.0.jar /opt/cenm/bin/clients.jar
COPY --chown=1000:1000 ./shared/run-api.sh /opt/cenm/bin/run-api.sh

USER 1000
# Non-root working directory — aligns with CIS Docker Benchmark 4.1
WORKDIR /opt/cenm
ENTRYPOINT bin/run-api.sh