set -e

N_THREADS=16    # number of threads in data preprocessing

#
# Read arguments
#
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"
case $key in
  --src)
    SRC="$2"; shift 2;;
  --tgt)
    TGT="$2"; shift 2;;
  --reload_codes)
    RELOAD_CODES="$2"; shift 2;;
  --reload_vocab)
    RELOAD_VOCAB="$2"; shift 2;;
  --prep)
    PREP="$2"; shift 2;;
  *)
  POSITIONAL+=("$1")
  shift
  ;;
esac
done
set -- "${POSITIONAL[@]}"

#
# Check parameters
#
if [ "$SRC" == "" ]; then echo "--src not provided"; exit; fi
if [ "$TGT" == "" ]; then echo "--tgt not provided"; exit; fi
if [ "$SRC" == "$TGT" ]; then echo "source and target cannot be identical"; exit; fi
if [ "$RELOAD_CODES" != "" ] && [ ! -f "$RELOAD_CODES" ]; then echo "cannot locate BPE codes"; exit; fi
if [ "$RELOAD_VOCAB" != "" ] && [ ! -f "$RELOAD_VOCAB" ]; then echo "cannot locate vocabulary"; exit; fi
if [ "$RELOAD_CODES" == "" -a "$RELOAD_VOCAB" != "" -o "$RELOAD_CODES" != "" -a "$RELOAD_VOCAB" == "" ]; then echo "BPE codes should be provided if and only if vocabulary is also provided"; exit; fi
if [ "$PREP" == "" ]; then echo "--prep not provided"; exit; fi

#
# Initialize tools and data paths
#

# main paths
MAIN_PATH=$PWD
TOOLS_PATH=$PWD/tools
DATA_PATH=$PWD/data
PROC_PATH=$DATA_PATH/processed/$SRC-$TGT
TMP=$PREP/tmp

if [ ! -d "$TMP" ]; then
  rm -rf $TMP
fi

# create paths
mkdir -p $TOOLS_PATH
mkdir -p $PROC_PATH
mkdir -p $TMP

# moses
MOSES=$TOOLS_PATH/mosesdecoder
REPLACE_UNICODE_PUNCT=$MOSES/scripts/tokenizer/replace-unicode-punctuation.perl
NORM_PUNC=$MOSES/scripts/tokenizer/normalize-punctuation.perl
REM_NON_PRINT_CHAR=$MOSES/scripts/tokenizer/remove-non-printing-char.perl
TOKENIZER=$MOSES/scripts/tokenizer/tokenizer.perl
INPUT_FROM_SGM=$MOSES/scripts/ems/support/input-from-sgm.perl
CLEAN=$MOSES/scripts/training/clean-corpus-n.perl

# fastBPE
FASTBPE_DIR=$TOOLS_PATH/fastBPE
FASTBPE=$TOOLS_PATH/fastBPE/fast

# BPE / vocab files 
BPE_CODES=$PROC_PATH/codes
SRC_VOCAB=$PROC_PATH/vocab.$SRC
TGT_VOCAB=$PROC_PATH/vocab.$TGT
FULL_VOCAB=$PROC_PATH/vocab.$SRC-$TGT

# train / valid / test parallel BPE data
PARA_SRC_TRAIN_BPE=$PROC_PATH/train.$SRC-$TGT.$SRC  # Update
PARA_TGT_TRAIN_BPE=$PROC_PATH/train.$SRC-$TGT.$TGT  # Update
PARA_SRC_VALID_BPE=$PROC_PATH/valid.$SRC-$TGT.$SRC
PARA_TGT_VALID_BPE=$PROC_PATH/valid.$SRC-$TGT.$TGT
PARA_SRC_TEST_BPE=$PROC_PATH/test.$SRC-$TGT.$SRC
PARA_TGT_TEST_BPE=$PROC_PATH/test.$SRC-$TGT.$TGT

# valid / test file raw data
unset PARA_SRC_TRAIN PARA_TGT_TRAIN PARA_SRC_VALID PARA_TGT_VALID PARA_SRC_TEST PARA_TGT_TEST    # Update

