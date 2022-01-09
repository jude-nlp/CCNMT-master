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
FULL_VOCAB=./data/raw/multi-domain-2-de/bpe_output/vocab

domains="news ted"

for domain in $domains; do
  echo "preprocess $domain";
  rm $DATA_PATH/$domain/*.pth
  for splt in train valid test; do
    python preprocess.py $FULL_VOCAB $DATA_PATH/$domain/$splt.de-en.en
    python preprocess.py $FULL_VOCAB $DATA_PATH/$domain/$splt.de-en.de
  done
done

# 改名字
echo "modify news name";
for splt in train valid test; do
  mv $DATA_PATH/news/$splt.de-en.en.pth $DATA_PATH/news/$splt.en-nw.en.pth 
  mv $DATA_PATH/news/$splt.de-en.de.pth $DATA_PATH/news/$splt.en-nw.nw.pth 
done

echo "modify ted name";
for splt in train valid test; do
  mv $DATA_PATH/ted/$splt.de-en.en.pth $DATA_PATH/ted/$splt.en-td.en.pth 
  mv $DATA_PATH/ted/$splt.de-en.de.pth $DATA_PATH/ted/$splt.en-td.td.pth 
done