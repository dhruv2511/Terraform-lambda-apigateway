from data_validation.validate_input_data import validate_input_data
import os
import logging
from typing import Mapping, Any

StringKeyedMapping = Mapping[str, Any]

LOG_LEVEL = os.environ.get("LOG_LEVEL", logging.INFO)
root_logger = logging.getLogger()
root_logger.setLevel(LOG_LEVEL)
log = logging.getLogger(__name__)


def process_validation(validation_configuration, input_data: StringKeyedMapping):
    """
    Applies the validation configuration against the date to validate.
    Throws an exception on failure to validate.
    """
    if not validate_input_data(validation_configuration, input_data):
        log.error("Failed Validation")
        raise ApiError("Invalid post data")


class ApiError(Exception):
    """
    Custom exception to hold management api exceptions
    """

    def __init__(self, data):
        self.data = data

    def __str__(self):
        return repr(self.data)
