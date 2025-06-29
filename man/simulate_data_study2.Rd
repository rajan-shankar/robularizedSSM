% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/simulate_data.R
\name{simulate_data_study2}
\alias{simulate_data_study2}
\title{Simulate DCRW Data for Study 2: Increasing Contamination and Varying Outlier Distance}
\usage{
simulate_data_study2(
  samples = 100,
  n = 200,
  max_contamination = 0.2,
  distances = c(1, 3, 5, 7, 9),
  n_oos = 20,
  phi_coef = 0.8,
  sigma2_w_lon = 0.1,
  sigma2_w_lat = 0.1,
  sigma2_v_lon = 0.4,
  sigma2_v_lat = 0.4,
  initial_state = c(0, 0, 0, 0),
  seed = NA
)
}
\arguments{
\item{samples}{Number of simulated data sets per contamination rate and outlier distance. Default is 100.}

\item{n}{Number of in-sample timesteps. Default is 200.}

\item{max_contamination}{Maximum proportion of contaminated (outlying) observations. Default is 0.2.}

\item{distances}{Vector of five distances for additive outliers. Must be of length 5. Default is \code{c(1, 3, 5, 7, 9)}.}

\item{n_oos}{Number of out-of-sample (future) timesteps. Default is 20.}

\item{phi_coef}{Autocorrelation parameter in the DCRW transition matrix. Default is 0.8.}

\item{sigma2_w_lon, sigma2_w_lat}{State noise variances (longitude and latitude). Default is 0.1 each.}

\item{sigma2_v_lon, sigma2_v_lat}{Observation noise variances (longitude and latitude). Default is 0.4 each.}

\item{initial_state}{Initial state vector of length 4. Default is \code{c(0, 0, 0, 0)}.}

\item{seed}{Optional random seed for reproducibility. Default is \code{NA}. Use \code{seed = 205} to reproduce the same data as in the paper.}
}
\value{
A tibble containing the simulated data sets. Each row corresponds to a simulated data set and includes
fields for contamination rate, distance, outliers, clean data, noisy observations, and out-of-sample values.
}
\description{
Simulates datasets under a first-difference correlated random walk (DCRW) state-space model
for Study 2 in the paper. This study examines the impact of increasing contamination levels
and varying outlier distances on model performance. All arguments have default values matching
the simulation setup used in the paper.
}
\details{
An equally-spaced sequence of five increasing contamination rates from 0 up to \code{max_contamination} will be constructed internally.
For example, if \code{max_contamination = 0.2}, the contamination rates will be \code{c(0, 0.05, 0.1, 0.15, 0.2)}.
The returned tibble will have \eqn{9\times} \code{samples} rows, with each row corresponding to a unique combination of contamination rate and distance.
The levels of contamination rate and distance are not 'crossed'; rather, the middle contamination rate (e.g. 0.1) will be crossed with all distances, and the middle distance (e.g. 5) will be crossed with all contamination rates.
This will result in \eqn{5\times 1 + 5\times 1 = 10} data sets. However, the middle contamination rate and middle distance will be double-counted, so the total number of unique data sets per sample will be \eqn{10 - 1 = 9}.
}
\examples{
data_study2 = simulate_data_study2(samples = 5, seed = 456)

}
\seealso{
\code{\link{simulate_data_study1}}
}
