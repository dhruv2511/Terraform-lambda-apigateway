import os
import boto3
import logging
from typing import Mapping, Any, Union, Iterator, Set, Callable, Type
import json
from dataclasses import dataclass
import re

StringKeyedMapping = Mapping[str, Any]

ddb_client = boto3.client('dynamodb')
table_name = os.environ['dynamodb_table']
regex = '^\w+([\.-]?\w+)*@\w+([\.-]?\w+)*(\.\w{2,3})+$'

LOG_LEVEL = os.environ.get("LOG_LEVEL", logging.INFO)
root_logger = logging.getLogger()
root_logger.setLevel(LOG_LEVEL)
log = logging.getLogger(__name__)


@dataclass
class ValidationProblem:
    field: str
    message: str


def process_validation(validation_configuration, input_data: StringKeyedMapping):
    """
    Applies the validation configuration against the date to validate.
    Throws an exception on failure to validate.
    """
    if not validate_input_data(validation_configuration, input_data):
        log.error("Failed Validation")
        raise ApiError("Invalid post data")


def validate_input_data(validation_structure, input_data):
    validator = build_validator(validation_structure)


def build_validator(validation_structure):
    def _validate_input_data(
            input_data: Mapping[str, Union[str, int, bool]]
    ) -> Iterator[ValidationProblem]:

        for vk, validators in validation_structure.items():
            try:
                iv = input_data[vk]
                for v in validators:
                    yield from v(vk, iv, input_data)
            except KeyError:
                yield ValidationProblem(vk, "Field is missing")

    return _validate_input_data

def build_insert_dynamodb_item(event_body: StringKeyedMapping) -> StringKeyedMapping:
    """
    This function receives a pre validated body-json and returns a data structure
    suitable for insertion to dynamodb.
    It does not know anything about aws lambda event structure, how to post to
    dynamodb nor how to validate the input data.
    :param event_body: dict of config to use to build dynamodb insert data structure.
    """
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


def get_body_json(event: StringKeyedMapping) -> StringKeyedMapping:
    """
    :param event: Lambda event trigger
    :return: body json if present, or raises an Exception
    """
    if "body" not in event:
        raise ApiError("Invalid post data")

    body_json = json.loads(event["body"])
    log.info(f"Body: {body_json}")
    return body_json


def is_type(t: Set[Type]) -> Callable[[str], Iterator[ValidationProblem]]:
    def v(k: str, v: Any, d: Mapping[str, Any]) -> Iterator[ValidationProblem]:
        if not isinstance(v, tuple(t)):
            yield ValidationProblem(k, "Invalid type")

    return v


def validate_email(k: str, v: Any, d: Mapping[str, Any]) -> Iterator[ValidationProblem]:
    if isinstance(v, str):
        if re.search(regex, v):
            pass
        else:
            yield ValidationProblem(k, f"Invalid Email")
    else:
        yield ValidationProblem(k, f"Not a String")


def get_insert_validation_config() -> Mapping[str, Any]:
    """
    :return: A validation configuration to validate post data before being used to insert to dynamodb.
    """
    return {
        "accountEmail": {is_type({str}), validate_email},
        "accountPrefix": {is_type({str})},
        "accountType": {is_type({str})},
        "appName": {is_type({str})},
        "cloudProvider": {is_type({str})},
        "costCenter": {is_type({str})},
        "createdAt": {is_type({int})},
        "envType": {is_type({str})},
        "id": {is_type({str})},
        "lob": {is_type({str})},
        "primaryRegion": {is_type({str})},
        "primaryVpcCidr": {is_type({str})},
        "reqId": {is_type({str}), validate_email},
        "responsible": {is_type({str})},
        "secondaryVpcCidr": {is_type({str})},
        "securityContact": {is_type({str})},
        "servicenowCase": {is_type({str})}
    }


def insert_to_table(
        table_name: str,
        item: Mapping[str, StringKeyedMapping],
) -> StringKeyedMapping:
    """
    Takes a prebuilt dynamodb item and inserts it to dynamodb.
    :return: Dynamodb insert response dict
    """
    log.info(f"Inserting in to table: {table_name}")
    response = ddb_client.put_item(TableName=table_name, Item=item)
    log.info(f"Dynamo db insert response: {response}")
    return response


def gen_nice_ddb_response(
        insert_response: StringKeyedMapping, entry_id: str
) -> Mapping[str, int]:
    """
    :param entry_id: the id of item inserted into the DynamoDb table
    :param insert_response: Raw dynamodb response
    :return: Returns the http status code in a dict
    """
    return {
        "id": entry_id,
        "HTTPStatusCode": insert_response["ResponseMetadata"]["HTTPStatusCode"],
    }

def post_handler(event, context):
    log.info("POST")

    json_body: StringKeyedMapping = get_body_json(event)

    process_validation(
        validation_configuration=get_insert_validation_config(), input_data=json_body
    )

    dynamo_db_insert_data: StringKeyedMapping = build_insert_dynamodb_item(
        event_body=json_body
    )

    ddb_response: StringKeyedMapping = insert_to_table(
        table_name=table_name, item=dynamo_db_insert_data
    )

    entry_id: str = dynamo_db_insert_data["id"]["S"]
    response: StringKeyedMapping = gen_nice_ddb_response(
        ddb_response, entry_id
    )
    log.info(f"Insert Response: {response}")
    return response


class ApiError(Exception):
    """
    Custom exception to hold management api exceptions
    """

    def __init__(self, data):
        self.data = data

    def __str__(self):
        return repr(self.data)
