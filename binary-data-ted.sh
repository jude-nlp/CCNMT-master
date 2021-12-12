# 二进制化
FULL_VOCAB=data/iwslt15/vocab
DATA_PATH=data/processed/iwslt15-4

langs="cs de fr zh"

for tgt in $langs; do
  echo "preprocess en-$tgt";
  rm $DATA_PATH/en-$tgt/*.pth
  for splt in train valid test; do
    python preprocess.py $FULL_VOCAB $DATA_PATH/en-$tgt/$splt.en-$tgt.$tgt
    python preprocess.py $FULL_VOCAB $DATA_PATH/en-$tgt/$splt.en-$tgt.en
    if [ "$tgt" == "de" -o  "$tgt" == "cs" ]; then
      echo "modify name $tgt";
      mv $DATA_PATH/en-$tgt/$splt.en-$tgt.$tgt.pth $DATA_PATH/en-$tgt/$splt.$tgt-en.$tgt.pth
      mv $DATA_PATH/en-$tgt/$splt.en-$tgt.en.pth $DATA_PATH/en-$tgt/$splt.$tgt-en.en.pth
    fi
  done
done