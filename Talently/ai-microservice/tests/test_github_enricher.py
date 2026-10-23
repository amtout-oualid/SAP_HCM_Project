"""Unit tests for GitHub username extraction and repository classification logic."""

import pytest
from services.github_enricher import extract_github_username


def test_extract_username_full_url():
    assert extract_github_username("https://github.com/octocat") == "octocat"
    assert extract_github_username("http://github.com/octocat/") == "octocat"
    assert extract_github_username("https://www.github.com/octocat") == "octocat"


def test_extract_username_with_query_and_fragment():
    assert extract_github_username("https://github.com/torvalds?tab=repositories") == "torvalds"
    assert extract_github_username("https://github.com/torvalds#readme") == "torvalds"


def test_extract_username_handle_and_raw():
    assert extract_github_username("@octocat") == "octocat"
    assert extract_github_username("octocat") == "octocat"


def test_extract_username_system_pages():
    assert extract_github_username("https://github.com/topics") is None
    assert extract_github_username("https://github.com/trending") is None
    assert extract_github_username("https://github.com/explore") is None


def test_extract_username_invalid():
    assert extract_github_username(None) is None
    assert extract_github_username("") is None
    assert extract_github_username("   ") is None
