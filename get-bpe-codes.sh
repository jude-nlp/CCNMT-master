# 1. concat 分别所有的数据
# 2. tokenize
# 3. learn BPE
# 4. apply BPE
# 5. get vocab

# usage  sh get-bpe-codes.sh --src en --tgt zh --prep ./data/raw/multi-domain-4-zh
set -e

N_THREADS=16    # number of threads in data preprocessing
CODES=30000
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
if [ "$PREP" == "" ]; then echo "--prep not provided"; exit; fi

# main paths
MAIN_PATH=$PWD
TOOLS_PATH=$PWD/tools
DATA_PATH=$PWD/data
PROC_PATH=$DATA_PATH/processed/$SRC-$TGT

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

if [ -d $PREP/bpe_output ];then
    rm -rf $PREP/bpe_output
fi
mkdir -p $PREP/bpe_output

# raw file
SRC_RAW=$PREP/bpe_output/all.$SRC
TGT_RAW=$PREP/bpe_output/all.$TGT
SRC_TOK=$SRC_RAW.tok
TGT_TOK=$TGT_RAW.tok
SRC_TRAIN_BPE=$SRC_RAW.bpe
TGT_TRAIN_BPE=$TGT_RAW.bpe

BPE_CODES=$PREP/bpe_output/codes
FULL_VOCAB=$PREP/bpe_output/vocab


# preprocessing commands - special case for Romanian
if [ "$SRC" == "ro" ]; then
  SRC_PREPROCESSING="$REPLACE_UNICODE_PUNCT | $NORM_PUNC -l $SRC | $REM_NON_PRINT_CHAR | $NORMALIZE_ROMANIAN | $REMOVE_DIACRITICS | $TOKENIZER -l $SRC -no-escape -threads $N_THREADS"
elif [ "$SRC" == "zh" ]; then
  SRC_PREPROCESSING="$REPLACE_UNICODE_PUNCT | $NORM_PUNC -l $SRC | $REM_NON_PRINT_CHAR"
else
  SRC_PREPROCESSING="$REPLACE_UNICODE_PUNCT | $NORM_PUNC -l $SRC | $REM_NON_PRINT_CHAR |                                            $TOKENIZER -l $SRC -no-escape -threads $N_THREADS"
fi
if [ "$TGT" == "ro" ]; then
  TGT_PREPROCESSING="$REPLACE_UNICODE_PUNCT | $NORM_PUNC -l $TGT | $REM_NON_PRINT_CHAR | $NORMALIZE_ROMANIAN | $REMOVE_DIACRITICS | $TOKENIZER -l $TGT -no-escape -threads $N_THREADS"
elif [ "$TGT" == "zh" ]; then
  TGT_PREPROCESSING="$REPLACE_UNICODE_PUNCT | $NORM_PUNC -l $TGT | $REM_NON_PRINT_CHAR"
else
  TGT_PREPROCESSING="$REPLACE_UNICODE_PUNCT | $NORM_PUNC -l $TGT | $REM_NON_PRINT_CHAR |                                            $TOKENIZER -l $TGT -no-escape -threads $N_THREADS"
fi

# concatenate monolingual data files
if [[ -f "$SRC_RAW" ]]; then
    rm $SRC_RAW
fi
if [[ -f "$TGT_RAW" ]]; then
    rm $TGT_RAW
fi
for domain in $(ls $PREP); do
  if [ -d $PREP/$domain ];then
    if [ -f $PREP/$domain/train*$SRC ];then
      cat $PREP/$domain/train*$SRC  >> $SRC_RAW
      cat $PREP/$domain/train*$TGT  >> $TGT_RAW
    fi
  fi
done


echo "$SRC monolingual data concatenated in: $SRC_RAW"
echo "$TGT monolingual data concatenated in: $TGT_RAW"

# tokenize data
if ! [[ -f "$SRC_TOK" ]]; then
  echo "Tokenize $SRC monolingual data..."
  eval "cat $SRC_RAW | $SRC_PREPROCESSING > $SRC_TOK"
fi

if ! [[ -f "$TGT_TOK" ]]; then
  echo "Tokenize $TGT monolingual data..."
  eval "cat $TGT_RAW | $TGT_PREPROCESSING > $TGT_TOK"
fi
echo "$SRC monolingual data tokenized in: $SRC_TOK"
echo "$TGT monolingual data tokenized in: $TGT_TOK"

# learn BPE codes
if [ ! -f "$BPE_CODES" ]; then
  echo "Learning BPE codes..."
  $FASTBPE learnbpe $CODES $SRC_TOK $TGT_TOK > $BPE_CODES
fi
echo "BPE learned in $BPE_CODES"

# apply BPE codes
if ! [[ -f "$SRC_TRAIN_BPE" ]]; then
  echo "Applying $SRC BPE codes..."
  $FASTBPE applybpe $SRC_TRAIN_BPE $SRC_TOK $BPE_CODES
fi
if ! [[ -f "$TGT_TRAIN_BPE" ]]; then
  echo "Applying $TGT BPE codes..."
  $FASTBPE applybpe $TGT_TRAIN_BPE $TGT_TOK $BPE_CODES
fi
echo "BPE codes applied to $SRC in: $SRC_TRAIN_BPE"
echo "BPE codes applied to $TGT in: $TGT_TRAIN_BPE"

# extract full vocabulary
if ! [[ -f "$FULL_VOCAB" ]]; then
  echo "Extracting vocabulary..."
  $FASTBPE getvocab $SRC_TRAIN_BPE $TGT_TRAIN_BPE > $FULL_VOCAB
fi
echo "Full vocab in: $FULL_VOCAB"