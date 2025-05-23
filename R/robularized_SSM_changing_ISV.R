#' A Cat Function
#'
#' This function allows you to express your love of cats.
#'
#' @importFrom magrittr %>%
#' @importFrom foreach %dopar%
#' @param love Do you love cats? Defaults to TRUE.
#' @details
#' Additional details...
#' @returns description
#' @export
robularized_SSM_isv = function(
    y,
    init_par,
    build,
    num_lambdas = 10,
    lowest_lambda = 2,
    highest_lambda = NA,
    num_lambdas_crowding = 0,
    cores = 1,
    B = 20,
    lower = NA,
    upper = NA
    ) {

  # Classical fit by using large lambda
  classical = run_IPOD_isv(y = y,
                       lambda = 100,
                       init_par = init_par,
                       build = build,
                       B = B,
                       lower = lower,
                       upper = upper)

  # Highest lambda is the supremum norm of mahalanobis residuals of classical fit
  if (is.na(highest_lambda)) {
    highest_lambda = max(fn_filter_isv(classical$par,
                                   y,
                                   classical$gamma,
                                   build)$mahalanobis_residuals
                         )
  }

  # lambda grid
  lambdas = seq(lowest_lambda,
                highest_lambda,
                length.out = num_lambdas)

  # Fit models across the grid
  model_list = lambda_grid_isv(y = y,
                           lambdas = lambdas,
                           #init_par = classical$par,
                           init_par = init_par,
                           build = build,
                           cores = cores,
                           lower = lower,
                           upper = upper,
                           B = B)

  if (num_lambdas_crowding != 0) {
    BIC = get_attribute(model_list, "BIC")
    prop_outlying = get_attribute(model_list, "prop_outlying")

    # Take BIC diffs and set any that are left of prop_outlying >= 0.5 to 0
    bad_up_to_and_including = sum(prop_outlying >= 0.5)
    diffs = abs(diff(BIC))
    if (bad_up_to_and_including >= 2) {
      diffs[1:(bad_up_to_and_including - 1)] = 0
    }

    # Find largest BIC diff
    diff_argmax = which.max(diffs)

    # Crowding lambda grid
    crowding_lambdas = seq(lambdas[diff_argmax],
                           lambdas[diff_argmax + 1],
                           length.out = num_lambdas_crowding + 2)[2:(num_lambdas_crowding+1)]

    # Fit models across the crowding grid
    model_crowding_list = lambda_grid_isv(y = y,
                                      lambdas = crowding_lambdas,
                                      #init_par = classical$par,
                                      init_par = init_par,
                                      build = build,
                                      cores = cores,
                                      lower = lower,
                                      upper = upper,
                                      B = B)

    # Append to model_crowding_list to model_list at appropriate location
    model_list = append(model_list, model_crowding_list, after = diff_argmax)

    # Attach class
    class(model_list) = "robularized_SSM_list"
  }

  return(model_list)
}

lambda_grid_isv = function(
    y,
    lambdas,
    init_par,
    build,
    cores,
    lower,
    upper,
    B
    ) {

  cl = parallel::makeCluster(cores)
  doParallel::registerDoParallel(cl,
                                 export = list(fn_filter_isv = fn_filter_isv,
                                               run_IPOD_isv = run_IPOD_isv))
  model_list = foreach::foreach(
    i = 1:length(lambdas)) %dopar% {
                  IPOD_output = run_IPOD_isv(y,
                                         lambdas[i],
                                         init_par,
                                         build,
                                         B,
                                         lower,
                                         upper)
                  filter_output = fn_filter_isv(IPOD_output$par,
                                            y,
                                            IPOD_output$gamma,
                                            build)

                  model = c(IPOD_output, filter_output)
                  class(model) = "robularized_SSM"
                  return(model)
                  }
  parallel::stopCluster(cl)

  class(model_list) = "robularized_SSM_list"
  return(model_list)
}

