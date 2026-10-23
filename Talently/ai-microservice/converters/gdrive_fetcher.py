"""Google Drive public link validator, file downloader, and format detector."""

import io
import logging
import re
import urllib.parse
import zipfile
from typing import Optional, Tuple
import requests

logger = logging.getLogger("sap_evaluator.gdrive")

# Custom exceptions for clear API error mapping
class GDriveError(Exception):
    """Base exception for Google Drive operations."""
    pass


class GDriveInvalidUrlError(GDriveError):
    """Raised when the URL is not a recognized Google Drive/Docs URL."""
    pass


class GDriveAccessDeniedError(GDriveError):
    """Raised when the Google Drive file is private or requires authorization."""
    pass


class GDriveUnsupportedFormatError(GDriveError):
    """Raised when the fetched file is not in PDF, DOCX, TXT, or MD format."""
    pass


SUPPORTED_FORMATS = {"pdf", "docx", "txt", "md"}


def extract_gdrive_id(url: str) -> Tuple[str, str]:
    """Extract File ID and document type from a Google Drive or Google Docs URL.

    Returns:
        Tuple of (file_id, doc_type) where doc_type is 'file' or 'document'.

    Raises:
        GDriveInvalidUrlError if ID cannot be determined.
    """
    if not url or not isinstance(url, str):
        raise GDriveInvalidUrlError("No Google Drive URL provided.")

    url = url.strip()

    # Pattern for Google Docs editor URL
    doc_match = re.search(r"docs\.google\.com/document/d/([a-zA-Z0-9_-]+)", url)
    if doc_match:
        return doc_match.group(1), "document"

    # Pattern for standard Drive file URL: /file/d/{id}/view
    file_match = re.search(r"drive\.google\.com/file/d/([a-zA-Z0-9_-]+)", url)
    if file_match:
        return file_match.group(1), "file"

    # Pattern for open?id={id}
    open_match = re.search(r"[?&]id=([a-zA-Z0-9_-]+)", url)
    if open_match and ("drive.google.com" in url or "docs.google.com" in url):
        return open_match.group(1), "file"

    # Direct uc link: uc?id={id}
    uc_match = re.search(r"drive\.google\.com/uc\?.*id=([a-zA-Z0-9_-]+)", url)
    if uc_match:
        return uc_match.group(1), "file"

    raise GDriveInvalidUrlError(
        f"Unable to parse Google Drive link. Please provide a standard Google Drive sharing link "
        f"(e.g., https://drive.google.com/file/d/FILE_ID/view?usp=sharing)"
    )


def _detect_format(content: bytes, content_type: str, filename: Optional[str]) -> str:
    """Detect file format using filename, Content-Type, and magic bytes."""
    # 1. Check filename extension
    if filename:
        ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
        if ext in SUPPORTED_FORMATS:
            return ext

    # 2. Check Magic Bytes
    if content.startswith(b"%PDF-"):
        return "pdf"

    if content.startswith(b"PK\x03\x04"):
        # Could be docx (which is a zip archive)
        try:
            with zipfile.ZipFile(io.BytesIO(content)) as zf:
                namelist = zf.namelist()
                if any(n.startswith("word/") for n in namelist) or "[Content_Types].xml" in namelist:
                    return "docx"
        except Exception:
            pass

    # 3. Check Content-Type header
    if "pdf" in content_type:
        return "pdf"
    if "wordprocessingml" in content_type or "msword" in content_type:
        return "docx"
    if "text/markdown" in content_type or "markdown" in content_type:
        return "md"
    if "text/plain" in content_type:
        return "txt"

    # 4. Text heuristic: try decoding small sample
    try:
        sample = content[:4096].decode("utf-8")
        if sample.isprintable() or "\n" in sample:
            return "txt"
    except UnicodeDecodeError:
        pass

    return "unknown"


