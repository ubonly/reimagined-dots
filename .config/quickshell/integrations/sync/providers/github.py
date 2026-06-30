from .device_flow import DeviceFlowProvider


class GitHubProvider(DeviceFlowProvider):
    provider_id = "github"
    display_name = "GitHub"
    account_host = "github.com"
