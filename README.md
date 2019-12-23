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



