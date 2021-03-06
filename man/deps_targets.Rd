% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/dependencies.R
\name{deps_targets}
\alias{deps_targets}
\title{List the dependencies of one or more targets}
\usage{
deps_targets(targets, config = read_drake_config(), reverse = FALSE)
}
\arguments{
\item{targets}{a character vector of target names}

\item{config}{an output list from \code{\link[=drake_config]{drake_config()}}}

\item{reverse}{logical, whether to compute reverse dependencies
(targets immediately downstream) instead of ordinary dependencies.}
}
\value{
A character vector, names of dependencies.
Files wrapped in escaped double quotes.
The other names listed are functions or generic R objects.
}
\description{
Unlike \code{\link[=deps_code]{deps_code()}}, \code{deps_targets()} just lists
the jobs that lie upstream of the \code{targets} on the workflow
graph, and \code{file_out()} files are not included.
}
\examples{
\dontrun{
test_with_dir("Quarantine side effects.", {
load_mtcars_example() # Get the code with drake_example("mtcars").
# Dependencies of the knitr-generated targets like 'report.md'
# include targets/imports referenced with `readd()` or `loadd()`.
config <- drake_config(my_plan)
deps_targets(file_store("report.md"), config = config)
deps_targets("regression1_small", config = config)
deps_targets(c("small", "large"), config = config, reverse = TRUE)
})
}
}
