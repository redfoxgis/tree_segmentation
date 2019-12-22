require(lidR) # Most of the LiDAR processing
require(rlas) # Necessary for writelax
require(rgdal) # Writing to shp or raster
require(tictoc) # for timing
require(sp) # A few spatial operations

# Input and output paths
files <- list.files(path="/Users/aaron/gdrive/projects/ubc_project/data/las_2018", pattern="*.las", full.names=TRUE, recursive=FALSE)
outws <- "/Users/aaron/Desktop/temp/ubc_trees_shp"

lasfilternoise <- function(las, sensitivity){
  # Create a function to filter noise from point cloud
  # https://cran.r-project.org/web/packages/lidR/vignettes/lidR-catalog-apply-examples.html
  p95 <- grid_metrics(las, ~quantile(Z, probs = 0.95), 10)
  las <- lasmergespatial(las, p95, "p95")
  las <- lasfilter(las, Z < p95*sensitivity)
  las$p95 <- NULL
  return(las)
}

normalize <- function(las_denoised, f){
  # Normalize data 
  las_dtm <- readLAS(f)
  dtm <- grid_terrain(las_dtm, algorithm = knnidw(k = 8, p = 2))
  las_normalized <- lasnormalize(las_denoised, dtm)
  return(las_normalized)
}

chm <- function(las_normalized){
  # Generate a normalized canopy height model ~198 seconds
  # https://github.com/Jean-Romain/lidR/wiki/Segment-individual-trees-and-compute-metrics
  algo <- pitfree(thresholds = c(0,10,20,30,40,50), subcircle = 0.2)
  chm  <- grid_canopy(las_normalized, 0.5, algo)
  
  # Smooth the CHM with double pass median filter
  ker <- matrix(1,3,3)
  chm_s <- focal(chm, w = ker, fun = median)
  chm_s <- focal(chm, w = ker, fun = median)
  return(chm_s)
}

treeseg <- function(canopy_height_model, las_normalized){
  # tree segmentation
  algo <- watershed(canopy_height_model, th = 4)
  las_watershed  <- lastrees(las_normalized, algo)
  
  # remove points that are not assigned to a tree
  trees <- lasfilter(las_watershed, !is.na(treeID))
  return(trees)
}

tree_hull_polys <- function(las_trees){
  # Generate polygon tree canopies
  hulls  <- tree_hulls(las_trees, type = "convex", func = .stdmetrics)
  hulls_sub <- subset(hulls, area <1200 & area > 3)
  return(hulls_sub)
}

counter <- 1

for (f in files) {
  tic(paste(basename(f), "processed"))
  # Read in las file and write index file
  print(paste("Reading ", basename(f), " | ", counter, " of ", length(files)))
  las <- readLAS(f, filter="-drop_class 1 3 4 6 7 8 9") # read las and keep class 2 (bare earth) and 5 (trees) classes
  writelax(f) # Create a spatial index file (.lax) to speed up processing

  print("Filtering noise...")
  las_denoised <- lasfilternoise(las, sensitivity = 1.2)
  print("Normalizing...")
  las_normalized <- normalize(las_denoised, f)
  print("Generating CHM...")
  canopy_height_model <- chm(las_normalized)
  print("Tree Segmentation...")
  las_trees <- treeseg(canopy_height_model, las_normalized)
  print("Generating Tree hulls...")
  final_tree_hulls <- tree_hull_polys(las_trees)
  print("Writing to shp...")
  # Write to shapefile
  writeOGR(obj = final_tree_hulls, dsn = outws, layer = tools::file_path_sans_ext(basename(f)), driver = "ESRI Shapefile")
  toc()
  counter <- counter + 1
  print("On to the next las...")
}

print("Processing complete.")