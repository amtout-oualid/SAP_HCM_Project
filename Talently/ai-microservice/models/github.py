"""Pydantic models for GitHub profiles, repository details, and README data."""

from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field


class GitHubProfile(BaseModel):
    """Normalized GitHub user profile."""
    username: str
    name: Optional[str] = None
    bio: Optional[str] = None
    location: Optional[str] = None
    company: Optional[str] = None
    public_repos: Optional[int] = None
    followers: Optional[int] = None
    following: Optional[int] = None
    created_at: Optional[str] = None
    updated_at: Optional[str] = None
    avatar_url: Optional[str] = None
    blog: Optional[str] = None
    twitter_username: Optional[str] = None
    hireable: Optional[bool] = None


class GitHubProjectDetails(BaseModel):
    """Detailed repository metrics from GitHub API."""
    stars: int = 0
    forks: int = 0
    language: Optional[str] = None
    description: Optional[str] = None
    created_at: Optional[str] = None
    updated_at: Optional[str] = None
    topics: List[str] = Field(default_factory=list)
    open_issues: int = 0
    size: int = 0
    fork: bool = False
    archived: bool = False
    default_branch: Optional[str] = "main"
    contributors: int = 1


class GitHubProject(BaseModel):
    """Candidate GitHub repository with README content for evaluation."""
    name: str
    owner: Optional[str] = None
    description: Optional[str] = None
    github_url: str
    live_url: Optional[str] = None
    technologies: List[str] = Field(default_factory=list)
    project_type: str = "self_project"  # "open_source" or "self_project"
    contributor_count: int = 1
    author_commit_count: int = 0
    total_commit_count: int = 0
    github_details: Optional[GitHubProjectDetails] = None
    readme_content: Optional[str] = None  # Truncated README snippet for LLM evaluation
