#*******************************************************************************
#
# ------------------ Tools for interfacing with LSD results ------------------
#
#   Written by Marcelo C. Pereira, University of Campinas
#
#   Copyright Marcelo C. Pereira
#   Distributed under the GNU General Public License
#
#*******************************************************************************

# ==== Read effective dimensions of results file (rows x columns) ====

info.dimensions.lsd <- function( file ) {

  # read from disk
  dataSet <- read.raw.lsd( file )

  # caclulate statistics
  tSteps <- nrow( dataSet )
  nVars <- ncol( dataSet )
  varNames <- name.clean.lsd( colnames( dataSet ) )

  info <- list( tSteps = tSteps, nVars = nVars, varNames = varNames )
  class( info ) <- "info.dimensions.lsd"

  return( info )
}


# ==== Read variable names in results file (no duplicates) ====

info.names.lsd <- function( file ) {

  if( is.null( file ) || ! is.character( file ) || file == "" )
    stop( "Invalid results file name (file)" )

  # read header line (labels) from disk
  header <- scan( file, what = character( ), sep = "\t", quote = NULL,
                  nlines = 1, quiet = TRUE )
  header <- header[ 1 : ( length( header ) - 1 ) ]  # remove last tab

  if( length( header ) == 0 )            # invalid file?
    stop( paste0( "File '", file, "' is invalid!") )

  # extract labels and remove duplicates
  lsd.name <- unique( name.var.lsd( make.names( header ) ) )

  return( lsd.name )
}


# ==== Read initial conditions in results file ====

info.init.lsd <- function( file ) {

  # read from disk
  dataSet <- read.raw.lsd( file, nrows = 0 )

  return( dataSet )
}


# ==== Read  info from a results file ====

info.details.lsd <- function( file ) {

  # read from disk
  dataSet <- read.raw.lsd( file, nrows = 0 )

  # get the most "deep" object position
  maxPosit <- 1
  for( i in 1 : length( colnames( dataSet ) ) ) {
    # break position into components
    parseName <- unlist( strsplit( colnames( dataSet )[ i ],"\\." ) )
    parsePosit <- unlist( strsplit( parseName[ 2 ], "_" ) )
    maxPosit <- max( maxPosit, length( parsePosit ) )
  }

  # get variable names
  fullNames <- colnames( dataSet )
  lsdNames <- name.var.lsd( fullNames )

  # organize dataset with variable names in rows
  info <- data.frame( stringsAsFactors = FALSE )
  for( i in 1 : length( colnames( dataSet ) ) ) {
    # break position and time into components
    parseName <- unlist( strsplit( fullNames[ i ],"\\." ) )
    parsePosit <- unlist( strsplit( parseName[ 2 ], "_" ) )
    parseTime <- unlist( strsplit( parseName[ 3 ], "_" ) )
    # form new row
    newLine <- data.frame( Full_name = fullNames[ i ],
                           R_name = parseName[ 1 ],
                           LSD_name = lsdNames[ i ],
                           Init_value = dataSet[ 1, i ],
                           Init_time = strtoi( parseTime [ 1 ] ),
                           End_time = strtoi( parseTime [ 2 ] ),
                           stringsAsFactors = FALSE )
    # add positions > 1
    iniCol <- ncol( newLine )
    for( j in 1 : maxPosit ) {
      if( j > length( parsePosit ) )
        posit <- NA
      else
        posit <- strtoi( parsePosit[ j ] )

      newLine <- cbind( newLine, posit )
      colnames( newLine )[ iniCol + j ] <- paste0( "Posit_", j )
    }

    info <- rbind( info, newLine )
  }

  class( info ) <- append( class( info ), "info.details.lsd" )

  return( info )
}


# ==== Compute statistics from multiple runs ====

