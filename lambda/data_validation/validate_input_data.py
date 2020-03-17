import logging
from dataclasses import dataclass
from typing import Any, Callable, Iterator, Mapping, Set, Type, Union

log = logging.getLogger(__name__)


@dataclass
class ValidationProblem:
    field: str
    message: str


def valid_as_epoch(k: str, v: Any, d: Mapping[str, Any]) -> Iterator[ValidationProblem]:
    if isinstance(v, int):
        if 0 < v < 2 ** 32:
            pass
        else:
            yield ValidationProblem(k, f"Out of range")
    else:
        yield ValidationProblem(k, f"Not a number")


def greater_than_other_field(
    field: str,
) -> Callable[[str], Iterator[ValidationProblem]]:
    def v(k: str, v: Any, d: Mapping[str, Any]) -> Iterator[ValidationProblem]:
        other_value = d[field]
        try:
            if other_value >= v:
                yield ValidationProblem(k, f"'{k}' should be greater than '{field}'")
        except TypeError:
            yield ValidationProblem(k, "Invalid type")

    return v


def is_type(t: Set[Type]) -> Callable[[str], Iterator[ValidationProblem]]:
    def v(k: str, v: Any, d: Mapping[str, Any]) -> Iterator[ValidationProblem]:
        if not isinstance(v, tuple(t)):
            yield ValidationProblem(k, "Invalid type")

    return v


def is_in_length_range(
    low: int, high: int
) -> Callable[[str], Iterator[ValidationProblem]]:
    def v(k: str, v: Any, d: Mapping[str, Any]) -> Iterator[ValidationProblem]:
        if len(v) in range(low, high):
            pass
        else:
            yield ValidationProblem(k, "Invalid input length")

    return v


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


def validate_input_data(validation_structure, input_data) -> bool:
    validator = build_validator(validation_structure)
    result = list(validator(input_data))
    for problem in result:
        log.warning(problem)
    return not bool(result)
