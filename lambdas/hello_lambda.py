def get_handler(event, context):
    return {"message": "Hello, World!"}


def post_handler(event, context):
    return {"message": "I should have created something..."}


def monitoring_get_handler(event, context):
    return {"message": "Hello, World!"}


def monitoring_post_handler(event, context):
    return {"message": "I should have created something..."}
