# 二进制化
FULL_VOCAB=data/multi-domain-3/vocab
DATA_PATH=data/processed/multi-domain-3

domains="emea gnome jrc"
domains_2="ma gm jc"

for domain in $domains; do
  echo "preprocess $domain";
  rm $DATA_PATH/$domain/*.pth
  for splt in train valid test; do
    python preprocess.py $FULL_VOCAB $DATA_PATH/$domain/$splt.en-fr.en
    python preprocess.py $FULL_VOCAB $DATA_PATH/$domain/$splt.en-fr.fr
  done
done

# 改名字
echo "modify emea name";
for splt in train valid test; do
  mv $DATA_PATH/emea/$splt.en-fr.en.pth $DATA_PATH/emea/$splt.en-ma.en.pth 
  mv $DATA_PATH/emea/$splt.en-fr.fr.pth $DATA_PATH/emea/$splt.en-ma.ma.pth 
done
echo "modify gnome name";
for splt in train valid test; do
  mv $DATA_PATH/gnome/$splt.en-fr.en.pth $DATA_PATH/gnome/$splt.en-gm.en.pth 
  mv $DATA_PATH/gnome/$splt.en-fr.fr.pth $DATA_PATH/gnome/$splt.en-gm.gm.pth 
done
echo "modify jrc name";
for splt in train valid test; do
  mv $DATA_PATH/jrc/$splt.en-fr.en.pth $DATA_PATH/jrc/$splt.en-jc.en.pth 
  mv $DATA_PATH/jrc/$splt.en-fr.fr.pth $DATA_PATH/jrc/$splt.en-jc.jc.pth 
done