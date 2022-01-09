#
# Read arguments
#
POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"
case $key in
  --path)
    DATA_PATH="$2"; shift 2;;
  *)
  POSITIONAL+=("$1")
  shift
  ;;
esac
done
set -- "${POSITIONAL[@]}"

# 二进制化
FULL_VOCAB=./data/raw/multi-domain-4-zh/bpe_output/vocab

domains="laws news spoken thesis"
domains_2="lw nw sp th"

for domain in $domains; do
  echo "preprocess $domain";
  rm $DATA_PATH/$domain/*.pth
  for splt in train valid test; do
    python preprocess.py $FULL_VOCAB $DATA_PATH/$domain/$splt.en-zh.en
    python preprocess.py $FULL_VOCAB $DATA_PATH/$domain/$splt.en-zh.zh
  done
done

# 改名字
echo "modify laws name";
for splt in train valid test; do
  mv $DATA_PATH/laws/$splt.en-zh.en.pth $DATA_PATH/laws/$splt.en-lw.en.pth 
  mv $DATA_PATH/laws/$splt.en-zh.zh.pth $DATA_PATH/laws/$splt.en-lw.lw.pth 
done
echo "modify news name";
for splt in train valid test; do
  mv $DATA_PATH/news/$splt.en-zh.en.pth $DATA_PATH/news/$splt.en-nw.en.pth 
  mv $DATA_PATH/news/$splt.en-zh.zh.pth $DATA_PATH/news/$splt.en-nw.nw.pth 
done
echo "modify spoken name";
for splt in train valid test; do
  mv $DATA_PATH/spoken/$splt.en-zh.en.pth $DATA_PATH/spoken/$splt.en-sp.en.pth 
  mv $DATA_PATH/spoken/$splt.en-zh.zh.pth $DATA_PATH/spoken/$splt.en-sp.sp.pth 
done
echo "modify thesis name";
for splt in train valid test; do
  mv $DATA_PATH/thesis/$splt.en-zh.en.pth $DATA_PATH/thesis/$splt.en-th.en.pth 
  mv $DATA_PATH/thesis/$splt.en-zh.zh.pth $DATA_PATH/thesis/$splt.en-th.th.pth 
done