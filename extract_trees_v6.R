require(lidR)
require(rlas) # Necessary for writelax
require(rgdal) # Writing to shp or raster
require(matlab) # for tic() toc() function

# define the las file
data <- '/Users/aaron/gdrive/projects/ubc_project/data/las_2018/4810E_54570N.las'
writelax(data) # Create a spatial index file (.lax) to speed up processing
las <- readLAS(data, filter="-drop_class 1 3 4 6 7 8 9")

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
#plot(las, color = "Classification") # Plot the points with colored classes

# Normalize data (try reading las file in using only ground points readlas())
las_dtm <- readLAS(data, filter="-drop_class 1 3 4 5 6 7 8 9")
dtm <- grid_terrain(las_dtm, algorithm = knnidw(k = 8, p = 2))
las_normalized <- lasnormalize(las_denoised, dtm)

# Inspect the normalized las file
plot(las_normalized)
summary(las_normalized)

# Generate a normalized CHM ~675 seconds
tic()
chm  <- grid_canopy(las_normalized, 0.25, pitfree(c(0,2,5,10,15), c(0,1), subcircle = 0.2))
toc()
plot(chm)

# Watershed segmentation ~993 seconds
tic()
algo <- watershed(chm, th = 4)
las_watershed  <- lastrees(las_normalized, algo)
toc()

# remove points that are not assigned to a tree
trees <- lasfilter(las_watershed, !is.na(treeID))

# View the results
plot(trees, color = "treeID", colorPalette = pastel.colors(100))

# Generate tree hulls and standard metrics ~29 seconds
tic()
hulls  = tree_hulls(trees, type = "concav", func = .stdmetrics)
toc()
spplot(hulls, "zmax")

# Subset hulls to retain polygons meeting certain criteria
sub = subset(hulls, area <100)

# Write to shapefile
writeOGR(obj=hulls, dsn="/Users/aaron/Desktop/temp/ubc_temp", layer="hulls-bbox", driver="ESRI Shapefile") # this is in geographical projection

