# x264 - Tests with modern Optical Flow algorithms
We tested modern optical flow algorithms that are listed here: http://sintel.is.tue.mpg.de/results

Results are evaluated in the Paper: **Using modern motion estimation algorithms in existing video codecs** - *Daniel J. Ringis, Davinder Singh, Francois Pitie, Anil Kokaram. SPIE 2018.*

## Installing
Install it with FFmpeg (for decoders mainly, though x264 has CLI).

The external motion estimation algorithm is called by x264 as a system call. Doing so gives us a way to use existing code for optical flow reasearch papers without reimplementing it again.

Compile the external motion estimator, say we wanna use OpenCV's DISFlow:
```
g++ opencv-motion-estimation.cpp -o ~/opencv-me `pkg-config --libs opencv`
```
Update the binary path in test-suite.sh
```
MOTION_ESTIMATOR_BIN=~/opencv-me
```

Compile frame-bin-to-png.c if external motion estimator needs png as input. 
```
gcc frame-bin-to-png.c -o ~/frame-bin-to-png `pkg-config --libs libpng`
```

## Running the tests
We generate the RD curves by varying the QP from 5 to 45 in steps of 5. The automated test suite generates a MATLAB script to plot graphs comparing the average PSNR and average bitrates when using x264's internal motion estimator (say hex) vs. when using external optical flow algorithm e.g. OpenCV's DISFlow or DeepFlow.
```
$ ./test-suite.sh
```
