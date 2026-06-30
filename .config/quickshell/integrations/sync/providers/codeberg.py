from .device_flow import DeviceFlowProvider


class CodebergProvider(DeviceFlowProvider):
    provider_id = "codeberg"
    display_name = "Codeberg"
    account_host = "codeberg.org"
