#' @export
print.robularized_SSM_list = function(x, ...) {
  model_list = x
  cat("Robularized SSM List with ", length(model_list), "models\n",
      "Use best_BIC_model() or outlier_target_model() to extract a single model.\n",
      "Use autoplot() to visualize the models.\n",
      "Use get_attribute() to extract attributes from the models.\n")
}

#' @export
print.robularized_SSM = function(x, ...) {
  model = x
  cat("Robularized SSM Model\n",
      "Lambda: ", model$lambda, "\n",
      "Outliers Detected: ", round(model$prop_outlying*100, 2), "%\n",
      "BIC: ", round(model$BIC, 3), "\n",
      "Log-Likelihood: ", round(model$loglik, 3), "\n",
      "RSS: ", round(model$RSS, 3), "\n",
      "IPOD Iterations: ", model$iterations, "\n",
      "Use $ to see more attributes.\n",)
}

#' @export
print.classical_SSM = function(x, ...) {
  model = x
  cat("Classical SSM Model\n",
      "Log-Likelihood: ", round(model$value, 3), "\n",
      "optim() Iterations: ", model$iterations, "\n",
      "Use $ to see more attributes.\n",)
}

#' @export
print.oracle_SSM = function(x, ...) {
  model = x
  cat("Oracle SSM Model\n",
      "Log-Likelihood: ", round(model$value, 3), "\n",
      "optim() Iterations: ", model$iterations, "\n",
      "Outlier Locations: ", model$outlier_locs, "n",
      "Use $ to see more attributes.\n",)
}

#' @export
print.huber_robust_SSM = function(x, ...) {
  model = x
  cat("Huber SSM Model\n",
      "Log-Likelihood: ", round(model$value, 3), "\n",
      "optim() Iterations: ", model$iterations, "\n",
      "Use $ to see more attributes.\n",)
}

#' @export
print.trimmed_robust_SSM = function(x, ...) {
  model = x
  cat("Trimmed SSM Model\n",
      "Log-Likelihood: ", round(model$value, 3), "\n",
      "optim() Iterations: ", model$iterations, "\n",
      "Alpha: ", model$alpha, "\n",
      "Use $ to see more attributes.\n",)
}

#' Autoplot for Robularized State Space Model List
#'
#' Generates a diagnostic plot for a list of robust state space models fit across a sequence of \eqn{\lambda} values. The plot displays the specified model attribute (e.g., BIC, proportion outlying, log-likelihood) against \eqn{\lambda}, with a vertical dashed line indicating the model with the lowest BIC among those with fewer than 50\% outliers.
#'
#' @param object An object of class \code{robularized_SSM_list} as returned by \code{\link{robularized_SSM}} when multiple \eqn{\lambda} values are used.
#' @param attribute A character string indicating which model attribute to plot. Options include \code{lambda}, \code{prop_outlying}, \code{BIC}, \code{loglik}, \code{RSS}, \code{iterations}, \code{value}, and \code{counts}. Defaults to \code{BIC}.
#' @param ... Other arguments passed to specific methods. Not used in this method.
#'
#' @return A \code{ggplot} object showing the trajectory of the specified attribute across \eqn{\lambda}.
#'
#' @details
#' The red dashed vertical line indicates the model with the lowest BIC among models with less than 50\% outlying time points, as a heuristic for robust model selection.
#'
#' @seealso \code{\link{robularized_SSM}}, \code{\link{get_attribute}}
#'
#' @importFrom ggplot2 ggplot aes geom_line geom_vline labs theme_bw autoplot
#' @importFrom dplyr filter slice
#' @importFrom magrittr %>%
#' @importFrom latex2exp TeX
#'
#' @export
#' @method autoplot robularized_SSM_list
autoplot.robularized_SSM_list = function(object, attribute = "BIC", ...) {

  model_list = object

  vector_attributes = c(
    "lambda",
    "prop_outlying",
    "BIC",
    "loglik",
    "RSS",
    "iterations",
    "value",
    "counts"
  )

  if (!(attribute %in% vector_attributes)) {
    stop("This attribute does not exist or is not numeric.")
  }

  data = data.frame(
    lambda = get_attribute(model_list, "lambda"),
    BIC = get_attribute(model_list, "BIC"),
    prop_outlying = get_attribute(model_list, "prop_outlying"),
    attribute = get_attribute(model_list, attribute))

  data %>%
    ggplot() +
    aes(x = lambda, y = attribute) +
    geom_line(linewidth = 1) +
    geom_vline(data = . %>%
                 dplyr::filter(prop_outlying < 0.5) %>%
                 dplyr::slice(which.min(BIC)),
               aes(xintercept = lambda),
               colour = "red", linetype = "dashed") +
    labs(x = latex2exp::TeX("$\\lambda$"),
         y = attribute) +
    theme_bw(base_size = 16)
}

