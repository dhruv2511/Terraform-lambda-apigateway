import requests
import json
import os
import http.client


headers = {
    'Authorization': f'Bearer {os.environ["access_token"]}',
    'Content-Type': 'application/vnd.api+json',
}




def get_handler(event, context):
    req_response = requests.get('https://app.terraform.io/api/v2/organizations', headers=headers)
    print(req_response)
    response = {
        "statusCode": req_response.status_code,
        "body": json.dumps(req_response.reason)
    }
    return response

def post_handler(event, context):
    req_response = requests.get('https://app.terraform.io/api/v2/organizations', headers=headers)
    print(req_response)
    response = {
        "statusCode": req_response.status_code,
        "body": json.dumps(req_response.reason)
    }
    return response