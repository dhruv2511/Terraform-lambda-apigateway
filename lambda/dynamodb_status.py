import boto3
import os
import logging
import json

LOG_LEVEL = os.environ.get("LOG_LEVEL", logging.INFO)
root_logger = logging.getLogger()
root_logger.setLevel(LOG_LEVEL)
log = logging.getLogger(__name__)

dynamodb_client = boto3.client('dynamodb')
table_name = os.environ['dynamodb_table']

def gen_api_response(
        response_body, status_code=200, headers=None, is_base64_encoded=False):
    response = {
        "statusCode": status_code,
        "headers": headers,
        "body": json.dumps(response_body),
        "isBase64Encoded": is_base64_encoded,
    }
    log.info(f"Lambda Response: {response}")
    return response


def handler(event, context):
    """
    Top level lambda handler
    """
    log.info(event)

    try:
        response = dynamodb_client.describe_table(TableName=table_name)
        return gen_api_response(response_body=response)

    except ApiError as ex:
        log.info(f"ErrorMsg: {ex.data}")
        data = {"ErrorMsg": ex.data}
        return gen_api_response(response_body=data, status_code=404)

    except Exception:
        return gen_api_response(response_body={}, status_code=500)


class ApiError(Exception):
    """
    Custom exception to hold management api exceptions
    """

    def __init__(self, data):
        self.data = data

    def __str__(self):
        return repr(self.data)