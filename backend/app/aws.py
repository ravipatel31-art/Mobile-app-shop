"""boto3 client/resource factory.

The endpoint URL is read from the environment on every call so the same code
talks to Floci locally (AWS_ENDPOINT_URL set by `eval $(floci env)`) or to real
AWS in production (variable unset)."""
import os
import boto3

from .config import Config


def _kwargs():
    endpoint = os.getenv("AWS_ENDPOINT_URL") or None
    return {
        "endpoint_url": endpoint,
        "region_name": os.getenv("AWS_REGION", Config.AWS_REGION),
    }


def dynamodb():
    return boto3.resource("dynamodb", **_kwargs())


def dynamodb_client():
    return boto3.client("dynamodb", **_kwargs())


def s3():
    return boto3.client("s3", **_kwargs())


def menu_table():
    return dynamodb().Table(Config.MENU_TABLE)


def orders_table():
    return dynamodb().Table(Config.ORDERS_TABLE)


def staff_table():
    return dynamodb().Table(Config.STAFF_TABLE)


def tables_table():
    return dynamodb().Table(Config.TABLES_TABLE)
