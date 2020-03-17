import os
import boto3
import logging
from typing import Mapping, Any, Union, Iterator, Set, Callable, Type
import json
from dataclasses import dataclass
import re

LOG_LEVEL = os.environ.get("LOG_LEVEL", logging.INFO)
root_logger = logging.getLogger()
root_logger.setLevel(LOG_LEVEL)
log = logging.getLogger(__name__)
table_name = os.environ['dynamodb_table']
ddb_client = boto3.client('dynamodb')


def get_json_body(event):
    print("JSON Body")
    body_json = event["body"]
    print(body_json)
    return body_json


def build_dynamodb_input(event_body):
    item = { "accountEmail": {"S": event_body["accountEmail"]},
             "accountPrefix": {"S": event_body["accountPrefix"]},
             "accountType": {"S": event_body["accountType"]},
             "appName": {"S": event_body["appName"]},
             "cloudProvider": {"S": event_body["cloudProvider"]},
             "costCenter": {"S": event_body["costCenter"]},
             "createdAt": {"N": event_body["createdAt"]},
             "envType": {"S": event_body["envType"]},
             "id": {"S": event_body["id"]},
             "lob": {"S": event_body["lob"]},
             "primaryRegion": {"S": event_body["primaryRegion"]},
             "primaryVpcCidr": {"S": event_body["primaryVpcCidr"]},
             "reqId": {"S": event_body["reqId"]},
             "responsible": {"S": event_body["responsible"]},
             "secondaryVpcCidr": {"S": event_body["secondaryVpcCidr"]},
             "securityContact": {"S": event_body["securityContact"]},
             "servicenowCase": {"S": event_body["servicenowCase"]}
             }
    log.debug(f"Data to insert in to dynamodb: {item}")
    return item

def insert_to_table(
        table_name: str,
        item,
):
    """
    Takes a prebuilt dynamodb item and inserts it to dynamodb.
    :return: Dynamodb insert response dict
    """
    log.info(f"Inserting in to table: {table_name}")
    response = ddb_client.put_item(TableName=table_name, Item=item)
    log.info(f"Dynamo db insert response: {response}")
    return response


def post_handler(event, context):
    print("POST")

    json_body = get_json_body(event)

    build_ddb_input = build_dynamodb_input(json_body)

    ddb_response = insert_to_table(
        table_name=table_name, item=build_ddb_input
    )

    response = {
        "StatusCode" : 200
    }

    return response
