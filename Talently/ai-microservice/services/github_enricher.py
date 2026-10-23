"""GitHub profile, repository metrics, and README enrichment service."""

import base64
import json
import logging
import os
import re
from typing import Dict, List, Optional, Any, Tuple
import requests

from core.config import settings, DEFAULT_MODEL, MODEL_PARAMETERS
from core.llm import initialize_llm_provider, extract_json_from_response
from core.templates import TemplateManager
from models.github import GitHubProfile

logger = logging.getLogger("sap_evaluator.github_enricher")


def extract_github_username(github_url: Optional[str]) -> Optional[str]:
    """Extract clean GitHub username from URL, handle, or string."""
    if not github_url or not isinstance(github_url, str):
        return None

    cleaned = github_url.strip().replace(" ", "")
    patterns = [
        r"https?://github\.com/([^/?#]+)",
        r"github\.com/([^/?#]+)",
        r"@([^/?#]+)",
        r"^([a-zA-Z0-9-]+)$",
    ]

    for pattern in patterns:
        match = re.search(pattern, cleaned)
        if match:
            username = match.group(1).rstrip("/")
            if username.lower() not in {"topics", "trending", "explore", "settings", "orgs"}:
                return username
    return None


class GitHubEnricher:
    """Enriches candidate evaluation data using GitHub API and repository README analysis."""

    def __init__(self, github_token: Optional[str] = None, model_name: Optional[str] = None):
        self.github_token = github_token or settings.GITHUB_TOKEN or os.environ.get("GITHUB_TOKEN")
        self.model_name = model_name or DEFAULT_MODEL
        self.template_manager = TemplateManager()
        self.provider = initialize_llm_provider(self.model_name)
        self.session = requests.Session()

    def _headers(self) -> Dict[str, str]:
        headers = {"User-Agent": "SAP-Candidate-Evaluator"}
        if self.github_token and self.github_token != "your_github_personal_access_token_here":
            headers["Authorization"] = f"token {self.github_token}"
        return headers

    def fetch_profile(self, username: str) -> Optional[GitHubProfile]:
        """Fetch user profile metadata from GitHub API."""
        try:
            url = f"https://api.github.com/users/{username}"
            resp = self.session.get(url, headers=self._headers(), timeout=10)
            if resp.status_code == 200:
                d = resp.json()
                return GitHubProfile(
                    username=username,
                    name=d.get("name"),
                    bio=d.get("bio"),
                    location=d.get("location"),
                    company=d.get("company"),
                    public_repos=d.get("public_repos", 0),
                    followers=d.get("followers", 0),
                    following=d.get("following", 0),
                    created_at=d.get("created_at"),
                    updated_at=d.get("updated_at"),
                    avatar_url=d.get("avatar_url"),
                    blog=d.get("blog"),
                    twitter_username=d.get("twitter_username"),
                    hireable=d.get("hireable"),
                )
            elif resp.status_code == 404:
                logger.warning(f"GitHub user '{username}' not found (404)")
                return None
            else:
                logger.warning(f"GitHub API error fetching profile for '{username}': HTTP {resp.status_code}")
                return None
        except Exception as e:
            logger.error(f"Network error fetching GitHub profile for '{username}': {e}")
            return None

    def fetch_contributors(self, owner: str, repo: str) -> List[Dict[str, Any]]:
        """Fetch contributors for a repository."""
        try:
            url = f"https://api.github.com/repos/{owner}/{repo}/contributors"
            resp = self.session.get(url, headers=self._headers(), timeout=8)
            return resp.json() if resp.status_code == 200 and isinstance(resp.json(), list) else []
        except Exception:
            return []

    fetch_repo_contributors = fetch_contributors

    def fetch_repo_readme(self, owner: str, repo: str, max_chars: int = 800) -> Optional[str]:
        """Fetch repository README and extract a cleaned, representative excerpt for quality evaluation.

        Args:
            owner: GitHub repository owner.
            repo: GitHub repository name.
            max_chars: Character limit to avoid prompt context bloat.

        Returns:
            Cleaned README text snippet, or None if no useful README exists.
        """
        try:
            url = f"https://api.github.com/repos/{owner}/{repo}/readme"
            # Request raw markdown directly
            headers = self._headers()
            headers["Accept"] = "application/vnd.github.raw"
            resp = self.session.get(url, headers=headers, timeout=10)

            if resp.status_code == 200:
                raw_readme = resp.text
            elif resp.status_code == 404:
                return None
            else:
                # Try fallback standard JSON (base64 encoded content)
                headers["Accept"] = "application/vnd.github.v3+json"
                resp = self.session.get(url, headers=headers, timeout=10)
                if resp.status_code == 200:
                    data = resp.json()
                    content_b64 = data.get("content", "")
                    raw_readme = base64.b64decode(content_b64).decode("utf-8", errors="ignore")
                else:
                    return None

            if not raw_readme or not raw_readme.strip():
                return None

            # Clean markdown badges, html comments, and image links
            cleaned = re.sub(r"\[!\[.*?\]\(.*?\)\]\(.*?\)", "", raw_readme)  # badge links
            cleaned = re.sub(r"!\[.*?\]\(.*?\)", "", cleaned)                 # images
            cleaned = re.sub(r"<!--.*?-->", "", cleaned, flags=re.DOTALL)     # comments
            cleaned = re.sub(r"<[^>]+>", "", cleaned)                         # html tags
            cleaned = re.sub(r"\n{3,}", "\n\n", cleaned).strip()

            if len(cleaned) < 30:
                # Stub README with negligible content
                return None

            # Truncate cleanly at paragraph or sentence boundary
            if len(cleaned) > max_chars:
                truncated = cleaned[:max_chars]
                last_newline = truncated.rfind("\n")
                if last_newline > max_chars // 2:
                    cleaned = truncated[:last_newline] + "\n... [README truncated for length]"
                else:
                    cleaned = truncated + "... [README truncated]"

            return cleaned

        except Exception as e:
            logger.debug(f"Could not fetch README for {owner}/{repo}: {e}")
            return None

    def fetch_all_repos(self, username: str, max_repos: int = 100) -> List[Dict[str, Any]]:
        """Fetch candidate's repositories with classification into open source and self projects."""
        try:
            url = f"https://api.github.com/users/{username}/repos"
            params = {"sort": "updated", "per_page": min(max_repos, 100), "type": "all"}
            resp = self.session.get(url, headers=self._headers(), params=params, timeout=12)

            if resp.status_code != 200 or not isinstance(resp.json(), list):
                logger.warning(f"Could not fetch repositories for '{username}': HTTP {resp.status_code}")
                return []

            repos_data = resp.json()
            projects = []

            for repo in repos_data:
                # Skip trivial forks with fewer than 5 forks
                if repo.get("fork") and repo.get("forks_count", 0) < 5:
                    continue

                repo_name = repo.get("name")
                owner = repo.get("owner", {}).get("login") or username
                contributors = self.fetch_repo_contributors(owner, repo_name)
                contributor_count = len(contributors)

                user_contributions = 0
                total_contributions = 0
                for c in contributors:
                    if isinstance(c, dict):
                        cnt = c.get("contributions", 0)
                        total_contributions += cnt
                        if c.get("login", "").lower() == username.lower():
                            user_contributions = cnt

                project_type = "open_source" if contributor_count > 1 else "self_project"

                projects.append({
                    "name": repo.get("name"),
                    "owner": owner,
                    "description": repo.get("description") or "No description provided",
                    "github_url": repo.get("html_url"),
                    "live_url": repo.get("homepage") or None,
                    "technologies": [repo.get("language")] if repo.get("language") else [],
                    "project_type": project_type,
                    "contributor_count": max(1, contributor_count),
                    "author_commit_count": user_contributions,
                    "total_commit_count": total_contributions,
                    "github_details": {
                        "stars": repo.get("stargazers_count", 0),
                        "forks": repo.get("forks_count", 0),
                        "language": repo.get("language"),
                        "created_at": repo.get("created_at"),
                        "updated_at": repo.get("updated_at"),
                        "contributors": max(1, contributor_count),
                        "open_issues": repo.get("open_issues_count", 0),
                        "size": repo.get("size", 0),
                    }
                })

            # Sort by stars descending
            projects.sort(key=lambda x: x["github_details"]["stars"], reverse=True)
            logger.info(f"Fetched {len(projects)} repositories for GitHub user '{username}'")
            return projects

        except Exception as e:
            logger.error(f"Error fetching repos for '{username}': {e}")
            return []

    def select_top_projects(self, projects: List[Dict[str, Any]], position_title: str) -> List[Dict[str, Any]]:
        """Use LLM to select up to 7 most relevant projects for the target position."""
        if not projects:
            return []

        # Filter projects where candidate has made contributions if contributor data is available
        valid_projects = [p for p in projects if p.get("author_commit_count", 1) > 0 or p.get("contributor_count", 1) == 1]
        if not valid_projects:
            valid_projects = projects

        if len(valid_projects) <= 7:
            return valid_projects

        try:
            projects_summary = json.dumps(valid_projects[:15], indent=2)
            prompt = self.template_manager.render_template(
                "github_project_selection",
                projects_data=projects_summary,
                position_title=position_title,
            )

            if not prompt:
                return valid_projects[:7]

            model_params = MODEL_PARAMETERS.get(self.model_name, {"temperature": 0.1, "top_p": 0.9})
            chat_params = {
                "model": self.model_name,
                "messages": [
                    {
                        "role": "system",
                        "content": "You are a technical recruiter. Select the 7 most impressive and relevant unique projects. Respond with valid JSON array of projects.",
                    },
                    {"role": "user", "content": prompt},
                ],
                "options": model_params,
            }

            response = self.provider.chat(**chat_params)
            response_text = extract_json_from_response(response["message"]["content"])
            selected = json.loads(response_text)

            if isinstance(selected, list) and len(selected) > 0:
                selected_names = {p.get("name") for p in selected if isinstance(p, dict)}
                # Map back to full project dicts
                matched = [p for p in valid_projects if p.get("name") in selected_names]
                if matched:
                    return matched[:7]

            return valid_projects[:7]

        except Exception as e:
            logger.warning(f"LLM project selection fallback to top 7: {e}")
            return valid_projects[:7]

    def enrich_candidate(self, github_url: str, position_title: str = "Software Engineering Intern") -> Dict[str, Any]:
        """Fetch profile, select top projects, and enrich with README quality content."""
        username = extract_github_username(github_url)
        if not username:
            logger.info(f"No valid GitHub username found in URL: '{github_url}'")
            return {}

        logger.info(f"Enriching candidate with GitHub profile '{username}'...")
        profile = self.fetch_profile(username)
        repos = self.fetch_all_repos(username)
        top_projects = self.select_top_projects(repos, position_title=position_title)

        # Enrich each selected project with README analysis
        logger.info(f"Fetching README documentation for {len(top_projects)} selected repositories...")
        for proj in top_projects:
            repo_name = proj.get("name")
            owner = proj.get("owner") or username
            readme_text = self.fetch_repo_readme(owner, repo_name)
            proj["readme_content"] = readme_text

        profile_data = profile.model_dump() if profile else {"username": username}

        return {
            "profile": profile_data,
            "projects": top_projects,
            "total_projects": len(top_projects),
        }
