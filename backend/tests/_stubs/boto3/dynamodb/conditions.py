"""Minimal stand-in for boto3.dynamodb.conditions supporting `.eq`."""


class _Cond:
    def __init__(self, name, value):
        self.name = name
        self.value = value

    def matches(self, item):
        return item.get(self.name) == self.value


class _Ref:
    def __init__(self, name):
        self.name = name

    def eq(self, value):
        return _Cond(self.name, value)


def Attr(name):  # noqa: N802 (match boto3 API)
    return _Ref(name)


def Key(name):  # noqa: N802
    return _Ref(name)
