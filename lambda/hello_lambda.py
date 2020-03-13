import requests
import json
import os
import logging

root_logger = logging.getLogger()
root_logger.setLevel("INFO")
log = logging.getLogger(__name__)

def get_handler(event, context):

    request("GET", "/organisations")
    res = conn.getresponse()
    log.debug(res)

    response = {
        "statusCode": res.status,
        "body": json.dumps(res.reason)
    }
    return response

def post_handler(event, context):
    conn = http.client.HTTPConnection("app.terraform.io/app/delta")
    conn.request("GET", "/organisations")
    res = conn.getresponse()
    log.debug(res)

    response = {
        "statusCode": res.status,
        "body": json.dumps(res.reason)
    }
    return response