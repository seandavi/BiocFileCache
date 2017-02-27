.util_standardize_rtype <-
    function(rtype, fpath)
{
    rtype <- match.arg(rtype, c("auto", "local", "web"))

    if (rtype == "auto") {
        test <- startsWith(fpath, "http") || startsWith(fpath, "ftp")
        if (test)
            rtype <- "web"
        else
            rtype <- "local"
    }

    rtype
}

.util_ask <-
    function(txt)
{
    repeat {
        response <- substr(tolower(readline(txt)), 1, 1)
        doit <- switch(response, y = TRUE, n = FALSE, NA)
        if (!is.na(doit))
            break
    }
    doit
}

.util_unlink <-
    function(rpaths, ...)
{
    status <- unlink(rpaths, ..., force=TRUE) == 0L
    if (!all(status))
        warning(
            "failed to unlink cache resource(s):",
            "\n  ", paste(sQuote(rpaths[status]), collapse="\n  ")
        )
    status
}

.util_set_last_modified <-
    function(bfc, rid)
{
    fpath <- .sql_get_fpath(bfc, rid)
    web_time <- .httr_get_last_modified(fpath)
    if (length(web_time) == 0L)
        web_time <- as.character(Sys.Date())
    .sql_set_last_modified(bfc, rid, web_time)

    bfc
}

.util_download <-
    function(bfc, rid, proxy, call)
{
    rpath <- .sql_get_rpath(bfc, rid)
    fpath <- .sql_get_fpath(bfc, rid)

    status <- .httr_download(fpath, rpath, proxy)
    if (!status) {
        bfcremove(bfc, rid)
        stop(
            call, " failed; resource removed",
            "\n  rid: ", rid,
            "\n  fpath: ", sQuote(fpath),
            "\n  reason: download failed",
            call. = FALSE)
    }

    .util_set_last_modified(bfc, rid)
}

.util_download_and_rename <-
    function(bfc, rid, proxy, call)
{
    rpath <- .sql_get_rpath(bfc, rid)
    fpath <- .sql_get_fpath(bfc, rid)
    temppath <- tempfile(tmpdir=bfccache(bfc))
    on.exit(unlink(temppath))

    status <- .httr_download(fpath, temppath, proxy)
    if (!status)
        stop(
            call, " failed",
            "\n  rid: ", rid,
            "\n  file: ", sQuote(fpath),
            "\n  reason: download failed",
            call. = FALSE
        )

    status <- file.rename(temppath, rpath)
    if (!status)
        stop(
            call, " failed",
            "\n  rid: ", rid,
            "\n  temporary path: ", sQuote(temppath),
            "\n  rpath: ", sQuote(rpath),
            "\n  reason: file.rename() failed",
            call. = FALSE
        )

    .util_set_last_modified(bfc, rid)
}