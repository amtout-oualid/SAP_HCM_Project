"""Plain text and Markdown file converter with robust encoding detection."""

import logging
from typing import Union

logger = logging.getLogger("sap_evaluator.txt_converter")


def convert_txt_to_markdown(txt_source: Union[str, bytes]) -> str:
    """Convert plain text or markdown source into a normalized string.

    Args:
        txt_source: String or raw bytes of text/markdown file.

    Returns:
        Clean, normalized markdown/text string.

    Raises:
        ValueError: If text is empty or cannot be decoded.
    """
    if isinstance(txt_source, str):
        text = txt_source
    elif isinstance(txt_source, bytes):
        encodings = ["utf-8", "utf-8-sig", "latin-1", "cp1252", "iso-8859-1"]
        decoded_text = None
        for enc in encodings:
            try:
                decoded_text = txt_source.decode(enc)
                break
            except UnicodeDecodeError:
                continue

        if decoded_text is None:
            raise ValueError("Unable to decode text file. Unsupported encoding.")
        text = decoded_text
    else:
        raise ValueError(f"Invalid txt_source type: {type(txt_source)}")

    # Normalize newlines
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    cleaned_text = text.strip()

    if not cleaned_text:
        raise ValueError("Text/Markdown file is empty.")

    logger.info(f"Loaded {len(cleaned_text)} characters from text/markdown source")
    return cleaned_text