PARA_SRC_TRAIN_RAW=$PREP/train.$SRC-$TGT.$SRC
PARA_TGT_TRAIN_RAW=$PREP/train.$SRC-$TGT.$TGT
PARA_SRC_VALID_RAW=$PREP/valid.$SRC-$TGT.$SRC
PARA_TGT_VALID_RAW=$PREP/valid.$SRC-$TGT.$TGT
PARA_SRC_TEST_RAW=$PREP/test.$SRC-$TGT.$SRC
PARA_TGT_TEST_RAW=$PREP/test.$SRC-$TGT.$TGT

# tokenized data
PARA_SRC_TRAIN=$TMP/train.tok.$SRC
PARA_TGT_TRAIN=$TMP/train.tok.$TGT
PARA_SRC_VALID=$TMP/valid.tok.$SRC
PARA_TGT_VALID=$TMP/valid.tok.$TGT
PARA_SRC_TEST=$TMP/test.tok.$SRC
PARA_TGT_TEST=$TMP/test.tok.$TGT

# cleaned data
PARA_SRC_TRAIN_CLEAN=$TMP/train.tok.clean.$SRC
PARA_TGT_TRAIN_CLEAN=$TMP/train.tok.clean.$TGT

# preprocessing commands - special case for Romanian
if [ "$SRC" == "ro" ]; then
  SRC_PREPROCESSING="$REPLACE_UNICODE_PUNCT | $NORM_PUNC -l $SRC | $REM_NON_PRINT_CHAR | $NORMALIZE_ROMANIAN | $REMOVE_DIACRITICS | $TOKENIZER -l $SRC -no-escape -threads $N_THREADS"
else if [ "$SRC" == "zh" ]; then
  SRC_PREPROCESSING="$REPLACE_UNICODE_PUNCT | $NORM_PUNC -l $SRC | $REM_NON_PRINT_CHAR"
else
  SRC_PREPROCESSING="$REPLACE_UNICODE_PUNCT | $NORM_PUNC -l $SRC | $REM_NON_PRINT_CHAR |                                            $TOKENIZER -l $SRC -no-escape -threads $N_THREADS"
fi
if [ "$TGT" == "ro" ]; then
  TGT_PREPROCESSING="$REPLACE_UNICODE_PUNCT | $NORM_PUNC -l $TGT | $REM_NON_PRINT_CHAR | $NORMALIZE_ROMANIAN | $REMOVE_DIACRITICS | $TOKENIZER -l $TGT -no-escape -threads $N_THREADS"
else if [ "$TGT" == "zh" ]; then
  TGT_PREPROCESSING="$REPLACE_UNICODE_PUNCT | $NORM_PUNC -l $TGT | $REM_NON_PRINT_CHAR"
else
  TGT_PREPROCESSING="$REPLACE_UNICODE_PUNCT | $NORM_PUNC -l $TGT | $REM_NON_PRINT_CHAR |                                            $TOKENIZER -l $TGT -no-escape -threads $N_THREADS"
fi

# check valid and test files are here
if ! [[ -f "$PARA_SRC_TRAIN_RAW" ]]; then echo "$PARA_SRC_TRAIN_RAW is not found!"; exit; fi
if ! [[ -f "$PARA_TGT_TRAIN_RAW" ]]; then echo "$PARA_TGT_TRAIN_RAW is not found!"; exit; fi
if ! [[ -f "$PARA_SRC_VALID_RAW" ]]; then echo "$PARA_SRC_VALID_RAW is not found!"; exit; fi
if ! [[ -f "$PARA_TGT_VALID_RAW" ]]; then echo "$PARA_TGT_VALID_RAW is not found!"; exit; fi
if ! [[ -f "$PARA_SRC_TEST_RAW" ]];  then echo "$PARA_SRC_TEST_RAW is not found!";  exit; fi
if ! [[ -f "$PARA_TGT_TEST_RAW" ]];  then echo "$PARA_TGT_TEST_RAW is not found!";  exit; fi

echo "Tokenizing train data..."
eval "cat $PARA_SRC_TRAIN_RAW | $SRC_PREPROCESSING > $PARA_SRC_TRAIN"
eval "cat $PARA_TGT_TRAIN_RAW | $TGT_PREPROCESSING > $PARA_TGT_TRAIN"

