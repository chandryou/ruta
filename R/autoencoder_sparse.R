#' Sparse autoencoder
#'
#' Creates a representation of a sparse autoencoder.
#' @param network Layer construct of class \code{"ruta_network"}
#' @param loss Character string specifying a loss function
#' @param high_probability Expected probability of the high value of the
#'   encoding layer. Set this to a value near zero in order to minimize
#'   activations in that layer.
#' @param weight The weight of the sparsity regularization
#' @return A construct of class \code{"ruta_autoencoder"}
#' @seealso \code{\link{sparsity}}, \code{\link{make_sparse}}, \code{\link{is_sparse}}
#' @export
autoencoder_sparse <- function(network, loss, high_probability = 0.1, weight = 0.2) {
  autoencoder(network, loss) %>%
    make_sparse(high_probability, weight)
}

#' Sparsity regularization
#'
#' @param high_probability Expected probability of the high value of the
#'   encoding layer. Set this to a value near zero in order to minimize
#'   activations in that layer.
#' @param weight The weight of the sparsity regularization
#' @return A Ruta regularizer object for the sparsity, to be inserted in the
#'   encoding layer.
#' @references Andrew Ng, Sparse Autoencoder.
#' \href{https://web.stanford.edu/class/cs294a/sparseAutoencoder_2011new.pdf}{CS294A Lecture Notes} (2011)
#' @seealso \code{\link{autoencoder_sparse}}, \code{\link{make_sparse}}, \code{\link{is_sparse}}
#' @export
sparsity <- function(high_probability, weight) {
  structure(
    list(
      high_probability = high_probability,
      weight = weight
    ),
    class = c(ruta_regularizer, ruta_sparsity)
  )
}

#' Add sparsity regularization to an autoencoder
#' @param learner A \code{"ruta_autoencoder"} object
#' @param high_probability Expected probability of the high value of the
#'   encoding layer. Set this to a value near zero in order to minimize
#'   activations in that layer.
#' @param weight The weight of the sparsity regularization
#' @return The same autoencoder with the sparsity regularization applied
#' @seealso \code{\link{sparsity}}, \code{\link{autoencoder_sparse}}, \code{\link{is_sparse}}
#' @export
make_sparse <- function(learner, high_probability = 0.1, weight = 0.2) {
  # TODO warn when activation function does not have well-defined low and high values
  learner$network[[learner$network %@% "encoding"]]$activity_regularizer <- sparsity(high_probability, weight)

  learner
}

#' Detect whether an autoencoder is sparse
#' @param learner A \code{"ruta_autoencoder"} object
#' @return Logical value indicating if a sparsity regularization in the encoding layer was found
#' @seealso \code{\link{sparsity}}, \code{\link{autoencoder_sparse}}, \code{\link{make_sparse}}
#' @export
is_sparse <- function(learner) {
  !is.null(learner$network[[learner$network %@% "encoding"]]$activity_regularizer)
}

#' Translate sparsity regularization to Keras regularizer
#' @param x Sparsity object
#' @param activation Name of the activation function used in the encoding layer
#' @return Function which can be used as activity regularizer in a Keras layer
#' @references Andrew Ng, Sparse Autoencoder.
#' \href{https://web.stanford.edu/class/cs294a/sparseAutoencoder_2011new.pdf}{CS294A Lecture Notes} (2011)
#' @export
to_keras.ruta_sparsity <- function(x, activation) {
  p_high = x$high_probability

  low_v = 0
  high_v = 1

  if (activation == "tanh") {
    low_v = -1
  }

  function(observed_activations) {
    observed <- observed_activations %>%
      keras::k_mean(axis = 0) %>%
      keras::k_clip(low_v + keras::k_epsilon(), high_v - keras::k_epsilon())

    # rescale means: what we want to calculate is the probability of a high value
    q_high <- (observed - low_v) / (high_v - low_v)

    keras::k_sum(
      # P(high) log P(high)/Q(high) +
      p_high * keras::k_log(p_high / q_high) +
      # P(low) log P(low)/P(low)
      (1 - p_high) * keras::k_log((1 - p_high) / (1 - q_high))
    )
  }
}
