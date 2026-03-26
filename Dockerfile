# =============================================================================
# SENTINEL Execution Environment Dockerfile
# Compatible with Ansible Automation Platform 2.6
#
# Base: registry.redhat.io/ansible-automation-platform-26/ee-minimal-rhel9
#       (already contains ansible-core 2.15+ and Python 3.11)
#
# Alternative public base (no Red Hat subscription required):
#   FROM registry.access.redhat.com/ubi9/python-311:latest
#   RUN pip3 install ansible-core>=2.15
#
# Build:
#   podman build -t sentinel-ee:2.6 .
#
# Push to Private Automation Hub:
#   podman tag sentinel-ee:2.6 hub.example.com/sentinel-ee:2.6
#   podman push hub.example.com/sentinel-ee:2.6
# =============================================================================

FROM registry.redhat.io/ansible-automation-platform-26/ee-minimal-rhel9:latest

# ----------------------------------------------------------------------------
# Labels
# ----------------------------------------------------------------------------
LABEL name="sentinel-ee" \
      version="2.6" \
      summary="SENTINEL Service Discovery EE for AAP 2.6" \
      description="Custom EE with oracledb, pywinrm, and required collections" \
      maintainer="sentinel-team"

# ----------------------------------------------------------------------------
# Switch to root for system-level installation
# ----------------------------------------------------------------------------
USER root

# ----------------------------------------------------------------------------
# System packages
# gcc / python3-devel  — compile C extensions (pywinrm, kerberos)
# krb5-devel / krb5-workstation — Kerberos for WinRM transport
# openssl-devel        — required by some Python crypto dependencies
# git                  — ansible-galaxy may need it for SCM sources
# ----------------------------------------------------------------------------
RUN microdnf install -y --nodocs \
        gcc \
        python3-devel \
        krb5-devel \
        krb5-workstation \
        openssl-devel \
        git \
    && microdnf clean all \
    && rm -rf /var/cache/dnf

# ----------------------------------------------------------------------------
# Python packages
# python-oracledb  — Oracle DB driver (thin mode; no Instant Client needed)
# pywinrm          — WinRM transport for Windows targets
# requests-kerberos / requests-ntlm — WinRM Kerberos and NTLM auth
# jmespath         — required by community.general JSON filters
# ----------------------------------------------------------------------------
COPY requirements.txt /tmp/requirements.txt

RUN pip3 install --no-cache-dir --upgrade pip setuptools wheel \
    && pip3 install --no-cache-dir -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt

# ----------------------------------------------------------------------------
# Ansible Collections
# Installed into the standard EE collections path so ansible-core picks them
# up automatically without any extra configuration.
# ----------------------------------------------------------------------------
COPY requirements.yml /tmp/requirements.yml

RUN ansible-galaxy collection install \
        --requirements-file /tmp/requirements.yml \
        --collections-path /usr/share/ansible/collections \
        --force \
    && rm /tmp/requirements.yml

# ----------------------------------------------------------------------------
# Verify critical imports are resolvable at image build time
# ----------------------------------------------------------------------------
RUN python3 -c "import oracledb; print('oracledb', oracledb.__version__)"
RUN python3 -c "import winrm;    print('pywinrm OK')"
RUN python3 -c "import jmespath; print('jmespath OK')"

# ----------------------------------------------------------------------------
# Drop back to the non-root EE user (UID 1000 in AAP EE images)
# ----------------------------------------------------------------------------
USER 1000

# Default entry point expected by AAP EE runtime
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/dumb-init"]
