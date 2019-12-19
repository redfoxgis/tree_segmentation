require(lidR)
require(rlas) # Necessary for writelax
require(rgdal) # Writing to shp or raster
require(matlab) # for tic() toc() function

# define the las file
data <- '/Users/aaron/gdrive/projects/ubc_project/data/las_2018/4810E_54570N.las'
las <- readLAS(data, filter="-drop_class 1 3 4 6 7 8 9") # read las and keep class 2 (bare earth) and 5 (trees) classes
writelax(data) # Create a spatial index file (.lax) to speed up processing

# Create a function to filter noise from point cloud
# https://cran.r-project.org/web/packages/lidR/vignettes/lidR-catalog-apply-examples.html
lasfilternoise = function(las, sensitivity)
{
  p95 <- grid_metrics(las, ~quantile(Z, probs = 0.95), 10)
  las <- lasmergespatial(las, p95, "p95")
  las <- lasfilter(las, Z < p95*sensitivity)
  las$p95 <- NULL
  return(las)
}

las_denoised <- lasfilternoise(las, sensitivity = 1.2)

# Inspect our las file
lascheck(las)
summary(las)
plot(las, color = "Classification") # Plot the points with colored classes

# Normalize data (try reading las file in using only ground points readlas())
las_dtm <- readLAS(data, filter="-drop_class 1 3 4 5 6 7 8 9")
dtm <- grid_terrain(las_dtm, algorithm = knnidw(k = 8, p = 2))
las_normalized <- lasnormalize(las_denoised, dtm)

# Inspect the normalized las file
lascheck(las_normalized)
plot(las_normalized)
summary(las_normalized)

# Generate a normalized CHM ~198 seconds
# https://github.com/Jean-Romain/lidR/wiki/Segment-individual-trees-and-compute-metrics
tic()
algo <- pitfree(thresholds = c(0,10,20,30,40,50), subcircle = 0.2)
chm  <- grid_canopy(las_normalized, 0.5, algo)
toc()
plot(chm)

# smoothing post-process (e.g. two pass, 3x3 median convolution) ~220 seconds
tic()
ker <- matrix(1,3,3)
chm_s <- focal(chm, w = ker, fun = median)
chm_s <- focal(chm, w = ker, fun = median)
toc()

plot(chm, col = height.colors(50)) # check the image
writeRaster(chm_s,"/Users/aaron/Desktop/temp/ubc_temp/chm_med_filter_0p5.tif", options=c('TFW=YES')) # Sanity check

# Watershed segmentation ~68 seconds
tic()
algo <- watershed(chm, th = 4)
las_watershed  <- lastrees(las_normalized, algo)
toc()

# remove points that are not assigned to a tree
trees <- lasfilter(las_watershed, !is.na(treeID))

# View the results
plot(trees, color = "treeID", colorPalette = pastel.colors(100))

# Generate tree hulls and standard metrics ~39 seconds
tic()
hulls  = tree_hulls(trees, type = "convex", func = .stdmetrics)
toc()
spplot(hulls, "zmax")

# Subset hulls to retain polygons meeting certain criteria (This filters out error polygons)
sub = subset(hulls, area <1200 & area > 3)

# Write to shapefile (Sanity check)
writeOGR(obj=sub, dsn="/Users/aaron/Desktop/temp/ubc_temp", layer="hulls-subset-0p5-v3", driver="ESRI Shapefile") # this is in geographical projection

# Detect trees (Optional, just to get tree centers)
# variable windows size
f <- function(x) { x * 0.07 + 3}
ttops <- tree_detection(las, lmf(f))
writeOGR(obj=ttops, dsn="/Users/aaron/Desktop/temp/ubc_temp", layer="treetops", driver="ESRI Shapefile") # Sanity check
