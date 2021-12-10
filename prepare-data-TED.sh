set -e
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
  *)
  POSITIONAL+=("$1")
  shift
  ;;
esac
done
set -- "${POSITIONAL[@]}"

src=$SRC
tgt=$TGT

lang=$SRC-$TGT

tmp=tmp
rm -rf tmp
mkdir tmp

echo "pre-processing train data..."
for l in $src $tgt; do
    f=train.tags.$lang.$l
    out=$tmp/train.$lang.$l

    cat $f | \
    grep -v '<url>' | \
    grep -v '<talkid>' | \
    grep -v '<keywords>' | \
    grep -v '<speaker>' | \
    grep -v '<reviewer>' | \
    grep -v '<translator>' | \
    grep -v '</translator>' | \
    grep -v '</reviewer>' | \
    sed -e 's/<title>//g' | \
    sed -e 's/<\/title>//g' | \
    sed -e 's/<description>//g' | \
    sed -e 's/<\/description>//g' > $out
    echo "$l done"
done


echo "pre-processing valid/test data..."
for l in $src $tgt; do
    for o in `ls IWSLT15.TED*.$l.xml`; do
    fname=${o##*/}
    f=$tmp/${fname%.*}
    echo $o $f
    grep '<seg id' $o | \
        sed -e 's/<seg id="[0-9]*">\s*//g' | \
        sed -e 's/\s*<\/seg>\s*//g' | \
        sed -e "s/\’/\'/g" > $f
    done
done

echo "creating dev..."
for l in $src $tgt; do

    cat $tmp/IWSLT15.TED.tst2010.$lang.$l \
        $tmp/IWSLT15.TED.tst2011.$lang.$l \
        > $tmp/valid.$lang.$l
done

echo "creating test..."
for l in $src $tgt; do

    cat $tmp/IWSLT15.TED.tst2012.$lang.$l \
        $tmp/IWSLT15.TED.tst2013.$lang.$l \
        > $tmp/test.$lang.$l
done
