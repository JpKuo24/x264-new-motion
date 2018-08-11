#!/bin/bash

# --subme: 0 to 11.
# -m, --subme <integer>       Subpixel motion estimation and mode decision [7]
#                                   - 0: fullpel only (not recommended)
#                                   - 1: SAD mode decision, one qpel iteration
#                                   - 2: SATD mode decision
#                                   - 3-5: Progressively more qpel
#                                   - 6: RD mode decision for I/P-frames
#                                   - 7: RD mode decision for all frames
#                                   - 8: RD refinement for I/P-frames
#                                   - 9: RD refinement for all frames
#                                   - 10: QP-RD - requires trellis=2, aq-mode>0
#                                   - 11: Full RD: disable all early terminations
# --no-psy                Disable all visual optimizations that worsen
# --tune psnr: --no-psy --aq-mode 0

MV_CALC_ST=bestMv
SUB_ME=1
BFRAMES_NO=0
REF_FRAMES=0
GOP_SIZE=100
#ME_RANGE=24 #default

#MOTION_ESTIMATOR_BIN=/home/dsm/opencv-me
MOTION_ESTIMATOR_BIN=/mnt/hgfs/Ubuntu/DeepFlow_release2.0/deepflow2
TEST_NAME=test1

FLOW_FILES_DIR_NAME=flow
ROOT_DIR="/mnt/hgfs/Ubuntu"
X264_DIR=${ROOT_DIR}/x264
SINTEL_DIR="/home/dsm/MPI-Sintel/training"
FFMPEG=/usr/local/bin/ffmpeg # ffmpeg binary
OUTPUT_DIR="${ROOT_DIR}/ffmpeg_output_${TEST_NAME}" # for output from codec, and matlab script
OUTPUT_DIR_MAT="${ROOT_DIR}" # for output from codec, and matlab script
TEMP_MVS_DIR="/home/dsm/temp_flo"
USE_ORIG_MVS_FILE="/tmp/use_orig_mvs"
MVS_CALC_STRATEGY_FILE="/tmp/mvs_calc_strategy" # (mean median best-mv)
MVS_DECISION_METHOD_FILE="/tmp/mvs_decision_method" # (force hybrid)
EXTERNAL_ME_TYPE_FILE="/tmp/external_me_type" # no-export, raw, png (no-export: don't export motion compensated ref frames; png: export raw frames and convert them to pngs for any algo that requires pngs inputs; raw: only raw pxs, opencv can use raw frames as i added support for optimizations)

echo "mean" > $MVS_CALC_STRATEGY_FILE
echo "png" > $EXTERNAL_ME_TYPE_FILE
echo "force" > $MVS_DECISION_METHOD_FILE

# NOTE: offset for GT flow files is hardcoded as -1. see me.c

MATLAB_FILE="${OUTPUT_DIR_MAT}/matlab.m"

cp $MOTION_ESTIMATOR_BIN /tmp/me
mkdir -p $OUTPUT_DIR
rm -f $MATLAB_FILE

# make && install
cd $X264_DIR
make -j8 && sudo make install
if [ $? != 0 ]; then
    exit -1;
fi

CODEC=libx264
CODEC_OPTS="-x264opts no-psy=1:aq-mode=0:ref=${REF_FRAMES}:subme=${SUB_ME}:min-keyint=${GOP_SIZE}"

declare -a ARRAY_SEQS_TYPES=(final)

#declare -a ARRAY_SEQS=(alley_1 alley_2 ambush_2 ambush_4 ambush_5 ambush_6 ambush_7 bamboo_1 bamboo_2 bandage_1 bandage_2 cave_2 cave_4 market_2 market_5 market_6 mountain_1 shaman_2 shaman_3 sleeping_1 sleeping_2 temple_2 temple_3)
#declare -a ARRAY_FRAMES=(50 50 21 33 50 20 50 50 50 50 50 50 50 50 50 40 50 50 50 50 50 50 50)
declare -a ARRAY_SEQS=(temple_2) 
#declare -a ARRAY_SEQS=(alley_1 ambush_5 bamboo_2 market_5 mountain_1 shaman_3 sleeping_2 temple_2)
declare -a ARRAY_FRAMES=(50 50 50 50 50 50 50 50 50) 
declare -a ARRAY_MODS=(orig $TEST_NAME)
declare -a ARRAY_SEQ_ORDER=(fwd)

declare -a ARRAY_ME=("hex") #"dia" "umh" "esa" "tesa")
declare -a ARRAY_QP=(1 5 10 15 20 25 30 35 40 45)