info.stats.lsd <- function( array, rows = 1, cols = 2, median = FALSE,
                            ci = c( "none", "mean", "median", "auto" ),
                            ci.conf = 0.95, ci.boot = NULL, boot.R = 999,
                            seed = 1, na.rm = TRUE, inf.rm = TRUE ) {

  if( ! is.array( array ) || ! is.numeric( array ) )
    stop( "Invalid array for statistics (array)" )

  if( is.null( rows ) || ! is.finite( rows ) || round( rows ) < 1 ||
      round( rows ) > length( dim( array ) ) )
    stop( "Invalid rows dimension (rows)" )

  if( is.null( cols ) || ! is.finite( cols ) || round( cols ) < 1 ||
      round( cols ) > length( dim( array ) ) || round( rows ) == round( cols ) )
    stop( "Invalid columns dimension (cols)" )

  if( is.null( median ) || ! is.logical( median ) )
    stop( "Invalid median switch (median)" )

  if( is.null( ci.conf ) || ! is.finite( ci.conf ) ||
      ci.conf <= 0 || ci.conf >= 1 )
    stop( "Invalid confidence level (ci.conf)" )

  if( ! is.null( ci.boot ) && ci.boot != "" &&
      ! ci.boot %in% c( "basic", "perc", "bca" ) ) {
    stop( "Invalid bootstrap confidence interval type (ci.boot)" )
  }

  if( is.null( boot.R ) || ! is.finite( boot.R ) || round( boot.R ) < 1 )
    stop( "Invalid bootstrap repetitions (boot.R)" )

  if( ! is.null( seed ) && ! is.finite( seed ) )
    stop( "Invalid random seed (seed)" )

  if( is.null( na.rm ) || ! is.logical( na.rm ) )
    stop( "Invalid NA removal switch (na.rm)" )

  if( is.null( inf.rm ) || ! is.logical( inf.rm ) )
    stop( "Invalid non-finite removal switch (inf.rm)" )

  rows   <- round( rows )
  cols   <- round( cols )
  boot.R <- round( boot.R )
  ci     <- match.arg( ci )

  # Get dimension data
  dimArray <- dim( array )
  nDimArray <- length( dimArray )
  dimNames <- dimnames( array )
  if( nDimArray < 3 || nDimArray > 4 )
    stop( "Invalid array dimensions for statistics (array)" )
  if( rows == cols || rows < 1 || rows > nDimArray ||
      cols < 1 || cols > nDimArray )
    stop( "Invalid dimension size(s) for statistics (array)" )

  if( rows > cols ) {                    # has to transpose at the end?
    dimH <- rows                        # make sure rows dim < cols dim
    rows <- cols
    cols <- dimH
    transp <- TRUE
  }
  else
    transp <- FALSE

  # Allocate 2D arrays
  avg <- sDev <- M <- m <- n <-
    array( as.numeric( NA ), dim = c( dimArray[ rows ], dimArray[ cols ] ),
           dimnames = list( dimNames[[ rows ]], dimNames[[ cols ]] ) )

  if( median )
    med <- mad <- avg

  if( ci == "auto" ) {
    if( median )
      ci <- "median"
    else
      ci <- "mean"
  }

  if( ! is.null( ci.boot ) && ci.boot == "" )
    ci.boot <- NULL

  if( ci != "none" )
    ci.lo <- ci.hi <- avg

  # prepare mask for dimension selection
  baseMask <- list( )
  for( k in 1 : nDimArray ) {
    if( rows == k || cols == k )        # dimensions to show
      baseMask[[ k ]] <- rep( FALSE, dimArray[ k ] )
    else
      baseMask[[ k ]] <- rep( TRUE, dimArray[ k ] )
  }

  set.seed( seed )       # reset PRNG seed to ensure reproducibility

  # Compute averages, std. deviation etc. and store in 2D arrays
  for( j in 1 : dimArray[ cols ] ) {
    for( i in 1 : dimArray[ rows ] ) {

      # Get the appropriate vector (3D array) or matrix (4D) for analysis
      first <- TRUE
      mask <- baseMask
      for( k in 1 : nDimArray )       # adjust the mask for (i,j)
        if( rows == k || cols == k ) {
          if( first ) {
            mask[[ k ]][ i ] <- TRUE
            first <- FALSE
          }
          else
            mask[[ k ]][ j ] <- TRUE
        }
      if( nDimArray == 3 )            # handle 3D arrays
        elem <- array[ mask[[ 1 ]], mask[[ 2 ]], mask[[ 3 ]] ]
      else                            # handle 4D arrays
        elem <- array[ mask[[ 1 ]], mask[[ 2 ]], mask[[ 3 ]], mask[[ 4 ]] ]

      # calculate the statistics
      if( na.rm )
        elem <- elem[ ! is.na( elem ) ]

      if( inf.rm )
        elem <- elem[ is.finite( elem ) ]

      n[ i, j ] <- num <- length( elem[ is.finite( elem ) ] )
      avg[ i, j ] <- mean( elem )
      sDev[ i, j ] <- stats::sd( elem )

      if( num > 0 ) {
        M[ i, j ] <- max( elem )
        m[ i, j ] <- min( elem )
      }
      else {                           # avoid Inf/-Inf when all is NA
        M[ i, j ] <- NA
        m[ i, j ] <- NA
      }

      if( median ) {
        med[ i, j ] <- stats::median( elem )
        mad[ i, j ] <- stats::mad( elem )
      }

      if( ci != "none" ) {
        ci.lo[ i, j ] <- ci.hi[ i, j ] <- NA

        if( num > 1 ) {
          if( is.null( ci.boot ) ) {
            if( ci == "mean" ) {
              d = abs( stats::qt( ( 1 - ci.conf ) / 2, num - 1 ) ) * sDev[ i, j ] /
                  sqrt( num )

              if( is.finite( avg[ i, j ] ) && ! is.null( d ) && is.finite( d ) ) {
                ci.lo[ i, j ] = avg[ i, j ] - d
                ci.hi[ i, j ] = avg[ i, j ] + d
              }
            } else {
              c <- suppressWarnings( stats::wilcox.test( elem, conf.int = TRUE,
                                                         conf.level = ci.conf,
                                                         digits.rank = 7 )$conf.int )

              if( is.finite( c[ 1 ] ) )
                ci.lo[ i, j ] <- c[ 1 ]

              if( is.finite( c[ 2 ] ) )
                ci.hi[ i, j ] <- c[ 2 ]
            }
          } else {
            if( ci == "mean" )
              f <- function( data, sel ) mean( data[ sel ] )
            else
              f <- function( data, sel ) stats::median( data[ sel ] )

            b <- c <- NULL
            try( invisible( utils::capture.output(
                    b <- boot::boot( elem, statistic = f, R = boot.R ) ) ),
                 silent = TRUE )

            if( ! is.null( b ) ) {
              try( invisible( utils::capture.output(
                      c <- boot::boot.ci( b, conf = ci.conf, type = ci.boot ) ) ),
                   silent = TRUE )
            }

            if( ci.boot == "perc" )
              ci.boot = "percent"       # adjust name difference in data

            if( ! is.null( c[[ ci.boot ]] ) && is.finite( c[[ ci.boot ]][ 4 ] ) )
              ci.lo[ i, j ] <- c[[ ci.boot ]][ 4 ]

            if( ! is.null( c[[ ci.boot ]] ) && is.finite( c[[ ci.boot ]][ 5 ] ) )
              ci.hi[ i, j ] <- c[[ ci.boot ]][ 5 ]
          }
        }
      }
    }
  }

  res <- list( avg = avg, sd = sDev, max = M, min = m, n = n )

  if( median ) {
    res[[ "med" ]] <- med
    res[[ "mad" ]] <- mad
  }

  if( ci != "none" ) {
    res[[ "ci.lo" ]] <- ci.lo
    res[[ "ci.hi" ]] <- ci.hi
  }

  if( transp )
    for( i in 1 : length( res ) )
      res[[ i ]] = t( res[[ i ]] )

  class( res ) <- "info.stats.lsd"

  return( res )
}


