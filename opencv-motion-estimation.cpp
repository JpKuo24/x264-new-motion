#include "opencv2/optflow.hpp"
#include "opencv2/video.hpp"
#include "opencv2/videoio.hpp"
#include <opencv2/opencv.hpp>
#include "opencv2/highgui.hpp"
#include "opencv2/imgproc.hpp"
#include "opencv2/objdetect/objdetect.hpp"
#include "opencv2/video/tracking.hpp"
#include <vector>
#include <stdio.h>
#include <iostream>

using namespace cv;
using namespace std;
using namespace optflow;

/* 
 * read the binary frame, each byte is uint8_t pixel luma value, next row is stride away.
 */
int read_frame_binary(Mat &mat, const char *filename, int stride, int height) {
    mat.create(height, stride, CV_8UC(1)); //rows, cols, type

    int length = stride * height;
    uint8_t *pixels = (uint8_t *) malloc(length * sizeof(uint8_t));

    FILE *file = fopen(filename, "rb");
    if (file == NULL) {
        printf("file pt is null\n");
        return 1;
    }

    int lr = fread(pixels, sizeof(uint8_t), length, file);
    if (lr != length) {
        printf("read pixels != length %d vs %d\n", lr, length);
        return 1;
    }

    for(int y = 0; y < mat.rows; y++)
        for(int x = 0; x < mat.cols; x++)
            mat.at<uint8_t>(y, x) = pixels[x + y*stride];

    return 0;
}

int main(int argc, char** argv) {
    int ret;
    Mat ref, enc, flow; //arg 1, 2, 3, stride, height

    if (argc != 6) {
        printf("error: invalid args count. args: <ref> <src/enc> <flow.flo> <stride> <height>\n");
        return 0;
    }

    const int stride = atoi(argv[4]);
    const int height = atoi(argv[5]);

    Ptr<DISOpticalFlow> algorithm = createOptFlow_DIS(DISOpticalFlow::PRESET_MEDIUM); //UTLRAFAST, FAST, MEDIUM

    //ref = imread(argv[1], CV_LOAD_IMAGE_COLOR);
    //resize(ref, ref, Size(640, 480));
    //cvtColor(ref, ref, COLOR_BGR2GRAY);

    //enc = imread(argv[2], CV_LOAD_IMAGE_COLOR);
    //resize(enc, enc, Size(640, 480));
    //cvtColor(enc, enc, COLOR_BGR2GRAY);

    if (ret = read_frame_binary(ref, argv[1], stride, height)) {
        printf("error reading frame: %s\n", argv[1]);
        return ret;
    }

    if (ret = read_frame_binary(enc, argv[2], stride, height)) {
        printf("error reading frame: %s\n", argv[2]);
        return ret;
    }

    algorithm->calc(ref, enc, flow);

    if (!writeOpticalFlow(argv[3], flow)) {
        printf("error writing optical flow\n");
        return 1;
    }

    return 0;
}
