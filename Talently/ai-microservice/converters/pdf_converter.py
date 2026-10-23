"""PDF to Markdown converter using PyMuPDF and pymupdf_rag."""

import io
import logging
from typing import Optional, Union
import pymupdf

from data.pymupdf_rag import to_markdown

logger = logging.getLogger("sap_evaluator.pdf_converter")


def convert_pdf_to_markdown(pdf_source: Union[str, bytes]) -> str:
    """Convert a PDF file (path or raw bytes) to structured Markdown text.

    Args:
        pdf_source: File path as string or raw bytes of the PDF.

    Returns:
        Structured markdown string extracted from the PDF.

    Raises:
        ValueError: If PDF cannot be opened or parsed.
    """
    try:
        if isinstance(pdf_source, bytes):
            doc = pymupdf.open(stream=pdf_source, filetype="pdf")
        elif isinstance(pdf_source, str):
            doc = pymupdf.open(pdf_source)
        else:
            raise ValueError(f"Invalid pdf_source type: {type(pdf_source)}")

        with doc:
            if doc.page_count == 0:
                raise ValueError("PDF document is empty (0 pages)")

            pages = range(doc.page_count)
            markdown_text = to_markdown(doc, pages=pages)

            if not markdown_text or not markdown_text.strip():
                # Fallback to plain text extraction if layout extraction returned empty
                logger.warning("pymupdf_rag returned empty text, falling back to page.get_text()")
                text_parts = [page.get_text("text") for page in doc]
                markdown_text = "\n\n".join(text_parts)

            logger.info(f"Extracted {len(markdown_text)} characters from {doc.page_count} PDF pages")
            return markdown_text.strip()

    except Exception as e:
        logger.error(f"Failed to convert PDF to markdown: {e}")
        raise ValueError(f"Failed to extract text from PDF: {str(e)}") from e