run_IPOD_isv = function(
    y,
    lambda,
    init_par,
    build,
    B,
    lower,
    upper
    ) {

  if (is.na(lower)[1]) {lower = rep(-Inf, length(init_par))}
  if (is.na(upper)[1]) {upper = rep(Inf, length(init_par))}

  build = function(par, isv) {

    Phi = diag(4)
    delta = 0.1
    Phi[1,3] = delta
    Phi[2,4] = delta
    A = diag(4)[1:2,]

    specify_SSM(Phi,
                par[1]*diag(4),
                A,
                par[2]*diag(2),
                rep(0,4),
                isv*diag(4))
  }
  isvs = c(0.33, 1, 3, 9)^2
  BICs_isv = numeric(length(isvs))
  prop_outlying_isv = numeric(length(isvs))
  par1_isv = numeric(length(isvs))
  par2_isv = numeric(length(isvs))
  for (isv in isvs) {

    n = ncol(y)
    dim_obs = nrow(y)
    par = init_par
    gamma = matrix(0, nrow = dim_obs, ncol = n)
    r = NA
    theta_old = par

    for (j in 1:B) {
      if (j != 1) {theta_old = res$par}
      res = stats::optim(
        par = par,
        fn = fn_filter_isv,
        y = y,
        gamma = gamma,
        build = function(x) build(x, isv = isv),
        return_obj = TRUE,
        method = "L-BFGS-B",
        lower = lower,
        upper = upper
      )

      if ((sum(res$par == lower) + sum(res$par == upper)) == 0) {
        par = res$par
      } else {
        par = init_par
      }

      filter_output = fn_filter_isv(res$par, y, gamma, function(x) build(x, isv = isv))
      r = y - filter_output$predicted_observations
      gamma_old = gamma
      gamma = matrix(0, nrow = dim_obs, ncol = n)
      gamma[,filter_output$mahalanobis_residuals > lambda] = r[,filter_output$mahalanobis_residuals > lambda]
      gap = max(abs(gamma - gamma_old))
      gap_theta = max(abs(res$par - theta_old))

      nz = sum(colSums(abs(gamma_old)) != 0)
      prop_outlying = nz / n

      if ((gap < 1e-4) && (gap_theta < 1e-4)) {
        break
      }
      # new termination criterion
      if (prop_outlying >= 0.5) {
        break
      }
    }

    p = length(init_par)
    RSS = sum((r - gamma_old)^2)
    BIC = (n-p)*log(RSS/(n-p)) + (nz+1)*(log(n-p) + 1)

    BICs_isv[which(isvs == isv)] = BIC
    prop_outlying_isv[which(isvs == isv)] = prop_outlying
    par1_isv[which(isvs == isv)] = res$par[1]
    par2_isv[which(isvs == isv)] = res$par[2]
  }

  best_isv = isvs[which.min(BICs_isv)]

  n = ncol(y)
  dim_obs = nrow(y)
  par = init_par
  gamma = matrix(0, nrow = dim_obs, ncol = n)
  r = NA
  theta_old = par

  for (j in 1:B) {
    if (j != 1) {theta_old = res$par}
    res = stats::optim(
      par = par,
      fn = fn_filter_isv,
      y = y,
      gamma = gamma,
      build = function(x) build(x, isv = best_isv),
      return_obj = TRUE,
      method = "L-BFGS-B",
      lower = lower,
      upper = upper
      )

    if ((sum(res$par == lower) + sum(res$par == upper)) == 0) {
      par = res$par
    } else {
      par = init_par
    }

    filter_output = fn_filter_isv(res$par, y, gamma, function(x) build(x, isv = best_isv))
    r = y - filter_output$predicted_observations
    gamma_old = gamma
    gamma = matrix(0, nrow = dim_obs, ncol = n)
    gamma[,filter_output$mahalanobis_residuals > lambda] = r[,filter_output$mahalanobis_residuals > lambda]
    gap = max(abs(gamma - gamma_old))
    gap_theta = max(abs(res$par - theta_old))

    nz = sum(colSums(abs(gamma_old)) != 0)
    prop_outlying = nz / n

    if ((gap < 1e-4) && (gap_theta < 1e-4)) {
      break
    }
    # new termination criterion
    if (prop_outlying >= 0.5) {
      break
    }
  }

  p = length(init_par)
  RSS = sum((r - gamma_old)^2)
  BIC = (n-p)*log(RSS/(n-p)) + (nz+1)*(log(n-p) + 1)
  #negloglik = n*fn_filter_isv(model$par, gamma = gamma_old, y = y, return_obj = TRUE)

  return(list(
    "lambda" = lambda,
    "par" = res$par,
    "prop_outlying" = prop_outlying,
    "BIC" = BIC,
    "RSS" = RSS,
    "gamma" = gamma_old,
    "iterations" = j,
    "best_isv" = best_isv,
    "BICs_isv" = BICs_isv,
    "prop_outlying_isv" = prop_outlying_isv,
    "par1_isv" = par1_isv,
    "par2_isv" = par2_isv
    ))
}

