#' @title Create the underlying node and edge data frames
#'   behind [vis_drake_graph()].
#' @description With the returned data frames,
#' you can plot your own custom `visNetwork` graph.
#' @export
#' @return A list of three data frames: one for nodes,
#'   one for edges, and one for
#'   the legend nodes. The list also contains the
#'   default title of the graph.
#' @seealso [vis_drake_graph()], [build_drake_graph()]
#' @param config a [drake_config()] configuration list.
#'   You can get one as a return value from [make()] as well.
#'
#' @param from Optional collection of target/import names.
#'   If `from` is nonempty,
#'   the graph will restrict itself to
#'   a neighborhood of `from`.
#'   Control the neighborhood with
#'   `mode` and `order`.
#'
#' @param mode Which direction to branch out in the graph
#'   to create a neighborhood around `from`.
#'   Use `"in"` to go upstream,
#'   `"out"` to go downstream,
#'   and `"all"` to go both ways and disregard
#'   edge direction altogether.
#'
#' @param order How far to branch out to create
#'   a neighborhood around `from` (measured
#'   in the number of nodes). Defaults to
#'   as far as possible.
#'
#' @param subset Optional character vector of of target/import names.
#'   Subset of nodes to display in the graph.
#'   Applied after `from`, `mode`, and `order`.
#'   Be advised: edges are only kept for adjacent nodes in `subset`.
#'   If you do not select all the intermediate nodes,
#'   edges will drop from the graph.
#'
#' @param targets_only logical,
#'   whether to skip the imports and only include the
#'   targets in the workflow plan.
#'
#' @param split_columns logical, deprecated.
#'
#' @param font_size numeric, font size of the node labels in the graph
#'
#' @param build_times character string or logical.
#'   If character, the choices are
#'     1. `"build"`: runtime of the command plus the time
#'       it take to store the target or import.
#'     2. `"command"`: just the runtime of the command.
#'     3. `"none"`: no build times.
#'   If logical, `build_times` selects whether to show the
#'   times from `build_times(..., type = "build")`` or use
#'   no build times at all. See [build_times()] for details.
#'
#' @param digits number of digits for rounding the build times
#'
#' @param from_scratch logical, whether to assume all the targets
#'   will be made from scratch on the next [make()].
#'   Makes all targets outdated, but keeps information about
#'   build progress in previous [make()]s.
#'
#' @param make_imports logical, whether to make the imports first.
#'   Set to `FALSE` to increase speed and risk using obsolete information.
#'
#' @param full_legend logical. If `TRUE`, all the node types
#'   are printed in the legend. If `FALSE`, only the
#'   node types used are printed in the legend.
#'
#' @param group optional character scalar, name of the column used to
#'   group nodes into columns. All the columns names of your `config$plan`
#'   are choices. The other choices (such as `"status"`) are column names
#'   in the `nodes` . To group nodes into clusters in the graph,
#'   you must also supply the `clusters` argument.
#'
#' @param clusters optional character vector of values to cluster on.
#'   These values must be elements of the column of the `nodes` data frame
#'   that you specify in the `group` argument to `drake_graph_info()`.
#'
#' @examples
#' \dontrun{
#' test_with_dir("Quarantine side effects.", {
#' load_mtcars_example() # Get the code with drake_example("mtcars").
#' config <- drake_config(my_plan) # my_plan loaded with load_mtcars_example()
#' vis_drake_graph(config) # Jump straight to the interactive graph.
#' # Get a list of data frames representing the nodes, edges,
#' # and legend nodes of the visNetwork graph from vis_drake_graph().
#' raw_graph <- drake_graph_info(config = config)
#' # Choose a subset of the graph.
#' smaller_raw_graph <- drake_graph_info(
#'   config = config,
#'   from = c("small", "reg2"),
#'   mode = "in"
#' )
#' # Inspect the raw graph.
#' str(raw_graph)
#' # Use the data frames to plot your own custom visNetwork graph.
#' # For example, you can omit the legend nodes
#' # and change the direction of the graph.
#' library(magrittr)
#' library(visNetwork)
#' visNetwork(nodes = raw_graph$nodes, edges = raw_graph$edges) %>%
#'   visHierarchicalLayout(direction = 'UD')
#' # Optionally visualize clusters.
#' config$plan$large_data <- grepl("large", config$plan$target)
#' graph <- drake_graph_info(
#'   config, group = "large_data", clusters = c(TRUE, FALSE))
#' tail(graph$nodes)
#' render_drake_graph(graph)
#' # You can even use clusters given to you for free in the `graph$nodes`
#' # data frame.
#' graph <- drake_graph_info(
#'   config, group = "status", clusters = "imported")
#' tail(graph$nodes)
#' render_drake_graph(graph)
#' })
#' }
drake_graph_info <- function(
  config = drake::read_drake_config(),
  from = NULL,
  mode = c("out", "in", "all"),
  order = NULL,
  subset = NULL,
  build_times = "build",
  digits = 3,
  targets_only = FALSE,
  split_columns = NULL,
  font_size = 20,
  from_scratch = FALSE,
  make_imports = TRUE,
  full_legend = FALSE,
  group = NULL,
  clusters = NULL
) {
  if (!length(V(config$graph)$name)){
    return(null_graph())
  }
  if (!is.null(split_columns)){
    warning("Argument split_columns is deprecated.", call. = FALSE)
  }
  config$build_times <- resolve_build_times(build_times)
  config$digits <- digits
  config$font_size <- font_size
  config$from_scratch <- from_scratch
  config$make_imports <- make_imports
  config$group <- group
  config$clusters <- clusters
  config <- get_raw_node_category_data(config)
  config$graph <- get_neighborhood(
    graph = config$graph,
    from = from,
    mode = match.arg(mode),
    order = order
  )
  config$graph <- subset_graph(graph = config$graph, subset = subset)
  if (targets_only){
    config$graph <- subset_graph(
      graph = config$graph,
      subset = config$plan$target
    )
  }
  network_data <- visNetwork::toVisNetworkData(config$graph)
  config$nodes <- merge(
    x = network_data$nodes,
    y = config$plan,
    by.x = "id",
    by.y = "target",
    all.x = TRUE
  )
  config <- trim_node_categories(config)
  config$nodes <- configure_nodes(config = config)
  config$edges <- network_data$edges
  if (nrow(config$edges)){
    config$edges$arrows <- "to"
  }
  if (length(config$group)){
    config <- cluster_nodes(config)
  }
  list(
    nodes = as_tibble(config$nodes),
    edges = as_tibble(config$edges),
    legend_nodes = filtered_legend_nodes(
      all_nodes = config$nodes,
      full_legend = full_legend,
      font_size = font_size
    ),
    default_title = default_graph_title(split_columns = split_columns)
  )
}
