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

    except dynamodb_client.exceptions.ResourceNotFoundException as ex:
        log.info(ex)
        data = {"ErrorMsg": ex}
        return gen_api_response(response_body=data, status_code=404)

    except Exception:
        return gen_api_response(response_body={}, status_code=500)