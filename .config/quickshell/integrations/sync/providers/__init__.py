from .codeberg import CodebergProvider
from .github import GitHubProvider
from .gitlab import GitLabProvider


PROVIDERS = (
    GitHubProvider(),
    GitLabProvider(),
    CodebergProvider(),
)

