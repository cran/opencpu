# Note: In some cases replayPlot() raises an error, but the error message is printed in the figure!
# Currently this case is detected via the error message 'invalid graphics state'
try_print_plot <- function(object, figure){
  out <- try(print(object), silent = TRUE)
  if(inherits(out, "try-error") && !grepl("invalid graphics state", attr(out, "condition")$message)){
    stop(sprintf("Failed to print plot: %s", attr(out, "condition")$message))
  }
  if(!file.exists(figure)){
    stop("This call did not generate any plot. Make sure the function/object produces a graph.");
  }
  res$setbody(file = figure);
  res$finish()
}

httpget_object <- local({
  main <- function(object, reqformat, objectname = "output", defaultformat = NULL){
    #Default format
    if(is.na(reqformat)){
      if(!length(defaultformat)){
        defaultformat <- "print"
      }
      res$redirectpath(defaultformat);
    }

    #render object
    switch(reqformat,
      "print" = httpget_object_print(object),
      "md" = httpget_object_pander(object),
      "text" = httpget_object_text(object),
      "ascii" = httpget_object_ascii(object),
      "bin" = httpget_object_bin(object, objectname),
      "csv" = httpget_object_csv(object, objectname),
      "feather" = httpget_object_feather(object, objectname),
      "arrowipc" = httpget_object_arrowipc(object, objectname),
      "parquet" = httpget_object_parquet(object, objectname),
      "spss" = httpget_object_spss(object, objectname),
      "sas" = httpget_object_sas(object, objectname),
      "stata" = httpget_object_stata(object, objectname),
      "file" = httpget_object_file(object),
      "json" = httpget_object_json(object),
      "ndjson" = httpget_object_ndjson(object),
      "rda" = httpget_object_rda(object, objectname),
      "rds" = httpget_object_rds(object, objectname),
      "pb" = httpget_object_pb(object, objectname),
      "tab" = httpget_object_tab(object, objectname),
      "png" = httpget_object_png(object),
      "pdf" = httpget_object_pdf(object, objectname),
      "svg" = httpget_object_svg(object, objectname),
      "svglite" = httpget_object_svglite(object, objectname),
      res$notfound(message=paste("Invalid output format for objects:", reqformat))
    )
  }

  httpget_object_bin <- function(object, objectname){
    mytmp <- tempfile();
    do.call("writeBin", c(req$get(), list(object=object, con=mytmp)));
    res$setbody(file=mytmp);
    res$setheader("Content-Type", "application/octet-stream");
    res$setheader("Content-disposition", paste("attachment;filename=", objectname, ".bin", sep=""));
    res$finish();
  }

  httpget_object_csv <- function(object, objectname){
    mytmp <- tempfile();

    #RFC4180 mandates CRLF, see ?write.table
    csv_eol <- ifelse(grepl("mingw", R.Version()$platform), "\n", "\r\n")
    do.call(function(row.names=FALSE, eol=csv_eol, na="", ...){
      write.csv(x=object, file=mytmp, row.names=as.logical(row.names), eol=eol, na=na, ...);
    }, req$get());
    res$setbody(file=mytmp);
    res$setheader("Content-Type", "text/csv; charset=utf-8");
    res$setheader("Content-disposition", paste("attachment;filename=", objectname, ".csv", sep=""));
    res$finish();
  }

  httpget_object_feather <- function(object, objectname){
    mytmp <- tempfile();
    do.call(arrow::write_feather, c(list(x = object, sink = mytmp), req$get()));
    res$setbody(file = mytmp)
    res$setheader("Content-Type", "application/feather")
    res$setheader("Content-disposition", paste("attachment;filename=", objectname, ".feather", sep=""));
    res$finish();
  }

  httpget_object_arrowipc <- function(object, objectname){
    mytmp <- tempfile();
    do.call(arrow::write_ipc_stream, c(list(x = object, sink = mytmp), req$get()));
    res$setbody(file = mytmp)
    res$setheader("Content-Type", "application/arrowipc")
    res$setheader("Content-disposition", paste("attachment;filename=", objectname, ".arrow", sep=""));
    res$finish();
  }

  httpget_object_parquet <- function(object, objectname){
    mytmp <- tempfile();
    do.call(arrow::write_parquet, c(list(x = object, sink = mytmp), req$get()));
    res$setbody(file = mytmp)
    res$setheader("Content-Type", " application/parquet")
    res$setheader("Content-disposition", paste("attachment;filename=", objectname, ".parquet", sep=""));
    res$finish();
  }

  httpget_object_spss <- function(object, objectname){
    mytmp <- tempfile()
    do.call(haven::write_sav, c(list(data = object, path = mytmp), req$get()))
    res$setbody(file = mytmp)
    res$setheader("Content-Type", "application/spss-sav")
    res$setheader("Content-disposition", paste("attachment;filename=", objectname, ".sav", sep=""))
    res$finish()
  }

  httpget_object_sas <- function(object, objectname){
    mytmp <- tempfile()
    do.call(haven::write_sas, c(list(data = object, path = mytmp), req$get()))
    res$setbody(file = mytmp)
    res$setheader("Content-Type", "application/sas7bdat")
    res$setheader("Content-disposition", paste("attachment;filename=", objectname, ".sas7bdat", sep=""))
    res$finish()
  }

  httpget_object_stata <- function(object, objectname){
    mytmp <- tempfile()
    do.call(haven::write_dta, c(list(data = object, path = mytmp), req$get()))
    res$setbody(file = mytmp)
    res$setheader("Content-Type", "application/stata-dta")
    res$setheader("Content-disposition", paste("attachment;filename=", objectname, ".dta", sep=""))
    res$finish()
  }

  httpget_object_tab <- function(object, objectname){
    mytmp <- tempfile();

    #To be consistent with csv output
    csv_eol <- ifelse(grepl("mingw", R.Version()$platform), "\n", "\r\n")
    do.call(function(row.names=FALSE, eol=csv_eol, na="", ...){
      write.table(x=object, file=mytmp, row.names=as.logical(row.names), eol=eol, na=na, ...);
    }, req$get());
    res$setbody(file=mytmp);
    res$setheader("Content-Type", 'text/plain; charset=utf-8');
    res$setheader("Content-disposition", paste("attachment;filename=", objectname, ".tab", sep=""));
    res$finish();
  }

  httpget_object_file <- function(object){
    #this assumes "object" is actually a path to a file
    res$sendfile(object);
  }

  #note: switch to our own json encoder later.
  #this encoder has padding argument.
  #it also replaces /encode
  #and also converts arguments to numeric where needed.

  httpget_object_json <- function(object){
    jsonstring <- do.call(function(pretty=TRUE, ...){
      toJSON(x=object, pretty=pretty, ...);
    }, req$get());
    res$setbody(jsonstring);
    res$setheader("Content-Type", "application/json");
    res$finish();
  }

  httpget_object_ndjson <- function(object){
    buf <- rawConnection(raw(0), "r+")
    on.exit(close(buf))
    do.call(function(verbose = NULL, con = NULL, ...){
      jsonlite::stream_out(x = object, con = buf, verbose = FALSE, ...)
    }, req$get());
    res$setbody(rawToChar(rawConnectionValue(buf)))
    res$setheader("Content-Type", "application/x-ndjson; charset=utf-8")
    res$finish()
  }

  httpget_object_print <- function(object){
    outtext <- utils::capture.output(do.call(printwithmax, c(req$get(), list(x=object))));
    res$sendtext(outtext);
  }

  httpget_object_pander <- function(object){
    outtext <- utils::capture.output(do.call(pander::pander, c(req$get(), list(x=object))));
    res$sendtext(outtext);
  }

  httpget_object_text <- function(object){
    object <- paste(unlist(object), collapse="\n")
    mytmp <- tempfile(fileext=".txt")
    do.call("cat", c(req$get(), list(x=object, file=mytmp)));
    res$sendfile(mytmp);
  }

  httpget_object_ascii <- function(object){
    outtext <- deparse(object);
    res$sendtext(outtext);
  }

  httpget_object_rda <- function(object, objectname){
    mytmp <- tempfile();
    myenv <- new.env();
    assign(objectname, object, myenv);
    do.call("save", c(req$get(), list(object=objectname, file=mytmp, envir=myenv)));
    res$setbody(file=mytmp);
    res$setheader("Content-Type", "application/octet-stream");
    res$setheader("Content-disposition", paste("attachment;filename=", objectname, ".RData", sep=""));
    res$finish();
  }

  httpget_object_rds <- function(object, objectname){
    mytmp <- tempfile();
    con <- file(mytmp, open = "wb")
    on.exit(close(con))
    do.call("saveRDS", c(req$get(), list(object=object, file=con)));
    res$setbody(file=mytmp);
    res$setheader("Content-Type", "application/r-rds");
    res$setheader("Content-disposition", paste("attachment;filename=", objectname, ".rds", sep=""));
    res$finish();
  }

  httpget_object_pb <- function(object, objectname){
    mytmp <- tempfile();
    do.call(protolite::serialize_pb, list(object=object, connection=mytmp));
    res$setbody(file=mytmp);
    res$setheader("Content-Type", "application/x-protobuf");
    res$setheader("Content-disposition", paste("attachment;filename=", objectname, ".pb", sep=""));
    res$finish();
  }

  httpget_object_png <- function(object){
    mytmp <- tempfile();
    args <- req$get()
    if(!is_mac())
      args$type = 'cairo'
    do.call(function(width=800, height=600, pointsize=12, ...){
      png(file=mytmp, width=as.numeric(width), height=as.numeric(height), pointsize=as.numeric(pointsize), ...);
    }, args)
    on.exit(dev.off())
    res$setheader("Content-Type", "image/png");
    try_print_plot(object, mytmp)
  }

  httpget_object_pdf <- function(object, objectname){
    mytmp <- tempfile();
    do.call(function(width=11.69, height=8.27, pointsize=12, paper="A4r", ...){
      pdf(file=mytmp, width=as.numeric(width), height=as.numeric(height), pointsize=as.numeric(pointsize), paper=paper, ...);
    }, req$get());
    on.exit(dev.off())
    res$setheader("Content-Type", "application/pdf");
    res$setheader("Content-disposition", paste("attachment;filename=", objectname, ".pdf", sep=""));
    try_print_plot(object, mytmp)
  }

  httpget_object_svg <- function(object, objectname){
    mytmp <- tempfile();
    do.call(function(width=11.69, height=8.27, pointsize=12, ...){
      svg(file=mytmp, width=as.numeric(width), height=as.numeric(height), pointsize=as.numeric(pointsize), ...);
    }, req$get());
    on.exit(dev.off())
    res$setheader("Content-Type", "image/svg+xml");
    try_print_plot(object, mytmp)
  }

  httpget_object_svglite <- function(object, objectname){
    mytmp <- tempfile();
    do.call(function(width=11.69, height=8.27, pointsize=12, ...){
      svglite::svglite(file=mytmp, width=as.numeric(width), height=as.numeric(height), pointsize=as.numeric(pointsize), ...);
    }, req$get());
    on.exit(dev.off())
    res$setheader("Content-Type", "image/svg+xml");
    try_print_plot(object, mytmp)
  }

  #export only main
  main
});