echo "Tokenizing valid and test data..."
eval "cat $PARA_SRC_VALID_RAW | $SRC_PREPROCESSING > $PARA_SRC_VALID"  # Update 下同
eval "cat $PARA_TGT_VALID_RAW | $TGT_PREPROCESSING > $PARA_TGT_VALID"
eval "cat $PARA_SRC_TEST_RAW | $SRC_PREPROCESSING > $PARA_SRC_TEST"
eval "cat $PARA_TGT_TEST_RAW | $TGT_PREPROCESSING > $PARA_TGT_TEST"

# clean data $TMP/train.$SRC.tok
perl $CLEAN -ratio 1.5 $TMP/train.tok $SRC $TGT $TMP/train.tok.clean 1 250

# reload BPE codes
cd $MAIN_PATH
if [ ! -f "$BPE_CODES" ] && [ -f "$RELOAD_CODES" ]; then
  echo "Reloading BPE codes from $RELOAD_CODES ..."
  cp $RELOAD_CODES $BPE_CODES
fi

echo "Applying BPE to train files..."
$FASTBPE applybpe $PARA_SRC_TRAIN_BPE $PARA_SRC_TRAIN_CLEAN $BPE_CODES     # Update
$FASTBPE applybpe $PARA_TGT_TRAIN_BPE $PARA_TGT_TRAIN_CLEAN $BPE_CODES     # Update

# reload full vocabulary
cd $MAIN_PATH
if [ ! -f "$FULL_VOCAB" ] && [ -f "$RELOAD_VOCAB" ]; then
  echo "Reloading vocabulary from $RELOAD_VOCAB ..."
  cp $RELOAD_VOCAB $FULL_VOCAB
fi

echo "Applying BPE to valid and test files..."
$FASTBPE applybpe $PARA_SRC_VALID_BPE $PARA_SRC_VALID $BPE_CODES
$FASTBPE applybpe $PARA_TGT_VALID_BPE $PARA_TGT_VALID $BPE_CODES
$FASTBPE applybpe $PARA_SRC_TEST_BPE  $PARA_SRC_TEST  $BPE_CODES
$FASTBPE applybpe $PARA_TGT_TEST_BPE  $PARA_TGT_TEST  $BPE_CODES

echo "Done"

# echo "Binarizing data..."
# rm -f $PARA_SRC_TRAIN_BPE.pth $PARA_TGT_TRAIN_BPE.pth $PARA_SRC_VALID_BPE.pth $PARA_TGT_VALID_BPE.pth $PARA_SRC_TEST_BPE.pth $PARA_TGT_TEST_BPE.pth     # Update
# echo "Binarizing train data..."
# $MAIN_PATH/preprocess.py $FULL_VOCAB $PARA_SRC_TRAIN_BPE    # Update
# $MAIN_PATH/preprocess.py $FULL_VOCAB $PARA_TGT_TRAIN_BPE    # Update
# echo "Binarizing test data..."
# $MAIN_PATH/preprocess.py $FULL_VOCAB $PARA_SRC_VALID_BPE
# $MAIN_PATH/preprocess.py $FULL_VOCAB $PARA_TGT_VALID_BPE
# $MAIN_PATH/preprocess.py $FULL_VOCAB $PARA_SRC_TEST_BPE
# $MAIN_PATH/preprocess.py $FULL_VOCAB $PARA_TGT_TEST_BPE

#
# Summary
#
# echo ""
# echo "===== Data summary"
# echo "Parallel training data:"
# echo "    $SRC: $PARA_SRC_TRAIN_BPE.pth"
# echo "    $TGT: $PARA_TGT_TRAIN_BPE.pth"
# echo "Parallel validation data:"
# echo "    $SRC: $PARA_SRC_VALID_BPE.pth"
# echo "    $TGT: $PARA_TGT_VALID_BPE.pth"
# echo "Parallel test data:"
# echo "    $SRC: $PARA_SRC_TEST_BPE.pth"
# echo "    $TGT: $PARA_TGT_TEST_BPE.pth"
# echo ""