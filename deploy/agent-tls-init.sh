#!/bin/sh
set -eu

tls=/run/agent-tls
trust=/run/agent-trust
umask 077

if [ ! -s "$tls/agent.crt" ] || [ ! -s "$tls/agent.key" ]; then
    openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
        -subj '/CN=agent-service' \
        -addext 'subjectAltName=DNS:agent-service' \
        -addext 'basicConstraints=critical,CA:FALSE' \
        -addext 'extendedKeyUsage=serverAuth' \
        -keyout "$tls/agent.key.new" -out "$tls/agent.crt.new"
    # Match the non-root Agent user defined in agent-service/Dockerfile.
    chown 10001:10001 "$tls/agent.key.new"
    chmod 0644 "$tls/agent.crt.new"
    mv "$tls/agent.key.new" "$tls/agent.key"
    mv "$tls/agent.crt.new" "$tls/agent.crt"
fi

openssl x509 -in "$tls/agent.crt" -checkend 0 -noout
cp "$tls/agent.crt" "$trust/agent.crt"
cp "$JAVA_HOME/lib/security/cacerts" "$trust/cacerts.new"
keytool -importcert -noprompt -alias dawnwatch-compose-agent \
    -file "$trust/agent.crt" -keystore "$trust/cacerts.new" -storepass changeit
chmod 0644 "$trust/agent.crt" "$trust/cacerts.new"
mv "$trust/cacerts.new" "$trust/cacerts"