for SEQ_TYPE in "${ARRAY_SEQS_TYPES[@]}"
do
    for SEQ_i in "${!ARRAY_SEQS[@]}"
    do
        MATLAB="\n\n"
        MATLAB_PLOT="plot("
        MATLAB_LEGEND="legend("

            for MOD in "${ARRAY_MODS[@]}"
            do
                if [ $MOD = "orig" ]; then
                    echo 1 > $USE_ORIG_MVS_FILE
                else
                    rm -f $USE_ORIG_MVS_FILE
                fi

                for SEQ_ORDER in "${ARRAY_SEQ_ORDER[@]}"
                do
                    SEQ=${ARRAY_SEQS[$SEQ_i]}
                    FRAMES=${ARRAY_FRAMES[$SEQ_i]}
                    printf "> %s type: %s, frames: %d, mod: %s\n" $SEQ $SEQ_TYPE $FRAMES $MOD
                    INPUT_YUV="${SINTEL_DIR}/${SEQ_ORDER}/${SEQ_TYPE}/${SEQ}/frame_%4d.png"

                    # copy motion vectors (flo)
                    rm -f ${TEMP_MVS_DIR}/*
                    if [ $MOD != "orig" ]; then
                        for ((i = 1; i < ${ARRAY_FRAMES[$SEQ_i]}; i++))
                        do
                            cp ${SINTEL_DIR}/${SEQ_ORDER}/${FLOW_FILES_DIR_NAME}/${SEQ}/frame_`printf '%04d' ${i}`.flo ${TEMP_MVS_DIR}/frame_`printf '%04d' ${i}`.flo
                        done
                    fi

                    for ME_METHOD in "${ARRAY_ME[@]}"
                    do
                        #generate a curve
                        PSNR_VALS=()
                        RATE_VALS=()
                        FILE_SIZES=()
                        IS_INTRA=()
                        IS_INTER=()
                        IS_SKIP=()
                        IS_OTHER_DIRECT=()
                        IS_OTHER_DIRECT_AND_SKIP=()
                        IS_OTHER_GMC_AND_SKIP=()
                        IS_OTHER_PCM=()
                        IS_OTHER_GMC=()
                        for QP in "${ARRAY_QP[@]}"
                        do
                            OUT_FILENAME_NOEXT=${OUTPUT_DIR}/${SEQ}_${SEQ_TYPE}_${MV_CALC_ST}_${ME_METHOD}_${MOD}_qp${QP}
                            echo -e "  >> \$FFmpeg -i ..${SEQ_TYPE}/${SEQ}/.. -c:v $CODEC $CODEC_OPTS -pix_fmt yuv420p \n             -bf $BFRAMES_NO -g $GOP_SIZE -qp $QP -me_method $ME_METHOD -psnr -threads 1 -frames $FRAMES \$out.mp4 -y"
                            $FFMPEG -i $INPUT_YUV -c:v $CODEC $CODEC_OPTS -pix_fmt yuv420p -bf $BFRAMES_NO -g $GOP_SIZE -qp $QP -me_method $ME_METHOD -psnr \
                            -threads 1 -frames $FRAMES \
                            -vstats_file ${OUT_FILENAME_NOEXT}_vstats.txt \
                            ${OUT_FILENAME_NOEXT}.mp4 -y 2>&1 |& tee ${OUT_FILENAME_NOEXT}.txt # > ${OUT_FILENAME_NOEXT}.txt
                            PSNR="`cat ${OUT_FILENAME_NOEXT}.txt | grep '] PSNR Mean' | sed -e 's/.*Avg:\([0-9]\+.[0-9]\+\).*kb\/s:\([0-9]\+.[0-9]\+\).*/\1/g'`"
                            if [ -z $PSNR ]; then
                                echo -e "\nError: Empty PSNR"
                                exit -1;
                            fi
                            PSNR_VALS+="${PSNR} "
                            RATE="`cat ${OUT_FILENAME_NOEXT}.txt | grep '] PSNR Mean' | sed -e 's/.*Avg:\([0-9]\+.[0-9]\+\).*kb\/s:\([0-9]\+.[0-9]\+\).*/\2/g'`"
                            RATE_VALS+="${RATE} "
                            printf "     >>> %s vs %s\n" $PSNR $RATE

                            FILE_SIZES+="`wc -c < ${OUT_FILENAME_NOEXT}.mp4` "

                            $FFMPEG -i ${OUT_FILENAME_NOEXT}.mp4 -vf codecview=mb=1 -f null - |& tee /tmp/ffmpeg_output_codecview.txt 2>&1 > /dev/null
                            IS_INTRA+="`grep -o IS_INTRA /tmp/ffmpeg_output_codecview.txt | wc -l` "
                            IS_INTER+="`grep -o IS_INTER /tmp/ffmpeg_output_codecview.txt | wc -l` "
                            IS_SKIP+="`grep -o IS_SKIP /tmp/ffmpeg_output_codecview.txt | wc -l` "
                            IS_OTHER_DIRECT+="`grep -o IS_OTHER_DIRECT_ONLY /tmp/ffmpeg_output_codecview.txt | wc -l` "
                            IS_OTHER_DIRECT_AND_SKIP+="`grep -o IS_OTHER_DIRECT_AND_SKIP /tmp/ffmpeg_output_codecview.txt | wc -l` "
                            IS_OTHER_GMC_AND_SKIP+="`grep -o IS_OTHER_GMC_AND_SKIP /tmp/ffmpeg_output_codecview.txt | wc -l` "
                            IS_OTHER_PCM+="`grep -o IS_OTHER_PCM /tmp/ffmpeg_output_codecview.txt | wc -l` "
                            IS_OTHER_GMC+="`grep -o IS_OTHER_GMC_ONLY /tmp/ffmpeg_output_codecview.txt | wc -l` "
                        done

                        MC_L1_V=${SEQ}_${SEQ_TYPE}_${MV_CALC_ST}_${ME_METHOD}_${MOD}
                        MC_L1="y_$MC_L1_V = [ ${PSNR_VALS}]"
                        MATLAB+="${MC_L1};\n"

                        MC_L1="x_$MC_L1_V = [ ${RATE_VALS}]"
                        MATLAB+="${MC_L1};\n"

                        MC_L1=" file_sizes__$MC_L1_V = [ ${FILE_SIZES}]"
                        MATLAB+="${MC_L1};\n"

                        MATLAB+=" IS_INTRA__${MC_L1_V} = [ ${IS_INTRA}];\n"
                        MATLAB+=" IS_INTER__${MC_L1_V} = [ ${IS_INTER}];\n"
                        MATLAB+=" IS_SKIP__${MC_L1_V} = [ ${IS_SKIP}];\n"
                        MATLAB+=" IS_OTHER_DIRECT__${MC_L1_V} = [ ${IS_OTHER_DIRECT}];\n"
                        MATLAB+=" IS_OTHER_DIRECT_AND_SKIP__${MC_L1_V} = [ ${IS_OTHER_DIRECT_AND_SKIP}];\n"
                        MATLAB+=" IS_OTHER_GMC_AND_SKIP__${MC_L1_V} = [ ${IS_OTHER_GMC_AND_SKIP}];\n"
                        MATLAB+=" IS_OTHER_PCM__${MC_L1_V} = [ ${IS_OTHER_PCM}];\n"
                        MATLAB+=" IS_OTHER_GMC__${MC_L1_V} = [ ${IS_OTHER_GMC}];\n"

                        if [ "$MATLAB_PLOT" != "plot(" ]; then MATLAB_PLOT+=", "; fi
                        MATLAB_PLOT+="x_$MC_L1_V, y_$MC_L1_V"
                        if [ "$MATLAB_LEGEND" != "legend(" ]; then MATLAB_LEGEND+=", "; fi
                        MATLAB_LEGEND+="'${SEQ} ${SEQ_TYPE} ${MV_CALC_ST} ${ME_METHOD} ${MOD}'"
                    done
                done
            done
        MATLAB+="\n"
        MATLAB+="figure();\n"
        MATLAB+="${MATLAB_PLOT});\n"
        MATLAB+="${MATLAB_LEGEND});\n"
        MATLAB+="title('${SEQ} ${SEQ_TYPE} ${MV_CALC_ST}');\n"

        echo -e "$MATLAB" |& tee -a $MATLAB_FILE
    done
done

cp $MATLAB_FILE ${OUTPUT_DIR}/matlab_${TEST_NAME}.m

rm -f /tmp/ffmpeg_output_codecview.txt
rm -f /tmp/ffmpeg_output.txt
rm -f $USE_ORIG_MVS_FILE
rm -f $MVS_CALC_STRATEGY_FILE
rm -f $EXTERNAL_ME_TYPE_FILE
rm -f $MVS_DECISION_METHOD_FILE

#matlab -nosplash -nodesktop -r "$MATLAB_FILE"
