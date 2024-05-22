# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
import base64
import io
import json
import logging
from collections.abc import Sequence
from io import IOBase
from typing import Any, Dict, List, Union

import backoff
import pandas as pd
import requests

from superset import app
from superset.reports.models import ReportRecipientType
from superset.reports.notifications.base import BaseNotification
from superset.reports.notifications.exceptions import (
    NotificationAuthorizationException,
    NotificationMalformedException,
    NotificationParamException,
    NotificationUnprocessableException,
)
from superset.utils.core import get_email_address_list
from superset.utils.decorators import statsd_gauge

logger = logging.getLogger(__name__)

# Slack only allows Markdown messages up to 4k chars
MAXIMUM_MESSAGE_SIZE = 4000


class TeamsNotification(BaseNotification):  # pylint: disable=too-few-public-methods
    """
    Sends a teams notification for a report recipient
    """

    type = ReportRecipientType.TEAMS

    def _get_recipient_webhook_urls(self) -> List[str]:
        """
        Get the recipient's channel(s).
        Note Slack SDK uses "channel" to refer to one or more
        channels. Multiple channels are demarcated by a comma.
        :returns: The comma separated list of channel(s)
        """
        recipient_str = json.loads(self._recipient.recipient_config_json)["target"]

        return get_email_address_list(recipient_str)

    @staticmethod
    def _dataframe_to_adaptive_table(df: pd.DataFrame) -> Dict[str, Any]:
        columns = [{"width": 1} for _ in range(len(df.columns))]
        header_row = {
            "type": "TableRow",
            "cells": [
                {
                    "type": "TableCell",
                    "items": [
                        {
                            "type": "TextBlock",
                            "text": col,
                            "wrap": True,
                            "weight": "Bolder",
                        }
                    ],
                }
                for col in df.columns
            ],
        }
        rows = [header_row]
        for idx, row in df.iterrows():
            data_row = {
                "type": "TableRow",
                "cells": [
                    {
                        "type": "TableCell",
                        "items": [
                            {
                                "type": "TextBlock",
                                "text": str(value),
                                "wrap": True,
                            }
                        ],
                    }
                    for value in row
                ],
            }
            rows.append(data_row)
        return {"type": "Table", "columns": columns, "rows": rows}

    def _prepare_csv_component(
        self, files: Sequence[Union[str, IOBase, bytes]]
    ) -> List[Dict[str, str]]:
        return [
            self._dataframe_to_adaptive_table(pd.read_csv(io.BytesIO(file)))  # type: ignore
            for file in files
        ]

    @staticmethod
    def _prepare_image_component(
        files: Sequence[Union[str, IOBase, bytes]]
    ) -> List[Dict[str, str]]:
        return [
            {
                "type": "Image",
                "url": "data:image/png;"
                f"base64,{base64.b64encode(file).decode('utf-8')}",  # type: ignore
            }
            for file in files
        ]

    def _get_body(
        self, title: str, files: Sequence[Union[str, IOBase, bytes]]
    ) -> List[Dict[str, Any]]:
        if files:
            if self._content.csv:
                file_components = self._prepare_csv_component(files)
            elif self._content.screenshots:
                file_components = self._prepare_image_component(files)
            elif self._content.embedded_data:
                file_components = self._prepare_csv_component(
                    self._content.embedded_data  # type: ignore
                )
            else:
                file_components = []
        return {  # type: ignore
            "type": "message",
            "attachments": [
                {
                    "contentType": "application/vnd.microsoft.card.adaptive",
                    "content": {
                        "type": "AdaptiveCard",
                        "body": [
                            {
                                "type": "TextBlock",
                                "size": "Medium",
                                "weight": "Bolder",
                                "text": f"{title}",
                            }
                        ]
                        + file_components
                        + [
                            {
                                "type": "TextBlock",
                                "text": f"{self._content.description}",
                                "wrap": True,
                            },
                        ],
                        "msteams": {"allowExpand": True},
                        "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                        "version": "1.0",
                        "actions": [
                            {
                                "type": "Action.OpenUrl",
                                "title": "Explore in Superset",
                                "url": f"{self._content.url}",
                            }
                        ],
                    },
                }
            ],
        }

    def _get_inline_files(self) -> Sequence[Union[str, IOBase, bytes]]:
        if self._content.csv:
            return [self._content.csv]
        if self._content.screenshots:
            return self._content.screenshots
        return []

    @backoff.on_exception(
        backoff.expo, requests.RequestException, factor=10, base=2, max_tries=5
    )
    @statsd_gauge("reports.teams.send")
    def send(self) -> None:
        files = self._get_inline_files()
        title = self._content.name
        try:
            body = self._get_body(title, files)
        except Exception as ex:
            raise NotificationUnprocessableException(str(ex)) from ex
        headers = {"Content-Type": "application/json"}
        webhook_urls = self._get_recipient_webhook_urls()
        logger.info(webhook_urls)
        for url in webhook_urls:
            try:
                logger.info(url)
                logger.info(body)
                response = requests.post(url, json=body, headers=headers)
                logger.info(response.status_code)
                if response.status_code == 403:
                    raise NotificationAuthorizationException(
                        "An authentication with MS Teams occured."
                    )
                if response.status_code >= 500:
                    raise NotificationMalformedException(
                        "A malford request was made to teams"
                    )
            except requests.RequestException as ex:
                raise NotificationParamException(str(ex)) from ex
