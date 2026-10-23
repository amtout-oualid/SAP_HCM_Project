"""Unified input processing layer for resumes (Google Drive link or raw file uploads)."""

import logging
from typing import Optional, Tuple, Dict, Any

from converters.gdrive_fetcher import (
    download_gdrive_file,
    GDriveError,
    GDriveInvalidUrlError,
    GDriveAccessDeniedError,
    GDriveUnsupportedFormatError,
)
from converters.pdf_converter import convert_pdf_to_markdown
from converters.docx_converter import convert_docx_to_markdown
from converters.txt_converter import convert_txt_to_markdown

logger = logging.getLogger("sap_evaluator.input_handler")


def process_resume_to_markdown(
    gdrive_url: Optional[str] = None,
    file_bytes: Optional[bytes] = None,
    filename: Optional[str] = None,
) -> Tuple[str, Dict[str, Any]]:
    """Process an incoming resume (Google Drive URL or uploaded file) into unified Markdown text.

    Args:
        gdrive_url: Public Google Drive or Google Docs URL.
        file_bytes: Raw bytes of uploaded file (if uploaded directly).
        filename: Name of the uploaded file.

    Returns:
        Tuple of (markdown_text, metadata_dict).

    Raises:
        ValueError: If inputs are invalid or format cannot be processed.
        GDriveAccessDeniedError: If Google Drive link is private/inaccessible.
        GDriveUnsupportedFormatError: If file format is not supported.
    """
    if gdrive_url:
        logger.info(f"Processing resume from Google Drive URL: {gdrive_url}")
        content, file_format, resolved_filename = download_gdrive_file(gdrive_url)
        source_type = "gdrive"
    elif file_bytes and filename:
        logger.info(f"Processing resume from direct file upload: {filename}")
        content = file_bytes
        ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
        if ext not in {"pdf", "docx", "txt", "md"}:
            raise ValueError(f"Unsupported file format '{ext}'. Supported formats: PDF, DOCX, TXT, MD.")
        file_format = ext
        resolved_filename = filename
        source_type = "upload"
    else:
        raise ValueError("Either a Google Drive URL (gdrive_url) or a file upload (file_bytes & filename) must be provided.")

    # Convert to Markdown according to detected format
    if file_format == "pdf":
        markdown_text = convert_pdf_to_markdown(content)
    elif file_format == "docx":
        markdown_text = convert_docx_to_markdown(content)
    elif file_format in {"txt", "md"}:
        markdown_text = convert_txt_to_markdown(content)
    else:
        raise ValueError(f"No converter available for format '{file_format}'.")

    metadata = {
        "source_type": source_type,
        "filename": resolved_filename,
        "format": file_format,
        "content_length": len(markdown_text),
    }

    return markdown_text, metadata
