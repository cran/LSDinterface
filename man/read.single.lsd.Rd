\name{read.single.lsd}
\alias{read.single.lsd}
\title{
Read LSD variables (time series) from a LSD results file (a single instance of each variable only)
}
\description{
This function reads the data series associated to one instance of each selected variable from a LSD results file (.res). Just a single instance (time series of a single LSD object) is read at each call.
}
\usage{
read.single.lsd(file, col.names = NULL, nrows = -1, skip = 0,
                check.names = TRUE, instance = 1)
}
\arguments{
  \item{file}{
the name of the LSD results file which the data are to be read from. If it does not contain an absolute path, the file name is relative to the current working directory, getwd(). This can be a compressed file (see file) and must include the appropriated extension (usually .res or .res.gz).
}
  \item{col.names}{
a vector of optional names for the variables. The default is to read all (unique) variables.
}
  \item{nrows}{
integer: the maximum number of time steps (rows) to read in. Negative and other invalid values are ignored. The default is to read all rows.
}
  \item{skip}{
integer: the number of time steps (rows) of the results file to skip before beginning to read data. The default is to read from the first time step (t = 1).
}
  \item{check.names}{
logical. If TRUE then the names of the variables are checked to ensure that they are syntactically valid variable names. If necessary they are adjusted (by make.names) so that they are, and also to ensure that there are no duplicates.
}
  \item{instance}{
integer: the instance of the variable to be read, for variables that exist in more than one object. This number is based on the position (column) of the variable in the results file. The default is to read the first instance.
}
}
\value{
Returns a matrix containing the selected variables' time series contained in the results file.
}
\author{Marcelo C. Pereira}
\note{
This function is useful to extract time series for variables that are single instanced, like summary statistics.
For multi-instanced variables, see \code{\link{read.multi.lsd}}. For extracting data from multiple similar files (like sensitivity analysis results), see \code{\link{read.list.lsd}} (multi-instanced variables) and \code{\link{read.3d.lsd}} (single-instanced variables).
}

\seealso{
\code{\link{read.multi.lsd}},
\code{\link{read.list.lsd}},
\code{\link{read.3d.lsd}},
\code{\link{read.4d.lsd}},
\code{\link{read.raw.lsd}}
}
\examples{
# Get the examples directory
path <- system.file( "extdata", package = "LSDinterface" )

# Load a sample .res file into a simple matrix (first instances only)
macroVar <- read.single.lsd( paste0( path, "/", "Sim1_1.res" ) )

# See matrix in the data viewer (require package 'utils')
\donttest{View( macroVar )}

# read second instance of a set of variables named '_A1p' and '_growth1'
ag2Table <- read.single.lsd( paste0( path, "/", "Sim1_2.res" ),
                             c( "_A1p", "_growth1" ), instance = 2 )
\donttest{View( ag2Table )}

# reads first instance of all variables, skipping the initial 20 time steps
# and keeping up to 50 time steps (from t = 21 up to t = 70)
var21_70 <- read.single.lsd( paste0( path, "/", "Sim1_1.res" ),
                             skip = 20, nrows = 50 )
\donttest{View( var21_70 )}
}
\keyword{ interface }
\keyword{ file }
\keyword{ datasets }
\keyword{ database }
