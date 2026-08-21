class ClientError(Exception):
    def __init__(self, error_code="ClientError", message=""):
        self.response = {"Error": {"Code": error_code, "Message": message}}
        super().__init__(message or error_code)
