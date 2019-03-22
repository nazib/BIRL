# SEE: https://github.com/jonclayden/RNiftyReg
# CMD>> Rscript scripts/Rscript/regist_niftyReg-elastic.r \
#                   data_images/rat-kidney_/scale-5pc/Rat_Kidney_HE.jpg \
#                   data_images/rat-kidney_/scale-5pc/Rat_Kidney_PanCytokeratin.jpg \
#                   data_images/rat-kidney_/scale-5pc/Rat_Kidney_HE.csv \
#                   output/

## Install packages if needed, then load them
# See: https://github.com/jonclayden/RNiftyReg
# install.packages(c("png", "jpeg", "OpenImageR" ,"devtools"))
# devtools::install_github("jonclayden/RNiftyReg")
library(OpenImageR)
library(methods)
library(RNiftyReg)
# require("png", "jpeg", "RNiftyReg")

args <- commandArgs(TRUE)
args

## Reference Image
pathImgA <- args[1]
## Moving Image
pathImgB <- args[2]
## Moving Landmarks
pathLnd <- args[3]
## output folder
outPath <- args[4]
outTime <- paste(outPath, 'time.txt', sep='')
outLnd <- paste(outPath, 'points.txt', sep='')
outImg <- paste(outPath, 'warped.jpg', sep='')

time.start <- Sys.time()

## Read images, and convert (naively) to greyscale by averaging the RGB channels
target <- rgb_2gray(readImage(pathImgA))
source <- rgb_2gray(readImage(pathImgB))

## NiftyReg supports max image size 2048, so any larger image has to be scaled
maxSize <- max(max(dim(target)), max(dim(source)))
scale <- maxSize / 2048.
if (scale > 1) {
    target <- resizeImage(target, floor(dim(target)[1] / scale), floor(dim(target)[2] / scale))
    source <- resizeImage(source, floor(dim(source)[1] / scale), floor(dim(source)[2] / scale))
}

initRes <- niftyreg.linear(source, target, scope="affine")
initRes$forwardTransforms[[1]]
## Register the images and retrieve the affine matrix
result <- niftyreg.nonlinear(source, target,
                             init=initRes$forwardTransforms,
                             symmetric=FALSE,
                             sourceMask=NULL,
                             nLevels=3,
                             maxIterations=300,
                             nBins=64,
                             bendingEnergyWeight=0.005,
                             jacobianWeight=0,
                             finalSpacing=c(5, 5, 5),
                             estimateOnly=FALSE,
                             verbose=TRUE)
result

## Export registration time
time.taken <- Sys.time() - time.start
cat(time.taken, file=outTime)

## Save image as bitmap
# png::writePNG(result$image, outImg)

clip_values <- function(x, a, b) {
    ifelse(x <= a,  a, ifelse(x >= b, b, x))
}

## Transform image
imgWarp <- applyTransform( forward(result) , source)
imgWarp <- clip_values(imgWarp, 0, 1)
if (scale > 1) {
    imgWarp <- resizeImage(imgWarp, round(dim(imgWarp)[1] * scale), round(dim(imgWarp)[2] * scale))
}
## Save image as bitmap
writeImage(imgWarp, outImg)

## Load landmarks from CSV
points <- as.matrix(read.table(pathLnd, skip=1, sep = ','))
points <- points[, c(3, 2)]
if (scale > 1) {
    points <- points / scale
}
## Transform points
pointsWarp <- applyTransform( forward(result) , points)
pointsWarp <- pointsWarp[, c(2,1)]
if (scale > 1) {
    pointsWarp <- pointsWarp * scale
}
## Save transformed points
cat('point\n',nrow(pointsWarp),'\n', file=outLnd)
write.table(pointsWarp, file=outLnd, sep = ' ', append=TRUE, row.names=FALSE, col.names=FALSE)

## Exit
quit('yes')
