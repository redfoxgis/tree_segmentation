# Tree Segmentation
This is the code repository for the UBC Tree Project. The purpose fo this repository:

- To document detailed steps in processing LiDAR.
- To visualize results.
- To provide code to segment and create tree hulls.

![Image of lastrees output](./media/trees.png)

## Dependencies
* lidR        (2.14+)
* rlas        (1.3.4+)
* rgdal       (1.4-8+)
* tictoc      (1.0+)
* sp          (1.3-2+)
* concaveman  (1.0.0+)

## Processing LiDAR point cloud data

This tutorial builds on a `lidR` tutorial called [Segment individual trees and compute metrics](https://github.com/Jean-Romain/lidR/wiki/Segment-individual-trees-and-compute-metrics) by exploring in-depth the process of preparing the raw point cloud prior to tree segmentation. 

### Downloading data
Let's start a las tile from the UBC campus with a nice mixture of buildings and trees. The City of Vancouver has a really nice web interface:

![City of Vancouver LiDAR Web Server](./media/lidar_server.png)

For this tutorial, we are going to download and work with [tile 4810E_54560N](https://webtransfer.vancouver.ca/opendata/2018LiDAR/4810E_54560N.zip)

Before we even unzip the downloaded file, let's inspect all of the available metadata to get a sense of how much we know about the data. Luckily, the web interface has a [nice metadata page](https://opendata.vancouver.ca/explore/dataset/lidar-2018/information/?location=12,49.2594,-123.14438). We can see from the metadata a few important features:

- The projected coordinate system is NAD 83 UTM Zone 13N
- Points density is 30 pts / m^2
- Data was acquired from August 27th and August 28th, 2018
- Points were classified as follows

      1. Unclassified;
      2. Bare-earth and low grass;
      3. Low vegetation (height <2m);
      4. High vegetation (height <2m);
      5. Water;
      6. Buildings;
      7. Other; and
      8. Noise (noise points, blunders, outliners, etc)
      
### Inspecting the point cloud data
Now we will begin inspecting the raw point cloud data using the R package `lidR`.