# ==== Compute distance measure between series and a set of references ====

info.distance.lsd <- function( array, references, instance = 1,
                               distance = "euclidean",
                               std.dist = FALSE, std.val = FALSE,
                               rank = FALSE, weights = 1, seed = 1, ... ) {

  if( ! is.array( array ) || ! is.numeric( array ) )
    stop( "Invalid array for statistics (array)" )

  if( ( ! is.matrix( references ) && ! is.data.frame( references ) ) ||
      ! is.numeric( references ) || is.null( colnames( references ) ) ||
      length( colnames( references ) ) == 0 )
    stop( "Invalid references matrix for statistics (references)" )

  if( is.null( instance ) || ! is.finite( instance ) || round( instance ) < 1 )
    stop( "Invalid variable instance (instance)" )

  if( is.null( std.dist ) || ! is.logical( std.dist ) )
    stop( "Invalid distance standardization switch (std.dist)" )

  if( is.null( std.val ) || ! is.logical( std.val ) )
    stop( "Invalid values standardization switch (std.val)" )

  if( is.null( rank ) || ! is.logical( rank ) )
    stop( "Invalid Monte Carlo ranking switch (rank)" )

  if( is.null( weights ) || ! is.vector( weights ) || length( weights ) == 0 ||
      ! all( is.finite( weights ) ) )
      stop( "Invalid weights vector (weights)" )

  if( ! is.null( seed ) && ! is.finite( seed ) )
    stop( "Invalid random seed (seed)" )

  references <- as.matrix( references )
  instance   <- round( instance )
  distance   <- match.arg( distance, c( "euclidean", "manhattan", "minkowski",
                                        "infnorm", "ccor", "sts", "dtw", "keogh.lb",
                                        "edr", "erp", "lcss", "fourier", "tquest",
                                        "dissim", "acf", "pacf", "ar.lpc.ceps",
                                        "ar.mah", "ar.mah.statistic", "ar.mah.pvalue",
                                        "ar.pic", "cdm", "cid", "cor", "cort",
                                        "int.per", "per", "mindist.sax", "ncd",
                                        "pred", "spec.glk", "spec.isd", "spec.llr",
                                        "pdc", "frechet", "tam" ) )

  nDim <- length( dim( array ) )
  if( nDim < 3 || nDim > 4 )
    stop( "Invalid array for statistics (array)" )

  vars <- colnames( references )[ match( dimnames( array )[[ 2 ]],
                                         colnames( references ) ) ]

  if( length( vars ) == 0 )
    stop( "No reference variable matches any array one  (references)" )

  if( ! is.null( names( weights ) ) ) {
    temp <- c( )
    for( var in vars ) {
      if( var %in% names( weights ) )
        temp <- append( temp, weights[ var ] )
      else
        temp <- append( temp, 0 )
    }

    if( sum( temp ) == 0 )
      stop( "Weights vector is incompatible with references matrix" )

    weights <- temp[ temp != 0 ]
    vars <- vars[ temp != 0 ]
  } else
    weights <- rep_len( weights, length( vars ) )

  nMC <- dim( array )[ nDim ]
  dist <- dist.rel <- matrix( data = NA, nrow = nMC, ncol = length( vars ) )
  rownames( dist ) <- dimnames( array )[[ nDim ]]
  colnames( dist ) <- vars

  if( rank ) {
    dist.rank <- rep.int( 0, nMC )
    names( dist.rank ) <- rownames( dist )
  }

  set.seed( seed )       # reset PRNG seed to ensure reproducibility

  for( i in 1 : nMC )
    for( j in 1 : length( vars ) ) {

      if( nDim == 3 )
        data <- matrix( c( array[ , vars[ j ], i ],
                           references[ , vars[ j ] ] ),
                        ncol = 2 )
      else
        data <- matrix( c( array[ , vars[ j ], instance, i ],
                           references[ , vars[ j ] ] ),
                        ncol = 2 )

      data <- data[ stats::complete.cases( data ), ]

      if( std.val || rank ) {
        data.std <- data[ , 1 ] / data[ , 2 ]
        data.std <- data.std[ is.finite( data.std ) ]

        if( length( data.std ) > 0 )
          dist.std <- TSdist::TSDistances( data.std,
                                           rep( 1, length( data.std ) ),
                                           distance = distance, ... )
        else
          dist.std <- NA
      }

      if( std.val )
        dist[ i, j ] <- dist.std
      else
        if( nrow( data ) > 0 )
          dist[ i, j ] <- TSdist::TSDistances( data[ , 1 ], data[ , 2 ],
                                               distance = distance, ... )

      if( std.dist && nrow( data ) > 0 )
        dist[ i, j ] <- dist[ i, j ] / nrow( data )

      if( rank && ! is.na( dist.std ) ) {
        dist.rel[ i, j ] <- dist.std / length( data.std )
        dist.rank[ i ] <- dist.rank[ i ] + dist.rel[ i, j ] * weights[ j ]
      }
    }

  dist.close <- apply( apply( dist, 2, rank, ties.method = "random" ), 2,
                       function( x ) names( x )[ match( x, 1 : length( x ) ) ] )
  rownames( dist.close ) <- 1 : nMC

  if( rank )
    info <- list( dist = dist, close = dist.close, rank = sort( dist.rank ) )
  else
    info <- list( dist = dist, close = dist.close )

  class( info ) <- "info.distance.lsd"

  return( info )
}
