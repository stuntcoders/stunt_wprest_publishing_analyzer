#!/bin/bash

if [ -z "$2" ]; then
	PROTOCOL="https"
else
	PROTOCOL=$2
fi

URL="https://$1/wp-json/wp/v2/posts?per_page=100"
URL2="https://$1/wp-json/wp/v2/posts?per_page=100&page=2"
STORAGE_FILE="$1.csv"
TEMP_FILE="$1.tmp"
CURRENT_Y_MONTH=$(date +"%Y-%m")

curl -s $URL | jsonv id,date > $STORAGE_FILE
curl -s $URL2 | jsonv id,date > $TEMP_FILE

awk -F "\"*T\"*" '{print $1}' $STORAGE_FILE > $TEMP_FILE
awk -F "\"*-\"*" '{print $1 "-" $2}' $STORAGE_FILE > $TEMP_FILE
mv $TEMP_FILE $STORAGE_FILE

sed 's/$/"/' $STORAGE_FILE > $TEMP_FILE
mv $TEMP_FILE $STORAGE_FILE

echo "ID,Date" | cat - $STORAGE_FILE > $TEMP_FILE
mv $TEMP_FILE $STORAGE_FILE

MINI=`csvstat -c 1 --min $STORAGE_FILE`
MAXI=`csvstat -c 1 --max $STORAGE_FILE`
COUN=`csvstat -c 1 --count $STORAGE_FILE | awk -F "\"* \"*" '{print $3}'`
MEDIAN_EDIT_PER_ARTICLE=$((($MINI+$MAXI)/$COUN))

MINI_D=`csvstat -c 2 --min $STORAGE_FILE`
MAXI_D=`csvstat -c 2 --max $STORAGE_FILE`

csvcut -c Date $STORAGE_FILE > $TEMP_FILE
mv $TEMP_FILE $STORAGE_FILE

mv $STORAGE_FILE data.csv
csvsql --query "SELECT Date, COUNT(*) AS 'Posts count' FROM data GROUP BY Date" data.csv > $STORAGE_FILE && rm data.csv

MEDI=`csvstat -c 2 --mean $STORAGE_FILE | awk '{print int($1)}'`

# Add missing dates from 2010 on
for year in `seq 2010 $(date +'%Y')`; do
    for month in `seq 01 12`; do
        DATEZ="$year-$(printf "%02d" $month)"

        if [ "$DATEZ" \< "$CURRENT_Y_MONTH" ]; then
            if [ ! -z $(grep "$DATEZ" "$STORAGE_FILE") ]; then D=1; else echo "$DATEZ,0" >> $STORAGE_FILE; fi
        fi
    done
done

# Sort by dates
csvsort -c 1 --reverse $STORAGE_FILE > $TEMP_FILE
mv $TEMP_FILE $STORAGE_FILE

echo "----------------"
echo "Median edits per article: $MEDIAN_EDIT_PER_ARTICLE"
echo "Total number of articles: $COUN"
echo "Median articles pr month: $MEDI"

echo "----------------"
echo "CSV with number of articles published per month can be found in following file: $STORAGE_FILE"