fn_filter_isv = function(
    par,
    y,
    gamma,
    build,
    return_obj = FALSE
    ) {

  SSM_specs = build(par)

  Phi = SSM_specs$state_transition_matrix
  Sigma_w = SSM_specs$state_noise_var
  A = SSM_specs$observation_matrix
  Sigma_v = SSM_specs$observation_noise_var
  x_tt = SSM_specs$init_state_mean
  P_tt = SSM_specs$init_state_var

  n = ncol(y)
  dim_obs = nrow(y)
  dim_state = nrow(Phi)

  x_tt_1 = NA
  P_tt_1 = NA
  y_tt_1 = NA
  S_t = NA
  objective = 0

  if (!return_obj) {
    filtered_states = matrix(0, nrow = dim_state, ncol = n)
    filtered_observations = matrix(0, nrow = dim_obs, ncol = n)
    predicted_states = matrix(0, nrow = dim_state, ncol = n)
    predicted_observations = matrix(0, nrow = dim_obs, ncol = n)
    predicted_observations_var = list()
    mahalanobis_residuals = NA
  }

  for (t in 1:n) {
    x_tt_1 = Phi %*% x_tt
    P_tt_1 = Phi %*% P_tt %*% t(Phi) + Sigma_w
    y_tt_1 = A %*% x_tt_1
    S_t = A %*% P_tt_1 %*% t(A) + Sigma_v
    inv_S_t = solve(S_t)
    if (sum(abs(gamma[,t])) == 0) {
      K_t = P_tt_1 %*% t(A) %*% inv_S_t
      x_tt = x_tt_1 + K_t %*% (y[,t] - y_tt_1)
      P_tt = P_tt_1 - K_t %*% A %*% P_tt_1
    } else {
      x_tt = x_tt_1
      P_tt = P_tt_1
    }
    if (return_obj) {
      objective = objective + 1/(2*n) * ((sum(abs(gamma[,t])) == 0) * log(det(S_t)) + t(y[,t] - y_tt_1 - gamma[,t]) %*% inv_S_t %*% (y[,t] - y_tt_1 - gamma[,t]))
    } else {
      filtered_states[,t] = x_tt
      filtered_observations[,t] = A %*% x_tt
      predicted_states[,t] = x_tt_1
      predicted_observations[,t] = y_tt_1
      predicted_observations_var[[t]] = S_t
      mahalanobis_residuals[t] = drop(sqrt(t(y[,t] - y_tt_1) %*% inv_S_t %*% (y[,t] - y_tt_1)))
    }
  }

  if (return_obj) {
    return(objective)
  } else {
    return(list(
      "filtered_states" = filtered_states,
      "filtered_observations" = filtered_observations,
      "predicted_states" = predicted_states,
      "predicted_observations" = predicted_observations,
      "predicted_observations_var" = predicted_observations_var,
      "mahalanobis_residuals" = mahalanobis_residuals
    ))
  }
}