def download_gdrive_file(url: str, timeout: int = 30) -> Tuple[bytes, str, str]:
    """Download a publicly accessible file from Google Drive.

    Validates:
    1. The link is publicly accessible (not private, not requiring login).
    2. The file is in a supported format (PDF, DOCX, TXT, MD).

    Args:
        url: Public Google Drive sharing link.
        timeout: HTTP request timeout in seconds.

    Returns:
        Tuple of (file_bytes, detected_extension, filename).

    Raises:
        GDriveInvalidUrlError: URL is not recognized as Google Drive.
        GDriveAccessDeniedError: Link is private or requires permission.
        GDriveUnsupportedFormatError: File is not a supported document format.
        GDriveError: Network or download failure.
    """
    file_id, doc_type = extract_gdrive_id(url)
    session = requests.Session()

    if doc_type == "document":
        # Google Docs documents must be exported as PDF
        download_url = f"https://docs.google.com/document/d/{file_id}/export?format=pdf"
    else:
        # Standard Drive file download endpoint
        download_url = f"https://drive.google.com/uc?export=download&id={file_id}"

    headers = {
        "User-Agent": (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        )
    }

    try:
        response = session.get(download_url, headers=headers, timeout=timeout, allow_redirects=True)
    except requests.exceptions.RequestException as e:
        logger.error(f"Network error downloading Google Drive file: {e}")
        raise GDriveError(f"Failed to connect to Google Drive: {str(e)}") from e

    # Check for HTTP access errors
    if response.status_code in (401, 403):
        raise GDriveAccessDeniedError(
            "Access Denied: The Google Drive file is private. "
            "Please configure link sharing to 'Anyone with the link can view'."
        )
    if response.status_code == 404:
        raise GDriveAccessDeniedError("The Google Drive file was not found or has been deleted.")

    if response.status_code != 200:
        raise GDriveError(f"Google Drive returned HTTP status {response.status_code}")

    content = response.content
    content_type = response.headers.get("Content-Type", "").lower()

    # Check if Google served a virus scan confirmation page (common for files > 100MB)
    if "confirm=" in response.text or "download_warning" in response.text:
        match = re.search(r"confirm=([0-9A-Za-z_]+)", response.text)
        confirm_token = match.group(1) if match else "t"
        confirm_url = f"https://drive.google.com/uc?export=download&id={file_id}&confirm={confirm_token}"
        response = session.get(confirm_url, headers=headers, timeout=timeout)
        content = response.content
        content_type = response.headers.get("Content-Type", "").lower()

    # Detect if response is actually a Google login / access denied HTML page
    if "text/html" in content_type:
        text_lower = response.text.lower()
        private_indicators = [
            "accounts.google.com",
            "servicelogin",
            "access denied",
            "you need permission",
            "request access",
            "sign in - google accounts",
            "permission denied",
        ]
        if any(ind in text_lower for ind in private_indicators):
            logger.warning(f"Google Drive link returned access restriction page: {url}")
            raise GDriveAccessDeniedError(
                "Access Denied: The Google Drive file is private and requires account login. "
                "Please open Google Drive, right click the file, select Share, and choose 'Anyone with the link can view'."
            )

    # Extract filename from Content-Disposition header if available
    cd = response.headers.get("Content-Disposition", "")
    filename = None
    if "filename=" in cd:
        fn_match = re.search(r'filename=["\']?([^"\';]+)["\']?', cd)
        if fn_match:
            filename = urllib.parse.unquote(fn_match.group(1))

    if not filename:
        filename = f"resume_{file_id}"

    # Determine file extension and validate format
    detected_format = _detect_format(content, content_type, filename)

    if detected_format not in SUPPORTED_FORMATS:
        logger.error(
            f"Unsupported file format detected: '{detected_format}' (Content-Type: {content_type}, Filename: {filename})"
        )
        raise GDriveUnsupportedFormatError(
            f"Unsupported resume format '{detected_format}'. "
            f"Supported file formats are: {', '.join(sorted(f.upper() for f in SUPPORTED_FORMATS))}."
        )

    logger.info(
        f"Successfully downloaded Google Drive file '{filename}' "
        f"({len(content)} bytes, format: {detected_format.upper()})"
    )
    return content, detected_format, filename
