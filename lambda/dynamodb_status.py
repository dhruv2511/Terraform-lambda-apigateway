import boto3
from botocore.exceptions import ClientError
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
        response_body, status_code=200):
    response = {
        "statusCode": status_code,
        "body": json.dumps(response_body),
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

    except ClientError as e:
        if e.response['Error']['Code'] == "ResourceNotFoundException":
            status_code = 404
        else:
            status_code = 500

        data = {"ErrorMsg": "Table Not Found"}
        return gen_api_response(response_body=data, status_code=status_code)

    except Exception:
        return gen_api_response(response_body={"Internal Server Error"}, status_code=500)

