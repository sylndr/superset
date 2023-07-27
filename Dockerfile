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
ARG PY_VER=3.8.16-slim
FROM node:16-slim AS superset-node

ARG NPM_BUILD_CMD="build"
ENV BUILD_CMD=${NPM_BUILD_CMD}
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true

RUN apt-get update || : && apt-get install -y \
    python3 \
    build-essential
# NPM ci first, as to NOT invalidate previous steps except for when package.json changes
RUN mkdir -p /app/superset-frontend

COPY ./docker/frontend-mem-nag.sh /
RUN /frontend-mem-nag.sh

WORKDIR /app/superset-frontend/

COPY superset-frontend/package*.json ./
RUN npm ci

COPY ./superset-frontend .

# This seems to be the most expensive step
RUN npm run ${BUILD_CMD}

######################################################################
# Final lean image...
######################################################################
FROM apache/superset:2.1.0

USER root

COPY --from=superset-node /app/superset/static/assets /app/superset/static/assets

# COPY superset /app/superset
# COPY setup.py MANIFEST.in README.md /app/
# RUN cd /app \
#     && chown -R superset:superset * \
#     && pip install -e . \
#     && flask fab babel-compile --target superset/translations

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
