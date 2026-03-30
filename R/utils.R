# ======================================================================
# Shared utility functions used by both R grading scripts
# ======================================================================

#' Build an authenticated OpenAI Assistants v2 request
#'
#' Constructs an \code{httr2} request object targeting the OpenAI v1 API,
#' pre-populated with a Bearer token from the \code{OPENAI_API_KEY} environment
#' variable and the \code{OpenAI-Beta: assistants=v2} header required by the
#' Assistants API.
#'
#' @param path Character. The API path to append to
#'   \code{https://api.openai.com/v1}, e.g. \code{"/assistants"}.
#'
#' @returns An \code{httr2_request} object ready for further modification (e.g.
#'   adding a body) and execution via \code{httr2::req_perform()}.
#'
#' @seealso \code{\link{create_assistant_v2}}
openai_req <- function(path) {
  key <- base::Sys.getenv("OPENAI_API_KEY", unset = NA_character_)
  if (base::is.na(key) || !base::nzchar(key)) {
    base::stop("OPENAI_API_KEY is not set.")
  }
  httr2::request(base::paste0("https://api.openai.com/v1", path)) |>
    httr2::req_headers(
      "Authorization" = base::paste("Bearer", key),
      "OpenAI-Beta"   = "assistants=v2"
    )
}

#' Safely coerce a value to a length-1 numeric
#'
#' A defensive wrapper around \code{as.numeric()} that returns \code{NA_real_}
#' whenever the input is \code{NULL}, a zero-length vector, or non-numeric.
#' Prevents \code{as.numeric(NULL)} from silently producing \code{numeric(0)},
#' which would cause \code{as.data.frame()} to fail with
#' \emph{"arguments imply differing number of rows: 1, 0"}.
#'
#' @param x A scalar value (numeric, integer, character, or \code{NULL}).
#'
#' @returns A length-1 double: the numeric value of \code{x}, or
#'   \code{NA_real_} if \code{x} is \code{NULL}, empty, or non-numeric.
safe_num <- function(x) {
  if (is.null(x) || length(x) == 0) return(NA_real_)
  v <- suppressWarnings(as.numeric(x[[1]]))
  if (is.na(v)) NA_real_ else v
}
