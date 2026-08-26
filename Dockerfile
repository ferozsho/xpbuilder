ARG SUPERSET_BASE_IMAGE=apache/superset:6.1.0@sha256:fb3464528ec7076f91195f0ff7835755aa023e281f1bb78a84782ce7a36b3705
FROM ${SUPERSET_BASE_IMAGE}

ARG XPBUILDER_VERSION=0.1.0

LABEL org.opencontainers.image.title="OpenXpertz XPBuilder" \
      org.opencontainers.image.description="Versioned OpenXpertz Advanced BI runtime" \
      org.opencontainers.image.version="${XPBUILDER_VERSION}" \
      org.opencontainers.image.source="https://github.com/ferozsho/xpbuilder"

USER root

COPY requirements.lock /tmp/xpbuilder-requirements.lock
RUN uv pip install \
        --python /app/.venv/bin/python \
        --no-cache \
        --requirement /tmp/xpbuilder-requirements.lock \
    && rm -f /tmp/xpbuilder-requirements.lock

COPY --chown=superset:superset config/superset_config.py /app/xpbuilder/superset_config.py
COPY --chown=superset:superset docker/initialize.sh /opt/xpbuilder/bin/initialize.sh
COPY customizations/templates/tail_js_custom_extra.html /app/superset/templates/tail_js_custom_extra.html
COPY customizations/images/superset-logo-horiz.png /app/superset/static/assets/images/superset-logo-horiz.png
COPY customizations/images/advance-bi-logo.png /app/superset/static/assets/images/advance-bi-logo.png
COPY customizations/images/favicon.png /app/superset/static/assets/images/favicon.png
COPY customizations/images/favicon64.png /app/superset/static/assets/images/favicon64.png

RUN chmod 0555 /opt/xpbuilder/bin/initialize.sh \
    && chmod 0444 /app/xpbuilder/superset_config.py \
        /app/superset/templates/tail_js_custom_extra.html \
        /app/superset/static/assets/images/superset-logo-horiz.png \
        /app/superset/static/assets/images/advance-bi-logo.png \
        /app/superset/static/assets/images/favicon.png \
        /app/superset/static/assets/images/favicon64.png

ENV SUPERSET_CONFIG_PATH=/app/xpbuilder/superset_config.py

USER superset
