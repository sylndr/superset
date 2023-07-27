#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

######################################################################
# Node stage to deal with static asset construction
######################################################################
ARG PY_VER=3.9-slim-bookworm

# if BUILDPLATFORM is null, set it to 'amd64' (or leave as is otherwise).
ARG BUILDPLATFORM=${BUILDPLATFORM:-amd64}
FROM --platform=${BUILDPLATFORM} node:16-slim AS superset-node

ARG NPM_BUILD_CMD="build"

RUN apt-get update -q \
    && apt-get install -yq --no-install-recommends \
    python3 \
    make \
    gcc \
    g++

ENV BUILD_CMD=${NPM_BUILD_CMD} \
    PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true

RUN apt-get update || : && apt-get install -y \
    python3 \
    build-essential
# NPM ci first, as to NOT invalidate previous steps except for when package.json changes
WORKDIR /app/superset-frontend

COPY ./docker/frontend-mem-nag.sh /

RUN /frontend-mem-nag.sh

COPY superset-frontend/package*.json ./

RUN npm ci

COPY ./superset-frontend ./

# This seems to be the most expensive step
RUN npm run ${BUILD_CMD}

######################################################################
# Final lean image...
######################################################################
FROM apache/superset:3.0.0

USER root

COPY --chown=superset:superset --from=superset-node /app/superset/static/assets superset/static/assets

## Lastly, let's install superset itself
COPY superset /app/superset
COPY setup.py MANIFEST.in README.md /app/
RUN cd /app \
    && chown -R superset:superset * \
    && pip install -e . \
    && flask fab babel-compile --target superset/translations

# COPY ./docker/run-server.sh /usr/bin/

# RUN chmod a+x /usr/bin/run-server.sh

RUN apt-get update && \
    apt-get install --no-install-recommends -y unzip wget

RUN export CHROMEDRIVER_VERSION=$(curl --silent https://chromedriver.storage.googleapis.com/LATEST_RELEASE_114) && \
    wget -qO google-chrome-stable_current_amd64.deb https://dl.google.com/linux/chrome/deb/pool/main/g/google-chrome-stable/google-chrome-stable_${CHROMEDRIVER_VERSION}-1_amd64.deb && \
    apt-get install -y --no-install-recommends ./google-chrome-stable_current_amd64.deb && \
    rm -f google-chrome-stable_current_amd64.deb && \
    wget -qO chromedriver_linux64.zip https://chromedriver.storage.googleapis.com/${CHROMEDRIVER_VERSION}/chromedriver_linux64.zip && \
    unzip chromedriver_linux64.zip -d /usr/bin && \
    chmod 755 /usr/bin/chromedriver && \
    rm -f chromedriver_linux64.zip

RUN pip install "Authlib==1.2.0" "selenium==4.9.0" "sqlalchemy-bigquery==1.6.1"

USER superset

EXPOSE 8088

CMD ["/usr/bin/run-server.sh"]
