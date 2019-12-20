require(lidR)
require(rlas) # Necessary for writelax
require(rgdal) # Writing to shp or raster
require(matlab) # for tic() toc() function
require(sp)

# https://stackoverflow.com/a/14958740/1446289

files <- list.files(path="/Users/aaron/Desktop/temp/ubc_temp/subset", pattern="*.las", full.names=TRUE, recursive=FALSE)

merged_hulls <- SpatialPolygonsDataFrame(SpatialPolygons(list()), data=data.frame())

# apply function
# Create a function to filter noise from point cloud
# https://cran.r-project.org/web/packages/lidR/vignettes/lidR-catalog-apply-examples.html
lasfilternoise <- function(las, sensitivity){
  p95 <- grid_metrics(las, ~quantile(Z, probs = 0.95), 10)
  las <- lasmergespatial(las, p95, "p95")
  las <- lasfilter(las, Z < p95*sensitivity)
  las$p95 <- NULL
  return(las)
}

normalize <- function(las_denoised, f){
  # Normalize data (try reading las file in using only ground points readlas())
  las_dtm <- readLAS(f)
  # For error: https://github.com/Jean-Romain/lidR/issues/184
  dtm <- grid_terrain(las_dtm, algorithm = knnidw(k = 8, p = 2))
  las_normalized <- lasnormalize(las_denoised, dtm)
  return(las_normalized)
}

chm <- function(las_normalized){
  # Generate a normalized CHM ~198 seconds
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
  algo <- watershed(canopy_height_model, th = 4)
  las_watershed  <- lastrees(las_normalized, algo)
  
  # remove points that are not assigned to a tree
  trees <- lasfilter(las_watershed, !is.na(treeID))
  return(trees)
}

tree_hulls <- function(las_trees){
  hulls  <- tree_hulls(trees, type = "convex", func = .stdmetrics)
  hulls_sub <- subset(hulls, area <1200 & area > 3)
  return(hulls_sub)
}

for (f in files) {
  print(f)
  print("Reading las")
  las <- readLAS(f, filter="-drop_class 1 3 4 6 7 8 9") # read las and keep class 2 (bare earth) and 5 (trees) classes
  writelax(f) # Create a spatial index file (.lax) to speed up processing

  print("Filtering noise...")
  las_denoised <- lasfilternoise(las, sensitivity = 1.2)
  print("Normalizing...")
  las_normalized <- normalize(las_denoised, f)
  print("Normalizing complete.")
  print("Generating CHM...")
  canopy_height_model <- chm(las_normalized)
  print("Tree Segmentation...")
  las_trees <- treeseg(canopy_height_model, las_normalized)
  print("Tree hulls...")
  final_tree_hulls <- tree_hulls(las_trees)
  print("Merge hulls...")
  merge_hulls <- rbind(final_tree_hulls, merged_hulls, makeUniqueIDs = TRUE)

}