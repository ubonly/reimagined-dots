from .device_flow import DeviceFlowProvider


class GitLabProvider(DeviceFlowProvider):
    provider_id = "gitlab"
    display_name = "GitLab"
    account_host = "gitlab.com"
